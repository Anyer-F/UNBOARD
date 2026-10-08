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

function Sql-Scalar($sql) {
  $salida = (docker exec unbound_db psql -U postgres -d unbound -t -A -c $sql 2>$null | Out-String)
  if ($salida -match '(\d+)') { return [long]$Matches[1] }
  return $null
}

function Upload-Multipart($url, $authToken, $filePath, $titulo, $descripcion) {
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
    $response = $client.PostAsync($url, $content).GetAwaiter().GetResult()
    $body = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
    $client.Dispose()
    return @{ Status = [int]$response.StatusCode; Body = $body }
  } catch {
    return @{ Status = 0; Body = $_.Exception.Message }
  }
}

function Download-File($url, $authToken, $outPath) {
  try {
    $client = New-Object System.Net.Http.HttpClient
    $client.Timeout = [System.TimeSpan]::FromSeconds(60)
    if ($authToken) {
      $client.DefaultRequestHeaders.Authorization =
        [System.Net.Http.Headers.AuthenticationHeaderValue]::Parse("Bearer $authToken")
    }
    $response = $client.GetAsync($url).GetAwaiter().GetResult()
    $status = [int]$response.StatusCode
    if ($response.IsSuccessStatusCode) {
      $bytes = $response.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()
      [System.IO.File]::WriteAllBytes($outPath, $bytes)
    }
    $client.Dispose()
    return @{ Status = $status }
  } catch {
    if (Test-Path $outPath) { Remove-Item $outPath -Force -ErrorAction SilentlyContinue }
    return @{ Status = 0 }
  }
}

