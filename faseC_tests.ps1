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

# Descubrimiento dinamico desde la BD (la BD conserva datos de ejecuciones anteriores)
$rolApadId = Sql-Scalar "SELECT id FROM rol WHERE nombre='Apadrinado'"
$comunidadC = Sql-Scalar "SELECT id_comunidad FROM coordinador WHERE id=$coordC"
$comunidadC2 = Sql-Scalar "SELECT id_comunidad FROM coordinador WHERE id=$coordC2"
Write-Host "Descubierto: rolApadId=$rolApadId comunidadC=$comunidadC (coord $coordC) comunidadC2=$comunidadC2 (coord $coordC2)" -ForegroundColor Yellow

# Asegurar el codigo de prueba CHIANTLA-26 en la comunidad del coordinador Carlos
docker exec unbound_db psql -U postgres -d unbound -t -A -c "INSERT INTO codigo_acceso (codigo, id_comunidad, id_coordinador, activo, fecha_creacion, fecha_expiracion, max_usos, usos, descripcion) SELECT 'CHIANTLA-26', $comunidadC, $coordC, TRUE, NOW(), NOW() + interval '6 months', 50, 0, 'Codigo de acceso de prueba' WHERE NOT EXISTS (SELECT 1 FROM codigo_acceso WHERE codigo='CHIANTLA-26' AND id_comunidad=$comunidadC);" | Out-Null

$ts = Get-Date -Format "HHmmss"

# Registrar dos usuarios nuevos con rol Apadrinado (sin perfil de apadrinado)
$correoNuevo = "nuevo$ts@unbound.org"
$regNuevo = Req POST "$base/auth/register" @{} ('{"nombre":"Nuevo Apadrinado","correo":"' + $correoNuevo + '","password":"password123","rolId":' + $rolApadId + '}')
Check "registro de nuevo apadrinado (sin comunidad)" 201 $regNuevo.Status
$idNuevo = ($regNuevo.Body | ConvertFrom-Json).usuarioId
$loginAN = Req POST "$base/auth/login" @{} ('{"correo":"' + $correoNuevo + '","password":"password123"}')
Check "login nuevo apadrinado" 200 $loginAN.Status
$dAN = $loginAN.Body | ConvertFrom-Json
$hAN = @{ Authorization = "Bearer $($dAN.token)" }

$correoOtro = "otro$ts@unbound.org"
$regOtro = Req POST "$base/auth/register" @{} ('{"nombre":"Otro Nuevo","correo":"' + $correoOtro + '","password":"password123","rolId":' + $rolApadId + '}')
Check "registro de segundo nuevo apadrinado" 201 $regOtro.Status
$idOtro = ($regOtro.Body | ConvertFrom-Json).usuarioId
$loginAN2 = Req POST "$base/auth/login" @{} ('{"correo":"' + $correoOtro + '","password":"password123"}')
Check "login segundo nuevo apadrinado" 200 $loginAN2.Status
$dAN2 = $loginAN2.Body | ConvertFrom-Json
$hAN2 = @{ Authorization = "Bearer $($dAN2.token)" }

