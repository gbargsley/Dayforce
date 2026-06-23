<#
.SYNOPSIS
 Deploy F:\ola\DatabaseBackup.sql to AdminDB on a list of servers using dbatools, and rename dbo.DatabaseBackup -> DatabaseBackup_glb001,
 only on SQL Server 2022 (major version 16) or newer.

.DESCRIPTION
 - Reads servers from a text file (one per line).
 - Reads SQL file into memory and sends via -Query.
 - Verifies SQL Server major version >= 16 (SQL Server 2022) before rename/deploy; otherwise skips.
 - Renames existing dbo.DatabaseBackup -> DatabaseBackup_glb001 (if present), then deploys SQL.
 - Writes per-server log files and a CSV summary with diagnostic fields (VersionInfo, Warnings, Error).
 - Uses dbatools (Invoke-DbaQuery). Integrated authentication assumed.

.PARAMETER ServerListPath
 Path to server list (one per line). Default: .\servers.txt

.PARAMETER SqlFile
 Path to SQL file to execute (client-readable). Default: F:\ola\DatabaseBackup.sql

.PARAMETER LogDir
 Directory for per-server logs and CSV summary. Default: .\DeployLogs

.PARAMETER Parallel
 If set and running in PowerShell 7+, will use ForEach-Object -Parallel to run servers concurrently.

.PARAMETER Throttle
 Throttle limit for parallel runs. Default: 8.

.NOTES
 - Recommended to run with pwsh (PowerShell 7+) for best results.
 - For live console updates when using -Parallel, run the included watcher in a separate terminal (see repo notes).
#>

param(
    [string]$ServerListPath = ".\Servers_PreProd_Remaining.txt",
    [string]$SqlFile = "F:\Temp\GB\Ola\Deploy\DatabaseBackup.sql",
    [string]$LogDir = ".\DeployLogs",
    [switch]$Parallel,
    [int]$Throttle = 8
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# -----------------------
# Preconditions & setup
# -----------------------
if (-not (Test-Path $ServerListPath)) { Throw "Server list not found at '$ServerListPath'." }
if (-not (Test-Path $SqlFile))      { Throw "SQL file not found at '$SqlFile'." }

if (-not (Get-Module -ListAvailable -Name dbatools)) {
    Throw "dbatools module not found. Install it with: Install-Module dbatools -Scope CurrentUser"
}
Import-Module dbatools -ErrorAction Stop

# Read SQL file into memory (fail-fast)
$sqlContent = Get-Content -Raw -Path $SqlFile -ErrorAction Stop

# Prepare logs and summary
New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
$timestamp = (Get-Date).ToString('yyyy-MM-dd_HH-mm-ss')
$summaryCsv = Join-Path $LogDir ("DeploySummary_{0}.csv" -f $timestamp)

# Read servers (ignore blank and comments)
$servers = Get-Content $ServerListPath | ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $_.StartsWith('#') }

# -----------------------
# T-SQL templates
# -----------------------
$renameSql = @'
IF EXISTS (SELECT 1 FROM sys.objects o WHERE o.object_id = OBJECT_ID(N'dbo.DatabaseBackup') AND o.type IN (N'P', N'PC'))
BEGIN
    EXEC sys.sp_rename N'dbo.DatabaseBackup', N'DatabaseBackup_glb001', N'OBJECT';
    SELECT 'RENAMED' AS Result;
END
ELSE
BEGIN
    SELECT 'NOT_FOUND' AS Result;
END
'@