function Bytes-Iguales($a, $b) {
  if ($a.Length -ne $b.Length) { return $false }
  for ($i = 0; $i -lt $a.Length; $i++) {
    if ($a[$i] -ne $b[$i]) { return $false }
  }
  return $true
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

# ================== 2. LOGINS Y SETUP ==================
$loginC = Req POST "$base/auth/login" @{} '{"correo":"carlos.mendez@unbound.org","password":"password123"}'
Check "login coordinador (carlos)" 200 $loginC.Status
$dC = $loginC.Body | ConvertFrom-Json
$hC = @{ Authorization = "Bearer $($dC.token)" }
$coordC = $dC.coordinadorId

$loginA = Req POST "$base/auth/login" @{} '{"correo":"juan.perez@unbound.org","password":"password123"}'
Check "login apadrinado (juan)" 200 $loginA.Status
$dA = $loginA.Body | ConvertFrom-Json
$hA = @{ Authorization = "Bearer $($dA.token)" }

$loginC2 = Req POST "$base/auth/login" @{} '{"correo":"segundo.coord@unbound.org","password":"password123"}'
Check "login segundo coordinador" 200 $loginC2.Status
$dC2 = $loginC2.Body | ConvertFrom-Json
$hC2 = @{ Authorization = "Bearer $($dC2.token)" }
$coordC2 = $dC2.coordinadorId

# Descubrimiento dinamico desde la BD
$rolApadId = Sql-Scalar "SELECT id FROM rol WHERE nombre='Apadrinado'"
$comunidadC = Sql-Scalar "SELECT id_comunidad FROM coordinador WHERE id=$coordC"
$comunidadC2 = Sql-Scalar "SELECT id_comunidad FROM coordinador WHERE id=$coordC2"
Write-Host "Descubierto: rolApadId=$rolApadId comunidadC=$comunidadC comunidadC2=$comunidadC2" -ForegroundColor Yellow

# Archivo de prueba con contenido conocido
$ts = Get-Date -Format "HHmmss"
$tempFile = Join-Path $env:TEMP "material_faseD_$ts.txt"
$contenidoPrueba = [System.Text.Encoding]::UTF8.GetBytes("Material de apoyo de prueba UNBOUND - Fase D ($ts)")
[System.IO.File]::WriteAllBytes($tempFile, $contenidoPrueba)

# Usuario nuevo con rol Apadrinado pero SIN comunidad asignada
$correoNuevo = "sincomunidad$ts@unbound.org"
$regNuevo = Req POST "$base/auth/register" @{} ('{"nombre":"Sin Comunidad","correo":"' + $correoNuevo + '","password":"password123","rolId":' + $rolApadId + '}')
Check "registro de apadrinado sin comunidad" 201 $regNuevo.Status
$loginSC = Req POST "$base/auth/login" @{} ('{"correo":"' + $correoNuevo + '","password":"password123"}')
Check "login apadrinado sin comunidad" 200 $loginSC.Status
$dSC = $loginSC.Body | ConvertFrom-Json
$hSC = @{ Authorization = "Bearer $($dSC.token)" }

# ================== 3. MATERIAL DE APOYO ==================
# Sin token
$matSinToken = Req GET "$base/material-apoyo" @{} $null
Check "material sin token denegado" 401 $matSinToken.Status

# Apadrinado ve lista vacia de su comunidad
$matA = Req GET "$base/material-apoyo" $hA $null
Check "apadrinado lista material de su comunidad" 200 $matA.Status

# Apadrinado no puede subir
$upA = Upload-Multipart "$base/material-apoyo/upload" $dA.token $tempFile "Intento de apadrinado" $null
Check "apadrinado no sube material" 403 $upA.Status

# Coordinador sube material a su comunidad
$upC = Upload-Multipart "$base/material-apoyo/upload" $dC.token $tempFile "Guia de cultivos" "Guia practica de cultivos para la comunidad"
Check "coordinador sube material de apoyo" 201 $upC.Status
$dMat = $upC.Body | ConvertFrom-Json
Check "material conserva el titulo" "Guia de cultivos" $dMat.titulo
Check "material conserva la descripcion" "Guia practica de cultivos para la comunidad" $dMat.descripcion
Check "material conserva el nombre de archivo" "material_faseD_$ts.txt" $dMat.nombreOriginal
Check "material pertenece a la comunidad del coordinador" "$comunidadC" "$($dMat.comunidadId)"
Check "material registra al coordinador que lo subio" "$coordC" "$($dMat.coordinadorId)"
Check "material tiene URL de descarga" $true ($dMat.urlDescarga -like "*material-apoyo/*/descargar")
$matId = $dMat.id

# Apadrinado de la comunidad ahora lo ve
$matADespues = Req GET "$base/material-apoyo" $hA $null
$matEnLista = $false
foreach ($item in ($matADespues.Body | ConvertFrom-Json)) {
  if ([string]$item.id -eq [string]$matId) { $matEnLista = $true }
}
Check "apadrinado de la comunidad ve el material" $true $matEnLista

# Coordinador de otra comunidad NO lo ve
$matC2Lista = Req GET "$base/material-apoyo" $hC2 $null
$matEnListaC2 = $false
foreach ($item in ($matC2Lista.Body | ConvertFrom-Json)) {
  if ([string]$item.id -eq [string]$matId) { $matEnListaC2 = $true }
}
Check "coordinador de otra comunidad no ve el material" $false $matEnListaC2

# Listado por comunidad ajena
$listAjeno = Req GET "$base/material-apoyo/comunidad/$comunidadC2" $hC $null
Check "coordinador no lista material de comunidad ajena" 403 $listAjeno.Status
$listPropia = Req GET "$base/material-apoyo/comunidad/$comunidadC2" $hC2 $null
Check "coordinador lista material de su comunidad" 200 $listPropia.Status

# Consulta de metadata por id
$metaA = Req GET "$base/material-apoyo/$matId" $hA $null
Check "apadrinado consulta metadata del material" 200 $metaA.Status
$metaAjeno = Req GET "$base/material-apoyo/$matId" $hC2 $null
Check "no miembro no consulta metadata del material" 403 $metaAjeno.Status

# Descarga del archivo (contenido byte a byte)
$descargado = Join-Path $env:TEMP "material_descargado_$ts.txt"
$dlA = Download-File "$base/material-apoyo/$matId/descargar" $dA.token $descargado
Check "apadrinado descarga el material" 200 $dlA.Status
$dlAjeno = Download-File "$base/material-apoyo/$matId/descargar" $dC2.token $descargado
Check "no miembro no descarga el material" 403 $dlAjeno.Status
if ($dlA.Status -eq 200) {
  $bytesDescargados = [System.IO.File]::ReadAllBytes($descargado)
  Check "contenido descargado coincide con el original" $true (Bytes-Iguales $contenidoPrueba $bytesDescargados)
}

# Visualizacion inline
$verA = Req GET "$base/material-apoyo/$matId/ver" $hA $null
Check "apadrinado visualiza el material" 200 $verA.Status

# Eliminacion: apadrinado no puede, ajeno no puede, propio coordinador puede
$delA = Req DELETE "$base/material-apoyo/$matId" $hA $null
Check "apadrinado no elimina material" 403 $delA.Status
$delAjeno = Req DELETE "$base/material-apoyo/$matId" $hC2 $null
Check "coordinador ajeno no elimina material" 403 $delAjeno.Status

# Coordinador C2 sube material a su comunidad
$upC2 = Upload-Multipart "$base/material-apoyo/upload" $dC2.token $tempFile "Material de Barillas" $null
Check "coordinador C2 sube material a su comunidad" 201 $upC2.Status
$dMatC2 = $upC2.Body | ConvertFrom-Json
Check "material de C2 pertenece a su comunidad" "$comunidadC2" "$($dMatC2.comunidadId)"
$matC2Id = $dMatC2.id

# Apadrinado de comunidad 1 no ve material de comunidad 2
$verCruzado = Req GET "$base/material-apoyo/$matC2Id" $hA $null
Check "apadrinado no accede a material de otra comunidad" 403 $verCruzado.Status

# Coordinador ajeno no elimina material de C2
$delC2Ajeno = Req DELETE "$base/material-apoyo/$matC2Id" $hC $null
Check "coordinador ajeno no elimina material de C2" 403 $delC2Ajeno.Status
# Coordinador C2 elimina su material
$delC2 = Req DELETE "$base/material-apoyo/$matC2Id" $hC2 $null
Check "coordinador elimina material de su comunidad" 204 $delC2.Status
# Coordinador elimina su propio material
$delPropio = Req DELETE "$base/material-apoyo/$matId" $hC $null
Check "coordinador elimina su propio material" 204 $delPropio.Status

# Validaciones
$upSinTitulo = Upload-Multipart "$base/material-apoyo/upload" $dC.token $tempFile "" $null
Check "material sin titulo rechazado" 400 $upSinTitulo.Status
$upSinArchivo = Upload-Multipart "$base/material-apoyo/upload" $dC.token $null "Sin archivo" $null
Check "material sin archivo rechazado" 400 $upSinArchivo.Status

# Apadrinado sin comunidad asignada
$matSC = Req GET "$base/material-apoyo" $hSC $null
Check "apadrinado sin comunidad no lista material" 403 $matSC.Status
$matSCCom = Req GET "$base/material-apoyo/comunidad/$comunidadC" $hSC $null
Check "apadrinado sin comunidad no lista por comunidad" 403 $matSCCom.Status

# Limpieza del archivo temporal
Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
Remove-Item $descargado -Force -ErrorAction SilentlyContinue

Write-Host "`n================= RESULTADOS FASE D =================" -ForegroundColor Cyan
Write-Host "PASS: $($global:pass)" -ForegroundColor Green
Write-Host "FAIL: $($global:fail)" -ForegroundColor Red
if ($global:fail -gt 0) {
  Write-Host "`nPruebas fallidas:" -ForegroundColor Red
  $global:errores | ForEach-Object { Write-Host " - $_" -ForegroundColor Red }
} else {
  Write-Host "`nTodas las pruebas de la Fase D pasaron correctamente." -ForegroundColor Green
}
