<#
.SYNOPSIS
 Deploy F:\ola\DatabaseBackup.sql to AdminDB on a list of servers using dbatools, and rename dbo.DatabaseBackup -> DatabaseBackup_glb3.

.PARAMETER ServerListPath
 Path to a text file with one server/instance per line (default: .\servers.txt).

.PARAMETER SqlFile
 Path to the SQL file to execute (default: F:\ola\DatabaseBackup.sql).

.PARAMETER LogDir
 Directory to store logs (default: .\DeployLogs).

.PARAMETER Parallel
 If set, run servers in parallel using ForEach-Object -Parallel (PowerShell 7+).

.NOTES
 - Uses dbatools Invoke-DbaQuery for execution (handles GO batches and -File).
 - Uses Integrated Authentication. If you need SQL auth, tell me and I will add secure credential support.
#>

param(
    [string]$ServerListPath = ".\servers.txt",
    [string]$SqlFile = "F:\Temp\GB\Ola\Deploy\DatabaseBackup.sql",
    [string]$LogDir = ".\DeployLogs",
    [switch]$Parallel
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Sanity checks ---
if (-not (Test-Path $ServerListPath)) {
    Write-Error "Server list not found at '$ServerListPath'. Create a file with one server/instance per line."
    return
}
if (-not (Test-Path $SqlFile)) {
    Write-Error "SQL file not found at '$SqlFile'."
    return
}

# Ensure dbatools is available
if (-not (Get-Module -ListAvailable -Name dbatools)) {
    Write-Host "dbatools module not found locally."
    # Uncomment to auto-install if desired and allowed in your environment:
    # Write-Host "Installing dbatools from PSGallery (requires internet and policy approval)..."
    # Install-Module -Name dbatools -Scope CurrentUser -Force
    Write-Error "Please install the 'dbatools' module (Install-Module dbatools) and re-run."
    return
}

Import-Module dbatools -ErrorAction Stop

# Prepare logs and summary
New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
$timestamp = (Get-Date).ToString("yyyy-MM-dd_HH-mm-ss")
$summaryCsv = Join-Path $LogDir "DeploySummary_$timestamp.csv"

# Read server list (ignore blank and lines starting with #)
$servers = Get-Content $ServerListPath | ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $_.StartsWith("#") }

# T-SQL to rename stored procedure if it exists (fully qualified)
$renameSql = @"
IF EXISTS (
    SELECT 1 FROM sys.objects o
    WHERE o.object_id = OBJECT_ID(N'dbo.DatabaseBackup') AND o.type IN (N'P', N'PC')
)
BEGIN
    EXEC sys.sp_rename N'dbo.DatabaseBackup', N'DatabaseBackup_glb3', N'OBJECT';
    SELECT 'RENAMED' AS Result;
END
ELSE
BEGIN
    SELECT 'NOT_FOUND' AS Result;
END
"@

# Function to process one server
function Invoke-DeployOnServer {
    param(
        [string]$Server,
        [string]$SqlFile,
        [string]$LogDir,
        [string]$Timestamp
    )
    $logFile = Join-Path $LogDir ("Deploy_{0}_{1}.log" -f ($Server -replace '[\\\/:]', '_'), $Timestamp)
    $entry = [PSCustomObject]@{
        Server       = $Server
        RenameResult = $null
        DeployResult = $null
        Error        = $null
        Timestamp    = (Get-Date).ToString("s")
    }

    Add-Content -Path $logFile -Value "=== Deploy start: $(Get-Date -Format o) on $Server ==="

    try {
        Write-Host "Processing $Server ..."
        Add-Content -Path $logFile -Value "Attempting to rename dbo.DatabaseBackup -> DatabaseBackup_glb3 in AdminDB..."

        # 1) Rename stored proc (use Invoke-DbaQuery to run the T-SQL)
        try {
            $renameOut = Invoke-DbaQuery -SqlInstance $Server -Database 'AdminDB' -Query $renameSql -Verbose -ErrorAction Stop
            # If it returns a resultset with 'RENAMED' or 'NOT_FOUND' pick it up; otherwise treat as success
            if ($renameOut -and $renameOut.Result) {
                $entry.RenameResult = $renameOut.Result -join ';'
            } else {
                $entry.RenameResult = "Executed"
            }
            Add-Content -Path $logFile -Value "Rename step output: $($entry.RenameResult)"
        } catch {
            $errMsg = $_.Exception.Message
            Add-Content -Path $logFile -Value "Rename failed: $errMsg"
            $entry.RenameResult = "Failed: $errMsg"
            # continue to attempt deploy — up to you; I will continue
        }

        # 2) Execute SQL file via -File (dbatools handles GO separators)
        Add-Content -Path $logFile -Value "Executing SQL file $SqlFile on AdminDB..."
        try {
            # Invoke-DbaQuery supports -File parameter and will run the file content; -QueryTimeout optional
            Invoke-DbaQuery -SqlInstance $Server -Database 'AdminDB' -File $SqlFile -Verbose -QueryTimeout 600 -ErrorAction Stop | Out-Null
            Add-Content -Path $logFile -Value "SQL file executed successfully."
            $entry.DeployResult = "Success"
        } catch {
            $errMsg2 = $_.Exception.Message
            Add-Content -Path $logFile -Value "SQL execution failed: $errMsg2"
            $entry.DeployResult = "Failed: $errMsg2"
            $entry.Error = $errMsg2
        }

    } catch {
        $outer = $_.Exception.Message
        Add-Content -Path $logFile -Value "Unhandled error: $outer"
        $entry.Error = $outer
        if (-not $entry.RenameResult) { $entry.RenameResult = "Error" }
        if (-not $entry.DeployResult) { $entry.DeployResult = "Error" }
    } finally {
        Add-Content -Path $logFile -Value "=== Deploy end: $(Get-Date -Format o) ===`n"
    }

    return $entry
}

# Run sequentially or in parallel (PowerShell 7+ for -Parallel)
if ($Parallel) {
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Write-Warning "Parallel was requested but PowerShell 7+ is required for ForEach-Object -Parallel. Running sequentially instead."
        $Parallel = $false
    }
}

$summary = @()
if ($Parallel) {
    $throttle = 8  # adjust as needed
    $summary = $servers | ForEach-Object -Parallel {
        param($s, $SqlFile, $LogDir, $timestamp)
        # Import dbatools inside parallel run
        Import-Module dbatools -ErrorAction Stop
        Invoke-DeployOnServer -Server $s -SqlFile $SqlFile -LogDir $LogDir -Timestamp $timestamp
    } -ArgumentList $SqlFile, $LogDir, $timestamp -ThrottleLimit $throttle
} else {
    foreach ($s in $servers) {
        $res = Invoke-DeployOnServer -Server $s -SqlFile $SqlFile -LogDir $LogDir -Timestamp $timestamp
        $summary += $res
    }
}

# Write summary CSV and show summary table
$summary | Export-Csv -Path $summaryCsv -NoTypeInformation -Force
Write-Host "`n=== Deployment summary ==="
$summary | Format-Table -AutoSize

Write-Host "`nPer-server logs are in: $LogDir"
Write-Host "Summary CSV: $summaryCsv"