# Outlook Alerts Body-Aware Analyzer
# Scans Inbox\Alerts and nested folders for the last 30 days
# Exports detail, summary, server, repeat, and daily trend CSVs for dashboarding

param(
    [int]$DaysBack = 30,
    [string]$RootFolderName = "Alerts",
    [string]$OutputPrefix = "AlertReport"
)

$StartDate = (Get-Date).AddDays(-$DaysBack)
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

$outlook = New-Object -ComObject Outlook.Application
$namespace = $outlook.GetNamespace("MAPI")
$inbox = $namespace.GetDefaultFolder(6)   # Inbox
$alertsRoot = $inbox.Folders.Item($RootFolderName)

if (-not $alertsRoot) {
    throw "Could not find Inbox\$RootFolderName"
}

$script:Rows = New-Object System.Collections.Generic.List[object]
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
        'SNMP CPU Load'                       { return 'CPU Load' }
        'Free Disk Space'                     { return 'Disk Space' }
        'SQL.*Failed|SQL Agent|Failed Jobs'    { return 'Job Failure' }
        'Backup|Commvault'                    { return 'Backup' }
        'Availability Group|AG[_ ]Health'     { return 'Availability Group' }
        'Mongo'                               { return 'MongoDB' }
        'Grafana'                             { return 'Grafana' }
        'Long Running Queries|LongRunning'    { return 'Long Running Query' }
        'Deadlock'                            { return 'Deadlock' }
        'Blocking'                            { return 'Blocking' }
        'Memory'                              { return 'Memory' }
        default {
            $s = $s -replace '\s*\|.*$', ''
            $s = $s -replace '\s*\(.*$', ''
            $s = $s.Trim()
            if ([string]::IsNullOrWhiteSpace($s)) { return "Other" }
            return $s
        }
    }
}

function Get-PlainTextBody {
    param([object]$Item)

    try {
        $body = [string]$Item.Body
    }
    catch {
        return ""
    }

    if ([string]::IsNullOrWhiteSpace($body)) {
        return ""
    }

    $body = $body -replace '\r\n', ' '
    $body = $body -replace '\n', ' '
    $body = $body -replace '\s+', ' '
    $body = $body.Trim()

    return $body
}

function Extract-AlertDetails {
    param(
        [string]$Subject,
        [string]$Body
    )

    $alertType = Normalize-AlertSubject -Subject $Subject
    $server = "Unknown"
    $metric = "Unknown"
    $status = "Unknown"
    $severity = "Unknown"
    $eventType = "Unknown"

    if ($Body -match '([a-zA-Z0-9\-]+\.(custadds|dayforcehcm)\.com)') {
        $server = $matches[1]
    }
    elseif ($Subject -match '([a-zA-Z0-9\-]+\.(custadds|dayforcehcm)\.com)') {
        $server = $matches[1]
    }

    if ($Body -match 'Sensor\s+(.+?)\s+\*\*\*') {
        $metric = $matches[1].Trim()
    }
    elseif ($Subject -match 'SNMP CPU Load|Free Disk Space|Failed Jobs|Long Running Queries|Availability Group|Backup|Deadlock|Blocking|Memory|Mongo') {
        $metric = $alertType
    }

    if ($Body -match '\b(Warning|Error|Critical|Down|Up|Resolved|Recovered|Failed|OK)\b') {
        $status = $matches[1]
    }

    if ($Body -match 'Down ended|resolved|recovered|is back to normal|OK') {
        $eventType = 'Recovery'
        $severity = 'Recovery'
    }
    elseif ($Body -match 'Down|failed|below the error limit|above the warning limit|above the error limit|error limit|warning limit') {
        $eventType = 'Alert'
        $severity = 'Active/Threshold Breach'
    }
    elseif ($Body -match 'escalation repeat|repeat') {
        $eventType = 'Repeat'
        $severity = 'Repeat'
    }

    if ($metric -eq 'Unknown') {
        if ($Body -match '(CPU Load|Free Disk Space|Failed Jobs|Long Running Queries|Availability Group|Backup|Deadlock|Blocking|Memory|Mongo)') {
            $metric = $matches[1]
        }
    }

    [PSCustomObject]@{
        AlertType = $alertType
        Server    = $server
        Metric    = $metric
        Status    = $status
        Severity  = $severity
        EventType = $eventType
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

            if ($item.Class -ne 43) { continue }  # Mail only
            if ($item.ReceivedTime -lt $StartDate) { continue }

            $bodyText = Get-PlainTextBody -Item $item
            $details = Extract-AlertDetails -Subject ([string]$item.Subject) -Body $bodyText

            $bodyPreview = $bodyText
            if ($bodyPreview.Length -gt 500) {
                $bodyPreview = $bodyPreview.Substring(0, 500)
            }

            $script:Rows.Add([PSCustomObject]@{
                ReceivedTime = $item.ReceivedTime
                Folder       = $Folder.FolderPath
                AlertType    = $details.AlertType
                Server       = $details.Server
                Metric       = $details.Metric
                Status       = $details.Status
                Severity     = $details.Severity
                EventType    = $details.EventType
                Subject      = [string]$item.Subject
                BodyPreview  = $bodyPreview
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

if ($script:Rows.Count -eq 0) {
    throw "No alert rows were collected. Check folder access, date range, or Outlook item availability."
}

$detailPath = ".\${OutputPrefix}_Details_$Timestamp.csv"
$summaryPath = ".\${OutputPrefix}_Summary_$Timestamp.csv"
$serverPath  = ".\${OutputPrefix}_Servers_$Timestamp.csv"
$repeatPath  = ".\${OutputPrefix}_Repeats_$Timestamp.csv"
$dailyPath   = ".\${OutputPrefix}_DailyTrend_$Timestamp.csv"

# Core detail export
$script:Rows |
    Sort-Object ReceivedTime -Descending |
    Export-Csv $detailPath -NoTypeInformation

# Summary by alert type
$summary = $script:Rows |
    Group-Object AlertType |
    Sort-Object Count -Descending |
    Select-Object @{Name='Count';Expression={$_.Count}}, @{Name='AlertType';Expression={$_.Name}}
$summary | Export-Csv $summaryPath -NoTypeInformation

# Server-heavy hitters
$servers = $script:Rows |
    Group-Object Server |
    Sort-Object Count -Descending |
    Select-Object @{Name='Count';Expression={$_.Count}}, @{Name='Server';Expression={$_.Name}}
$servers | Export-Csv $serverPath -NoTypeInformation

# Repeat analysis: alert type + server + metric
$repeats = $script:Rows |
    Group-Object AlertType, Server, Metric |
    Where-Object { $_.Count -gt 1 } |
    Sort-Object Count -Descending |
    Select-Object @{Name='Count';Expression={$_.Count}}, @{Name='AlertKey';Expression={$_.Name}}
$repeats | Export-Csv $repeatPath -NoTypeInformation

# Daily trend
$daily = $script:Rows |
    Group-Object @{Expression={([datetime]$_.ReceivedTime).Date}} |
    Sort-Object Name |
    Select-Object @{Name='Date';Expression={$_.Name}}, @{Name='Count';Expression={$_.Count}}
$daily | Export-Csv $dailyPath -NoTypeInformation

Write-Host ""
Write-Host "Exported files:"
Write-Host "  $detailPath"
Write-Host "  $summaryPath"
Write-Host "  $serverPath"
Write-Host "  $repeatPath"
Write-Host "  $dailyPath"