# ================== 3. CODIGOS DE ACCESO ==================
$listaCodA = Req GET "$base/codigos-acceso/comunidad/$comunidadC" $hA $null
Check "apadrinado no lista codigos de acceso" 403 $listaCodA.Status
$listaCodC = Req GET "$base/codigos-acceso/comunidad/$comunidadC" $hC $null
Check "coordinador lista codigos de su comunidad" 200 $listaCodC.Status
$codigosC = @($listaCodC.Body | ConvertFrom-Json)
$chi26 = $codigosC | Where-Object { $_.codigo -eq "CHIANTLA-26" } | Select-Object -First 1
Check "codigo de prueba CHIANTLA-26 existe" $true ($null -ne $chi26)
if ($null -ne $chi26) {
  Check "CHIANTLA-26 esta activo" $true ([bool]$chi26.activo)
}
$listaCodC2Ajeno = Req GET "$base/codigos-acceso/comunidad/$comunidadC2" $hC $null
Check "coordinador no lista codigos de comunidad ajena" 403 $listaCodC2Ajeno.Status
$listaCodC2 = Req GET "$base/codigos-acceso/comunidad/$comunidadC2" $hC2 $null
Check "coordinador C2 lista codigos de su comunidad" 200 $listaCodC2.Status
$crearCodA = Req POST "$base/codigos-acceso/comunidad/$comunidadC" $hA '{"descripcion":"Hack"}'
Check "apadrinado no genera codigos de acceso" 403 $crearCodA.Status
$crearCodAjeno = Req POST "$base/codigos-acceso/comunidad/$comunidadC2" $hC '{"descripcion":"Hack"}'
Check "coordinador no genera codigos en comunidad ajena" 403 $crearCodAjeno.Status
$crearCodC2 = Req POST "$base/codigos-acceso/comunidad/$comunidadC2" $hC2 '{"descripcion":"Codigo de prueba C2"}'
Check "coordinador genera codigo de acceso" 201 $crearCodC2.Status
$dCodC2 = $crearCodC2.Body | ConvertFrom-Json
Check "codigo generado tiene 8 caracteres" $true ($dCodC2.codigo.Length -eq 8)
Check "codigo generado pertenece a la comunidad" "$coordC2" "$($dCodC2.coordinadorId)"
Check "codigo generado pertenece a la comunidad C2" "$comunidadC2" "$($dCodC2.comunidadId)"
$codC2Id = $dCodC2.id
$codC2Texto = $dCodC2.codigo
$delCodAjeno = Req DELETE "$base/codigos-acceso/$codC2Id" $hC $null
Check "coordinador no desactiva codigo ajeno" 403 $delCodAjeno.Status
$delCodC2 = Req DELETE "$base/codigos-acceso/$codC2Id" $hC2 $null
Check "coordinador desactiva su codigo" 204 $delCodC2.Status
$crearCodPropio = Req POST "$base/codigos-acceso/comunidad/$comunidadC" $hC '{"descripcion":"Codigo propio"}'
Check "coordinador genera codigo en su comunidad" 201 $crearCodPropio.Status
$codPropioId = ($crearCodPropio.Body | ConvertFrom-Json).id
$delCodPropio = Req DELETE "$base/codigos-acceso/$codPropioId" $hC $null
Check "coordinador desactiva su propio codigo" 204 $delCodPropio.Status
$codSinToken = Req GET "$base/codigos-acceso/comunidad/$comunidadC" @{} $null
Check "codigos de acceso sin token denegado" 401 $codSinToken.Status

