param(
    [Parameter(Mandatory = $true)]
    [string]$ServerListPath,

    [string]$JobNameLike = '*FULL*',

    [string]$OutputCsvPath = ".\FullBackupJobStatus.csv"
)

Import-Module dbatools -ErrorAction Stop

function Convert-JobOutcome {
    param(
        [object]$Outcome
    )

    if ($null -eq $Outcome) {
        return 'Unknown'
    }

    $value = $Outcome.ToString()

    switch ($value) {
        '0' { 'Failed' }
        '1' { 'Succeeded' }
        '2' { 'Retry' }
        '3' { 'Canceled' }
        '4' { 'In Progress' }
        default { $value }
    }
}

if (-not (Test-Path $ServerListPath)) {
    throw "Server list file not found: $ServerListPath"
}

$servers = Get-Content $ServerListPath |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -and -not $_.StartsWith('#') } |
    Sort-Object -Unique

$results = foreach ($server in $servers) {
    try {
        $jobs = Get-DbaAgentJob -SqlInstance $server -ErrorAction Stop |
            Where-Object { $_.Name -like $JobNameLike }

        if (-not $jobs) {
            [pscustomobject]@{
                SqlInstance    = $server
                JobName        = $null
                LastRunStatus   = $null
                LastRunDate     = $null
                LastRunDuration = $null
                Enabled         = $null
                Notes           = 'No matching jobs found'
            }
            continue
        }

        foreach ($job in $jobs) {
            [pscustomobject]@{
                SqlInstance    = $server
                JobName        = $job.Name
                LastRunStatus   = Convert-JobOutcome $job.LastRunOutcome
                LastRunDate     = $job.LastRunDate
                LastRunDuration = $job.LastRunDuration
                Enabled         = $job.IsEnabled
                Notes           = $null
            }
        }
    }
    catch {
        [pscustomobject]@{
            SqlInstance    = $server
            JobName        = $null
            LastRunStatus   = $null
            LastRunDate     = $null
            LastRunDuration = $null
            Enabled         = $null
            Notes           = "ERROR: $($_.Exception.Message)"
        }
    }
}

$results | Export-Csv -Path $OutputCsvPath -NoTypeInformation
$results | Format-Table -AutoSize