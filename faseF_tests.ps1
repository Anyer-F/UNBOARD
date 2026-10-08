$ErrorActionPreference = "Continue"
$base = "http://localhost:8081/api"
Add-Type -AssemblyName System.Net.Http
$global:pass = 0
$global:fail = 0
$global:errores = @()

function Req($method, $url, $headers, $body) {
  try {
    if ($null -ne $body) {
      $resp = Invoke-WebRequest -Method $method -Uri $url -Headers $headers -ContentType "application/json" -Body $body -UseBasicParsing -TimeoutSec 30
    } else {
      $resp = Invoke-WebRequest -Method $method -Uri $url -Headers $headers -UseBasicParsing -TimeoutSec 30
    }
    return @{ Status = [int]$resp.StatusCode; Body = $resp.Content }
  } catch {
    $r = $_.Exception.Response
    if ($null -ne $r) {
      try {
        $sr = New-Object IO.StreamReader($r.GetResponseStream())
        $txt = $sr.ReadToEnd()
      } catch { $txt = "" }
      return @{ Status = [int]$r.StatusCode; Body = $txt }
    }
    return @{ Status = 0; Body = $_.Exception.Message }
  }
}

function Check($name, $expected, $actual) {
  if ($expected -eq $actual) {
    $global:pass++
    Write-Host "PASS: $name" -ForegroundColor Green
  } else {
    $global:fail++
    Write-Host "FAIL: $name (esperado $expected, obtenido $actual)" -ForegroundColor Red
    $global:errores += $name
  }
}

function Sql-Output($sql) {
  # -q (quiet) suprime el tag "INSERT 0 1" que psql imprime junto al RETURNING
  $salida = (docker exec unbound_db psql -U postgres -d unbound -t -A -q -c $sql 2>$null | Out-String)
  return $salida.Trim()
}

# PS 5.1: @($json | ConvertFrom-Json) produce un array ANIDADO y el
# return de una función desenvuelve colecciones. El operador coma (,)
# garantiza que siempre se devuelva un array plano real.
function Parse-Json($json) {
  if ([string]::IsNullOrWhiteSpace($json)) { return ,@() }
  $result = $json | ConvertFrom-Json
  if ($null -eq $result) { return ,@() }
  if ($result -is [array]) { return ,$result }
  return ,@($result)
}

