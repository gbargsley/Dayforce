<#
 Deploy-AdminDB.ps1
 Deploy F:\ola\DatabaseBackup.sql to AdminDB using dbatools.
 - Checks SQL major version >= 16 (SQL 2022) before deploy.
 - Renames existing dbo.DatabaseBackup -> DatabaseBackup_glb5 (if found).
 - Sends SQL content via -Query (reads file on client).
 - Produces per-server logs and a CSV summary.
#>

param(
    [string]$ServerListPath = ".\servers.txt",
    [string]$SqlFile = "F:\Temp\GB\Ola\Deploy\DatabaseBackup.sql",
    [string]$LogDir = ".\DeployLogs",
    [switch]$Parallel,
    [int]$Throttle = 8
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Preconditions
if (-not (Test-Path $ServerListPath)) { Throw "Server list not found at '$ServerListPath'." }
if (-not (Test-Path $SqlFile))      { Throw "SQL file not found at '$SqlFile'." }

if (-not (Get-Module -ListAvailable -Name dbatools)) {
    Throw "dbatools module not found. Install with: Install-Module dbatools -Scope CurrentUser"
}
Import-Module dbatools -ErrorAction Stop

# Read SQL file into memory
$sqlContent = Get-Content -Raw -Path $SqlFile -ErrorAction Stop

# Prepare logs and summary path
New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
$timestamp = (Get-Date).ToString('yyyy-MM-dd_HH-mm-ss')
$summaryCsv = Join-Path $LogDir ("DeploySummary_{0}.csv" -f $timestamp)

# Load servers
$servers = Get-Content $ServerListPath |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -and -not $_.StartsWith('#') }

# T-SQL templates (here-strings kept simple)
$renameSql = @'
IF EXISTS (SELECT 1 FROM sys.objects o WHERE o.object_id = OBJECT_ID(N'dbo.DatabaseBackup') AND o.type IN (N'P', N'PC'))
BEGIN
    EXEC sys.sp_rename N'dbo.DatabaseBackup', N'DatabaseBackup_glb5', N'OBJECT';
    SELECT 'RENAMED' AS Result;
END
ELSE
BEGIN
    SELECT 'NOT_FOUND' AS Result;
END
'@

$versionQuery = "SELECT SERVERPROPERTY('ProductMajorVersion') AS MajorVersion, SERVERPROPERTY('ProductVersion') AS ProductVersion;"