# ================== 4. SOLICITUDES DE INCORPORACION ==================
# Juan ya tiene comunidad -> no puede solicitar
$solConComunidad = Req POST "$base/solicitudes-incorporacion" $hA ('{"comunidadId":' + $comunidadC + ',"codigo":"CHIANTLA-26"}')
Check "apadrinado con comunidad no puede solicitar" 403 $solConComunidad.Status
# Coordinador no es rol Apadrinado -> no puede solicitar
$solCoord = Req POST "$base/solicitudes-incorporacion" $hC ('{"comunidadId":' + $comunidadC + ',"codigo":"CHIANTLA-26"}')
Check "coordinador no puede solicitar incorporacion" 403 $solCoord.Status
# Codigo invalido
$solInvalido = Req POST "$base/solicitudes-incorporacion" $hAN ('{"comunidadId":' + $comunidadC + ',"codigo":"INVALIDO"}')
Check "solicitud con codigo invalido rechazada" 400 $solInvalido.Status
# Codigo de otra comunidad
$solOtraCom = Req POST "$base/solicitudes-incorporacion" $hAN ('{"comunidadId":' + $comunidadC2 + ',"codigo":"CHIANTLA-26"}')
Check "solicitud con codigo de otra comunidad rechazada" 400 $solOtraCom.Status
# Solicitud valida
$solValida = Req POST "$base/solicitudes-incorporacion" $hAN ('{"comunidadId":' + $comunidadC + ',"codigo":"CHIANTLA-26"}')
Check "solicitud de incorporacion valida creada" 201 $solValida.Status
$dSol = $solValida.Body | ConvertFrom-Json
Check "solicitud queda PENDIENTE" "PENDIENTE" $dSol.estado
Check "solicitud registra el codigo usado" "CHIANTLA-26" $dSol.codigo
Check "solicitud apunta a la comunidad correcta" "$comunidadC" "$($dSol.comunidadId)"
$solId = $dSol.id
# Duplicada
$solDup = Req POST "$base/solicitudes-incorporacion" $hAN ('{"comunidadId":' + $comunidadC + ',"codigo":"CHIANTLA-26"}')
Check "solicitud duplicada (pendiente) rechazada" 400 $solDup.Status
# Mias
$mias = Req GET "$base/solicitudes-incorporacion/mias" $hAN $null
Check "usuario lista sus solicitudes" 200 $mias.Status
$idsMias = @(($mias.Body | ConvertFrom-Json) | ForEach-Object { "$($_.id)" })
Check "sus solicitudes incluyen la creada" $true ($idsMias -contains "$solId")
# Pendientes: coordinador vs apadrinado vs otro coordinador
$pendA = Req GET "$base/solicitudes-incorporacion/pendientes" $hA $null
Check "apadrinado no lista solicitudes pendientes" 403 $pendA.Status
$pendC = Req GET "$base/solicitudes-incorporacion/pendientes" $hC $null
Check "coordinador lista pendientes de su comunidad" 200 $pendC.Status
$idsPendC = @(($pendC.Body | ConvertFrom-Json) | ForEach-Object { "$($_.id)" })
Check "pendientes incluye la solicitud" $true ($idsPendC -contains "$solId")
$pendC2 = Req GET "$base/solicitudes-incorporacion/pendientes" $hC2 $null
Check "coordinador C2 lista sus pendientes" 200 $pendC2.Status
$idsPendC2 = @(($pendC2.Body | ConvertFrom-Json) | ForEach-Object { "$($_.id)" })
Check "coordinador C2 no ve solicitudes de otra comunidad" $false ($idsPendC2 -contains "$solId")
# Aprobar/rechazar por coordinador ajeno
$aprobAjeno = Req PATCH "$base/solicitudes-incorporacion/$solId/aprobar" $hC2 $null
Check "coordinador ajeno no aprueba solicitud" 403 $aprobAjeno.Status
$rechAjeno = Req PATCH "$base/solicitudes-incorporacion/$solId/rechazar" $hC2 $null
Check "coordinador ajeno no rechaza solicitud" 403 $rechAjeno.Status

