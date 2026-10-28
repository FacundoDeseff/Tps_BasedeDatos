#Requires -Version 5.1
<#
.SYNOPSIS
    Respaldo diario de la base foodstore en formato personalizado (pg_dump -Fc).

.DESCRIPTION
    Genera backups/foodstore_YYYYMMDD_HHMM.dump escribiendo primero en
    foodstore_YYYYMMDD_HHMM.dump.parcial y renombrando solo si pg_dump
    termina con codigo 0. Registra el resultado en logs/backup_YYYYMMDD.log.

    - No pide ni guarda contrasenas: usa --no-password y deja la
      autenticacion en %APPDATA%\postgresql\pgpass.conf.
    - Ante cualquier error sale con codigo 1 y elimina el .parcial.
    - Aplica retencion: conserva los ultimos -Retention .dump.

.PARAMETER Server
    Host del servidor. Default: localhost.

.PARAMETER Port
    Puerto del servidor. Default: 5433 (entorno del TP).

.PARAMETER User
    Usuario de PostgreSQL. Default: postgres.

.PARAMETER Database
    Base a respaldar. Default: foodstore.

.PARAMETER PgBin
    Carpeta con pg_dump.exe / pg_restore.exe.

.PARAMETER BackupDir
    Carpeta destino de los .dump. Default: backups/ en la raiz del TP.

.PARAMETER LogDir
    Carpeta de logs. Default: logs/ en la raiz del TP.

.PARAMETER Retention
    Cantidad de .dump a conservar (>= 1). Default: 7.

.PARAMETER SkipVerify
    Omite la verificacion con pg_restore -l.

.EXAMPLE
    .\backup_foodstore.ps1 -Port 5432

.EXAMPLE
    .\backup_foodstore.ps1 -Port 5999
    # camino de error: exit 1, sin .dump y sin .parcial
#>
[CmdletBinding()]
param(
    [string]$Server = 'localhost',
    [int]$Port = 5433,
    [string]$User = 'postgres',
    [string]$Database = 'foodstore',
    [string]$PgBin = 'C:\Program Files\PostgreSQL\17\bin',
    [string]$BackupDir,
    [string]$LogDir,
    [int]$Retention = 7,
    [switch]$SkipVerify
)

$ErrorActionPreference = 'Stop'

$script:ExitCode = 0
$script:LogPath = $null
$script:ParcialPath = $null

function Write-Log {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'
    )
    $line = '[{0}] {1,-5} {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Write-Host $line
    if ($script:LogPath) {
        Add-Content -LiteralPath $script:LogPath -Value $line -Encoding UTF8
    }
}

function Remove-Parcial {
    if ($script:ParcialPath -and (Test-Path -LiteralPath $script:ParcialPath)) {
        Remove-Item -LiteralPath $script:ParcialPath -Force -ErrorAction SilentlyContinue
        Write-Log "Se elimino el archivo parcial incompleto: $script:ParcialPath" 'WARN'
    }
}

