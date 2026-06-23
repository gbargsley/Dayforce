<#
 Deploy-AdminDB.ps1
 Deploy F:\ola\DatabaseBackup.sql to AdminDB using dbatools.
 - Checks SQL major version >= 16 (SQL 2022) before deploy.
 - Renames existing dbo.DatabaseBackup -> DatabaseBackup_glb4 (if found).
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
    EXEC sys.sp_rename N'dbo.DatabaseBackup', N'DatabaseBackup_glb4', N'OBJECT';
    SELECT 'RENAMED' AS Result;
END
ELSE
BEGIN
    SELECT 'NOT_FOUND' AS Result;
END
'@

$versionQuery = "SELECT SERVERPROPERTY('ProductMajorVersion') AS MajorVersion, SERVERPROPERTY('ProductVersion') AS ProductVersion;"

function Get-SqlMajorVersion {
    param([string]$Server)
    try {
        $res = Invoke-DbaQuery -SqlInstance $Server -Database 'master' -Query $versionQuery -ErrorAction Stop
        if ($res -and $res[0]) { $row = $res[0] } else { $row = $res }
        $maj = $null
        if ($row -and $row.MajorVersion -ne $null -and $row.MajorVersion -ne '') {
            [int]$maj = $row.MajorVersion
        } else {
            if ($row -and $row.ProductVersion) {
                $pv = $row.ProductVersion -as [string]
                $prefix = ($pv -split '\.')[0]
                if ($prefix -match '^\d+$') { [int]$maj = [int]$prefix }
            }
        }
        return @{ Success = $true; Major = $maj; ProductVersion = $row.ProductVersion }
    } catch {
        return @{ Success = $false; Error = $_.Exception.Message; Major = $null; ProductVersion = $null }
    }
}

function Invoke-DeployOnServer {
    param(
        [string]$Server,
        [string]$SqlText,
        [string]$LogDir,
        [string]$Timestamp
    )

    $safe = ($Server -replace '[\\/:]', '_')
    $logFile = Join-Path $LogDir ("Deploy_{0}_{1}.log" -f $safe, $Timestamp)

    $entry = [PSCustomObject]@{
        Server = $Server
        SqlMajor = $null
        ProductVersion = $null
        RenameResult = $null
        DeployResult = $null
        Error = $null
        Timestamp = (Get-Date).ToString('s')
    }

    Add-Content -Path $logFile -Value ("=== Deploy start: {0} on {1} ===" -f (Get-Date -Format o), $Server)

    try {
        Add-Content -Path $logFile -Value "Checking SQL version..."
        $v = Get-SqlMajorVersion -Server $Server

        if (-not $v.Success) {
            $msg = "Version query failed: " + $v.Error
            Add-Content -Path $logFile -Value $msg
            $entry.Error = $v.Error
            $entry.RenameResult = "Skipped - version unknown"
            $entry.DeployResult = "Skipped - version unknown"
            return $entry
        }

        $entry.SqlMajor = $v.Major
        $entry.ProductVersion = $v.ProductVersion
        Add-Content -Path $logFile -Value ("Detected Major={0}, ProductVersion={1}" -f $v.Major, $v.ProductVersion)

        if ($null -eq $v.Major -or $v.Major -lt 16) {
            $skipNote = "SKIPPED - SQL version " + $v.ProductVersion + " (major " + $v.Major + ") is older than SQL Server 2022 (major 16)."
            Add-Content -Path $logFile -Value $skipNote
            $entry.RenameResult = "Skipped - SQL version " + $v.ProductVersion
            $entry.DeployResult = "Skipped - SQL version " + $v.ProductVersion
            return $entry
        }

        Add-Content -Path $logFile -Value "SQL version is 2022+ — proceeding."

        # Rename existing proc to _glb4
        try {
            Add-Content -Path $logFile -Value "Attempting rename dbo.DatabaseBackup -> DatabaseBackup_glb4..."
            $renameOut = Invoke-DbaQuery -SqlInstance $Server -Database 'AdminDB' -Query $renameSql -ErrorAction Stop
            if ($renameOut -and $renameOut.Result) {
                $entry.RenameResult = ($renameOut.Result -join ';')
            } else {
                $entry.RenameResult = "Executed"
            }
            Add-Content -Path $logFile -Value ("Rename result: " + $entry.RenameResult)
        } catch {
            $err = $_.Exception
            $errFull = $err | Format-List * -Force | Out-String
            Add-Content -Path $logFile -Value ("Rename failed: " + $err.Message)
            Add-Content -Path $logFile -Value ("Full exception:`n" + $errFull)
            $entry.RenameResult = ("Failed: " + $err.Message)
            # continue to attempt deploy
        }

        # Deploy SQL content
        try {
            Add-Content -Path $logFile -Value ("Executing SQL content on AdminDB (length " + $SqlText.Length + " chars)...")
            Invoke-DbaQuery -SqlInstance $Server -Database 'AdminDB' -Query $SqlText -QueryTimeout 600 -ErrorAction Stop | Out-Null
            Add-Content -Path $logFile -Value "SQL executed successfully."
            $entry.DeployResult = "Success"
        } catch {
            $err2 = $_.Exception
            $err2Full = $err2 | Format-List * -Force | Out-String
            Add-Content -Path $logFile -Value ("SQL execution failed: " + $err2.Message)
            Add-Content -Path $logFile -Value ("Full exception:`n" + $err2Full)
            $entry.DeployResult = ("Failed: " + $err2.Message)
            $entry.Error = $err2Full
        }

    } catch {
        $outer = $_.Exception
        $outerFull = $outer | Format-List * -Force | Out-String
        Add-Content -Path $logFile -Value ("Unhandled error: " + $outer.Message)
        Add-Content -Path $logFile -Value ("Full exception:`n" + $outerFull)
        $entry.Error = $outerFull
        if (-not $entry.RenameResult) { $entry.RenameResult = "Error" }
        if (-not $entry.DeployResult) { $entry.DeployResult = "Error" }
    } finally {
        Add-Content -Path $logFile -Value ("=== Deploy end: {0} ===`n" -f (Get-Date -Format o))
    }

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
    foreach ($s in $servers) {
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