# Aprobar la solicitud (con verificacion de usos del codigo en la BD)
$usosAntes = Sql-Scalar "SELECT usos FROM codigo_acceso WHERE codigo='CHIANTLA-26' AND id_comunidad=$comunidadC"
$aprob = Req PATCH "$base/solicitudes-incorporacion/$solId/aprobar" $hC $null
Check "coordinador responsable aprueba solicitud" 200 $aprob.Status
$dAprob = $aprob.Body | ConvertFrom-Json
Check "solicitud aprobada cambia a APROBADA" "APROBADA" $dAprob.estado
# Verificar que se creo el perfil de apadrinado
$perfilNuevo = Req GET "$base/apadrinados/usuario/$idNuevo" $hAN $null
Check "aprobacion crea perfil de apadrinado" 200 $perfilNuevo.Status
$dPerfil = $perfilNuevo.Body | ConvertFrom-Json
Check "apadrinado aprobado queda en la comunidad" "$comunidadC" "$($dPerfil.comunidadId)"
Check "apadrinado aprobado queda bajo el coordinador que aprobo" "$coordC" "$($dPerfil.coordinadorId)"
# Verificar expediente creado
$expNuevo = Req GET "$base/expedientes/apadrinado/$($dPerfil.id)" $hAN $null
Check "aprobacion crea expediente del apadrinado" 200 $expNuevo.Status
# Verificar uso del codigo (en la BD)
$usosDespues = Sql-Scalar "SELECT usos FROM codigo_acceso WHERE codigo='CHIANTLA-26' AND id_comunidad=$comunidadC"
Check "aprobacion registra el uso del codigo" ($usosAntes + 1) $usosDespues
# Ahora el usuario ya tiene comunidad
$solDespues = Req POST "$base/solicitudes-incorporacion" $hAN ('{"comunidadId":' + $comunidadC + ',"codigo":"CHIANTLA-26"}')
Check "usuario con comunidad ya no puede solicitar" 403 $solDespues.Status
# Aprobar solicitud ya resuelta
$aprobDup = Req PATCH "$base/solicitudes-incorporacion/$solId/aprobar" $hC $null
Check "no se puede aprobar solicitud ya resuelta" 400 $aprobDup.Status

# ================== 5. FLUJO DE RECHAZO ==================
# C2 genera un codigo nuevo para su comunidad
$crearCodC2b = Req POST "$base/codigos-acceso/comunidad/$comunidadC2" $hC2 '{"descripcion":"Codigo C2 para rechazo"}'
Check "coordinador C2 genera codigo" 201 $crearCodC2b.Status
$codC2bTexto = ($crearCodC2b.Body | ConvertFrom-Json).codigo
# otro usuario nuevo solicita comunidad C2
$sol2 = Req POST "$base/solicitudes-incorporacion" $hAN2 ('{"comunidadId":' + $comunidadC2 + ',"codigo":"' + $codC2bTexto + '"}')
Check "segunda solicitud de incorporacion creada" 201 $sol2.Status
$dSol2 = $sol2.Body | ConvertFrom-Json
$sol2Id = $dSol2.id
Check "segunda solicitud PENDIENTE" "PENDIENTE" $dSol2.estado
Check "segunda solicitud apunta a la comunidad C2" "$comunidadC2" "$($dSol2.comunidadId)"
# C2 la rechaza con observaciones
$rech = Req PATCH "$base/solicitudes-incorporacion/$sol2Id/rechazar?observaciones=Codigo%20invalido" $hC2 $null
Check "coordinador responsable rechaza solicitud" 200 $rech.Status
$dRech = $rech.Body | ConvertFrom-Json
Check "solicitud rechazada cambia a RECHAZADA" "RECHAZADA" $dRech.estado
Check "se guardan las observaciones del rechazo" $true ($dRech.observaciones -ne $null)
# El usuario rechazado NO tiene perfil de apadrinado
$perfilRechazado = Req GET "$base/apadrinados/usuario/$idOtro" $hAN2 $null
Check "usuario rechazado no obtiene perfil de apadrinado" 404 $perfilRechazado.Status
# El usuario rechazado puede volver a solicitar (no tiene pendientes)
$sol2b = Req POST "$base/solicitudes-incorporacion" $hAN2 ('{"comunidadId":' + $comunidadC2 + ',"codigo":"' + $codC2bTexto + '"}')
Check "usuario rechazado puede solicitar de nuevo" 201 $sol2b.Status

Write-Host "`n================= RESULTADOS FASE C =================" -ForegroundColor Cyan
Write-Host "PASS: $($global:pass)" -ForegroundColor Green
Write-Host "FAIL: $($global:fail)" -ForegroundColor Red
if ($global:fail -gt 0) {
  Write-Host "`nPruebas fallidas:" -ForegroundColor Red
  $global:errores | ForEach-Object { Write-Host " - $_" -ForegroundColor Red }
} else {
  Write-Host "`nTodas las pruebas de la Fase C pasaron correctamente." -ForegroundColor Green
}
