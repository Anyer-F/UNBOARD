$ErrorActionPreference = "Continue"
$base = "http://localhost:8081/api"
$global:pass = 0
$global:fail = 0
$global:errores = @()

function Decodificar-Utf8($resp) {
  try {
    $stream = $resp.RawContentStream
    if ($null -ne $stream -and $stream.Length -gt 0) {
      $stream.Position = 0
      $bytes = New-Object byte[] $stream.Length
      $leidos = $stream.Read($bytes, 0, $bytes.Length)
      return [System.Text.Encoding]::UTF8.GetString($bytes, 0, $leidos)
    }
  } catch {}
  return $resp.Content
}

function Req($method, $url, $headers, $body) {
  try {
    if ($null -ne $body) {
      $resp = Invoke-WebRequest -Method $method -Uri $url -Headers $headers -ContentType "application/json" -Body $body -UseBasicParsing -TimeoutSec 30
    } else {
      $resp = Invoke-WebRequest -Method $method -Uri $url -Headers $headers -UseBasicParsing -TimeoutSec 30
    }
    return @{ Status = [int]$resp.StatusCode; Body = (Decodificar-Utf8 $resp) }
  } catch {
    $r = $_.Exception.Response
    if ($null -ne $r) {
      try {
        $sr = New-Object IO.StreamReader($r.GetResponseStream(), [System.Text.Encoding]::UTF8)
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

# ================== 2. LOGINS Y SETUP ==================
$loginC = Req POST "$base/auth/login" @{} '{"correo":"carlos.mendez@unbound.org","password":"password123"}'
Check "login coordinador (carlos)" 200 $loginC.Status
$dC = $loginC.Body | ConvertFrom-Json
$hC = @{ Authorization = "Bearer $($dC.token)" }

$loginA = Req POST "$base/auth/login" @{} '{"correo":"juan.perez@unbound.org","password":"password123"}'
Check "login apadrinado (juan)" 200 $loginA.Status
$dA = $loginA.Body | ConvertFrom-Json
$hA = @{ Authorization = "Bearer $($dA.token)" }

$loginC2 = Req POST "$base/auth/login" @{} '{"correo":"segundo.coord@unbound.org","password":"password123"}'
Check "login segundo coordinador" 200 $loginC2.Status
$dC2 = $loginC2.Body | ConvertFrom-Json
$hC2 = @{ Authorization = "Bearer $($dC2.token)" }

# Descubrimiento dinamico desde la BD
$apadA = Sql-Scalar "SELECT a.id FROM apadrinado a JOIN usuario u ON u.id=a.id_usuario WHERE u.correo='juan.perez@unbound.org'"
$usuarioA = Sql-Scalar "SELECT id FROM usuario WHERE correo='juan.perez@unbound.org'"
$comunidadC = Sql-Scalar "SELECT id_comunidad FROM coordinador WHERE id=(SELECT c.id FROM coordinador c JOIN usuario u ON u.id=c.id_usuario WHERE u.correo='carlos.mendez@unbound.org')"
Write-Host "Descubierto: apadrinadoA=$apadA usuarioA=$usuarioA comunidadC=$comunidadC" -ForegroundColor Yellow

$ts = Get-Date -Format "HHmmss"
$futura = "2099-12-31"
$pasada = "2020-01-01"

function Crear-Actividad($titulo, $fechaLimite) {
  $body = '{"titulo":"' + $titulo + '","descripcion":"Actividad de prueba Fase E","fechaLimite":"' + $fechaLimite + '","apadrinadoId":' + $apadA + ',"requiereDocumento":false,"requiereFotografia":false}'
  return (Req POST "$base/actividades" $script:hC $body)
}

function Patch-Estado($actividadId, $estado, $obs) {
  $body = '{"estado":"' + $estado + '","observaciones":"' + $obs + '"}'
  return (Req Patch "$base/actividades/$actividadId/estado" $script:hC $body)
}

# ================== 3. AUTORIZACION DE ESTADOS ==================
$crea0 = Crear-Actividad "Actividad auth $ts" $futura
Check "coordinador crea actividad" 201 $crea0.Status
$idAct0 = ($crea0.Body | ConvertFrom-Json).id

$patchSinToken = Req Patch "$base/actividades/$idAct0/estado" @{} '{"estado":"ENTREGADA"}'
Check "cambiar estado sin token denegado" 401 $patchSinToken.Status

$patchApadrinado = Req Patch "$base/actividades/$idAct0/estado" $hA '{"estado":"ENTREGADA"}'
Check "apadrinado no cambia estado" 403 $patchApadrinado.Status

$vencidoApadrinado = Req POST "$base/actividades/$idAct0/vencido" $hA $null
Check "apadrinado no marca vencido" 403 $vencidoApadrinado.Status

$masivoApadrinado = Req POST "$base/actividades/marcar-vencidos" $hA '{}'
Check "apadrinado no ejecuta marcado masivo" 403 $masivoApadrinado.Status

$patchAjeno = Req Patch "$base/actividades/$idAct0/estado" $hC2 '{"estado":"ENTREGADA"}'
Check "coordinador ajeno no cambia estado" 403 $patchAjeno.Status

$vencidoAjeno = Req POST "$base/actividades/$idAct0/vencido" $hC2 $null
Check "coordinador ajeno no marca vencido" 403 $vencidoAjeno.Status

# ================== 4. FLUJO EN_REVISIÓN ==================
$tituloAct1 = "Actividad revision completa $ts"
$crea1 = Crear-Actividad $tituloAct1 $futura
Check "crear actividad para revision" 201 $crea1.Status
$act1 = $crea1.Body | ConvertFrom-Json
$idAct1 = $act1.id
Check "actividad inicia pendiente" "PENDIENTE" "$($act1.estado)"

$revDirecta = Patch-Estado $idAct1 "EN_REVISION" ""
Check "revision directa desde pendiente rechazada" 400 $revDirecta.Status

$entrega = Patch-Estado $idAct1 "ENTREGADA" "Entrega registrada"
Check "registrar entrega" 200 $entrega.Status
Check "estado tras entrega" "ENTREGADA" "$(($entrega.Body | ConvertFrom-Json).estado)"

$revision = Patch-Estado $idAct1 "EN_REVISION" "Iniciando revision"
Check "iniciar revision desde entregada" 200 $revision.Status
$actRevisada = $revision.Body | ConvertFrom-Json
Check "estado en revision" "EN_REVISION" "$($actRevisada.estado)"

$aprobacion = Patch-Estado $idAct1 "APROBADA" "Entrega aprobada"
Check "aprobar desde revision" 200 $aprobacion.Status
Check "estado aprobada" "APROBADA" "$(($aprobacion.Body | ConvertFrom-Json).estado)"

# Actividad 2: queda en EN_REVISION para filtrado
$tituloAct2 = "Actividad en revision $ts"
$crea2 = Crear-Actividad $tituloAct2 $futura
$idAct2 = ($crea2.Body | ConvertFrom-Json).id
Patch-Estado $idAct2 "ENTREGADA" "Entrega" | Out-Null
$revision2 = Patch-Estado $idAct2 "EN_REVISION" "En revision pendiente"
Check "actividad queda en revision" 200 $revision2.Status

# Historial de la revision
$hist2 = Req GET "$base/actividades/$idAct2/historial" $hC $null
Check "historial consultable" 200 $hist2.Status
$tieneRevisionIniciada = $false
foreach ($h in ($hist2.Body | ConvertFrom-Json)) {
  if ($h.accion -eq "REVISIÓN INICIADA" -and "$($h.estadoAnterior)" -eq "ENTREGADA" -and "$($h.estadoNuevo)" -eq "EN_REVISION") {
    $tieneRevisionIniciada = $true
  }
}
Check "historial registra la revision iniciada" $true $tieneRevisionIniciada

# ================== 5. ESTADO VENCIDO ==================
$tituloAct3 = "Actividad vencida individual $ts"
$crea3 = Crear-Actividad $tituloAct3 $pasada
Check "crear actividad con fecha limite pasada" 201 $crea3.Status
$idAct3 = ($crea3.Body | ConvertFrom-Json).id

$vencidoIndividual = Req POST "$base/actividades/$idAct3/vencido" $hC $null
Check "marcar actividad vencida" 200 $vencidoIndividual.Status
Check "estado vencido" "VENCIDO" "$(($vencidoIndividual.Body | ConvertFrom-Json).estado)"

$consulta3 = Req GET "$base/actividades/$idAct3" $hC $null
Check "consultar actividad vencida" 200 $consulta3.Status
Check "actividad permanece vencida" "VENCIDO" "$(($consulta3.Body | ConvertFrom-Json).estado)"

$hist3 = Req GET "$base/actividades/$idAct3/historial" $hC $null
$tieneVencimiento = $false
foreach ($h in ($hist3.Body | ConvertFrom-Json)) {
  if ($h.accion -eq "VENCIMIENTO" -and "$($h.estadoNuevo)" -eq "VENCIDO") {
    $tieneVencimiento = $true
  }
}
Check "historial registra el vencimiento" $true $tieneVencimiento

# Idempotencia: marcar de nuevo no falla
$vencidoDeNuevo = Req POST "$base/actividades/$idAct3/vencido" $hC $null
Check "marcar vencida idempotente" 200 $vencidoDeNuevo.Status

# Actividad 4: fecha futura, no puede vencerse
$crea4 = Crear-Actividad "Actividad futura $ts" $futura
$idAct4 = ($crea4.Body | ConvertFrom-Json).id
$vencidoFutura = Req POST "$base/actividades/$idAct4/vencido" $hC $null
Check "actividad futura no se marca vencida" 400 $vencidoFutura.Status

# Actividad 5: entregada, no puede vencerse
$crea5 = Crear-Actividad "Actividad entregada $ts" $pasada
$idAct5 = ($crea5.Body | ConvertFrom-Json).id
Patch-Estado $idAct5 "ENTREGADA" "Entrega a tiempo" | Out-Null
$vencidoEntregada = Req POST "$base/actividades/$idAct5/vencido" $hC $null
Check "actividad entregada no se marca vencida" 400 $vencidoEntregada.Status

# VENCIDO no es asignable via PATCH /estado
$patchVencido = Patch-Estado $idAct4 "VENCIDO" "intento"
Check "vencido no asignable por cambio de estado" 400 $patchVencido.Status

# ================== 6. MARCADO MASIVO ==================
$tituloAct6 = "Actividad masivo vencida $ts"
$crea6 = Crear-Actividad $tituloAct6 $pasada
$idAct6 = ($crea6.Body | ConvertFrom-Json).id
$tituloAct7 = "Actividad masivo vigente $ts"
$crea7 = Crear-Actividad $tituloAct7 $futura
$idAct7 = ($crea7.Body | ConvertFrom-Json).id

$masivo = Req POST "$base/actividades/marcar-vencidos" $hC '{}'
Check "marcado masivo de vencidos" 200 $masivo.Status
$marcaAct6 = $false
$marcaAct7 = $false
foreach ($m in ($masivo.Body | ConvertFrom-Json)) {
  if ("$($m.id)" -eq "$idAct6") { $marcaAct6 = $true }
  if ("$($m.id)" -eq "$idAct7") { $marcaAct7 = $true }
}
Check "marcado masivo marca la actividad vencida" $true $marcaAct6
Check "marcado masivo no marca la vigente" $false $marcaAct7

$consulta6 = Req GET "$base/actividades/$idAct6" $hC $null
Check "actividad masivo quedo vencida" "VENCIDO" "$(($consulta6.Body | ConvertFrom-Json).estado)"
$consulta7 = Req GET "$base/actividades/$idAct7" $hC $null
Check "actividad vigente permanece pendiente" "PENDIENTE" "$(($consulta7.Body | ConvertFrom-Json).estado)"

# Coordinador C2: marcado masivo no toca actividades ajenas
$masivoC2 = Req POST "$base/actividades/marcar-vencidos" $hC2 '{}'
Check "coordinador C2 ejecuta marcado masivo" 200 $masivoC2.Status
$marcaAct6C2 = $false
foreach ($m in ($masivoC2.Body | ConvertFrom-Json)) {
  if ("$($m.id)" -eq "$idAct6") { $marcaAct6C2 = $true }
}
Check "C2 no marca actividades ajenas" $false $marcaAct6C2

# ================== 7. FILTRADO POR ESTADO ==================
$filtroVencidas = Req GET "$base/actividades/apadrinado/$($apadA)?estado=VENCIDO" $hA $null
Check "filtrar actividades vencidas del apadrinado" 200 $filtroVencidas.Status
if ($filtroVencidas.Status -ne 200) {
  Write-Host "  DEBUG cuerpo de error: $($filtroVencidas.Body)" -ForegroundColor Yellow
}
$fVenAct3 = $false
$fVenAct6 = $false
$fVenAct7 = $false
foreach ($f in ($filtroVencidas.Body | ConvertFrom-Json)) {
  if ("$($f.id)" -eq "$idAct3") { $fVenAct3 = $true }
  if ("$($f.id)" -eq "$idAct6") { $fVenAct6 = $true }
  if ("$($f.id)" -eq "$idAct7") { $fVenAct7 = $true }
}
Check "lista de vencidas incluye la marcada" $true $fVenAct3
Check "lista de vencidas incluye la masiva" $true $fVenAct6
Check "lista de vencidas excluye la vigente" $false $fVenAct7

$filtroRevision = Req GET "$base/actividades/apadrinado/$($apadA)?estado=EN_REVISION" $hA $null
Check "filtrar actividades en revision" 200 $filtroRevision.Status
$fRevAct2 = $false
foreach ($f in ($filtroRevision.Body | ConvertFrom-Json)) {
  if ("$($f.id)" -eq "$idAct2") { $fRevAct2 = $true }
}
Check "lista en revision incluye la actividad" $true $fRevAct2

$filtroAprobadas = Req GET "$base/actividades/apadrinado/$($apadA)?estado=APROBADA" $hA $null
$fAprobAct1 = $false
foreach ($f in ($filtroAprobadas.Body | ConvertFrom-Json)) {
  if ("$($f.id)" -eq "$idAct1") { $fAprobAct1 = $true }
}
Check "lista aprobadas incluye la actividad" $true $fAprobAct1

# ================== 8. NOTIFICACIONES ==================
$notisA = Req GET "$base/notificaciones/usuario/$usuarioA" $hA $null
Check "apadrinado consulta sus notificaciones" 200 $notisA.Status
$tieneNotiRevision = $false
$tieneNotiVencida = $false
foreach ($n in ($notisA.Body | ConvertFrom-Json)) {
  if ($n.titulo -eq "Documento en revisión") { $tieneNotiRevision = $true }
  if ($n.titulo -eq "Actividad vencida" -and "$($n.mensaje)" -like "*$tituloAct3*") {
    $tieneNotiVencida = $true
  }
}
Check "notificacion de documento en revision" $true $tieneNotiRevision
Check "notificacion de actividad vencida" $true $tieneNotiVencida

# ================== 9. LISTA DEL COORDINADOR ==================
$listaC = Req GET "$base/actividades/coordinador/$($dC.coordinadorId)?estado=VENCIDO" $hC $null
Check "coordinador filtra sus actividades vencidas" 200 $listaC.Status
$cVenAct6 = $false
foreach ($f in ($listaC.Body | ConvertFrom-Json)) {
  if ("$($f.id)" -eq "$idAct6") { $cVenAct6 = $true }
}
Check "coordinador ve sus vencidas" $true $cVenAct6

Write-Host "`n================= RESULTADOS FASE E =================" -ForegroundColor Cyan
Write-Host "PASS: $($global:pass)" -ForegroundColor Green
Write-Host "FAIL: $($global:fail)" -ForegroundColor Red
if ($global:fail -gt 0) {
  Write-Host "`nPruebas fallidas:" -ForegroundColor Red
  $global:errores | ForEach-Object { Write-Host " - $_" -ForegroundColor Red }
} else {
  Write-Host "`nTodas las pruebas de la Fase E pasaron correctamente." -ForegroundColor Green
}