function Upload-Multipart($url, $authToken, $filePath, $titulo, $descripcion, $comunidadId) {
  try {
    $client = New-Object System.Net.Http.HttpClient
    $client.Timeout = [System.TimeSpan]::FromSeconds(60)
    if ($authToken) {
      $client.DefaultRequestHeaders.Authorization =
        [System.Net.Http.Headers.AuthenticationHeaderValue]::Parse("Bearer $authToken")
    }
    $content = New-Object System.Net.Http.MultipartFormDataContent
    if ($filePath -ne $null) {
      $fileBytes = [System.IO.File]::ReadAllBytes($filePath)
      $fileContent = New-Object System.Net.Http.ByteArrayContent(, $fileBytes)
      $fileContent.Headers.ContentType =
        [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("application/octet-stream")
      $content.Add($fileContent, "file", [System.IO.Path]::GetFileName($filePath))
    }
    if ($null -ne $titulo) {
      $content.Add([System.Net.Http.StringContent]::new($titulo), "titulo")
    }
    if ($null -ne $descripcion) {
      $content.Add([System.Net.Http.StringContent]::new($descripcion), "descripcion")
    }
    if ($null -ne $comunidadId) {
      $content.Add([System.Net.Http.StringContent]::new([string]$comunidadId), "comunidadId")
    }
    $response = $client.PostAsync($url, $content).GetAwaiter().GetResult()
    $body = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
    $client.Dispose()
    return @{ Status = [int]$response.StatusCode; Body = $body }
  } catch {
    return @{ Status = 0; Body = $_.Exception.Message }
  }
}

# ================== 1. ESPERAR BACKEND ==================
$listo = $false
for ($i = 0; $i -lt 40; $i++) {
  try {
    $r = Invoke-WebRequest -Method Post -Uri "$base/auth/login" -ContentType "application/json" -Body '{"correo":"carlos.mendez@unbound.org","password":"password123"}' -UseBasicParsing -TimeoutSec 5
    if ([int]$r.StatusCode -eq 200) { $listo = $true; break }
  } catch {}
  Start-Sleep -Seconds 5
}
if (-not $listo) { Write-Host "Backend no disponible" -ForegroundColor Red; exit 1 }
Write-Host "Backend listo`n" -ForegroundColor Cyan

# ================== 2. LOGINS ==================
$loginC = Req POST "$base/auth/login" @{} '{"correo":"carlos.mendez@unbound.org","password":"password123"}'
Check "login coordinador (carlos)" 200 $loginC.Status
$dC = $loginC.Body | ConvertFrom-Json
$hC = @{ Authorization = "Bearer $($dC.token)" }

$loginS = Req POST "$base/auth/login" @{} '{"correo":"segundo.coord@unbound.org","password":"password123"}'
Check "login coordinador (segundo)" 200 $loginS.Status
$dS = $loginS.Body | ConvertFrom-Json
$hS = @{ Authorization = "Bearer $($dS.token)" }

$loginA = Req POST "$base/auth/login" @{} '{"correo":"juan.perez@unbound.org","password":"password123"}'
Check "login apadrinado (juan)" 200 $loginA.Status
$dA = $loginA.Body | ConvertFrom-Json
$hA = @{ Authorization = "Bearer $($dA.token)" }

# ================== 3. COMUNIDADES DEL COORDINADOR ==================
$com = Req GET "$base/coordinadores/comunidades" $hC $null
Check "listar comunidades del coordinador" 200 $com.Status
$comunidadesIniciales = Parse-Json $com.Body
Check "carlos tiene al menos 1 comunidad" $true ($comunidadesIniciales.Count -ge 1)

$comunidadPrincipalId = Sql-Output "SELECT id_comunidad FROM coordinador WHERE id_usuario = (SELECT id FROM usuario WHERE correo = 'carlos.mendez@unbound.org')"
$contienePrincipal = $false
foreach ($c in $comunidadesIniciales) { if ([string]$c.id -eq [string]$comunidadPrincipalId) { $contienePrincipal = $true } }
Check "la lista incluye la comunidad principal" $true $contienePrincipal

# apadrinado no puede listar comunidades de coordinador
$comA = Req GET "$base/coordinadores/comunidades" $hA $null
Check "apadrinado no puede listar comunidades del coordinador" 403 $comA.Status

# ================== 4. CREAR COMUNIDAD NUEVA (HUÉRFANA) ==================
$guid = [System.Guid]::NewGuid().ToString('N').Substring(0, 8)
$nombreComunidad = "Aldea Fase F $guid"
$crearCom = Req POST "$base/comunidades" $hC ('{"nombre":"' + $nombreComunidad + '","municipio":"Chiantla","departamento":"Huehuetenango"}')
Check "crear comunidad (coordinador)" 201 $crearCom.Status
$comNueva = $crearCom.Body | ConvertFrom-Json
$huerfanaId = [string]$comNueva.id
Check "la nueva comunidad tiene ID" $true ($huerfanaId -ne "")

# la nueva comunidad NO aparece aún en las comunidades de carlos
$comAntes = Req GET "$base/coordinadores/comunidades" $hC $null
$listaAntes = Parse-Json $comAntes.Body
$yaAparece = $false
foreach ($c in $listaAntes) { if ([string]$c.id -eq $huerfanaId) { $yaAparece = $true } }
Check "la comunidad nueva aún no es responsabilidad de carlos" $false $yaAparece

# ================== 5. ASOCIAR COMUNIDAD ==================
$assoc = Req POST "$base/coordinadores/comunidades/$huerfanaId" $hC $null
Check "asociar comunidad al coordinador" 200 $assoc.Status

$com2 = Req GET "$base/coordinadores/comunidades" $hC $null
Check "listar comunidades después de asociar" 200 $com2.Status
$lista2 = Parse-Json $com2.Body
Check "carlos ahora tiene 2 comunidades" 2 $lista2.Count
$contieneNueva = $false
foreach ($c in $lista2) { if ([string]$c.id -eq $huerfanaId) { $contieneNueva = $true } }
Check "la lista incluye la comunidad asociada" $true $contieneNueva

# idempotencia: asociar de nuevo no duplica
$assoc2 = Req POST "$base/coordinadores/comunidades/$huerfanaId" $hC $null
Check "asociar comunidad ya asociada (idempotente)" 200 $assoc2.Status
$com2b = Req GET "$base/coordinadores/comunidades" $hC $null
$lista2b = Parse-Json $com2b.Body
Check "no se duplicó la asociación" 2 $lista2b.Count

# el perfil del coordinador expone sus comunidades
$perfil = Req GET "$base/coordinadores/$($dC.coordinadorId)" $hC $null
Check "perfil del coordinador" 200 $perfil.Status
$perfilObj = $perfil.Body | ConvertFrom-Json
Check "el perfil expone 2 comunidades" 2 @($perfilObj.comunidades).Count

# ================== 6. MATERIAL DE APOYO EN LA SEGUNDA COMUNIDAD ==================
$tempFile = [System.IO.Path]::GetTempFileName()
Set-Content -Path $tempFile -Value "Contenido de prueba Fase F" -NoNewline
$tituloMat = "Material Fase F $guid"
$up = Upload-Multipart "$base/material-apoyo/upload" $dC.token $tempFile $tituloMat "Descripcion Fase F" $huerfanaId
Check "subir material a la segunda comunidad" 201 $up.Status
$upObj = $up.Body | ConvertFrom-Json
Check "el material quedó en la segunda comunidad" $true ([string]$upObj.comunidadId -eq $huerfanaId)
$materialId = [string]$upObj.id

# subir sin indicar comunidad deja el material en la comunidad principal
$tempFile2 = [System.IO.Path]::GetTempFileName()
Set-Content -Path $tempFile2 -Value "Contenido principal" -NoNewline
$upPrin = Upload-Multipart "$base/material-apoyo/upload" $dC.token $tempFile2 "Material Principal F6 $guid" "Desc" $null
Check "subir material sin comunidad (va a la principal)" 201 $upPrin.Status
$upPrinObj = $upPrin.Body | ConvertFrom-Json
Check "el material sin comunidad quedó en la principal" $true ([string]$upPrinObj.comunidadId -eq [string]$comunidadPrincipalId)
$materialPrinId = [string]$upPrinObj.id

# apadrinado no puede subir material
$upA = Upload-Multipart "$base/material-apoyo/upload" $dA.token $tempFile "X" "X" $null
Check "apadrinado no puede subir material" 403 $upA.Status

Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
Remove-Item $tempFile2 -Force -ErrorAction SilentlyContinue

# el listado del coordinador incluye material de todas sus comunidades
$mat = Req GET "$base/material-apoyo" $hC $null
Check "listar material de mis comunidades" 200 $mat.Status
$matList = Parse-Json $mat.Body
$encontradoMat = $false
foreach ($m in $matList) { if ([string]$m.comunidadId -eq $huerfanaId) { $encontradoMat = $true } }
Check "el listado incluye material de la segunda comunidad" $true $encontradoMat

# listar por comunidad accesible
$matCom = Req GET "$base/material-apoyo/comunidad/$huerfanaId" $hC $null
Check "coordinador lista material de su segunda comunidad" 200 $matCom.Status

# otro coordinador no accede a la comunidad asociada
$matComS = Req GET "$base/material-apoyo/comunidad/$huerfanaId" $hS $null
Check "otro coordinador no ve la segunda comunidad" 403 $matComS.Status

# eliminar el material mientras la comunidad aún es accesible
$delMat = Req DELETE "$base/material-apoyo/$materialId" $hC $null
Check "coordinador elimina material de su segunda comunidad" 204 $delMat.Status
$delMatPrin = Req DELETE "$base/material-apoyo/$materialPrinId" $hC $null
Check "coordinador elimina material de su comunidad principal" 204 $delMatPrin.Status

# ================== 7. APADRINADOS EN LA SEGUNDA COMUNIDAD ==================
$correoNuevo = "apf6_$guid@unbound.org"
$crearAp = Req POST "$base/apadrinados" $hC ('{"nombre":"Apadrinado Fase F","correo":"' + $correoNuevo + '","password":"password123","comunidadId":' + $huerfanaId + '}')
Check "crear apadrinado en la segunda comunidad" 201 $crearAp.Status
$apObj = $crearAp.Body | ConvertFrom-Json
Check "el apadrinado quedó en la segunda comunidad" $true ([string]$apObj.comunidadId -eq $huerfanaId)
$nuevoApadrinadoId = [string]$apObj.id

# el coordinador ve los apadrinados de todas sus comunidades
$aps = Req GET "$base/apadrinados" $hC $null
Check "listar apadrinados del coordinador" 200 $aps.Status
$apsList = Parse-Json $aps.Body
$encontradoAp = $false
foreach ($a in $apsList) { if ([string]$a.id -eq $nuevoApadrinadoId) { $encontradoAp = $true } }
Check "el listado incluye el apadrinado de la segunda comunidad" $true $encontradoAp

# otro coordinador no lo ve
$apsS = Req GET "$base/apadrinados" $hS $null
$apsSList = Parse-Json $apsS.Body
$loVe = $false
foreach ($a in $apsSList) { if ([string]$a.id -eq $nuevoApadrinadoId) { $loVe = $true } }
Check "otro coordinador no ve el apadrinado de la segunda comunidad" $false $loVe

# acceso individual
$apInd = Req GET "$base/apadrinados/$nuevoApadrinadoId" $hC $null
Check "coordinador accede al apadrinado de su segunda comunidad" 200 $apInd.Status
$apIndS = Req GET "$base/apadrinados/$nuevoApadrinadoId" $hS $null
Check "otro coordinador no accede al apadrinado" 403 $apIndS.Status

# ================== 8. EXCLUSIVIDAD DE COMUNIDADES ==================
$ex1 = Req POST "$base/coordinadores/comunidades/$huerfanaId" $hS $null
Check "exclusividad: otro coordinador no asocia comunidad ocupada" 403 $ex1.Status
$ex2 = Req POST "$base/coordinadores/comunidades/$comunidadPrincipalId" $hS $null
Check "exclusividad: otro coordinador no asocia comunidad principal ajena" 403 $ex2.Status

# ================== 9. SOLICITUDES DE INCORPORACIÓN ==================
# usuario solicitante (rol Apadrinado, sin perfil de apadrinado)
$correoSoli = "solf6_$guid@unbound.org"
$idSolicitante = Sql-Output "INSERT INTO usuario (nombre, correo, password, id_rol) VALUES ('Solicitante Fase F', '$correoSoli', 'password123', (SELECT id FROM rol WHERE nombre = 'Apadrinado')) RETURNING id"
Check "se creó el usuario solicitante" $true ($idSolicitante -ne "")
$idSolicitud = Sql-Output "INSERT INTO solicitud_incorporacion (id_usuario, id_comunidad, codigo, estado, fecha_solicitud) VALUES ($idSolicitante, $huerfanaId, 'F6-TEST', 'PENDIENTE', now()) RETURNING id"
Check "se creó la solicitud pendiente" $true ($idSolicitud -ne "")

# el coordinador lista pendientes de todas sus comunidades
$pend = Req GET "$base/solicitudes-incorporacion/pendientes" $hC $null
Check "listar solicitudes pendientes" 200 $pend.Status
$pendList = Parse-Json $pend.Body
$encontradaSol = $false
foreach ($s in $pendList) { if ([string]$s.id -eq [string]$idSolicitud) { $encontradaSol = $true } }
Check "las pendientes incluyen la segunda comunidad" $true $encontradaSol

# otro coordinador no ve la solicitud
$pendS = Req GET "$base/solicitudes-incorporacion/pendientes" $hS $null
$pendSList = Parse-Json $pendS.Body
$laVe = $false
foreach ($s in $pendSList) { if ([string]$s.id -eq [string]$idSolicitud) { $laVe = $true } }
Check "otro coordinador no ve la solicitud de la segunda comunidad" $false $laVe

# aprobar la solicitud de la segunda comunidad
$aprobar = Req PATCH "$base/solicitudes-incorporacion/$idSolicitud/aprobar" $hC $null
Check "aprobar solicitud de la segunda comunidad" 200 $aprobar.Status

# el apadrinado aprobado queda visible para el coordinador
$aps2 = Req GET "$base/apadrinados" $hC $null
$aps2List = Parse-Json $aps2.Body
$aprobadoVisible = $false
foreach ($a in $aps2List) { if ([string]$a.usuarioId -eq [string]$idSolicitante) { $aprobadoVisible = $true } }
Check "el apadrinado aprobado es visible para el coordinador" $true $aprobadoVisible

# ================== 10. DESASOCIAR COMUNIDAD ==================
$des = Req DELETE "$base/coordinadores/comunidades/$huerfanaId" $hC $null
Check "desasociar segunda comunidad" 200 $des.Status
$com3 = Req GET "$base/coordinadores/comunidades" $hC $null
$lista3 = Parse-Json $com3.Body
Check "después de desasociar queda 1 comunidad" 1 $lista3.Count

# la comunidad deja de ser accesible para el coordinador
$matCom3 = Req GET "$base/material-apoyo/comunidad/$huerfanaId" $hC $null
Check "tras desasociar, la comunidad deja de ser accesible" 403 $matCom3.Status

# la comunidad principal no se puede desasociar
$desPrin = Req DELETE "$base/coordinadores/comunidades/$comunidadPrincipalId" $hC $null
Check "la comunidad principal no se puede desasociar" 403 $desPrin.Status

# ================== RESUMEN ==================
Write-Host "`n==============================" -ForegroundColor Cyan
Write-Host "Resumen Fase F:" -ForegroundColor Cyan
Write-Host "  PASS: $($global:pass)" -ForegroundColor Green
Write-Host "  FAIL: $($global:fail)" -ForegroundColor Red
if ($global:fail -gt 0) {
  Write-Host "Errores:" -ForegroundColor Red
  foreach ($e in $global:errores) { Write-Host "  - $e" -ForegroundColor Red }
  exit 1
}