# -----------------------
# Helper: safe wrapper for Invoke-DbaQuery
# Captures warnings and full exception details
# -----------------------
function Invoke-DbaQuerySafe {
    param(
        [string]$Server,
        [string]$Database,
        [string]$Query,
        [int]$QueryTimeout = 600
    )

    $warningBuffer = @()
    try {
        $result = Invoke-DbaQuery -SqlInstance $Server -Database $Database -Query $Query -QueryTimeout $QueryTimeout `
                    -ErrorAction Stop -WarningAction SilentlyContinue -WarningVariable warningBuffer
        return @{
            Success = $true
            Result  = $result
            Warnings = $warningBuffer
            Error = $null
            Exception = $null
        }
    } catch {
        $ex = $_.Exception
        $full = $ex | Format-List * -Force | Out-String
        return @{
            Success = $false
            Result  = $null
            Warnings = $warningBuffer
            Error = $ex.Message
            Exception = $full
        }
    }
}

# -----------------------
# Helper: robust SQL version detection
# Returns: @{ Success, Major, ProductVersion, Warnings, Raw, VersionString, Error }
# -----------------------
function Get-SqlVersionInfo {
    param(
        [Parameter(Mandatory)]
        [string]$SqlInstance,

        [pscredential]$SqlCredential
    )

    try {
        $server = Connect-DbaInstance -SqlInstance $SqlInstance

        $SqlMajor = $server.VersionMajor
        $ProductVersion = $server.Version.ToString()

        if (-not $SqlMajor -or -not $ProductVersion) {
            $row = Invoke-DbaQuery -SqlInstance $SqlInstance -Query "
            SELECT CAST(SERVERPROPERTY('ProductVersion') AS varchar(30)) AS ProductVersion;
            " | Select-Object -First 1

            $ProductVersion = $row.ProductVersion
            if ($ProductVersion) {
                $SqlMajor = ([version]$ProductVersion).Major
            }
        }

        Write-Host "Detected Major=$SqlMajor, ProductVersion=$ProductVersion"

    if (-not $SqlMajor -or -not $ProductVersion) {
        throw "Unable to determine SQL version."
    }
}
catch {
    Write-Warning "Version detection failed for $($SqlInstance): $($_.Exception.Message)"
    $SqlMajor = $null
    $ProductVersion = $null
}
}

function Get-SqlMajorVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Server
    )

    try {
        $conn = Connect-DbaInstance -SqlInstance $Server

        $major = $conn.VersionMajor
        $versionString = $null

        if ($conn.Version) {
            $versionString = $conn.Version.ToString()
        }

        if (-not $major -or -not $versionString) {
            $row = Invoke-DbaQuery -SqlInstance $Server -Query @"
SELECT CAST(SERVERPROPERTY('ProductVersion') AS varchar(30)) AS ProductVersion;
"@ | Select-Object -First 1

            $versionString = $row.ProductVersion
            if ($versionString) {
                $major = ([version]$versionString).Major
            }
        }

        if (-not $major) {
            return [pscustomobject]@{
                Success       = $false
                Major         = $null
                VersionString = $versionString
                ProductVersion = $versionString
                Warnings      = "Unable to determine SQL major version."
                Error         = "Unable to determine SQL major version."
            }
        }

        [pscustomobject]@{
            Success        = $true
            Major          = [int]$major
            VersionString  = $versionString
            ProductVersion = $versionString
            Warnings       = $null
            Error          = $null
        }
    }
    catch {
        [pscustomobject]@{
            Success        = $false
            Major          = $null
            VersionString  = $null
            ProductVersion = $null
            Warnings       = $_.Exception.Message
            Error          = $_.Exception.Message
        }
    }
}

# -----------------------
# Main per-server worker
# -----------------------
function Invoke-DeployOnServer {
    param(
        [string]$Server,
        [string]$SqlText,
        [string]$LogDir,
        [string]$Timestamp
    )

    $safeName = ($Server -replace '[\\/:]', '_')
    $logFile = Join-Path $LogDir ("Deploy_{0}_{1}.log" -f $safeName, $Timestamp)

    $entry = [PSCustomObject]@{
        Server = $Server
        SqlMajor = $null
        ProductVersion = $null
        VersionInfo = $null
        RenameResult = $null
        DeployResult = $null
        Warnings = $null
        Error = $null
        Timestamp = (Get-Date).ToString('s')
    }

    Add-Content -Path $logFile -Value ("=== Deploy start: {0} on {1} ===" -f (Get-Date -Format o), $Server)

    # 1) Version check — skip immediately if detection fails
    $ver = Get-SqlMajorVersion -Server $Server

    if (-not $ver.Success) {
        Write-Warning "Version detection failed for $($Server): $($ver.Error)"

        $entry.SqlMajor      = $null
        $entry.ProductVersion = $null
        $entry.VersionInfo   = $ver.Error
        $entry.DeployResult  = "Skipped - Connection/Version failure"
        $entry.Warnings      = $ver.Warnings
        $entry.Error         = $ver.Error

        # Add to results and continue to next server
        $results += $entry
        continue
    }

    $SqlMajor = $ver.Major

    # Fill diagnostic fields
    $entry.SqlMajor = $ver.Major
    $entry.ProductVersion = $ver.ProductVersion
    $entry.Warnings = $ver.Warnings
    $entry.VersionInfo = if ($ver.VersionString) { $ver.VersionString } elseif ($ver.Raw) { ($ver.Raw | Out-String).Trim() } else { $null }

    Add-Content -Path $logFile -Value ("Detected Major={0}, ProductVersion={1}" -f ($ver.Major -as [string]), ($ver.ProductVersion -as [string]))
    if ($entry.VersionInfo) { Add-Content -Path $logFile -Value ("VersionInfo: " + $entry.VersionInfo) }
    if ($entry.Warnings) { Add-Content -Path $logFile -Value ("Version query warnings: " + $entry.Warnings) }

    if ($null -eq $ver.Major -or $ver.Major -lt 16) {
        $skipNote = "SKIPPED - SQL version " + ($ver.ProductVersion -or $ver.VersionString -or 'unknown') + " (major " + ($ver.Major -as [string]) + ") is older/unknown; skipping deployment."
        Add-Content -Path $logFile -Value $skipNote
        $entry.RenameResult = "Skipped - SQL version"
        $entry.DeployResult = "Skipped - SQL version"
        return $entry
    }

    Add-Content -Path $logFile -Value "SQL version is 2022+ — proceeding."

    # 2) Rename existing proc to _glb001
    Add-Content -Path $logFile -Value "Attempting rename dbo.DatabaseBackup -> DatabaseBackup_glb001..."
    $renameSafe = Invoke-DbaQuerySafe -Server $Server -Database 'AdminDB' -Query $renameSql -QueryTimeout 120

    if (-not $renameSafe.Success) {
        $errMsg = $renameSafe.Error
        $warnMsg = ($renameSafe.Warnings -join '; ')
        Add-Content -Path $logFile -Value ("Rename step failed: " + $errMsg)
        if ($warnMsg) { Add-Content -Path $logFile -Value ("Rename warnings: " + $warnMsg) }

        if ($errMsg -match 'network path' -or $errMsg -match 'could not open a connection' -or $errMsg -match 'login failed' -or $errMsg -match 'The system cannot find the file') {
            $entry.RenameResult = "ConnectionFailed: " + $errMsg
        } else {
            $entry.RenameResult = "Failed: " + $errMsg
        }
        $entry.Error = $renameSafe.Exception
        $entry.Warnings = ($entry.Warnings) ? ($entry.Warnings + '; ' + $warnMsg) : $warnMsg
        # NOTE: currently we continue to attempt the deploy even if rename had issues. Change behavior if desired.
    } else {
        if ($renameSafe.Result -and $renameSafe.Result.Result) {
            $entry.RenameResult = ($renameSafe.Result.Result -join ';')
        } else {
            $entry.RenameResult = "Executed"
        }
        if ($renameSafe.Warnings) {
            Add-Content -Path $logFile -Value ("Rename warnings: " + ($renameSafe.Warnings -join '; '))
            $entry.Warnings = ($entry.Warnings) ? ($entry.Warnings + '; ' + ($renameSafe.Warnings -join '; ')) : ($renameSafe.Warnings -join '; ')
        }
    }

    # 3) Deploy SQL content
    Add-Content -Path $logFile -Value ("Executing SQL content on AdminDB (length " + $SqlText.Length + " chars)...")
    $deploySafe = Invoke-DbaQuerySafe -Server $Server -Database 'AdminDB' -Query $SqlText -QueryTimeout 600

    if (-not $deploySafe.Success) {
        $errMsg = $deploySafe.Error
        $warnMsg = ($deploySafe.Warnings -join '; ')
        Add-Content -Path $logFile -Value ("SQL execution failed: " + $errMsg)
        if ($warnMsg) { Add-Content -Path $logFile -Value ("SQL execution warnings: " + $warnMsg) }

        if ($errMsg -match 'network path' -or $errMsg -match 'could not open a connection' -or $errMsg -match 'login failed' -or $errMsg -match 'The system cannot find the file') {
            $entry.DeployResult = "ConnectionFailed: " + $errMsg
        } else {
            $entry.DeployResult = "Failed: " + $errMsg
        }
        $entry.Error = $deploySafe.Exception
        $entry.Warnings = ($entry.Warnings) ? ($entry.Warnings + '; ' + $warnMsg) : $warnMsg
    } else {
        Add-Content -Path $logFile -Value "SQL executed successfully."
        $entry.DeployResult = "Success"
        if ($deploySafe.Warnings) {
            Add-Content -Path $logFile -Value ("SQL execution warnings: " + ($deploySafe.Warnings -join '; '))
            $entry.Warnings = ($entry.Warnings) ? ($entry.Warnings + '; ' + ($deploySafe.Warnings -join '; ')) : ($deploySafe.Warnings -join '; ')
        }
    }

    Add-Content -Path $logFile -Value ("=== Deploy end: {0} ===`n" -f (Get-Date -Format o))

    return $entry
}

# -----------------------
# Execute over server list
# -----------------------
if ($Parallel -and $PSVersionTable.PSVersion.Major -lt 7) {
    Write-Warning "Parallel requested but PowerShell 7+ is required for -Parallel. Running sequentially."
    $Parallel = $false
}

$summary = @()

if ($Parallel) {
    # Informational note: worker output is buffered in PS7; consider running the watcher if you want live logs.
    Write-Host "Running in parallel mode (PowerShell 7). Note: worker console output may be buffered."
    $summary = $servers | ForEach-Object -Parallel {
        param($s, $SqlText, $LogDir, $ts, $renameSqlRef)
        Import-Module dbatools -ErrorAction Stop
        # Bring the rename SQL text into the runspace (we pass via $using: isn't available inside -Parallel param)
        Invoke-DeployOnServer -Server $s -SqlText $SqlText -LogDir $LogDir -Timestamp $ts
    } -ArgumentList $sqlContent, $LogDir, $timestamp -ThrottleLimit $Throttle
} else {
    foreach ($s in $servers) {
        Write-Host "`nStarting deployment on server: $s"
        $res = Invoke-DeployOnServer -Server $s -SqlText $sqlContent -LogDir $LogDir -Timestamp $timestamp
        $summary += $res
    }
}

# -----------------------
# Export summary CSV with diagnostic columns
# -----------------------
$summary | Select-Object Server, SqlMajor, ProductVersion, VersionInfo, RenameResult, DeployResult, Warnings, Error, Timestamp |
    Export-Csv -Path $summaryCsv -NoTypeInformation -Force

Write-Host "`n=== Deployment summary ==="
$summary | Format-Table -AutoSize

Write-Host "Per-server logs:" $LogDir
Write-Host "Summary CSV:" $summaryCsv