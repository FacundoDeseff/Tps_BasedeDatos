#Requires -Version 5.1
<#
.SYNOPSIS
    Simulacro de restauracion de foodstore en foodstore_restore_test (Parte 4).

.DESCRIPTION
    Restaura el ultimo respaldo (o el indicado con -DumpFile) en la base
    descartable foodstore_restore_test, corre las validaciones y mide RTO/RPO.

    Garantias de seguridad:
    - La base destino es una CONSTANTE: 'foodstore_restore_test'. No hay
      parametro -Database, asi que el script no puede apuntar a foodstore.
    - Antes de ejecutar nada valida que el dump exista, no este vacio y sea
      legible con pg_restore -l (y que contenga las 5 tablas del TP8).
    - Solo usa dropdb/createdb sobre la constante; nunca sobre foodstore.
    - Al terminar deja foodstore_restore_test para inspeccion.

    Medicion:
    - RTO = desde inmediatamente antes de createdb hasta que termina la
      validacion (el PDF pide arrancar el cronometro antes de crear la base).
    - RPO = antiguedad del dump al momento de iniciar el cronometro.

    Sale con codigo 0 si la validacion devuelve PASS y 1 en cualquier otro caso.

.PARAMETER DumpFile
    Ruta del .dump a restaurar. Si se omite, toma el ultimo
    foodstore_YYYYMMDD_HHMM.dump de backups/ ordenado por nombre.

.PARAMETER Port
    Puerto del servidor. Default: 5432.

.EXAMPLE
    .\restore_test.ps1 -Port 5432

.EXAMPLE
    .\restore_test.ps1 -DumpFile C:\no\existe.dump
    # camino de error: aborta ANTES de crear ninguna base
#>
[CmdletBinding()]
param(
    [string]$Server = 'localhost',
    [int]$Port = 5432,
    [string]$User = 'postgres',
    [string]$PgBin,
    [string]$DumpFile,
    [string]$LogDir,
    [int]$ConnectTimeout = 15
)

$ErrorActionPreference = 'Stop'

# ----------------------------------------------------------------------
# Constantes de seguridad: la base destino NO es parametrizable.
# ----------------------------------------------------------------------
$TargetDatabase    = 'foodstore_restore_test'
$ForbiddenDatabase = 'foodstore'

$script:ExitCode = 0
$script:LogPath = $null
$script:Inv = [Globalization.CultureInfo]::InvariantCulture

function Write-Log {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'
    )
    $line = '[{0}] {1,-5} {2}' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss', $script:Inv), $Level, $Message
    Write-Host $line
    if (-not $script:LogPath) { return }
    try {
        Add-Content -LiteralPath $script:LogPath -Value $line -Encoding UTF8 -ErrorAction Stop
    }
    catch {
        Write-Host ("[WARN ] No se pudo escribir en el log '{0}': {1}" -f $script:LogPath, $_.Exception.Message)
    }
}

function Resolve-PgBin {
    param([string]$Explicito)
    if ($Explicito) { return $Explicito }
    $enPath = Get-Command 'pg_restore.exe' -ErrorAction SilentlyContinue
    if ($enPath) { return (Split-Path -Parent $enPath.Source) }
    $mejor = $null
    $mejorVer = $null
    foreach ($f in @(Get-ChildItem -Path 'C:\Program Files\PostgreSQL\*\bin\pg_restore.exe' -ErrorAction SilentlyContinue)) {
        $verTxt = Split-Path -Leaf (Split-Path -Parent (Split-Path -Parent $f.FullName))
        try { $ver = [version]$verTxt } catch { continue }
        if (-not $mejorVer -or $ver -gt $mejorVer) { $mejorVer = $ver; $mejor = $f.DirectoryName }
    }
    return $mejor
}

function Invoke-NativeTool {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & $FilePath @Arguments 2>&1
        $code = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previous
    }
    return [pscustomobject]@{
        ExitCode = $code
        Output   = @($output | ForEach-Object { [string]$_ })
    }
}

function Format-Duracion {
    param([double]$Segundos)
    $ts = [TimeSpan]::FromSeconds($Segundos)
    return ('{0:mm\:ss} ({1:N1} s)' -f $ts, $Segundos)
}

