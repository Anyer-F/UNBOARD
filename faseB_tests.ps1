$ErrorActionPreference = "Continue"
$base = "http://localhost:8081/api"
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

function Sql-Scalar($sql) {
  $salida = (docker exec unbound_db psql -U postgres -d unbound -t -A -c $sql 2>$null | Out-String)
  if ($salida -match '(\d+)') { return [long]$Matches[1] }
  return $null
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
$idCarlos = $dC.usuarioId
$coordC = $dC.coordinadorId

$loginA = Req POST "$base/auth/login" @{} '{"correo":"juan.perez@unbound.org","password":"password123"}'
Check "login apadrinado (juan)" 200 $loginA.Status
$dA = $loginA.Body | ConvertFrom-Json
$hA = @{ Authorization = "Bearer $($dA.token)" }
$idJuan = $dA.usuarioId
$apadrinadoIdJuan = $dA.apadrinadoId

$loginC2 = Req POST "$base/auth/login" @{} '{"correo":"segundo.coord@unbound.org","password":"password123"}'
Check "login segundo coordinador" 200 $loginC2.Status
$dC2 = $loginC2.Body | ConvertFrom-Json
$hC2 = @{ Authorization = "Bearer $($dC2.token)" }
$idC2 = $dC2.usuarioId
$coordC2 = $dC2.coordinadorId

# Comunidad de C2 (desde BD)
$comunidadC2 = Sql-Scalar "SELECT id_comunidad FROM coordinador WHERE id_usuario=(SELECT id FROM usuario WHERE correo='segundo.coord@unbound.org');"

# ================== 3. ROLES ==================
$roles = Req GET "$base/roles" $hC $null
Check "listar roles con token" 200 $roles.Status
$listaRoles = $roles.Body | ConvertFrom-Json
$rolCoordId = "$((@($listaRoles) | Where-Object { $_.nombre -eq "Coordinador" } | Select-Object -First 1).id)"
$rolApadId = "$((@($listaRoles) | Where-Object { $_.nombre -eq "Apadrinado" } | Select-Object -First 1).id)"
$rolAdminId = "$((@($listaRoles) | Where-Object { $_.nombre -eq "Administrador" } | Select-Object -First 1).id)"

# ================== 4. REGISTRO PÚBLICO ==================
$regCoord = Req POST "$base/auth/register" @{} ('{"nombre":"Intruso","correo":"intruso.faseb@unbound.org","password":"password123","rolId":' + $rolCoordId + '}')
Check "registro publico con rol Coordinador rechazado" 400 $regCoord.Status
$regAdmin = Req POST "$base/auth/register" @{} ('{"nombre":"Intruso2","correo":"intruso2.faseb@unbound.org","password":"password123","rolId":' + $rolAdminId + '}')
Check "registro publico con rol Administrador rechazado" 400 $regAdmin.Status
# otro.apadrinado: registro publico con rol Apadrinado (o reutilizar si ya existe)
$existeOtroUser = Sql-Scalar "SELECT id FROM usuario WHERE correo='otro.apadrinado@unbound.org';"
if ($null -eq $existeOtroUser) {
  $regOk = Req POST "$base/auth/register" @{} ('{"nombre":"Otro Apadrinado","correo":"otro.apadrinado@unbound.org","password":"password123","rolId":' + $rolApadId + '}')
  Check "registro publico con rol Apadrinado aceptado" 201 $regOk.Status
  $idOtroUsuario = ($regOk.Body | ConvertFrom-Json).usuarioId
} else {
  $idOtroUsuario = $existeOtroUser
}

# ================== 5. C2 CREA PERFIL DE APDINADO ==================
# (si el perfil ya existia de una ejecucion previa, se reutiliza)
$existePerfil = Sql-Scalar "SELECT id FROM apadrinado WHERE id_usuario=$idOtroUsuario;"
if ($null -eq $existePerfil) {
  $crearAp = Req POST "$base/apadrinados" $hC2 ('{"usuarioId":' + $idOtroUsuario + '}')
  Check "coordinador crea perfil de apadrinado" 201 $crearAp.Status
  $apadrinadoIdOtro = ($crearAp.Body | ConvertFrom-Json).id
} else {
  $apadrinadoIdOtro = $existePerfil
}

# Login del otro apadrinado
$loginA2 = Req POST "$base/auth/login" @{} '{"correo":"otro.apadrinado@unbound.org","password":"password123"}'
Check "login otro apadrinado" 200 $loginA2.Status
$dA2 = $loginA2.Body | ConvertFrom-Json
$hA2 = @{ Authorization = "Bearer $($dA2.token)" }

# ================== 6. EXPEDIENTES / ACTIVIDADES / CARTAS DE PRUEBA ==================
# C2 obtiene el expediente de su apadrinado (se crea automaticamente con el perfil)
$crearExp = Req GET "$base/expedientes/apadrinado/$apadrinadoIdOtro" $hC2 $null
Check "coordinador C2 consulta expediente de su apadrinado" 200 $crearExp.Status
$expOtroId = ($crearExp.Body | ConvertFrom-Json).id

# Expediente de juan (ya existe)
$expJuanResp = Req GET "$base/expedientes/apadrinado/$apadrinadoIdJuan" $hC $null
Check "coordinador consulta expediente de su apadrinado" 200 $expJuanResp.Status
$expJuanId = ($expJuanResp.Body | ConvertFrom-Json).id

# C crea actividad para juan (envia coordinadorId de C2 en el body para verificar que se ignora)
$bodyActC = '{"titulo":"Actividad Test Fase B","descripcion":"desc","fechaLimite":"2026-12-31","requiereDocumento":true,"requiereFotografia":false,"coordinadorId":' + $coordC2 + ',"apadrinadoId":' + $apadrinadoIdJuan + '}'
$crearActC = Req POST "$base/actividades" $hC $bodyActC
Check "coordinador crea actividad" 201 $crearActC.Status
$dActC = $crearActC.Body | ConvertFrom-Json
Check "actividad asignada al coordinador autenticado (ignora body)" "$coordC" "$($dActC.coordinadorId)"
$actCId = $dActC.id

# C2 crea actividad para su apadrinado (envia coordinadorId de C en el body)
$bodyActC2 = '{"titulo":"Actividad C2 Fase B","descripcion":"desc","fechaLimite":"2026-12-31","requiereDocumento":false,"requiereFotografia":false,"coordinadorId":' + $coordC + ',"apadrinadoId":' + $apadrinadoIdOtro + '}'
$crearActC2 = Req POST "$base/actividades" $hC2 $bodyActC2
Check "coordinador C2 crea actividad" 201 $crearActC2.Status
$dActC2 = $crearActC2.Body | ConvertFrom-Json
Check "actividad de C2 asignada a C2 (ignora body)" "$coordC2" "$($dActC2.coordinadorId)"
$actC2Id = $dActC2.id

# A crea carta para sí mismo
$bodyCarta = '{"titulo":"Carta de Juan Fase B","contenido":"Contenido de prueba","tipoCarta":"GENERAL","apadrinadoId":' + $apadrinadoIdJuan + '}'
$crearCarta = Req POST "$base/cartas" $hA $bodyCarta
Check "apadrinado crea carta propia" 201 $crearCarta.Status
$cartaJuanId = ($crearCarta.Body | ConvertFrom-Json).id

# A intenta crear carta para otro apadrinado
$bodyCartaMal = '{"titulo":"Carta intrusa","contenido":"x","apadrinadoId":' + $apadrinadoIdOtro + '}'
$cartaMal = Req POST "$base/cartas" $hA $bodyCartaMal
Check "apadrinado no crea carta para otro apadrinado" 403 $cartaMal.Status

# A2 crea carta para sí mismo
$bodyCartaOtro = '{"titulo":"Carta del Otro Fase B","contenido":"Contenido","apadrinadoId":' + $apadrinadoIdOtro + '}'
$crearCartaOtro = Req POST "$base/cartas" $hA2 $bodyCartaOtro
Check "otro apadrinado crea su carta" 201 $crearCartaOtro.Status
$cartaOtroId = ($crearCartaOtro.Body | ConvertFrom-Json).id

Write-Host "`n================= PRUEBAS DE AUTENTICACION =================" -ForegroundColor Cyan
$sinToken = Req GET "$base/apadrinados" @{} $null
Check "sin token -> 401" 401 $sinToken.Status
$tokenMalo = @{ Authorization = "Bearer invalido" }
$conTokenMalo = Req GET "$base/apadrinados" $tokenMalo $null
Check "token invalido -> 401" 401 $conTokenMalo.Status

Write-Host "`n================= APDINADO: SOLO SUS RECURSOS =================" -ForegroundColor Cyan
# --- Apadrinados ---
$getApPropio = Req GET "$base/apadrinados/$apadrinadoIdJuan" $hA $null
Check "apadrinado consulta su perfil" 200 $getApPropio.Status
$getApAjeno = Req GET "$base/apadrinados/$apadrinadoIdOtro" $hA $null
Check "apadrinado no consulta otro apadrinado" 403 $getApAjeno.Status
$putAp = Req PUT "$base/apadrinados/$apadrinadoIdJuan" $hA '{"coordinadorId":1}'
Check "apadrinado no modifica su perfil de apadrinado" 403 $putAp.Status
$delAp = Req DELETE "$base/apadrinados/$apadrinadoIdJuan" $hA $null
Check "apadrinado no elimina su perfil" 403 $delAp.Status
$crearApMal = Req POST "$base/apadrinados" $hA '{"nombre":"X"}'
Check "apadrinado no crea apadrinados" 403 $crearApMal.Status
$getApPorUsuarioPropio = Req GET "$base/apadrinados/usuario/$idJuan" $hA $null
Check "apadrinado consulta su perfil por usuario" 200 $getApPorUsuarioPropio.Status
$getApPorUsuarioAjeno = Req GET "$base/apadrinados/usuario/$idCarlos" $hA $null
Check "apadrinado no consulta perfil por usuario ajeno" 403 $getApPorUsuarioAjeno.Status
$listaApA = Req GET "$base/apadrinados" $hA $null
Check "apadrinado lista registros" 200 $listaApA.Status
$arrApA = @($listaApA.Body | ConvertFrom-Json)
Check "apadrinado solo ve su propio registro" $true (($arrApA.Count -eq 1) -and ("$($arrApA[0].id)" -eq "$apadrinadoIdJuan"))

# --- Coordinador sobre apadrinados ajenos ---
$getApAjenoC = Req GET "$base/apadrinados/$apadrinadoIdOtro" $hC $null
Check "coordinador no consulta apadrinado de otra comunidad" 403 $getApAjenoC.Status
$putApAjenoC = Req PUT "$base/apadrinados/$apadrinadoIdOtro" $hC '{"nombre":"Hack"}'
Check "coordinador no modifica apadrinado ajeno" 403 $putApAjenoC.Status
$delApAjenoC = Req DELETE "$base/apadrinados/$apadrinadoIdOtro" $hC $null
Check "coordinador no elimina apadrinado ajeno" 403 $delApAjenoC.Status
$listaApC = Req GET "$base/apadrinados" $hC $null
Check "coordinador lista sus apadrinados" 200 $listaApC.Status
$idsApC = @(($listaApC.Body | ConvertFrom-Json) | ForEach-Object { "$($_.id)" })
Check "coordinador ve al apadrinado de su comunidad" $true ($idsApC -contains "$apadrinadoIdJuan")
Check "coordinador no ve apadrinado de otra comunidad" $false ($idsApC -contains "$apadrinadoIdOtro")
$coordsC = Req GET "$base/apadrinados/coordinador/$coordC" $hC $null
Check "coordinador lista apadrinados por su coordinadorId" 200 $coordsC.Status
$coordsC2Mal = Req GET "$base/apadrinados/coordinador/$coordC2" $hC $null
Check "coordinador no lista apadrinados de otro coordinador" 403 $coordsC2Mal.Status
$coordsComPropia = Req GET "$base/apadrinados/comunidad/$comunidadC2" $hC2 $null
Check "coordinador lista apadrinados de su comunidad" 200 $coordsComPropia.Status
$coordsComAjena = Req GET "$base/apadrinados/comunidad/$comunidadC2" $hC $null
Check "coordinador no lista apadrinados de comunidad ajena" 403 $coordsComAjena.Status

# Crear apadrinado nuevo asignado a C (con coordinadorId de C2 en el body)
$ts = Get-Date -Format "HHmmss"
$bodyNuevoAp = '{"nombre":"Apadrinado Asignado","correo":"asignado' + $ts + '@unbound.org","password":"password123","coordinadorId":' + $coordC2 + '}'
$creadoAp = Req POST "$base/apadrinados" $hC $bodyNuevoAp
Check "coordinador crea apadrinado" 201 $creadoAp.Status
$dNuevoAp = $creadoAp.Body | ConvertFrom-Json
Check "apadrinado nuevo asignado al coordinador autenticado" "$coordC" "$($dNuevoAp.coordinadorId)"

# --- Actividades ---
$getActPropia = Req GET "$base/actividades/$actCId" $hA $null
Check "apadrinado consulta su actividad" 200 $getActPropia.Status
$getActAjena = Req GET "$base/actividades/$actC2Id" $hA $null
Check "apadrinado no consulta actividad ajena" 403 $getActAjena.Status
$getActC2PorC = Req GET "$base/actividades/$actC2Id" $hC $null
Check "coordinador no consulta actividad de otra comunidad" 403 $getActC2PorC.Status
$getActC2PorC2 = Req GET "$base/actividades/$actC2Id" $hC2 $null
Check "coordinador C2 consulta su actividad" 200 $getActC2PorC2.Status
$listaActA = Req GET "$base/actividades" $hA $null
Check "apadrinado lista sus actividades" 200 $listaActA.Status
$idsActA = @(($listaActA.Body | ConvertFrom-Json) | ForEach-Object { "$($_.id)" })
Check "apadrinado no ve actividades de otros" $false ($idsActA -contains "$actC2Id")
$listaActC = Req GET "$base/actividades" $hC $null
Check "coordinador lista sus actividades" 200 $listaActC.Status
$idsActC = @(($listaActC.Body | ConvertFrom-Json) | ForEach-Object { "$($_.id)" })
Check "coordinador ve sus actividades" $true ($idsActC -contains "$actCId")
Check "coordinador no ve actividades ajenas" $false ($idsActC -contains "$actC2Id")
$actPorApPropio = Req GET "$base/actividades/apadrinado/$apadrinadoIdJuan" $hA $null
Check "apadrinado lista actividades por su apadrinadoId" 200 $actPorApPropio.Status
$actPorApAjeno = Req GET "$base/actividades/apadrinado/$apadrinadoIdOtro" $hA $null
Check "apadrinado no lista actividades de otro apadrinado" 403 $actPorApAjeno.Status
$actPorCoordPropio = Req GET "$base/actividades/coordinador/$coordC" $hC $null
Check "coordinador lista actividades por su coordinadorId" 200 $actPorCoordPropio.Status
$actPorCoordAjeno = Req GET "$base/actividades/coordinador/$coordC2" $hC $null
Check "coordinador no lista actividades de otro coordinador" 403 $actPorCoordAjeno.Status
$histPropio = Req GET "$base/actividades/$actCId/historial" $hA $null
Check "apadrinado consulta historial de su actividad" 200 $histPropio.Status
$histAjeno = Req GET "$base/actividades/$actC2Id/historial" $hA $null
Check "apadrinado no consulta historial ajeno" 403 $histAjeno.Status
$histApPropio = Req GET "$base/actividades/apadrinado/$apadrinadoIdJuan/historial" $hA $null
Check "historial por apadrinado propio" 200 $histApPropio.Status
$histApAjeno = Req GET "$base/actividades/apadrinado/$apadrinadoIdOtro/historial" $hA $null
Check "historial por apadrinado ajeno denegado" 403 $histApAjeno.Status
$delActMal = Req DELETE "$base/actividades/$actCId" $hA $null
Check "apadrinado no elimina actividad" 403 $delActMal.Status
$putActMal = Req PUT "$base/actividades/$actCId" $hA '{"titulo":"Hack"}'
Check "apadrinado no edita actividad" 403 $putActMal.Status
$crearActMal = Req POST "$base/actividades" $hA '{"titulo":"Hack","apadrinadoId":1}'
Check "apadrinado no crea actividades" 403 $crearActMal.Status
# masiva
$crearMasivaMal = Req POST "$base/actividades/masiva" $hA ('{"titulo":"Hack","apadrinadoIds":[' + $apadrinadoIdJuan + ']}')
Check "apadrinado no crea actividades masivas" 403 $crearMasivaMal.Status
# cambiar estado
$cambioEst = Req PATCH "$base/actividades/$actCId/estado" $hC '{"estado":"EN_PROCESO","observaciones":"test"}'
Check "coordinador cambia estado de su actividad" 200 $cambioEst.Status
$cambioEstMal = Req PATCH "$base/actividades/$actCId/estado" $hA '{"estado":"APROBADA"}'
Check "apadrinado no cambia estado de actividad" 403 $cambioEstMal.Status
$cambioEstAjeno = Req PATCH "$base/actividades/$actC2Id/estado" $hC '{"estado":"APROBADA"}'
Check "coordinador no cambia estado de actividad ajena" 403 $cambioEstAjeno.Status

# --- Expedientes ---
$listaExpA = Req GET "$base/expedientes" $hA $null
Check "apadrinado lista sus expedientes" 200 $listaExpA.Status
$arrExpA = @($listaExpA.Body | ConvertFrom-Json)
Check "apadrinado solo ve su expediente" $true (($arrExpA.Count -eq 1) -and ("$($arrExpA[0].id)" -eq "$expJuanId"))
$expAjenoA = Req GET "$base/expedientes/$expOtroId" $hA $null
Check "apadrinado no consulta expediente ajeno" 403 $expAjenoA.Status
$expPorApAjeno = Req GET "$base/expedientes/apadrinado/$apadrinadoIdOtro" $hA $null
Check "apadrinado no consulta expediente por apadrinado ajeno" 403 $expPorApAjeno.Status
$listaExpC = Req GET "$base/expedientes" $hC $null
Check "coordinador lista expedientes de sus apadrinados" 200 $listaExpC.Status
$idsExpC = @(($listaExpC.Body | ConvertFrom-Json) | ForEach-Object { "$($_.id)" })
Check "coordinador no ve expediente de otra comunidad" $false ($idsExpC -contains "$expOtroId")
$expC2PorC = Req GET "$base/expedientes/$expOtroId" $hC $null
Check "coordinador no consulta expediente ajeno" 403 $expC2PorC.Status
$crearExpMal = Req POST "$base/expedientes/apadrinado/$apadrinadoIdOtro" $hC $null
Check "coordinador no crea expediente para apadrinado ajeno" 403 $crearExpMal.Status
$expPdfAjeno = Req GET "$base/expedientes/$expOtroId/exportar-pdf" $hA $null
Check "apadrinado no exporta PDF de expediente ajeno" 403 $expPdfAjeno.Status
$expZipAjeno = Req GET "$base/expedientes/$expOtroId/exportar-zip" $hA $null
Check "apadrinado no exporta ZIP de expediente ajeno" 403 $expZipAjeno.Status

# --- Cartas ---
$listaCartasA = Req GET "$base/cartas" $hA $null
Check "apadrinado lista sus cartas" 200 $listaCartasA.Status
$idsCartasA = @(($listaCartasA.Body | ConvertFrom-Json) | ForEach-Object { "$($_.id)" })
Check "apadrinado ve sus cartas" $true ($idsCartasA -contains "$cartaJuanId")
Check "apadrinado no ve cartas ajenas" $false ($idsCartasA -contains "$cartaOtroId")
$listaCartasC = Req GET "$base/cartas" $hC $null
Check "coordinador lista cartas de sus apadrinados" 200 $listaCartasC.Status
$idsCartasC = @(($listaCartasC.Body | ConvertFrom-Json) | ForEach-Object { "$($_.id)" })
Check "coordinador ve cartas de sus apadrinados" $true ($idsCartasC -contains "$cartaJuanId")
Check "coordinador no ve cartas ajenas" $false ($idsCartasC -contains "$cartaOtroId")
$listaCartasA2 = Req GET "$base/cartas" $hA2 $null
$idsCartasA2 = @(($listaCartasA2.Body | ConvertFrom-Json) | ForEach-Object { "$($_.id)" })
Check "otro apadrinado ve sus cartas" $true ($idsCartasA2 -contains "$cartaOtroId")
Check "otro apadrinado no ve cartas ajenas" $false ($idsCartasA2 -contains "$cartaJuanId")
$getCartaPropia = Req GET "$base/cartas/$cartaJuanId" $hA $null
Check "apadrinado consulta su carta" 200 $getCartaPropia.Status
$getCartaAjena = Req GET "$base/cartas/$cartaOtroId" $hA $null
Check "apadrinado no consulta carta ajena" 403 $getCartaAjena.Status
$getCartaPorExpAjeno = Req GET "$base/cartas/expediente/$expOtroId" $hA $null
Check "apadrinado no lista cartas por expediente ajeno" 403 $getCartaPorExpAjeno.Status
$getCartaPorActAjena = Req GET "$base/cartas/actividad/$actC2Id" $hA $null
Check "apadrinado no lista cartas por actividad ajena" 403 $getCartaPorActAjena.Status
$estadoCartas = Req GET "$base/cartas/estado/BORRADOR" $hA $null
Check "apadrinado lista sus cartas por estado" 200 $estadoCartas.Status
$aprobPropia = Req PATCH "$base/cartas/$cartaJuanId/estado?estado=APROBADA" $hA $null
Check "apadrinado no aprueba su propia carta" 403 $aprobPropia.Status
$aprobC = Req PATCH "$base/cartas/$cartaJuanId/estado?estado=APROBADA" $hC $null
Check "coordinador responsable aprueba carta" 200 $aprobC.Status
$aprobC2Mal = Req PATCH "$base/cartas/$cartaJuanId/estado?estado=APROBADA" $hC2 $null
Check "coordinador no aprueba carta de otra comunidad" 403 $aprobC2Mal.Status
$aprobOtroC2 = Req PATCH "$base/cartas/$cartaOtroId/estado?estado=APROBADA" $hC2 $null
Check "coordinador C2 aprueba carta de su apadrinado" 200 $aprobOtroC2.Status
$envioCarta = Req PATCH "$base/cartas/$cartaJuanId/enviar" $hA $null
Check "apadrinado envia su carta" 200 $envioCarta.Status
$delCartaAjena = Req DELETE "$base/cartas/$cartaOtroId" $hA $null
Check "apadrinado no elimina carta ajena" 403 $delCartaAjena.Status
$putCartaAjena = Req PUT "$base/cartas/$cartaOtroId" $hA '{"titulo":"Hack"}'
Check "apadrinado no modifica carta ajena" 403 $putCartaAjena.Status

# --- Documentos ---
function Upload-Documento($token, $expedienteId) {
  try {
    Add-Type -AssemblyName System.Net.Http | Out-Null
    $handler = New-Object System.Net.Http.HttpClientHandler
    $client = New-Object System.Net.Http.HttpClient($handler)
    $client.DefaultRequestHeaders.Authorization = New-Object System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", $token)
    $content = New-Object System.Net.Http.MultipartFormDataContent
    $fileBytes = [System.IO.File]::ReadAllBytes("$env:TEMP\doc-faseb.txt")
    $fileContent = New-Object System.Net.Http.ByteArrayContent(,$fileBytes)
    $fileContent.Headers.ContentType = New-Object System.Net.Http.Headers.MediaTypeHeaderValue("text/plain")
    $content.Add($fileContent, "file", "doc-faseb.txt")
    $content.Add((New-Object System.Net.Http.StringContent("$expedienteId")), "expedienteId")
    $response = $client.PostAsync("http://localhost:8081/api/documentos/upload", $content).Result
    $status = [int]$response.StatusCode
    $body = $response.Content.ReadAsStringAsync().Result
    $client.Dispose()
    return @{ Status = $status; Body = $body }
  } catch {
    return @{ Status = 0; Body = $_.Exception.Message }
  }
}

Set-Content -Path "$env:TEMP\doc-faseb.txt" -Value "Documento de prueba Fase B" -Force
$upPropio = Upload-Documento $dA.token "$expJuanId"
$docId = 0
if ($upPropio.Status -eq 201) { $docId = ($upPropio.Body | ConvertFrom-Json).id }
Check "apadrinado sube documento a su expediente" 201 $upPropio.Status
$upAjeno = Upload-Documento $dA.token "$expOtroId"
Check "apadrinado no sube documento a expediente ajeno" 403 $upAjeno.Status
$upCoord = Upload-Documento $dC.token "$expJuanId"
Check "coordinador sube documento a expediente de su apadrinado" 201 $upCoord.Status
$upCoordAjeno = Upload-Documento $dC.token "$expOtroId"
Check "coordinador no sube documento a expediente ajeno" 403 $upCoordAjeno.Status

# Upload referenciando usuarioId (validacion de inferencia no autorizada)
function Upload-DocumentoUsuario($token, $usuarioId) {
  try {
    Add-Type -AssemblyName System.Net.Http | Out-Null
    $handler = New-Object System.Net.Http.HttpClientHandler
    $client = New-Object System.Net.Http.HttpClient($handler)
    $client.DefaultRequestHeaders.Authorization = New-Object System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", $token)
    $content = New-Object System.Net.Http.MultipartFormDataContent
    $fileBytes = [System.IO.File]::ReadAllBytes("$env:TEMP\doc-faseb.txt")
    $fileContent = New-Object System.Net.Http.ByteArrayContent(,$fileBytes)
    $fileContent.Headers.ContentType = New-Object System.Net.Http.Headers.MediaTypeHeaderValue("text/plain")
    $content.Add($fileContent, "file", "doc-faseb.txt")
    $content.Add((New-Object System.Net.Http.StringContent("$usuarioId")), "usuarioId")
    $response = $client.PostAsync("http://localhost:8081/api/documentos/upload", $content).Result
    $status = [int]$response.StatusCode
    $body = $response.Content.ReadAsStringAsync().Result
    $client.Dispose()
    return @{ Status = $status; Body = $body }
  } catch {
    return @{ Status = 0; Body = $_.Exception.Message }
  }
}
$upPropioUsuario = Upload-DocumentoUsuario $dA.token "$idJuan"
Check "apadrinado sube documento via su propio usuarioId" 201 $upPropioUsuario.Status
$upUsuarioAjeno = Upload-DocumentoUsuario $dC.token "$idOtroUsuario"
Check "coordinador no sube documento via usuarioId de apadrinado ajeno" 403 $upUsuarioAjeno.Status
$getDoc = Req GET "$base/documentos/$docId" $hA $null
Check "apadrinado consulta su documento" 200 $getDoc.Status
$getDocAjeno = Req GET "$base/documentos/$docId" $hA2 $null
Check "otro apadrinado no consulta documento ajeno" 403 $getDocAjeno.Status
$getDocC = Req GET "$base/documentos/$docId" $hC $null
Check "coordinador consulta documento de su apadrinado" 200 $getDocC.Status
$getDocC2 = Req GET "$base/documentos/$docId" $hC2 $null
Check "coordinador no consulta documento ajeno" 403 $getDocC2.Status
$docsActPropia = Req GET "$base/documentos/actividad/$actCId" $hA $null
Check "apadrinado lista documentos de su actividad" 200 $docsActPropia.Status
$docsActAjena = Req GET "$base/documentos/actividad/$actC2Id" $hA $null
Check "apadrinado no lista documentos de actividad ajena" 403 $docsActAjena.Status
$docsApPropio = Req GET "$base/documentos/apadrinado/$apadrinadoIdJuan" $hA $null
Check "documentos por apadrinado propio" 200 $docsApPropio.Status
$docsApAjeno = Req GET "$base/documentos/apadrinado/$apadrinadoIdOtro" $hA $null
Check "documentos por apadrinado ajeno denegado" 403 $docsApAjeno.Status
$docsExpAjeno = Req GET "$base/documentos/expediente/$expOtroId" $hA $null
Check "documentos por expediente ajeno denegado" 403 $docsExpAjeno.Status
$dlDoc = Req GET "$base/documentos/$docId/descargar" $hA $null
Check "apadrinado descarga su documento" 200 $dlDoc.Status
$dlDocAjeno = Req GET "$base/documentos/$docId/descargar" $hA2 $null
Check "apadrinado no descarga documento ajeno" 403 $dlDocAjeno.Status
$delDoc = Req DELETE "$base/documentos/$docId" $hA $null
Check "apadrinado elimina su documento" 204 $delDoc.Status

# --- Usuarios ---
$getPropio = Req GET "$base/usuarios/$idJuan" $hA $null
Check "apadrinado consulta su propio usuario" 200 $getPropio.Status
$getAjeno = Req GET "$base/usuarios/$idCarlos" $hA $null
Check "apadrinado no consulta otro usuario" 403 $getAjeno.Status
$putPropio = Req PUT "$base/usuarios/$idJuan" $hA '{"nombre":"Juan Perez Lopez"}'
Check "apadrinado actualiza su nombre" 200 $putPropio.Status
$putAjeno = Req PUT "$base/usuarios/$idCarlos" $hA '{"nombre":"Hack"}'
Check "apadrinado no modifica otro usuario" 403 $putAjeno.Status
$listaUsuarios = Req GET "$base/usuarios" $hC $null
Check "lista global de usuarios denegada" 403 $listaUsuarios.Status
$crearUsuario = Req POST "$base/usuarios" $hC '{"nombre":"X","correo":"x@y.com","password":"z"}'
Check "crear usuario denegado" 403 $crearUsuario.Status
$borrarUsuario = Req DELETE "$base/usuarios/$idJuan" $hA $null
Check "eliminar usuario denegado" 403 $borrarUsuario.Status

# --- Coordinadores ---
$getCoordPropio = Req GET "$base/coordinadores/$coordC" $hC $null
Check "coordinador consulta su perfil" 200 $getCoordPropio.Status
$getCoordAjeno = Req GET "$base/coordinadores/$coordC2" $hC $null
Check "coordinador no consulta otro coordinador" 403 $getCoordAjeno.Status
$getCoordApad = Req GET "$base/coordinadores/$coordC" $hA $null
Check "apadrinado no consulta perfil de coordinador" 403 $getCoordApad.Status
$listaCoords = Req GET "$base/coordinadores" $hC $null
Check "lista de coordinadores denegada" 403 $listaCoords.Status
$crearCoord = Req POST "$base/coordinadores" $hC '{"usuarioId":1}'
Check "crear coordinador denegado" 403 $crearCoord.Status
$putCoord = Req PUT "$base/coordinadores/$coordC" $hC '{"usuarioId":1}'
Check "modificar coordinador denegado" 403 $putCoord.Status
$delCoord = Req DELETE "$base/coordinadores/$coordC" $hC $null
Check "eliminar coordinador denegado" 403 $delCoord.Status
$coordsPorCom = Req GET "$base/coordinadores/comunidad/$comunidadC2" $hC2 $null
Check "coordinador lista coordinadores de su comunidad" 200 $coordsPorCom.Status
$coordsPorComAj = Req GET "$base/coordinadores/comunidad/$comunidadC2" $hC $null
Check "coordinador no lista coordinadores de comunidad ajena" 403 $coordsPorComAj.Status

# --- Notificaciones ---
$notifPropia = Req GET "$base/notificaciones/usuario/$idJuan" $hA $null
Check "apadrinado consulta sus notificaciones" 200 $notifPropia.Status
$notifAjena = Req GET "$base/notificaciones/usuario/$idCarlos" $hA $null
Check "apadrinado no consulta notificaciones ajenas" 403 $notifAjena.Status
$conteo = Req GET "$base/notificaciones/usuario/$idJuan/conteo-no-leidas" $hA $null
Check "conteo de no leidas propio" 200 $conteo.Status
$crearNotif = Req POST "$base/notificaciones" $hA '{"usuarioId":1,"tipo":"GENERAL","mensaje":"x"}'
Check "crear notificacion denegado" 403 $crearNotif.Status
$notifC = Req GET "$base/notificaciones/usuario/$idCarlos" $hC $null
Check "coordinador consulta sus notificaciones" 200 $notifC.Status

# --- Comunidades ---
$listaCom = Req GET "$base/comunidades" $hA $null
Check "lectura de comunidades permitida" 200 $listaCom.Status
$crearComMal = Req POST "$base/comunidades" $hA '{"nombre":"X","municipio":"Y","departamento":"Z"}'
Check "apadrinado no crea comunidades" 403 $crearComMal.Status
$crearComOk = Req POST "$base/comunidades" $hC ('{"nombre":"Comunidad Fase B ' + $ts + '","municipio":"Tactic","departamento":"Alta Verapaz"}')
Check "coordinador crea comunidad" 201 $crearComOk.Status
$getCom = Req GET "$base/comunidades/$comunidadC2" $hA $null
Check "consulta de comunidad por id" 200 $getCom.Status
$modComAjena = Req PUT "$base/comunidades/$comunidadC2" $hC '{"nombre":"Intento de robo"}'
Check "coordinador no modifica comunidad ajena" 403 $modComAjena.Status
$delComAjena = Req DELETE "$base/comunidades/$comunidadC2" $hC $null
Check "coordinador no elimina comunidad ajena" 403 $delComAjena.Status
$modComPropia = Req PUT "$base/comunidades/$comunidadC2" $hC2 ('{"nombre":"Comunidad C2 ' + $ts + '","municipio":"Barillas","departamento":"Huehuetenango"}')
Check "coordinador modifica su propia comunidad" 200 $modComPropia.Status

# --- FCM (correccion de bug de ID) ---
$fcm = Req POST "$base/fcm/registrar-token" $hA '{"fcmToken":"faseb-test-token"}'
Check "registrar token FCM con JWT (correo como subject)" 200 $fcm.Status
$fcmSinToken = Req POST "$base/fcm/registrar-token" @{} '{"fcmToken":"x"}'
Check "FCM sin token denegado" 401 $fcmSinToken.Status

Write-Host "`n================= RESULTADOS FASE B =================" -ForegroundColor Cyan
Write-Host "PASS: $($global:pass)" -ForegroundColor Green
Write-Host "FAIL: $($global:fail)" -ForegroundColor Red
if ($global:fail -gt 0) {
  Write-Host "`nPruebas fallidas:" -ForegroundColor Red
  $global:errores | ForEach-Object { Write-Host " - $_" -ForegroundColor Red }
} else {
  Write-Host "`nTodas las pruebas de la Fase B pasaron correctamente." -ForegroundColor Green
}
