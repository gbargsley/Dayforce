<#
Remove-OldFiles.ps1
Deletes *.out files older than CutoffHours.
Exits 0 on success, non-zero on failure.
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Path,
    [int]$CutoffHours = 24,
    [switch]$Recurse,
    [string]$LogPath = "D:\MSDiagnosticDataCapture\DeletedOutFiles.log",
    [switch]$DryRun,  # present = DRY RUN
        # NEW: accept PerformDelete passed to the script (so scheduler can pass it)
    [switch]$PerformDelete,

    # NEW: threshold for low-space check (percent free). Adjust default as you like.
    [int]$SpaceThreshold = 25
)

# Ensure we see detailed errors
$ErrorActionPreference = 'Stop'

function Remove-LargestOutIfLowSpace {
    [CmdletBinding()]
    param(
        [int]$ThresholdPercent = 50,
        [string]$Drive = 'D:',
        [string]$TargetFolder = 'D:\MSDiagnosticDataCapture',
        [switch]$PerformDelete,
        [string]$LogFile = 'D:\MSDiagnosticDataCapture\RemoveOutCleanup.log',


        # Database Mail params
        [string]$MailTo = 'garry.bargsley@dayforce.com',    # override with real recipients
        [string]$MailSubjectPrefix = 'Alert: D: low disk - .out deleted',
        [string]$SqlInstance = 'AZM1DFCSQL04D,31433',        # SQL instance to run sp_send_dbmail on
        [switch]$UseSqlAuth,                       # if set, use -SqlCredential
        [System.Management.Automation.PSCredential]$SqlCredential
    )

    function Write-Log {
        param([string]$Message)
        $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        $line = "$ts`t$Message"
        # Ensure log folder exists
        $ld = Split-Path $LogFile -Parent
        if ($ld -and -not (Test-Path $ld)) { New-Item -Path $ld -ItemType Directory -Force | Out-Null }
        $line | Out-File -FilePath $LogFile -Append -Encoding UTF8
        Write-Verbose $line
    }

    function Send-DbMail { param($To,$Subject,$Body) Write-Log "Send-DbMail: EMAIL DISABLED BY CONFIG — skipping send." ; return @{ Sent = $false; Error = 'Disabled' } }


    try {
        Write-Log "Started. Drive=$Drive Threshold=$ThresholdPercent TargetFolder=$TargetFolder PerformDelete=$($PerformDelete.IsPresent)"

        $driveNormalized = $Drive.TrimEnd('\')
        if ($driveNormalized -notmatch '^([A-Za-z]):$') { throw "Drive parameter '$Drive' invalid." }
        $driveLetter = $Matches[1]

        # get free percent
        $freePercent = $null
        try {
            $vol = Get-Volume -DriveLetter $driveLetter -ErrorAction Stop
            if ($vol -and $vol.Size -gt 0) { $freePercent = [math]::Round(($vol.SizeRemaining / $vol.Size) * 100, 2) }
        } catch {
            $disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='${driveNormalized}'" -ErrorAction SilentlyContinue
            if ($disk -and $disk.Size -gt 0) { $freePercent = [math]::Round(($disk.FreeSpace / $disk.Size) * 100, 2) }
        }

        if ($null -eq $freePercent) { Write-Log "ERROR: cannot determine free space for $Drive"; return @{ Action='Error'; Error='Cannot determine free space' } }
        Write-Log "Drive $driveNormalized free% = $freePercent"

        if ($freePercent -ge $ThresholdPercent) {
            Write-Log "Free% ($freePercent) >= Threshold ($ThresholdPercent). No action."
            return @{ Action='None'; FreePercent=$freePercent }
        }

        # ensure folder exists
        if (-not (Test-Path $TargetFolder)) {
            Write-Log "TargetFolder '$TargetFolder' does not exist. Nothing to delete."
            return @{ Action='None'; FreePercent=$freePercent; Message='Target folder missing' }
        }

        # find largest .out
        $largest = Get-ChildItem -Path $TargetFolder -File -Recurse -Filter '*.out' -ErrorAction SilentlyContinue |
                   Where-Object { $_.Length -gt 0 } |
                   Sort-Object -Property Length -Descending |
                   Select-Object -First 1
        if (-not $largest) {
            $largest = Get-ChildItem -Path $TargetFolder -File -Recurse -ErrorAction SilentlyContinue |
                       Where-Object { $_.Extension -and ($_.Extension -ieq '.out') -and ($_.Length -gt 0) } |
                       Sort-Object -Property Length -Descending |
                       Select-Object -First 1
        }

        if (-not $largest) {
            Write-Log "No .out files to delete."
            return @{ Action='None'; FreePercent=$freePercent; Message='No .out files' }
        }

        $sizeMB = [math]::Round($largest.Length / 1MB, 2)
        Write-Log ("Largest .out found: {0} ({1} MB)" -f $largest.FullName, $sizeMB)

        if ($PerformDelete.IsPresent) {
            Write-Log "PerformDelete specified: attempting to delete $($largest.FullName)"
            try {
                Remove-Item -LiteralPath $largest.FullName -Force -ErrorAction Stop
                Write-Log ("Deleted: {0}" -f $largest.FullName)

                # Send DB Mail using default profile (intentionally no @profile_name)
                $subject = "$MailSubjectPrefix - $driveNormalized free $freePercent% (deleted .out)"
                $body = @"
<p>Drive <b>$driveNormalized</b> free: $freePercent%.</p>
<p>Deleted largest <b>.out</b> file under <b>$TargetFolder</b>:</p>
<ul>
  <li>File: $($largest.FullName)</li>
  <li>SizeMB: $sizeMB</li>
  <li>Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</li>
</ul>
"@

                $mail = Send-DbMail -To $MailTo -Subject $subject -Body $body
                if ($mail.Sent) { Write-Log "Database Mail sent to $MailTo." } else { Write-Log ("Database Mail not sent: {0}" -f ($mail.Error -join '; ')) }

                return @{ Action='Deleted'; File=$largest.FullName; SizeMB=$sizeMB; FreePercent=$freePercent; MailSent=$mail.Sent }
            } catch {
                Write-Log ("ERROR deleting file: {0}" -f $_.Exception.Message)
                return @{ Action='Error'; Error=$_.Exception.Message }
            }
        } else {
            Write-Log "Dry-run: would delete $($largest.FullName) ($sizeMB MB). To delete, call with -PerformDelete."
            return @{ Action='WouldDelete'; File=$largest.FullName; SizeMB=$sizeMB; FreePercent=$freePercent }
        }
    } catch {
        Write-Log ("Unhandled error: {0}" -f $_.Exception.Message)
        return @{ Action='Error'; Error=$_.Exception.Message }
    }
}

function Write-Log {
    param([string]$Text)
    $time = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $line = "$time | $Text"
    # Try write to console and append to file (create folder if needed)
    Write-Output $line
    try {
        $logDir = Split-Path -Path $LogPath -Parent
        if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
        $line | Out-File -FilePath $LogPath -Append -Encoding UTF8
    } catch {
        Write-Error "Failed to write to log path $LogPath : $($_.Exception.Message)"
    }
}

try {
    if (-not (Test-Path -Path $Path)) {
        Write-Log "ERROR: Path does not exist: $Path"
        exit 2
    }

    $cutoff = (Get-Date).AddHours(-$CutoffHours)
    Write-Log "INFO: Cutoff = $cutoff (files older than $CutoffHours hours)"
    Write-Log "INFO: Target path = $Path (Filter = *.out), Recurse = $($Recurse.IsPresent), DryRun = $($DryRun.IsPresent)"
    
        # If caller requested PerformDelete (and not DryRun), run low-space removal first.
    if ($PerformDelete.IsPresent) {
        if ($DryRun.IsPresent) {
            Write-Log "INFO: -PerformDelete was passed but -DryRun is also present. Skipping actual deletion actions (including low-space removal)."
        } else {
            Write-Log "INFO: -PerformDelete requested. Checking low-space removal before deleting old files (SpaceThreshold = $SpaceThreshold%)."
            try {
                # Drive letter derived from Path's root (e.g., 'D:')
                $driveRoot = (Split-Path -Qualifier $Path)
                if (-not $driveRoot) { $driveRoot = 'D:' }   # fallback

                # Call helper; forward the PerformDelete switch into it.
                $spaceResult = Remove-LargestOutIfLowSpace -ThresholdPercent $SpaceThreshold -Drive $driveRoot -TargetFolder $Path -PerformDelete

                # Log a compact summary (use ConvertTo-Json if available)
                try {
                    $sr = $spaceResult | ConvertTo-Json -Compress -Depth 4
                    Write-Log ("INFO: Low-space removal result: {0}" -f $sr)
                } catch {
                    Write-Log ("INFO: Low-space removal result: {0}" -f $spaceResult)
                }
            } catch {
                Write-Log ("WARN: Low-space removal call failed: {0}" -f $_.Exception.Message)
            }
        }
    } else {
        Write-Log "INFO: -PerformDelete not passed; skipping low-space pre-clean step."
    }

    # Build splatted parameters correctly
    $gciParams = @{
        Path = $Path
        File = $true
        Filter = "*.out"
        ErrorAction = 'Stop'
    }
    if ($Recurse) { $gciParams.Recurse = $true }

    # Get candidates
    $files = Get-ChildItem @gciParams

    $oldFiles = $files | Where-Object { $_.LastWriteTime -lt $cutoff }

    if (-not $oldFiles -or $oldFiles.Count -eq 0) {
        Write-Log "INFO: No .out files older than cutoff found in $Path"
        exit 0
    }

    Write-Log ("INFO: Found {0} candidate(s) to process." -f $oldFiles.Count)
    if ($DryRun) {
        Write-Log "DRY RUN: The following files would be deleted:"
        foreach ($of in $oldFiles) {
            Write-Log ("Candidate: {0} | LastWrite: {1}" -f $of.FullName, $of.LastWriteTime)
        }
        exit 0
    }

    $hadError = $false
    foreach ($f in $oldFiles) {
        try {
            # safe, complete timestamp + filename
            $entry = "{0} | {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $f.FullName
            $entry | Out-File -FilePath $LogPath -Append -Encoding UTF8

            # Use -LiteralPath to avoid issues with special chars in filenames
            Remove-Item -LiteralPath $f.FullName -Force -ErrorAction Stop

            Write-Log ("DELETED: {0}" -f $f.FullName)
        } catch {
            Write-Log ("ERROR: Failed to delete {0} : {1}" -f $f.FullName, $_.Exception.Message)
            Write-Log ("ERROR: Full exception: {0}" -f ($_ | Out-String))
            $hadError = $true
        }
    }

    if ($hadError) {
        Write-Log "ERROR: One or more deletions failed. See log for details: $LogPath"
        exit 1
    } else {
        Write-Log "INFO: Completed successfully."
        exit 0
    }

} catch {
    Write-Log ("FATAL: Unexpected error: {0}" -f $_.Exception.Message)
    Write-Log ("FATAL: Full exception: {0}" -f ($_ | Out-String))
    exit 3
}