try {
    # ------------------------------------------------------------------
    # 0. Guardia: la base destino jamas puede ser foodstore
    # ------------------------------------------------------------------
    if ($TargetDatabase -ne 'foodstore_restore_test') {
        throw "Constante TargetDatabase invalida: '$TargetDatabase'."
    }
    if ($TargetDatabase -eq $ForbiddenDatabase) {
        throw 'ABORTADO: el script no puede operar sobre foodstore.'
    }

    # ------------------------------------------------------------------
    # 1. Log y herramientas
    # ------------------------------------------------------------------
    $root = Split-Path -Parent $PSScriptRoot
    if (-not $LogDir) { $LogDir = Join-Path $root 'logs' }
    $now = Get-Date
    $logName = 'restore_{0}.log' -f $now.ToString('yyyyMMdd', $script:Inv)
    try {
        if (-not (Test-Path -LiteralPath $LogDir)) {
            New-Item -ItemType Directory -Path $LogDir -Force -ErrorAction Stop | Out-Null
        }
        $script:LogPath = Join-Path $LogDir $logName
    }
    catch {
        $script:LogPath = Join-Path $env:TEMP $logName
        Write-Host ("[WARN ] No se pudo usar '{0}' para logs ({1}). Se usa '{2}'." -f $LogDir, $_.Exception.Message, $script:LogPath)
    }

    $PgBin = Resolve-PgBin -Explicito $PgBin
    if (-not $PgBin) {
        throw 'No se encontro pg_restore.exe ni en el PATH ni en C:\Program Files\PostgreSQL\<version>\bin.'
    }
    $pgRestore = Join-Path $PgBin 'pg_restore.exe'
    $psql = Join-Path $PgBin 'psql.exe'
    $createdb = Join-Path $PgBin 'createdb.exe'
    $dropdb = Join-Path $PgBin 'dropdb.exe'
    foreach ($tool in @($pgRestore, $psql, $createdb, $dropdb)) {
        if (-not (Test-Path -LiteralPath $tool)) {
            throw "No se encontro la herramienta: $tool"
        }
    }

    # ------------------------------------------------------------------
    # 2. Resolver y validar el dump ANTES de tocar cualquier base
    # ------------------------------------------------------------------
    if (-not $DumpFile) {
        $backupDir = Join-Path $root 'backups'
        $patron = '^foodstore_\d{8}_\d{4}\.dump$'
        $candidatos = @(Get-ChildItem -LiteralPath $backupDir -File -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match $patron } |
                Sort-Object -Property Name -Descending)
        if ($candidatos.Count -eq 0) {
            throw "No hay respaldos foodstore_YYYYMMDD_HHMM.dump en '$backupDir'. Generar uno con backup_foodstore.ps1."
        }
        $DumpFile = $candidatos[0].FullName
    }

    if (-not (Test-Path -LiteralPath $DumpFile)) {
        throw "El dump no existe: $DumpFile. No se creo ninguna base."
    }
    $dumpItem = Get-Item -LiteralPath $DumpFile
    if ($dumpItem.Length -le 0) {
        throw "El dump tiene 0 bytes: $DumpFile. No se creo ninguna base."
    }
    $dumpHash = (Get-FileHash -LiteralPath $dumpItem.FullName -Algorithm SHA256).Hash
    $dumpMB = [math]::Round($dumpItem.Length / 1MB, 2)

    Write-Log ('INICIO simulacro | destino={0} | puerto={1} | dump={2} | bytes={3} | sha256={4}' -f `
            $TargetDatabase, $Port, $dumpItem.FullName, $dumpItem.Length, $dumpHash)

    $list = Invoke-NativeTool -FilePath $pgRestore -Arguments @('-l', $dumpItem.FullName)
    if ($list.ExitCode -ne 0) {
        foreach ($line in $list.Output) { if ($line.Trim()) { Write-Log ("pg_restore> " + $line) 'ERROR' } }
        throw "pg_restore -l fallo con codigo $($list.ExitCode): el dump no es legible. No se creo ninguna base."
    }
    $esperadas = @('categoria', 'producto', 'usuario', 'pedido', 'detalle_pedido')
    $faltantes = @($esperadas | Where-Object { -not ($list.Output -match ("\bTABLE public {0}\b" -f $_)) })
    if ($faltantes.Count -gt 0) {
        throw ("El dump no contiene las tablas esperadas: {0}. No se creo ninguna base." -f ($faltantes -join ', '))
    }
    $objetos = @($list.Output | Where-Object { $_ -match '^\d+;' }).Count
    Write-Log ("Pre-flight OK | objetos={0} | tablas={1}" -f $objetos, ($esperadas -join ','))

    $validaciones = Join-Path $root 'sql\validaciones_restore.sql'
    $checkSql = Join-Path $root 'sql\validaciones_restore_check.sql'
    if (-not (Test-Path -LiteralPath $validaciones)) { throw "No se encontro $validaciones" }
    if (-not (Test-Path -LiteralPath $checkSql)) { throw "No se encontro $checkSql" }

    if (-not $env:PGCONNECT_TIMEOUT) { $env:PGCONNECT_TIMEOUT = "$ConnectTimeout" }

    # ------------------------------------------------------------------
    # 3. Base descartable: borrar si quedo de una corrida anterior
    # ------------------------------------------------------------------
    $drop = Invoke-NativeTool -FilePath $dropdb -Arguments @('-w', '--if-exists', '-h', $Server, '-p', "$Port", '-U', $User, $TargetDatabase)
    foreach ($line in $drop.Output) { if ($line.Trim()) { Write-Log ("dropdb> " + $line) } }
    if ($drop.ExitCode -ne 0) {
        throw "dropdb fallo con codigo $($drop.ExitCode) sobre '$TargetDatabase'."
    }

    # ------------------------------------------------------------------
    # 4. T0 y createdb
    # ------------------------------------------------------------------
    $t0 = Get-Date
    Write-Log ('T0={0} | creando {1}' -f $t0.ToString('yyyy-MM-dd HH:mm:ss.fff', $script:Inv), $TargetDatabase)

    $create = Invoke-NativeTool -FilePath $createdb -Arguments @('-w', '-h', $Server, '-p', "$Port", '-U', $User, $TargetDatabase)
    foreach ($line in $create.Output) { if ($line.Trim()) { Write-Log ("createdb> " + $line) 'ERROR' } }
    if ($create.ExitCode -ne 0) {
        throw "createdb fallo con codigo $($create.ExitCode)."
    }

    # ------------------------------------------------------------------
    # 5. Restauracion
    # ------------------------------------------------------------------
    Write-Log ('Ejecutando: pg_restore -h {0} -p {1} -U {2} -d {3} --no-owner --no-privileges --exit-on-error {4}' -f `
            $Server, $Port, $User, $TargetDatabase, $dumpItem.FullName)
    $restore = Invoke-NativeTool -FilePath $pgRestore -Arguments @(
        '-w', '-h', $Server, '-p', "$Port", '-U', $User, '-d', $TargetDatabase,
        '--no-owner', '--no-privileges', '--exit-on-error', $dumpItem.FullName
    )
    foreach ($line in $restore.Output) { if ($line.Trim()) { Write-Log ("pg_restore> " + $line) } }
    if ($restore.ExitCode -ne 0) {
        throw "pg_restore fallo con codigo $($restore.ExitCode). La base '$TargetDatabase' quedo para inspeccion."
    }

    # ------------------------------------------------------------------
    # 6. Validaciones detalladas + check de una linea
    # ------------------------------------------------------------------
    $detalle = Invoke-NativeTool -FilePath $psql -Arguments @(
        '-w', '-h', $Server, '-p', "$Port", '-U', $User, '-d', $TargetDatabase,
        '-v', 'ON_ERROR_STOP=1', '-f', $validaciones
    )
    foreach ($line in $detalle.Output) { Write-Log ("validacion> " + $line) }
    if ($detalle.ExitCode -ne 0) {
        throw "La validacion detallada fallo con codigo $($detalle.ExitCode)."
    }

    $check = Invoke-NativeTool -FilePath $psql -Arguments @(
        '-w', '-h', $Server, '-p', "$Port", '-U', $User, '-d', $TargetDatabase,
        '-At', '-v', 'ON_ERROR_STOP=1', '-f', $checkSql
    )
    $resultado = ''
    if ($check.Output.Count -gt 0) {
        $resultado = (@($check.Output | Where-Object { $_.Trim() }) | Select-Object -Last 1)
        if ($resultado) { $resultado = $resultado.Trim() }
    }
    $t1 = Get-Date

    if ($check.ExitCode -ne 0) {
        throw "El check de validacion fallo con codigo $($check.ExitCode)."
    }
    if ($resultado -ne 'PASS') {
        throw "Validacion NO conforme: $resultado. La base '$TargetDatabase' quedo para inspeccion."
    }

    # ------------------------------------------------------------------
    # 7. Metricas
    # ------------------------------------------------------------------
    $rtoSeg = ($t1 - $t0).TotalSeconds
    $rpoSeg = ($t0 - $dumpItem.LastWriteTime).TotalSeconds
    if ($rpoSeg -lt 0) { $rpoSeg = 0 }

    Write-Log ('T1={0} | validacion={1}' -f $t1.ToString('yyyy-MM-dd HH:mm:ss.fff', $script:Inv), $resultado)
    Write-Log ('RTO={0} | RPO={1}' -f (Format-Duracion $rtoSeg), (Format-Duracion $rpoSeg))
    Write-Log ('RESULTADO=OK base={0} dump={1} bytes={2} sha256={3} validacion={4} rto_s={5:N1} rpo_s={6:N1}' -f `
            $TargetDatabase, $dumpItem.Name, $dumpItem.Length, $dumpHash, $resultado, $rtoSeg, $rpoSeg)
}
catch {
    Write-Log ("ERROR: " + $_.Exception.Message) 'ERROR'
    $script:ExitCode = 1
    Write-Log 'RESULTADO=ERROR' 'ERROR'
}

exit $script:ExitCode