function Invoke-NativeTool {
    # Ejecuta una herramienta externa capturando stdout+stderr sin que
    # $ErrorActionPreference = 'Stop' convierta el stderr en excepcion.
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

try {
    # ------------------------------------------------------------------
    # 0. Validacion de parametros y herramientas
    # ------------------------------------------------------------------
    if ($Retention -lt 1) {
        throw "-Retention debe ser 1 o mas (recibido: $Retention)."
    }

    $root = Split-Path -Parent $PSScriptRoot
    if (-not $BackupDir) { $BackupDir = Join-Path $root 'backups' }
    if (-not $LogDir) { $LogDir = Join-Path $root 'logs' }

    $pgDump = Join-Path $PgBin 'pg_dump.exe'
    $pgRestore = Join-Path $PgBin 'pg_restore.exe'
    if (-not (Test-Path -LiteralPath $pgDump)) {
        throw "No se encontro pg_dump.exe en '$PgBin'. Usar -PgBin con la carpeta correcta."
    }

    foreach ($dir in @($BackupDir, $LogDir)) {
        if (-not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }

    $stamp = Get-Date -Format 'yyyyMMdd_HHmm'
    $script:LogPath = Join-Path $LogDir ('backup_{0}.log' -f (Get-Date -Format 'yyyyMMdd'))

    $fileName = '{0}_{1}.dump' -f $Database, $stamp
    $finalPath = Join-Path $BackupDir $fileName
    $script:ParcialPath = Join-Path $BackupDir ($fileName + '.parcial')

    Write-Log ('INICIO respaldo | servidor={0}:{1} | usuario={2} | base={3} | destino={4} | retencion={5}' -f `
            $Server, $Port, $User, $Database, $finalPath, $Retention)
    Write-Log 'Autenticacion: pgpass.conf (%APPDATA%\postgresql\pgpass.conf), sin contrasena en el script.'

    if (Test-Path -LiteralPath $finalPath) {
        throw "El archivo destino ya existe: $finalPath"
    }

    # ------------------------------------------------------------------
    # 1. Respaldo en .parcial
    # ------------------------------------------------------------------
    $dumpArgs = @(
        '-Fc'
        '--no-password'
        '-h', $Server
        '-p', "$Port"
        '-U', $User
        '-d', $Database
        '-f', $script:ParcialPath
    )

    Write-Log ('Ejecutando: pg_dump {0}' -f ($dumpArgs -join ' '))
    $dump = Invoke-NativeTool -FilePath $pgDump -Arguments $dumpArgs

    if ($dump.ExitCode -ne 0) {
        foreach ($line in $dump.Output) {
            if ($line.Trim()) { Write-Log ("pg_dump> " + $line) 'ERROR' }
        }
        throw "pg_dump termino con codigo $($dump.ExitCode)."
    }

    foreach ($line in $dump.Output) {
        if ($line.Trim()) { Write-Log ("pg_dump> " + $line) }
    }

    # ------------------------------------------------------------------
    # 2. Rename solo si el dump existe y no esta vacio
    # ------------------------------------------------------------------
    if (-not (Test-Path -LiteralPath $script:ParcialPath)) {
        throw 'pg_dump salio con codigo 0 pero no genero el archivo .parcial.'
    }

    $sizeBytes = (Get-Item -LiteralPath $script:ParcialPath).Length
    if ($sizeBytes -le 0) {
        throw 'El .parcial generado tiene 0 bytes.'
    }

    Move-Item -LiteralPath $script:ParcialPath -Destination $finalPath -Force
    $script:ParcialPath = $null

    $sizeMB = [math]::Round($sizeBytes / 1MB, 2)
    Write-Log "Dump generado: $finalPath ($sizeMB MB)"

    # ------------------------------------------------------------------
    # 3. Verificacion del artefacto
    # ------------------------------------------------------------------
    if (-not (Test-Path -LiteralPath $finalPath)) {
        throw "El archivo final no existe despues del rename: $finalPath"
    }

    $hash = (Get-FileHash -LiteralPath $finalPath -Algorithm SHA256).Hash
    Write-Log "SHA256=$hash"

    if (-not $SkipVerify) {
        if (-not (Test-Path -LiteralPath $pgRestore)) {
            throw "No se encontro pg_restore.exe en '$PgBin'; no se puede verificar el dump."
        }
        $list = Invoke-NativeTool -FilePath $pgRestore -Arguments @('-l', $finalPath)
        if ($list.ExitCode -ne 0) {
            foreach ($line in $list.Output) {
                if ($line.Trim()) { Write-Log ("pg_restore> " + $line) 'ERROR' }
            }
            throw "pg_restore -l fallo con codigo $($list.ExitCode): el dump no es legible."
        }
        $objetos = @($list.Output | Where-Object { $_ -match '^\d+;' }).Count
        Write-Log "pg_restore -l OK | objetos=$objetos"
        if ($objetos -lt 1) {
            throw 'pg_restore -l no listo ningun objeto: el dump esta vacio.'
        }
    }
    else {
        Write-Log 'pg_restore -l omitido (-SkipVerify).' 'WARN'
    }

    # ------------------------------------------------------------------
    # 4. Retencion: conservar los ultimos N .dump
    # ------------------------------------------------------------------
    $viejos = @(Get-ChildItem -LiteralPath $BackupDir -Filter ($Database + '_*.dump') -File |
            Sort-Object LastWriteTime -Descending |
            Select-Object -Skip $Retention)

    if ($viejos.Count -eq 0) {
        Write-Log "Retencion: no hay archivos para borrar (se conservan hasta $Retention)."
    }
    else {
        foreach ($viejo in $viejos) {
            Remove-Item -LiteralPath $viejo.FullName -Force
            Write-Log "Retencion: eliminado $($viejo.Name) ($($viejo.LastWriteTime.ToString('yyyy-MM-dd HH:mm')))"
        }
        Write-Log "Retencion: se conservan los ultimos $Retention .dump."
    }

    $activos = @(Get-ChildItem -LiteralPath $BackupDir -Filter ($Database + '_*.dump') -File)
    Write-Log "Dumps disponibles: $($activos.Count)"
    Write-Log "RESULTADO=OK archivo=$fileName tamano_mb=$sizeMB sha256=$hash"
}
catch {
    Write-Log ("ERROR: " + $_.Exception.Message) 'ERROR'
    Remove-Parcial
    $script:ExitCode = 1
    if ($script:LogPath) {
        $parcial = if ($script:ParcialPath) { $script:ParcialPath } else { 'ninguno' }
        Write-Log "RESULTADO=ERROR parcial=$parcial" 'ERROR'
    }
}
finally {
    Remove-Parcial
}

exit $script:ExitCode