# --- helper wrapper to capture warnings and exceptions from Invoke-DbaQuery ---
function Invoke-DbaQuerySafe {
    param(
        [string]$Server,
        [string]$Database,
        [string]$Query,
        [int]$QueryTimeout = 600
    )

    $warningBuffer = @()
    try {
        # Capture warnings into $warningBuffer and stop on errors
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
        # Grab both the exception message and any warnings emitted
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

# --- robust Get-SqlMajorVersion that uses the safe wrapper ---
function Get-SqlMajorVersion {
    param([string]$Server)

    $versionQuery = "SELECT SERVERPROPERTY('ProductMajorVersion') AS MajorVersion, SERVERPROPERTY('ProductVersion') AS ProductVersion;"

    $safe = Invoke-DbaQuerySafe -Server $Server -Database 'master' -Query $versionQuery -QueryTimeout 60

    if (-not $safe.Success) {
        # Log warning array and error up the chain
        return @{
            Success = $false
            Error = $safe.Error
            Warnings = ($safe.Warnings -join '; ')
            Major = $null
            ProductVersion = $null
            Raw = $safe.Result
        }
    }

    $res = $safe.Result
    $raw = $res
    if ($res -and $res.Count -ge 1) { $row = $res[0] } else { $row = $res }

    # helper to attempt common property names
    $getProp = {
        param($o, $names)
        foreach ($n in $names) {
            if ($null -ne $o -and $o.PSObject.Properties.Match($n).Count -gt 0) {
                return $o.PSObject.Properties[$n].Value
            }
        }
        return $null
    }

    $majVal = & $getProp $row @('MajorVersion','ProductMajorVersion','PRODUCTMAJORVERSION','MAJORVERSION')
    $pvVal  = & $getProp $row @('ProductVersion','PRODUCTVERSION','Product_Version')

    if (($majVal -eq $null -or $majVal -eq '') -and ($pvVal -ne $null -and $pvVal -ne '')) {
        $pvStr = [string]$pvVal
        $prefix = ($pvStr -split '\.')[0]
        if ($prefix -match '^\d+$') { $majVal = [int]$prefix }
    }

    if ($majVal -ne $null) {
        try { $majVal = [int]$majVal } catch { $majVal = $null }
    }

    return @{
        Success = $true
        Major = $majVal
        ProductVersion = ($pvVal -ne $null) ? [string]$pvVal : $null
        Warnings = ($safe.Warnings -join '; ')
        Raw = $raw
    }
}

# --- updated Invoke-DeployOnServer uses the safe wrapper for every DB call ---
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
        RenameResult = $null
        DeployResult = $null
        Error = $null
        Warnings = $null
        Timestamp = (Get-Date).ToString('s')
    }

    Add-Content -Path $logFile -Value ("=== Deploy start: {0} on {1} ===" -f (Get-Date -Format o), $Server)

    # 1) version check
    $ver = Get-SqlMajorVersion -Server $Server
    if (-not $ver.Success) {
        $msg = "Version detection failed: " + $ver.Error
        if ($ver.Warnings) { $msg += " | Warnings: " + $ver.Warnings }
        Add-Content -Path $logFile -Value $msg
        # mark and skip server immediately
        $entry.Error = $ver.Error
        $entry.RenameResult = "Skipped - version unknown"
        $entry.DeployResult = "Skipped - version unknown"
        $entry.Warnings = $ver.Warnings
        return $entry    # <-- immediate skip, no rename/deploy attempted
    }

    $entry.SqlMajor = $ver.Major
    $entry.ProductVersion = $ver.ProductVersion
    if ($ver.Warnings) { Add-Content -Path $logFile -Value ("Version query warnings: " + $ver.Warnings); $entry.Warnings = $ver.Warnings }

    Add-Content -Path $logFile -Value ("Detected Major={0}, ProductVersion={1}" -f $ver.Major, $ver.ProductVersion)

    if ($null -eq $ver.Major -or $ver.Major -lt 16) {
        $skipNote = "SKIPPED - SQL version " + $ver.ProductVersion + " (major " + $ver.Major + ") is older than SQL Server 2022 (major 16)."
        Add-Content -Path $logFile -Value $skipNote
        $entry.RenameResult = "Skipped - SQL version " + $ver.ProductVersion
        $entry.DeployResult = "Skipped - SQL version " + $ver.ProductVersion
        return $entry
    }

    # 2) rename existing proc to _glb
    Add-Content -Path $logFile -Value "Attempting rename dbo.DatabaseBackup -> DatabaseBackup_glb..."
    $renameSafe = Invoke-DbaQuerySafe -Server $Server -Database 'AdminDB' -Query $renameSql -QueryTimeout 120

    if (-not $renameSafe.Success) {
        # connection or other failure
        $errMsg = $renameSafe.Error
        $warnMsg = ($renameSafe.Warnings -join '; ')
        Add-Content -Path $logFile -Value ("Rename step failed: " + $errMsg)
        if ($warnMsg) { Add-Content -Path $logFile -Value ("Rename warnings: " + $warnMsg) }
        # Detect common connectivity messages and mark accordingly
        if ($errMsg -match 'network path' -or $errMsg -match 'could not open a connection' -or $errMsg -match 'login failed' -or $errMsg -match 'The system cannot find the file') {
            $entry.RenameResult = "ConnectionFailed: " + $errMsg
            $entry.Error = $renameSafe.Exception
            $entry.Warnings = $warnMsg
        } else {
            $entry.RenameResult = "Failed: " + $errMsg
            $entry.Error = $renameSafe.Exception
            $entry.Warnings = $warnMsg
        }
        # continue to attempt deploy? per earlier decision: continue to attempt deploy if possible
    } else {
        # success: capture the result message if present
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

    # 3) deploy SQL content
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

    # finalize log
    Add-Content -Path $logFile -Value ("=== Deploy end: {0} ===`n" -f (Get-Date -Format o))

    return $entry
}

# Execute (parallel or sequential)
if ($Parallel -and $PSVersionTable.PSVersion.Major -lt 7) {
    Write-Warning "Parallel requested but PS 7+ required. Running sequentially."
    $Parallel = $false
}

$summary = @()
if ($Parallel) {
    $summary = $servers | ForEach-Object -Parallel {
        param($s, $SqlText, $LogDir, $ts)
        Import-Module dbatools -ErrorAction Stop
        Invoke-DeployOnServer -Server $s -SqlText $SqlText -LogDir $LogDir -Timestamp $ts
    } -ArgumentList $sqlContent, $LogDir, $timestamp -ThrottleLimit $Throttle
} else {
    # Sequential loop (in main script)
    foreach ($s in $servers) {
        Write-Host "`nStarting deployment on server: $s"   # <-- live immediate console message
        $res = Invoke-DeployOnServer -Server $s -SqlText $sqlContent -LogDir $LogDir -Timestamp $timestamp
        $summary += $res
    }
}

# Save summary
$summary | Export-Csv -Path $summaryCsv -NoTypeInformation -Force

Write-Host "=== Deployment summary ==="
$summary | Format-Table -AutoSize

Write-Host "Per-server logs:" $LogDir
Write-Host "Summary CSV:" $summaryCsv
