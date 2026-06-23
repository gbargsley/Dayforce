<#
.SYNOPSIS
 Rollback: remove newly deployed DatabaseBackup, restore original from DatabaseBackup_glb, and ensure _glb removed.

.DESCRIPTION
 Reads server names from a text file (one per line), and on each server:
  1) Drop dbo.DatabaseBackup if it exists
  2) Rename dbo.DatabaseBackup_glb -> dbo.DatabaseBackup
  3) Ensure dbo.DatabaseBackup_glb no longer exists (drop if it still exists)
  4) Verify final state and log results

.PARAMETER ServerListPath
 Path to a text file with one server/instance per line (default: .\servers.txt).

.PARAMETER LogDir
 Directory to store logs (default: .\RollbackLogs).

.PARAMETER Parallel
 If set, run servers in parallel using ForEach-Object -Parallel (PowerShell 7+).

.EXAMPLE
 .\Rollback-Restore-Original-Dbatools.ps1 -ServerListPath .\servers.txt -LogDir C:\Temp\RollbackLogs

.NOTES
 - Uses dbatools Invoke-DbaQuery. Integrated auth is assumed.
 - This script WILL remove any existing dbo.DatabaseBackup before restoring the _glb copy.
#>

param(
    [string]$ServerListPath = ".\servers.txt",
    [string]$LogDir = ".\RollbackLogs",
    [switch]$Parallel
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- sanity checks ---
if (-not (Test-Path $ServerListPath)) {
    Write-Error "Server list not found at '$ServerListPath'. Create a file with one server/instance per line."
    return
}

if (-not (Get-Module -ListAvailable -Name dbatools)) {
    Write-Host "dbatools module not found locally."
    # Uncomment to auto-install if desired and allowed in your environment:
    # Install-Module -Name dbatools -Scope CurrentUser -Force
    Write-Error "Please install the 'dbatools' module (Install-Module dbatools) and re-run."
    return
}
Import-Module dbatools -ErrorAction Stop

# Prepare logs and summary
New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
$timestamp = (Get-Date).ToString("yyyy-MM-dd_HH-mm-ss")
$summaryCsv = Join-Path $LogDir "RollbackSummary_$timestamp.csv"

# Read server list (ignore blank and lines starting with #)
$servers = Get-Content $ServerListPath | ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $_.StartsWith("#") }

# T-SQL sequence used per server:
# 1) Capture existence
# 2) Drop dbo.DatabaseBackup if present
# 3) Rename dbo.DatabaseBackup_glb -> dbo.DatabaseBackup (if _glb exists)
# 4) Drop dbo.DatabaseBackup_glb if it still exists (safety)
# 5) Return verification results (existence flags and any messages)
$rollbackSqlTemplate = @"
SET NOCOUNT ON;

DECLARE @hasBackup INT = 0, @hasGlb INT = 0;
SET @hasBackup = CASE WHEN OBJECT_ID(N'dbo.DatabaseBackup','P') IS NOT NULL THEN 1 ELSE 0 END;
SET @hasGlb   = CASE WHEN OBJECT_ID(N'dbo.DatabaseBackup_glb','P') IS NOT NULL THEN 1 ELSE 0 END;

/* Step 1: drop current DatabaseBackup if present */
IF @hasBackup = 1
BEGIN
    BEGIN TRY
        EXEC (N'DROP PROCEDURE dbo.DatabaseBackup');
        SELECT 'DROPPED_ORIGINAL' AS StepResult;
    END TRY
    BEGIN CATCH
        SELECT 'DROP_FAILED' AS StepResult, ERROR_MESSAGE() AS ErrorMsg;
        RETURN;
    END CATCH
END
ELSE
BEGIN
    SELECT 'NO_ORIGINAL' AS StepResult;
END

/* Refresh hasGlb after potential changes */
SET @hasGlb   = CASE WHEN OBJECT_ID(N'dbo.DatabaseBackup_glb','P') IS NOT NULL THEN 1 ELSE 0 END;

/* Step 2: rename _glb -> DatabaseBackup */
IF @hasGlb = 1
BEGIN
    BEGIN TRY
        EXEC sys.sp_rename N'dbo.DatabaseBackup_glb', N'DatabaseBackup', N'OBJECT';
        SELECT 'RENAMED_glb_to_original' AS StepResult;
    END TRY
    BEGIN CATCH
        SELECT 'RENAME_FAILED' AS StepResult, ERROR_MESSAGE() AS ErrorMsg;
        RETURN;
    END CATCH
END
ELSE
BEGIN
    SELECT 'NO_GLB_FOUND' AS StepResult;
END

/* Step 3: Cleanup - if any leftover _glb exists, drop it */
IF OBJECT_ID(N'dbo.DatabaseBackup_glb','P') IS NOT NULL
BEGIN
    BEGIN TRY
        EXEC (N'DROP PROCEDURE dbo.DatabaseBackup_glb');
        SELECT 'DROPPED_leftover_glb' AS StepResult;
    END TRY
    BEGIN CATCH
        SELECT 'DROP_GLB_FAILED' AS StepResult, ERROR_MESSAGE() AS ErrorMsg;
        RETURN;
    END CATCH
