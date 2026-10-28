#Requires -Version 5.1
<#
.SYNOPSIS
    Respaldo diario de la base foodstore en formato personalizado (pg_dump -Fc).

.DESCRIPTION
    Genera backups/foodstore_YYYYMMDD_HHMM.dump escribiendo primero en
    foodstore_YYYYMMDD_HHMM.dump.parcial y renombrando solo si pg_dump
    termina con codigo 0 y el artefacto pasa la verificacion.
    Registra el resultado en logs/backup_YYYYMMDD.log.

    - No pide ni guarda contrasenas: usa --no-password y deja la
      autenticacion en %APPDATA%\postgresql\pgpass.conf.
    - Ante cualquier error sale con codigo 1 y elimina el .parcial.
    - Verifica el .parcial con pg_restore -l ANTES de renombrarlo, para
      que ningun dump ilegible quede como respaldo "valido".
    - Aplica retencion: conserva los ultimos -Retention .dump de esta base.

.PARAMETER Server
    Host del servidor. Default: localhost.

.PARAMETER Port
    Puerto del servidor. Default: 5433 (entorno del TP). En la maquina de
    Facu Deseff / Santi el servidor escucha en 5432: pasar -Port 5432.

.PARAMETER User
    Usuario de PostgreSQL. Default: postgres.

.PARAMETER Database
    Base a respaldar. Default: foodstore.

.PARAMETER PgBin
    Carpeta con pg_dump.exe / pg_restore.exe. Si se omite, se resuelve
    pg_dump.exe desde el PATH y, si no esta, desde la instalacion mas
    reciente en C:\Program Files\PostgreSQL\<version>\bin.

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
    [string]$PgBin,
    [string]$BackupDir,
    [string]$LogDir,
    [int]$Retention = 7,
    [switch]$SkipVerify
)

$ErrorActionPreference = 'Stop'

$script:ExitCode = 0
$script:LogPath = $null
$script:LogFallbackUsado = $false
$script:ParcialPath = $null

# La cultura actual podria usar otro calendario (p. ej. ar-SA) y romper el
# nombre foodstore_YYYYMMDD_HHMM.dump. Todo lo que va a nombre de archivo
# se formatea con la cultura invariante.
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
        # Un log ilegible (bloqueado, disco lleno, carpeta borrada) no debe
        # tumbar el respaldo ni impedir que se registre el error real.
        Write-Host ("[WARN ] No se pudo escribir en el log '{0}': {1}" -f $script:LogPath, $_.Exception.Message)
        if (-not $script:LogFallbackUsado) {
            $script:LogFallbackUsado = $true
            try {
                $alt = Join-Path $env:TEMP ('backup_emergencia_{0}.log' -f (Get-Date).ToString('yyyyMMdd', $script:Inv))
                Add-Content -LiteralPath $alt -Value $line -Encoding UTF8 -ErrorAction Stop
                Write-Host "[WARN ] Se registro en el log de emergencia: $alt"
            }
            catch {
                Write-Host '[WARN ] Tampoco se pudo escribir el log de emergencia; solo queda la salida por consola.'
            }
        }
    }
}

function Remove-Parcial {
    if (-not $script:ParcialPath) { return }
    if (-not (Test-Path -LiteralPath $script:ParcialPath)) { return }
    try {
        Remove-Item -LiteralPath $script:ParcialPath -Force -ErrorAction Stop
        Write-Log "Se elimino el archivo parcial incompleto: $script:ParcialPath" 'WARN'
    }
    catch {
        Write-Log ("No se pudo eliminar el .parcial '{0}': {1}" -f $script:ParcialPath, $_.Exception.Message) 'ERROR'
    }
}

