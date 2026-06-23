$DaysBack = 30
$StartDate = (Get-Date).AddDays(-$DaysBack)

$outlook = New-Object -ComObject Outlook.Application
$namespace = $outlook.GetNamespace("MAPI")
$inbox = $namespace.GetDefaultFolder(6)
$alertsRoot = $inbox.Folders.Item("Alerts")

$script:Results = New-Object System.Collections.Generic.List[object]
$script:FoldersVisited = 0
$script:ItemsSeen = 0
$script:ItemsAdded = 0

function Normalize-AlertSubject {
    param([string]$Subject)

    if ([string]::IsNullOrWhiteSpace($Subject)) { return "Unknown" }

    $s = $Subject.Trim()
    $s = $s -replace '^(RE:\s*)+', ''
    $s = $s -replace '^(FW:\s*)+', ''
    $s = $s -replace '^\[PRTG[^\]]*\]\s*', ''
    $s = $s -replace '^\[.*?\]\s*', ''

    switch -Regex ($s) {
        'SNMP CPU Load'                    { return 'CPU Load' }
        'Free Disk Space'                  { return 'Disk Space' }
        'SQL.*Failed|SQL Agent|Failed Jobs'{ return 'Job Failure' }
        'Backup|Commvault'                 { return 'Backup' }
        'Availability Group|AG[_ ]Health'  { return 'Availability Group' }
        'Mongo'                            { return 'MongoDB' }
        'Grafana'                          { return 'Grafana' }
        'Long Running Queries|LongRunning' { return 'Long Running Query' }
        'Deadlock'                         { return 'Deadlock' }
        'Blocking'                         { return 'Blocking' }
        'Memory'                           { return 'Memory' }
        default {
            $s = $s -replace '\s*\|.*$', ''
            $s = $s -replace '\s*\(.*$', ''
            $s = $s.Trim()
            if ([string]::IsNullOrWhiteSpace($s)) { return "Other" }
            return $s
        }
    }
}

function Process-Folder {
    param([object]$Folder)

    $script:FoldersVisited++
    Write-Host "Processing folder: $($Folder.FolderPath)"

    $items = $Folder.Items
    $count = $items.Count

    for ($i = 1; $i -le $count; $i++) {
        try {
            $item = $items.Item($i)
            if (-not $item) { continue }

            $script:ItemsSeen++

            # Mail item class = 43
            if ($item.Class -ne 43) { continue }

            if ($item.ReceivedTime -lt $StartDate) { continue }

            $script:Results.Add([PSCustomObject]@{
                ReceivedTime = $item.ReceivedTime
                Folder       = $Folder.FolderPath
                AlertType    = Normalize-AlertSubject -Subject $item.Subject
                Subject      = $item.Subject
            })

            $script:ItemsAdded++
        }
        catch {
            Write-Warning ("Folder {0}, item {1}: {2}" -f $Folder.FolderPath, $i, $_.Exception.Message)
        }
    }

    foreach ($subFolder in $Folder.Folders) {
        Process-Folder -Folder $subFolder
    }
}

Process-Folder -Folder $alertsRoot

Write-Host ""
Write-Host "Folders visited: $script:FoldersVisited"
Write-Host "Items seen:      $script:ItemsSeen"
Write-Host "Items added:     $script:ItemsAdded"
Write-Host ""

$summary = $script:Results |
    Group-Object AlertType |
    Sort-Object Count -Descending |
    Select-Object Count, Name

$summary | Format-Table -AutoSize

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$summary | Export-Csv ".\AlertSummary_$timestamp.csv" -NoTypeInformation
$script:Results | Export-Csv ".\AlertDetails_$timestamp.csv" -NoTypeInformation