END

/* Final verification */
SELECT 
    CASE WHEN OBJECT_ID(N'dbo.DatabaseBackup','P') IS NOT NULL THEN 1 ELSE 0 END AS Final_HasBackup,
    CASE WHEN OBJECT_ID(N'dbo.DatabaseBackup_glb','P') IS NOT NULL THEN 1 ELSE 0 END AS Final_HasGlb;
"@

# Function to run rollback on one server
function Invoke-RestoreOriginal {
    param(
        [string]$Server,
        [string]$LogDir,
        [string]$Timestamp
    )

    $safeServer = ($Server -replace '[\\\/:]', '_')
    $logFile = Join-Path $LogDir ("Rollback_{0}_{1}.log" -f $safeServer, $Timestamp)
    $entry = [PSCustomObject]@{
        Server       = $Server
        Action       = $null
        Details      = $null
        Final_HasBackup = $null
        Final_HasGlb = $null
        Error        = $null
        Timestamp    = (Get-Date).ToString("s")
    }

    Add-Content -Path $logFile -Value "=== Rollback start: $(Get-Date -Format o) on $Server ==="
    Add-Content -Path $logFile -Value "Running rollback SQL sequence..."

    try {
        # Run the rollback SQL; Invoke-DbaQuery will return result sets (we will inspect)
        $outputs = Invoke-DbaQuery -SqlInstance $Server -Database 'AdminDB' -Query $rollbackSqlTemplate -Verbose -ErrorAction Stop

        # outputs may be a collection of PSObjects (multiple resultsets). We'll inspect them in order to build a readable summary.
        $msgList = @()
        if ($outputs) {
            foreach ($o in $outputs) {
                # If object has StepResult, log it
                if ($o.PSObject.Properties.Match('StepResult').Count -gt 0) {
                    $sr = $o.StepResult
                    if ($o.PSObject.Properties.Match('ErrorMsg').Count -gt 0) {
                        $em = $o.ErrorMsg
                        $msgList += "$sr - $em"
                    } else {
                        $msgList += "$sr"
                    }
                } elseif ($o.PSObject.Properties.Match('Final_HasBackup').Count -gt 0) {
                    # Final verification row
                    $entry.Final_HasBackup = $o.Final_HasBackup
                    $entry.Final_HasGlb = $o.Final_HasGlb
                } else {
                    # Generic row, stringify
                    $msgList += ($o | Out-String).Trim()
                }
            }
        } else {
            $msgList += "No output returned from Invoke-DbaQuery."
        }

        Add-Content -Path $logFile -Value ("SQL steps output:`n" + ($msgList -join "`n"))
        # Determine outcome: if Final_HasBackup == 1 and Final_HasGlb == 0 -> success
        if ($entry.Final_HasBackup -eq 1 -and $entry.Final_HasGlb -eq 0) {
            $entry.Action = "Restored"
            $entry.Details = ($msgList -join "; ")
            Add-Content -Path $logFile -Value "Verification success: DatabaseBackup present; DatabaseBackup_glb absent."
        } else {
            $entry.Action = "Partial/Failed"
            $entry.Details = ($msgList -join "; ")
            Add-Content -Path $logFile -Value "Verification result: Final_HasBackup=$($entry.Final_HasBackup), Final_HasGlb=$($entry.Final_HasGlb)"
        }

    } catch {
        $err = $_.Exception.Message
        Add-Content -Path $logFile -Value "ERROR during rollback: $err"
        $entry.Action = "Error"
        $entry.Error = $err
    } finally {
        Add-Content -Path $logFile -Value "=== Rollback end: $(Get-Date -Format o) ===`n"
    }

    return $entry
}

# Run sequentially or parallel (PS7+)
if ($Parallel) {
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Write-Warning "Parallel requested but PowerShell 7+ required. Running sequentially instead."
        $Parallel = $false
    }
}

$summary = @()
if ($Parallel) {
    $throttle = 8
    $summary = $servers | ForEach-Object -Parallel {
        param($s, $LogDir, $ts)
        Import-Module dbatools -ErrorAction Stop
        Invoke-RestoreOriginal -Server $s -LogDir $LogDir -Timestamp $ts
    } -ArgumentList $LogDir, $timestamp -ThrottleLimit $throttle
} else {
    foreach ($s in $servers) {
        $res = Invoke-RestoreOriginal -Server $s -LogDir $LogDir -Timestamp $timestamp
        $summary += $res
    }
}

# Write summary
$summary | Export-Csv -Path $summaryCsv -NoTypeInformation -Force

Write-Host "`n=== Rollback summary ==="
$summary | Format-Table -AutoSize

Write-Host "`nPer-server logs are in: $LogDir"
Write-Host "Summary CSV: $summaryCsv"