function Resolve-PgBin {
    param([string]$Explicito)
    if ($Explicito) { return $Explicito }

    $enPath = Get-Command 'pg_dump.exe' -ErrorAction SilentlyContinue
    if ($enPath) { return (Split-Path -Parent $enPath.Source) }

    # Si hay varias versiones instaladas, se usa la mas nueva de verdad
    # (comparando version, no alfabeticamente: "9" > "17" como texto).
    $mejor = $null
    $mejorVer = $null
    foreach ($f in @(Get-ChildItem -Path 'C:\Program Files\PostgreSQL\*\bin\pg_dump.exe' -ErrorAction SilentlyContinue)) {
        $verTxt = Split-Path -Leaf (Split-Path -Parent (Split-Path -Parent $f.FullName))
        try { $ver = [version]$verTxt } catch { continue }
        if (-not $mejorVer -or $ver -gt $mejorVer) {
            $mejorVer = $ver
            $mejor = $f.DirectoryName
        }
    }
    return $mejor
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
    # 0. Log primero: cualquier fallo posterior tiene que quedar registrado
    # ------------------------------------------------------------------
    $root = Split-Path -Parent $PSScriptRoot
    if (-not $BackupDir) { $BackupDir = Join-Path $root 'backups' }
    if (-not $LogDir) { $LogDir = Join-Path $root 'logs' }

    $now = Get-Date
    $stamp = $now.ToString('yyyyMMdd_HHmm', $script:Inv)
    $logName = 'backup_{0}.log' -f $now.ToString('yyyyMMdd', $script:Inv)

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

    # ------------------------------------------------------------------
    # 1. Validacion de parametros y herramientas
    # ------------------------------------------------------------------
    if ($Retention -lt 1) {
        throw "-Retention debe ser 1 o mas (recibido: $Retention)."
    }

    $PgBin = Resolve-PgBin -Explicito $PgBin
    if (-not $PgBin) {
        throw 'No se encontro pg_dump.exe ni en el PATH ni en C:\Program Files\PostgreSQL\<version>\bin. Usar -PgBin con la carpeta correcta.'
    }

    $pgDump = Join-Path $PgBin 'pg_dump.exe'
    $pgRestore = Join-Path $PgBin 'pg_restore.exe'
    if (-not (Test-Path -LiteralPath $pgDump)) {
        throw "No se encontro pg_dump.exe en '$PgBin'. Usar -PgBin con la carpeta correcta."
    }

    if (-not (Test-Path -LiteralPath $BackupDir)) {
        New-Item -ItemType Directory -Path $BackupDir -Force -ErrorAction Stop | Out-Null
    }

    $fileName = '{0}_{1}.dump' -f $Database, $stamp
    $finalPath = Join-Path $BackupDir $fileName
    # El nombre final mantiene la resolucion de minuto que pide el SPEC.
    # El .parcial lleva segundos para que dos corridas concurrentes no
    # escriban el mismo archivo temporal (sigue cumpliendo *.dump.parcial).
    $parcialStamp = $now.ToString('yyyyMMdd_HHmmss', $script:Inv)
    $script:ParcialPath = Join-Path $BackupDir ('{0}_{1}.dump.parcial' -f $Database, $parcialStamp)

    # Timeout de conexion: un servidor colgado no debe colgar la tarea programada.
    if (-not $env:PGCONNECT_TIMEOUT) { $env:PGCONNECT_TIMEOUT = '15' }

    Write-Log ('INICIO respaldo | servidor={0}:{1} | usuario={2} | base={3} | destino={4} | retencion={5}' -f `
            $Server, $Port, $User, $Database, $finalPath, $Retention)
    Write-Log 'Autenticacion: pgpass.conf (%APPDATA%\postgresql\pgpass.conf), sin contrasena en el script.'

    if (Test-Path -LiteralPath $finalPath) {
        throw "El archivo destino ya existe: $finalPath"
    }

    # ------------------------------------------------------------------
    # 2. Respaldo en .parcial
    # ------------------------------------------------------------------
    $dumpArgs = @(
        '-Fc'
        '--no-password'
        '--lock-wait-timeout=30s'
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

    if (-not (Test-Path -LiteralPath $script:ParcialPath)) {
        throw 'pg_dump salio con codigo 0 pero no genero el archivo .parcial.'
    }

    $sizeBytes = (Get-Item -LiteralPath $script:ParcialPath).Length
    if ($sizeBytes -le 0) {
        throw 'El .parcial generado tiene 0 bytes.'
    }
    $sizeMB = [math]::Round($sizeBytes / 1MB, 2)
    Write-Log "Dump escrito en .parcial: $script:ParcialPath ($sizeMB MB)"

    # ------------------------------------------------------------------
    # 3. Verificacion del artefacto ANTES del rename
    #    Si el .parcial no es legible, se descarta y nunca llega a .dump.
    # ------------------------------------------------------------------
    $objetos = 0
    if ($SkipVerify) {
        Write-Log 'pg_restore -l omitido (-SkipVerify).' 'WARN'
    }
    else {
        if (-not (Test-Path -LiteralPath $pgRestore)) {
            throw "No se encontro pg_restore.exe en '$PgBin'; no se puede verificar el dump."
        }
        $list = Invoke-NativeTool -FilePath $pgRestore -Arguments @('-l', $script:ParcialPath)
        if ($list.ExitCode -ne 0) {
            foreach ($line in $list.Output) {
                if ($line.Trim()) { Write-Log ("pg_restore> " + $line) 'ERROR' }
            }
            throw "pg_restore -l fallo con codigo $($list.ExitCode): el dump no es legible."
        }
        $objetos = @($list.Output | Where-Object { $_ -match '^\d+;' }).Count
        if ($objetos -lt 1) {
            throw 'pg_restore -l no listo ningun objeto: el dump esta vacio.'
        }

        # Un TOC con objetos no alcanza: tienen que estar las tablas del TP8.
        $esperadas = @('categoria', 'producto', 'usuario', 'pedido', 'detalle_pedido')
        $faltantes = @($esperadas | Where-Object { -not ($list.Output -match ("\bTABLE public {0}\b" -f $_)) })
        if ($faltantes.Count -gt 0) {
            throw ("El dump no contiene las tablas esperadas: {0}" -f ($faltantes -join ', '))
        }
        Write-Log ("pg_restore -l OK | objetos={0} | tablas={1}" -f $objetos, ($esperadas -join ','))
    }

    # ------------------------------------------------------------------
    # 4. Rename: recien ahora el .parcial se convierte en respaldo
    # ------------------------------------------------------------------
    Move-Item -LiteralPath $script:ParcialPath -Destination $finalPath
    $script:ParcialPath = $null

    Write-Log "Dump generado: $finalPath ($sizeMB MB)"

    if (-not (Test-Path -LiteralPath $finalPath)) {
        throw "El archivo final no existe despues del rename: $finalPath"
    }

    $hash = (Get-FileHash -LiteralPath $finalPath -Algorithm SHA256).Hash
    Write-Log "SHA256=$hash"

    # ------------------------------------------------------------------
    # 5. Retencion: conservar los ultimos N .dump DE ESTA BASE
    #    Un fallo de retencion no invalida el respaldo recien hecho.
    # ------------------------------------------------------------------
    try {
        # Anclado y escapado: 'foodstore' NO debe matchear
        # 'foodstore_restore_test_...'. El nombre es el timestamp, asi que
        # ordenar por nombre equivale a ordenar cronologicamente y no depende
        # del LastWriteTime (que puede venir alterado por una copia).
        $patron = '^' + [regex]::Escape($Database) + '_\d{8}_\d{4}\.dump$'
        $todos = @(Get-ChildItem -LiteralPath $BackupDir -File | Where-Object { $_.Name -match $patron })
        $ordenados = @($todos | Sort-Object -Property Name -Descending)
        $viejos = @($ordenados | Select-Object -Skip $Retention | Where-Object { $_.FullName -ne $finalPath })

        if ($viejos.Count -eq 0) {
            Write-Log "Retencion: no hay archivos para borrar (se conservan hasta $Retention)."
        }
        else {
            foreach ($viejo in $viejos) {
                try {
                    Remove-Item -LiteralPath $viejo.FullName -Force -ErrorAction Stop
                    Write-Log "Retencion: eliminado $($viejo.Name)"
                }
                catch {
                    Write-Log ("Retencion: no se pudo eliminar {0}: {1}" -f $viejo.Name, $_.Exception.Message) 'WARN'
                }
            }
            Write-Log "Retencion: se conservan los ultimos $Retention .dump de '$Database'."
        }

        $activos = @(Get-ChildItem -LiteralPath $BackupDir -File | Where-Object { $_.Name -match $patron })
        Write-Log "Dumps disponibles de '$Database': $($activos.Count)"
    }
    catch {
        Write-Log ("Retencion: no se pudo aplicar ({0}). El respaldo recien creado es valido." -f $_.Exception.Message) 'WARN'
    }

    Write-Log "RESULTADO=OK archivo=$fileName tamano_mb=$sizeMB sha256=$hash"
}
catch {
    Write-Log ("ERROR: " + $_.Exception.Message) 'ERROR'
    Remove-Parcial
    $script:ExitCode = 1
    # Se informa el estado REAL del .parcial despues de la limpieza: si ya se
    # borro, el log no debe seguir mostrando su ruta como si existiera.
    $parcial = 'ninguno'
    if ($script:ParcialPath) {
        $parcial = if (Test-Path -LiteralPath $script:ParcialPath) {
            "quedo=$($script:ParcialPath)"
        }
        else { 'eliminado' }
    }
    Write-Log "RESULTADO=ERROR parcial=$parcial" 'ERROR'
}
finally {
    Remove-Parcial
}

exit $script:ExitCode
