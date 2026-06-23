#Requires -Modules dbatools

function Test-AnyPatternMatch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Text,

        [Parameter(Mandatory)]
        [string[]]$Patterns
    )

    foreach ($pattern in $Patterns) {
        if ($Text -match $pattern) {
            return $true
        }
    }

    return $false
}

function Get-AgEventPhase {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Category,

        [Parameter(Mandatory)]
        [string]$Message
    )

    $combined = "$Category $Message"

    switch -Regex ($combined) {
        'Lease timeout|lease expired|lease mechanism' { return 'Failure / lease loss' }
        'Health check timeout|sp_server_diagnostics|diagnostics heartbeat' { return 'Detection / health probe failure' }
        'Failover / role transition|transition(ed)? to the primary role|transition(ed)? to the resolving role|PRIMARY_NORMAL|PRIMARY_PENDING|RESOLVING' { return 'Role transition' }
        'Connectivity / endpoint issue|endpoint|connection timeout|timeout occurred while waiting|not synchronizing' { return 'Connectivity problem' }
        default { return 'Other AG event' }
    }
}

function Get-AgRoleTransitions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Events
    )

    $ordered = @($Events | Sort-Object LogTime)
    $transitions = @()

    foreach ($event in $ordered) {
        $msg = [string]$event.Message
        $fromState = $null
        $toState = $null
        $kind = $null
        $evidence = $null
        $confidence = 'Low'
        $isPromotion = $false

        if ($msg -match "changed from '(?<from>[^']+)' to '(?<to>[^']+)'") {
            $fromState = $matches.from
            $toState = $matches.to
            $evidence = 'Explicit state change'

            if ($toState -match 'PRIMARY') {
                $kind = 'Promotion'
                $isPromotion = $true
                $confidence = 'High'
            }
            elseif ($toState -match 'RESOLVING|SECONDARY') {
                $kind = 'Demotion'
                $confidence = 'High'
            }
            else {
                continue
            }
        }
        elseif ($msg -match 'transition(ed)? to the primary role') {
            $kind = 'Promotion'
            $toState = 'PRIMARY'
            $isPromotion = $true
            $confidence = 'High'
            $evidence = 'Transition to primary role'
        }
        elseif ($msg -match 'transition(ed)? to the resolving role') {
            $kind = 'Demotion'
            $toState = 'RESOLVING'
            $confidence = 'High'
            $evidence = 'Transition to resolving role'
        }
        elseif ($msg -match 'preparing to transition to the primary role') {
            $kind = 'Promotion'
            $toState = 'PRIMARY'
            $isPromotion = $true
            $confidence = 'Medium'
            $evidence = 'Preparing to transition to primary role'
        }
        elseif ($msg -match 'preparing to transition to the resolving role') {
            $kind = 'Demotion'
            $toState = 'RESOLVING'
            $confidence = 'Medium'
            $evidence = 'Preparing to transition to resolving role'
        }
        elseif ($msg -match 'changing roles from "RESOLVING" to "PRIMARY"') {
            $kind = 'Promotion'
            $fromState = 'RESOLVING'
            $toState = 'PRIMARY'
            $isPromotion = $true
            $confidence = 'High'
            $evidence = 'Resolving to primary'
        }
        elseif ($msg -match 'changing roles from "PRIMARY" to "RESOLVING"') {
            $kind = 'Demotion'
            $fromState = 'PRIMARY'
            $toState = 'RESOLVING'
            $confidence = 'High'
            $evidence = 'Primary to resolving'
        }
        else {
            continue
        }

        $transitions += [pscustomobject]@{
            Time        = $event.LogTime
            Instance    = $event.Instance
            Kind        = $kind
            IsPromotion = $isPromotion
            FromState   = $fromState
            ToState     = $toState
            Evidence    = $evidence
            Confidence  = $confidence
            Source      = $event.Source
            Message     = $event.Message
        }
    }

    return @($transitions | Sort-Object Time)
}

function Get-AgPrimaryAtTime {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$RoleTransitions,

        [Parameter(Mandatory)]
        [datetime]$Time
    )

    $primary = $null
    $promotions = @($RoleTransitions | Where-Object { $_.IsPromotion } | Sort-Object Time)

    foreach ($transition in $promotions) {
        if ($transition.Time -le $Time) {
            $primary = $transition.Instance
        }
        else {
            break
        }
    }

    return $primary
}

function Get-AgPrimaryChain {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$RoleTransitions
    )

    $promotions = @($RoleTransitions | Where-Object { $_.IsPromotion } | Sort-Object Time)
    $timeline = @()
    $chain = @()
    $lastInstance = $null

    foreach ($promotion in $promotions) {
        $timeline += [pscustomobject]@{
            Time      = $promotion.Time
            Instance  = $promotion.Instance
            FromState = $promotion.FromState
            ToState   = $promotion.ToState
            Evidence  = $promotion.Evidence
        }

        if ($null -eq $lastInstance -or $promotion.Instance -ne $lastInstance) {
            $chain += $promotion.Instance
            $lastInstance = $promotion.Instance
        }
    }

    [pscustomobject]@{
        ChainText         = if ($chain.Count -gt 0) { $chain -join ' -> ' } else { 'No primary promotion observed' }
        InitialPrimary    = if ($chain.Count -gt 0) { $chain[0] } else { $null }
        FinalPrimary      = if ($chain.Count -gt 0) { $chain[-1] } else { $null }
        PromotionCount    = $promotions.Count
        UniquePrimaryCount = $chain.Count
        Timeline          = @($timeline)
    }
}

function Get-AgIncidentGroups {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Events,

        [Parameter(Mandatory)]
        [object[]]$RoleTransitions,

        [int]$GapMinutes = 20
    )

    $ordered = @($Events | Sort-Object LogTime)
    if (-not $ordered -or $ordered.Count -eq 0) {
        return @()
    }

    $groups = @()
    $current = @()
    $lastTime = $null

    foreach ($event in $ordered) {
        if ($current.Count -gt 0 -and $null -ne $lastTime) {
            $gap = ($event.LogTime - $lastTime).TotalMinutes
            if ($gap -gt $GapMinutes) {
                $groups += ,$current
                $current = @()
            }
        }

        $current += $event
        $lastTime = $event.LogTime
    }

    if ($current.Count -gt 0) {
        $groups += ,$current
    }

    $incidentGroups = @()
    $incidentId = 0
    $promotions = @($RoleTransitions | Where-Object { $_.IsPromotion } | Sort-Object Time)

    foreach ($group in $groups) {
        $incidentId++
        $eventsInIncident = @($group | Sort-Object LogTime)
        $startTime = $eventsInIncident[0].LogTime
        $endTime = $eventsInIncident[-1].LogTime

        $transitionsInIncident = @(
            $RoleTransitions | Where-Object {
                $_.Time -ge $startTime -and $_.Time -le $endTime
            } | Sort-Object Time
        )

        $promotionsInIncident = @($transitionsInIncident | Where-Object { $_.IsPromotion })
        $demotionsInIncident = @($transitionsInIncident | Where-Object { -not $_.IsPromotion -and $_.Kind -eq 'Demotion' })

        $primaryBefore = Get-AgPrimaryAtTime -RoleTransitions $promotions -Time ($startTime.AddMilliseconds(-1))
        $primaryAfter = Get-AgPrimaryAtTime -RoleTransitions $promotions -Time $endTime

        $firstFailure = $eventsInIncident | Where-Object {
            $_.Category -in @('Lease timeout', 'Health check timeout', 'Connectivity / endpoint issue')
        } | Select-Object -First 1

        $firstPromotion = $promotionsInIncident | Select-Object -First 1
        $firstDemotion = $demotionsInIncident | Select-Object -First 1

        $trigger = if ($firstFailure) {
            $firstFailure.Category
        }
        elseif ($firstPromotion) {
            'Role transition'
        }
        elseif ($firstDemotion) {
            'Role transition'
        }
        elseif ($eventsInIncident.Count -gt 0) {
            $eventsInIncident[0].Category
        }
        else {
            'Unknown'
        }

        $primaryChanged = ($null -ne $primaryBefore -and $null -ne $primaryAfter -and $primaryBefore -ne $primaryAfter)
        $hasRoleMove = ($promotionsInIncident.Count -gt 0 -or $demotionsInIncident.Count -gt 0)
        $hasFailureSignal = ($null -ne $firstFailure)

        $severity = if ($hasFailureSignal -or $primaryChanged) {
            'High'
        }
        elseif ($hasRoleMove) {
            'Medium'
        }
        else {
            'Low'
        }

        $status = if ($primaryChanged) {
            'Recovered'
        }
        elseif ($hasRoleMove) {
            'Changed'
        }
        else {
            'Informational'
        }

        $confidence = if ($primaryChanged -or ($hasRoleMove -and $primaryBefore)) {
            'High'
        }
        elseif ($hasRoleMove -or $hasFailureSignal) {
            'Medium'
        }
        else {
            'Low'
        }

        $incidentGroups += [pscustomobject]@{
            IncidentId      = $incidentId
            StartTime       = $startTime
            EndTime         = $endTime
            DurationMinutes = [math]::Round(($endTime - $startTime).TotalMinutes, 2)
            EventCount      = $eventsInIncident.Count
            Severity        = $severity
            Status          = $status
            Confidence      = $confidence
            Trigger         = $trigger
            PrimaryBefore   = $primaryBefore
            PrimaryAfter    = $primaryAfter
            PrimaryChanged  = $primaryChanged
            Categories      = @($eventsInIncident.Category | Sort-Object -Unique)
            Replicas        = @($eventsInIncident.Instance | Sort-Object -Unique)
            RoleTransitions = @($transitionsInIncident)
            Events          = @($eventsInIncident)
        }
    }

    return @($incidentGroups)
}

function Convert-ToAgNarrative {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Events,

        [Parameter(Mandatory)]
        [string]$AvailabilityGroup,

        [Parameter(Mandatory)]
        [datetime]$StartTime,

        [Parameter(Mandatory)]
        [datetime]$EndTime,

        [Parameter(Mandatory)]
        [string[]]$Targets,

        [Parameter(Mandatory)]
        [object[]]$Incidents,

        [Parameter(Mandatory)]
        [object[]]$PrimaryTimeline,

        [string]$PrimaryChainText,

        [object[]]$SkippedReplicas = @()
    )

    $ordered = @($Events | Sort-Object LogTime)
    $lines = New-Object System.Collections.Generic.List[string]

    $lines.Add("AG Incident Summary: $AvailabilityGroup") | Out-Null
    $lines.Add(("Window: {0} to {1}" -f $StartTime.ToString('yyyy-MM-dd HH:mm:ss'), $EndTime.ToString('yyyy-MM-dd HH:mm:ss'))) | Out-Null
    $lines.Add(("Replicas scanned: {0}" -f $Targets.Count)) | Out-Null

    if ($SkippedReplicas -and $SkippedReplicas.Count -gt 0) {
        $lines.Add(("Skipped replicas: {0}" -f (($SkippedReplicas | ForEach-Object { "{0} ({1})" -f $_.Name, $_.Reason }) -join ', '))) | Out-Null
    }
    else {
        $lines.Add("Skipped replicas: none") | Out-Null
    }

    $lines.Add(("Events found: {0}" -f $ordered.Count)) | Out-Null
    $lines.Add(("Incidents detected: {0}" -f $Incidents.Count)) | Out-Null
    $lines.Add(("Primary chain observed: {0}" -f $PrimaryChainText)) | Out-Null
    $lines.Add(("Primary promotions observed: {0}" -f $PrimaryTimeline.Count)) | Out-Null

    if ($Incidents.Count -gt 1) {
        $lines.Add("Multiple incidents were detected. The assessment below is grouped by incident so the state changes stay readable.") | Out-Null
    }
    elseif ($Incidents.Count -eq 1) {
        $lines.Add("One incident was detected in the selected window.") | Out-Null
    }
    else {
        $lines.Add("No incident groups were created from the selected window.") | Out-Null
    }

    $lines.Add("") | Out-Null
    $lines.Add("Quick answer:") | Out-Null

    if ($PrimaryTimeline.Count -gt 1) {
        $lines.Add("- A primary change was observed in the window.") | Out-Null
    }
    else {
        $lines.Add("- No clear primary promotion was observed in the window.") | Out-Null
    }

    if ($Incidents.Count -gt 0) {
        $topIncident = $Incidents | Sort-Object @{ Expression = { if ($_.Severity -eq 'High') { 1 } elseif ($_.Severity -eq 'Medium') { 2 } else { 3 } } }, StartTime | Select-Object -First 1
        $lines.Add(("- The most important incident looks like Incident {0} [{1}] from {2} to {3}." -f $topIncident.IncidentId, $topIncident.Severity, $topIncident.StartTime.ToString('yyyy-MM-dd HH:mm:ss'), $topIncident.EndTime.ToString('yyyy-MM-dd HH:mm:ss'))) | Out-Null
    }

    $lines.Add("") | Out-Null
    $lines.Add("Incident workflow:") | Out-Null

    foreach ($incident in ($Incidents | Sort-Object IncidentId)) {
        $primaryFlow = if ($incident.PrimaryChanged) {
            "{0} -> {1}" -f $incident.PrimaryBefore, $incident.PrimaryAfter
        }
        elseif ($incident.PrimaryAfter) {
            "primary stayed on {0}" -f $incident.PrimaryAfter
        }
        elseif ($incident.PrimaryBefore) {
            "primary before incident: {0}" -f $incident.PrimaryBefore
        }
        else {
            'primary could not be established from the logs'
        }

        $lines.Add(("Incident {0} [{1}] {2} -> {3} ({4} min, {5} events, {6}, confidence {7})" -f `
            $incident.IncidentId,
            $incident.Severity,
            $incident.StartTime.ToString('yyyy-MM-dd HH:mm:ss'),
            $incident.EndTime.ToString('yyyy-MM-dd HH:mm:ss'),
            $incident.DurationMinutes,
            $incident.EventCount,
            $incident.Status,
            $incident.Confidence)) | Out-Null
        $lines.Add(("  Trigger: {0}; Categories: {1}" -f $incident.Trigger, ($incident.Categories -join ', '))) | Out-Null
        $lines.Add(("  Primary before/after: {0}" -f $primaryFlow)) | Out-Null
    }

    $lines.Add("") | Out-Null
    $lines.Add("Primary timeline:") | Out-Null
    if ($PrimaryTimeline.Count -gt 0) {
        foreach ($row in $PrimaryTimeline) {
            $lines.Add(("{0}  {1}  {2} -> {3}  ({4})" -f `
                $row.Time.ToString('yyyy-MM-dd HH:mm:ss'),
                $row.Instance,
                $row.FromState,
                $row.ToState,
                $row.Evidence)) | Out-Null
        }
    }
    else {
        $lines.Add("No explicit primary promotion events were found.") | Out-Null
    }

    $lines.Add("") | Out-Null
    $lines.Add("Assessment:") | Out-Null

    if ($Incidents.Count -gt 1) {
        $lines.Add("The window contains multiple separate AG incidents. The primary timeline above is the safest way to understand how the AG moved from one node to another.") | Out-Null
    }

    if ($PrimaryTimeline.Count -gt 1) {
        $firstPrimary = $PrimaryTimeline[0].Instance
        $lastPrimary = $PrimaryTimeline[$PrimaryTimeline.Count - 1].Instance
        if ($firstPrimary -ne $lastPrimary) {
            $lines.Add(("The primary chain changed from {0} to {1} during the window." -f $firstPrimary, $lastPrimary)) | Out-Null
        }
        else {
            $lines.Add(("The primary chain began and ended on {0}." -f $firstPrimary)) | Out-Null
        }
    }

    $highIncident = $Incidents | Where-Object { $_.Severity -eq 'High' } | Select-Object -First 1
    if ($highIncident) {
        $lines.Add(("Incident {0} is the strongest candidate for the main failover or outage sequence." -f $highIncident.IncidentId)) | Out-Null
    }
    else {
        $lines.Add("No high-severity failover candidate was identified from the available logs.") | Out-Null
    }

    return ($lines -join [Environment]::NewLine)
}

function Export-AgFailureHtml {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Report,

        [Parameter(Mandatory)]
        [string]$Path
    )

    if ($null -eq $Report) {
        throw "Export-AgFailureHtml received a null report object."
    }

    function Get-SafePropertyValue {
        param(
            [Parameter(Mandatory)]
            [object]$Object,

            [Parameter(Mandatory)]
            [string]$Name,

            [object]$Default = $null
        )

        if ($null -eq $Object) { return $Default }
        $prop = $Object.PSObject.Properties[$Name]
        if ($null -eq $prop) { return $Default }
        return $prop.Value
    }

    function Get-RowClass {
        param([object]$Event)
        $phase = [string](Get-SafePropertyValue -Object $Event -Name 'Phase' -Default '')
        $category = [string](Get-SafePropertyValue -Object $Event -Name 'Category' -Default '')
        switch -Regex (("$category $phase")) {
            'Lease timeout|Health check timeout|Failure / lease loss|Detection / health probe failure' { return 'row-high' }
            'Role transition' { return 'row-medium' }
            default { return 'row-low' }
        }
    }

    function Get-IncidentClass {
        param([object]$Incident)
        switch ([string](Get-SafePropertyValue -Object $Incident -Name 'Severity' -Default 'Low')) {
            'High' { return 'incident-high' }
            'Medium' { return 'incident-medium' }
            default { return 'incident-low' }
        }
    }

    $rawIncidents = @(Get-SafePropertyValue -Object $Report -Name 'Incidents' -Default @())
    $incidents = @(
        foreach ($incident in $rawIncidents) {
            if ($null -eq $incident) { continue }
            if ($null -eq $incident.PSObject.Properties['IncidentId']) { continue }
            $incident
        }
    )

    $primaryTimeline = @(
        Get-SafePropertyValue -Object $Report -Name 'PrimaryTimeline' -Default @()
    )

    $summaryText = [System.Net.WebUtility]::HtmlEncode([string](Get-SafePropertyValue -Object $Report -Name 'SummaryText' -Default ''))
    $primaryChainText = [System.Net.WebUtility]::HtmlEncode([string](Get-SafePropertyValue -Object $Report -Name 'PrimaryChainText' -Default ''))

    $skippedHtml = ''
    $skipped = @(Get-SafePropertyValue -Object $Report -Name 'SkippedReplicas' -Default @())
    if ($skipped.Count -gt 0) {
        $skippedHtml = @"
    <tr><th>Skipped Replicas</th><td>$([System.Net.WebUtility]::HtmlEncode(($skipped -join ', ')))</td></tr>
"@
    }

    $metaHtml = @"
<table>
    <tr><th>Availability Group</th><td>$([System.Net.WebUtility]::HtmlEncode([string](Get-SafePropertyValue -Object $Report -Name 'AvailabilityGroup' -Default '')))</td></tr>
    <tr><th>Seed Instance</th><td>$([System.Net.WebUtility]::HtmlEncode([string](Get-SafePropertyValue -Object $Report -Name 'SeedInstance' -Default '')))</td></tr>
    <tr><th>Window Start</th><td>$([System.Net.WebUtility]::HtmlEncode([string](Get-SafePropertyValue -Object $Report -Name 'StartTime' -Default '')))</td></tr>
    <tr><th>Window End</th><td>$([System.Net.WebUtility]::HtmlEncode([string](Get-SafePropertyValue -Object $Report -Name 'EndTime' -Default '')))</td></tr>
    <tr><th>Events</th><td>$([System.Net.WebUtility]::HtmlEncode([string](Get-SafePropertyValue -Object $Report -Name 'EventCount' -Default '')))</td></tr>
    <tr><th>Incidents</th><td>$([System.Net.WebUtility]::HtmlEncode([string]$incidents.Count))</td></tr>
    <tr><th>Primary Chain</th><td>$primaryChainText</td></tr>
    <tr><th>Primary Promotions</th><td>$([System.Net.WebUtility]::HtmlEncode([string]($primaryTimeline.Count)))</td></tr>
    <tr><th>Primary Before</th><td>$([System.Net.WebUtility]::HtmlEncode([string](Get-SafePropertyValue -Object $Report -Name 'PrimaryBefore' -Default '')))</td></tr>
    <tr><th>Primary After</th><td>$([System.Net.WebUtility]::HtmlEncode([string](Get-SafePropertyValue -Object $Report -Name 'PrimaryAfter' -Default '')))</td></tr>
$skippedHtml</table>
"@

    $timelineRows = foreach ($row in $primaryTimeline) {
        "<tr><td>$([System.Net.WebUtility]::HtmlEncode([string](Get-SafePropertyValue -Object $row -Name 'Time' -Default '')))</td><td>$([System.Net.WebUtility]::HtmlEncode([string](Get-SafePropertyValue -Object $row -Name 'Instance' -Default '')))</td><td>$([System.Net.WebUtility]::HtmlEncode([string](Get-SafePropertyValue -Object $row -Name 'FromState' -Default '')))</td><td>$([System.Net.WebUtility]::HtmlEncode([string](Get-SafePropertyValue -Object $row -Name 'ToState' -Default '')))</td><td>$([System.Net.WebUtility]::HtmlEncode([string](Get-SafePropertyValue -Object $row -Name 'Evidence' -Default '')))</td></tr>"
    }

    if (-not $timelineRows) { $timelineRows = @() }

    $overviewRows = foreach ($incident in $incidents) {
        $cls = Get-IncidentClass -Incident $incident
        $incidentId = [System.Net.WebUtility]::HtmlEncode([string](Get-SafePropertyValue -Object $incident -Name 'IncidentId' -Default ''))
        $start = [System.Net.WebUtility]::HtmlEncode([string](Get-SafePropertyValue -Object $incident -Name 'StartTime' -Default ''))
        $end = [System.Net.WebUtility]::HtmlEncode([string](Get-SafePropertyValue -Object $incident -Name 'EndTime' -Default ''))
        $duration = [System.Net.WebUtility]::HtmlEncode([string](Get-SafePropertyValue -Object $incident -Name 'DurationMinutes' -Default ''))
        $eventCount = [System.Net.WebUtility]::HtmlEncode([string](Get-SafePropertyValue -Object $incident -Name 'EventCount' -Default ''))
        $status = [System.Net.WebUtility]::HtmlEncode([string](Get-SafePropertyValue -Object $incident -Name 'Status' -Default ''))
        $trigger = [System.Net.WebUtility]::HtmlEncode([string](Get-SafePropertyValue -Object $incident -Name 'Trigger' -Default ''))
        $categories = [System.Net.WebUtility]::HtmlEncode(((Get-SafePropertyValue -Object $incident -Name 'Categories' -Default @()) -join ', '))
        $primaryBefore = [System.Net.WebUtility]::HtmlEncode([string](Get-SafePropertyValue -Object $incident -Name 'PrimaryBefore' -Default ''))
        $primaryAfter = [System.Net.WebUtility]::HtmlEncode([string](Get-SafePropertyValue -Object $incident -Name 'PrimaryAfter' -Default ''))
        $confidence = [System.Net.WebUtility]::HtmlEncode([string](Get-SafePropertyValue -Object $incident -Name 'Confidence' -Default ''))

        "<tr class='$cls'><td>$incidentId</td><td>$start</td><td>$end</td><td>$duration</td><td>$eventCount</td><td>$status</td><td>$confidence</td><td>$trigger</td><td>$categories</td><td>$primaryBefore</td><td>$primaryAfter</td></tr>"
    }

    $incidentSections = foreach ($incident in $incidents) {
        $incidentClass = Get-IncidentClass -Incident $incident
        $incidentId = [System.Net.WebUtility]::HtmlEncode([string](Get-SafePropertyValue -Object $incident -Name 'IncidentId' -Default ''))
        $severity = [System.Net.WebUtility]::HtmlEncode([string](Get-SafePropertyValue -Object $incident -Name 'Severity' -Default ''))
        $status = [System.Net.WebUtility]::HtmlEncode([string](Get-SafePropertyValue -Object $incident -Name 'Status' -Default ''))
        $confidence = [System.Net.WebUtility]::HtmlEncode([string](Get-SafePropertyValue -Object $incident -Name 'Confidence' -Default ''))
        $trigger = [System.Net.WebUtility]::HtmlEncode([string](Get-SafePropertyValue -Object $incident -Name 'Trigger' -Default ''))
        $primaryBefore = [System.Net.WebUtility]::HtmlEncode([string](Get-SafePropertyValue -Object $incident -Name 'PrimaryBefore' -Default ''))
        $primaryAfter = [System.Net.WebUtility]::HtmlEncode([string](Get-SafePropertyValue -Object $incident -Name 'PrimaryAfter' -Default ''))
        $categories = [System.Net.WebUtility]::HtmlEncode(((Get-SafePropertyValue -Object $incident -Name 'Categories' -Default @()) -join ', '))
        $start = [System.Net.WebUtility]::HtmlEncode([string](Get-SafePropertyValue -Object $incident -Name 'StartTime' -Default ''))
        $end = [System.Net.WebUtility]::HtmlEncode([string](Get-SafePropertyValue -Object $incident -Name 'EndTime' -Default ''))
        $duration = [System.Net.WebUtility]::HtmlEncode([string](Get-SafePropertyValue -Object $incident -Name 'DurationMinutes' -Default ''))

        $eventRows = foreach ($event in @(Get-SafePropertyValue -Object $incident -Name 'Events' -Default @())) {
            $rowClass = Get-RowClass -Event $event
            $logTime = [System.Net.WebUtility]::HtmlEncode([string](Get-SafePropertyValue -Object $event -Name 'LogTime' -Default ''))
            $instance = [System.Net.WebUtility]::HtmlEncode([string](Get-SafePropertyValue -Object $event -Name 'Instance' -Default ''))
            $phase = [System.Net.WebUtility]::HtmlEncode([string](Get-SafePropertyValue -Object $event -Name 'Phase' -Default ''))
            $category = [System.Net.WebUtility]::HtmlEncode([string](Get-SafePropertyValue -Object $event -Name 'Category' -Default ''))
            $source = [System.Net.WebUtility]::HtmlEncode([string](Get-SafePropertyValue -Object $event -Name 'Source' -Default ''))
            $message = [System.Net.WebUtility]::HtmlEncode([string](Get-SafePropertyValue -Object $event -Name 'Message' -Default ''))

            "<tr class='$rowClass'><td>$incidentId</td><td>$logTime</td><td>$instance</td><td>$phase</td><td>$category</td><td>$source</td><td>$message</td></tr>"
        }

        if (-not $eventRows) { $eventRows = @() }

        $story = "Trigger: {0}; Categories: {1}; Primary before/after: {2} -> {3}" -f $trigger, $categories, $primaryBefore, $primaryAfter

        @"
<div class='incident-block $incidentClass'>
  <h3>Incident $incidentId - $severity - $status</h3>
  <p><strong>Window:</strong> $start to $end<br/><strong>Duration:</strong> $duration minutes<br/><strong>Confidence:</strong> $confidence<br/><strong>Story:</strong> $([System.Net.WebUtility]::HtmlEncode($story))</p>
  <table>
    <tr><th>Incident</th><th>Time</th><th>Replica</th><th>Phase</th><th>Category</th><th>Source</th><th>Message</th></tr>
    $($eventRows -join "`n")
  </table>
</div>
"@
    }

    $html = @"
<html>
<head>
    <meta charset="utf-8" />
    <title>AG Failure Log Review</title>
    <style>
        body { font-family: Segoe UI, Arial, sans-serif; margin: 20px; color: #222; }
        h1, h2, h3 { margin-bottom: 8px; }
        table { border-collapse: collapse; width: 100%; margin-bottom: 18px; }
        th, td { border: 1px solid #d0d0d0; padding: 6px 8px; vertical-align: top; text-align: left; }
        th { background: #f3f3f3; }
        pre { white-space: pre-wrap; background: #f7f7f7; border: 1px solid #dcdcdc; padding: 12px; }
        .meta { margin-bottom: 18px; }
        .tiny { color: #666; font-size: 12px; }
        .incident-block { margin: 18px 0 26px 0; padding: 14px; border: 1px solid #ddd; border-left-width: 8px; border-radius: 8px; background: #fff; }
        .incident-high { border-left-color: #b42318; background: #fff7f7; }
        .incident-medium { border-left-color: #d97706; background: #fffaf0; }
        .incident-low { border-left-color: #15803d; background: #f6fff9; }
        .row-high td { background: #fff1f1; }
        .row-medium td { background: #fff7e6; }
        .row-low td { background: #f5fbff; }
    </style>
</head>
<body>
    <h1>Availability Group Failure Log Review</h1>
    <div class="meta">
        $metaHtml
    </div>
    <h2>Summary</h2>
    <pre>$summaryText</pre>

    <h2>Primary Timeline</h2>
    <p class="tiny">This shows the exact promotion evidence used to explain how the AG moved from one primary to another.</p>
    <table>
        <tr><th>Time</th><th>Replica</th><th>From</th><th>To</th><th>Evidence</th></tr>
        $($timelineRows -join "`n")
    </table>

    <h2>Incident Overview</h2>
    <p class="tiny">Incidents are grouped by quiet gaps between events. The primary before/after columns come from the primary timeline, not from a guess.</p>
    <table>
        <tr>
            <th>Incident</th><th>Start</th><th>End</th><th>Duration (min)</th><th>Events</th><th>Status</th><th>Confidence</th><th>Trigger</th><th>Categories</th><th>Primary Before</th><th>Primary After</th>
        </tr>
        $($overviewRows -join "`n")
    </table>

    <h2>Incident Detail</h2>
    $($incidentSections -join "`n")
</body>
</html>
"@

    Set-Content -Path $Path -Value $html -Encoding UTF8
    return $Path
}

function Send-AgFailureEmail {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Report,

        [Parameter(Mandatory)]
        [string]$To,

        [Parameter(Mandatory)]
        [string]$From,

        [Parameter(Mandatory)]
        [string]$SmtpServer,

        [string]$Subject = "AG Failure Report: $($Report.AvailabilityGroup)",

        [int]$Port = 25,

        [switch]$UseSsl
    )

    $tempPath = Join-Path $env:TEMP ("{0}_AgFailure_{1:yyyyMMddHHmmss}.html" -f $Report.AvailabilityGroup, (Get-Date))
    Export-AgFailureHtml -Report $Report -Path $tempPath | Out-Null
    $body = Get-Content -Path $tempPath -Raw

    Send-MailMessage `
        -To $To `
        -From $From `
        -Subject $Subject `
        -BodyAsHtml `
        -Body $body `
        -SmtpServer $SmtpServer `
        -Port $Port `
        -UseSsl:$UseSsl
}

function Invoke-DbaAgErrorLogReview {
    [CmdletBinding()]
    param(
        [Alias('SqlInstance')]
        [Parameter(Mandatory)]
        [string]$SeedInstance,

        [Parameter(Mandatory)]
        [string]$AvailabilityGroup,

        [Parameter(Mandatory)]
        [datetime]$StartTime,

        [Parameter(Mandatory)]
        [datetime]$EndTime,

        [Parameter()]
        [int]$SecondaryPort = 31433,

        [Parameter()]
        [int]$IncidentGapMinutes = 20,

        [Parameter()]
        [switch]$ShowEvents,

        [Parameter()]
        [string]$HtmlPath,

        [Parameter()]
        [switch]$OpenHtml
    )

    if ($StartTime -ge $EndTime) {
        throw "StartTime must be earlier than EndTime."
    }

    $ag = Get-DbaAvailabilityGroup -SqlInstance $SeedInstance -AvailabilityGroup $AvailabilityGroup -EnableException
    if (-not $ag) {
        throw "Availability group '$AvailabilityGroup' was not found on '$SeedInstance'."
    }

    $replicas = $ag | Get-DbaAgReplica -EnableException | Select-Object Name, Role
    if (-not $replicas) {
        throw "No replicas were returned for Availability Group '$AvailabilityGroup'."
    }

    $targets = @(
        foreach ($replica in $replicas) {
            if ([string]::IsNullOrWhiteSpace($replica.Name)) { continue }
            if ($replica.Role -match 'Secondary') {
                if ($replica.Name -match ',\d+$') {
                    $replica.Name
                }
                else {
                    "{0},{1}" -f $replica.Name, $SecondaryPort
                }
            }
            else {
                $replica.Name
            }
        }
    ) | Sort-Object -Unique

    if (-not $targets -or $targets.Count -eq 0) {
        throw "No replica targets could be resolved for AG '$AvailabilityGroup'."
    }

    Write-Verbose ("Replica targets: " + ($targets -join ", "))

    $includePatterns = @(
        'transition(ed)? to the primary role',
        'transition(ed)? to the resolving role',
        'lease timeout',
        'lease expired',
        'health check timeout',
        'sp_server_diagnostics',
        'RESOLVING',
        'PRIMARY_PENDING',
        'PRIMARY_NORMAL'
    )

    $excludePatterns = @(
        '\bBACKUP DATABASE\b',
        '\bBACKUP LOG\b',
        'database was backed up',
        'log was backed up',
        'log backup',
        'backup of database',
        'backup database'
    )

    $patterns = [ordered]@{
        'Failover / role transition' = @(
            'transition(ed)? to the primary role',
            'transition(ed)? to the resolving role',
            'state of the local availability replica',
            'PRIMARY_NORMAL',
            'PRIMARY_PENDING',
            'RESOLVING'
        )
        'Lease timeout' = @(
            'lease timeout',
            'lease expired',
            'lease mechanism'
        )
        'Health check timeout' = @(
            'health check timeout',
            'sp_server_diagnostics',
            'diagnostics heartbeat'
        )
        'Connectivity / endpoint issue' = @(
            'endpoint',
            'connection timeout',
            'timeout occurred while waiting',
            'not synchronizing'
        )
    }

    $allEvents = New-Object System.Collections.Generic.List[object]
    $skippedReplicas = New-Object System.Collections.Generic.List[object]

    foreach ($instance in $targets) {
        Write-Verbose "Searching error log on [$instance]"

        try {
            $rows = Get-DbaErrorLog -SqlInstance $instance -After $StartTime -Before $EndTime -EnableException |
                Where-Object {
                    $text = $_.Text
                    $matchesInclude = Test-AnyPatternMatch -Text $text -Patterns $includePatterns
                    $matchesExclude = Test-AnyPatternMatch -Text $text -Patterns $excludePatterns
                    $isAgRelated =
                        $text -match [regex]::Escape($AvailabilityGroup) -or
                        $text -match 'availability group|availability replica|lease timeout|health check|RESOLVING|PRIMARY_PENDING|PRIMARY_NORMAL'
                    $isAgRelated -and $matchesInclude -and (-not $matchesExclude)
                }

            foreach ($row in $rows) {
                $text = $row.Text
                $category = 'Other AG-related event'
                $matched = $false

                foreach ($key in $patterns.Keys) {
                    foreach ($pattern in $patterns[$key]) {
                        if ($text -match $pattern) {
                            $category = $key
                            $matched = $true
                            break
                        }
                    }
                    if ($matched) { break }
                }

                $phase = Get-AgEventPhase -Category $category -Message $text

                [void]$allEvents.Add([pscustomobject]@{
                    Instance          = $instance
                    LogTime           = $row.LogDate
                    AvailabilityGroup = $AvailabilityGroup
                    Category          = $category
                    Phase             = $phase
                    Source            = $row.Source
                    Message           = ($text -replace '\s+', ' ').Trim()
                })
            }
        }
        catch {
            Write-Verbose "Skipping [$instance] because log access failed: $($_.Exception.Message)"
            [void]$skippedReplicas.Add([pscustomobject]@{
                Name   = $instance
                Reason = $_.Exception.Message
            })
            continue
        }
    }

    $sortedEvents = @($allEvents | Sort-Object LogTime)
    $roleTransitions = @(Get-AgRoleTransitions -Events $sortedEvents)
    $primaryChain = Get-AgPrimaryChain -RoleTransitions $roleTransitions
    $incidents = @(Get-AgIncidentGroups -Events $sortedEvents -RoleTransitions $roleTransitions -GapMinutes $IncidentGapMinutes)

    $categoryCounts = @(
        $sortedEvents |
            Group-Object Category |
            Sort-Object Count -Descending |
            ForEach-Object {
                [pscustomobject]@{
                    Category = $_.Name
                    Count    = $_.Count
                }
            }
    )

    $skippedReplicaText = @(
        $skippedReplicas | ForEach-Object { "{0} ({1})" -f $_.Name, $_.Reason }
    )

    $summaryText = Convert-ToAgNarrative `
        -Events $sortedEvents `
        -AvailabilityGroup $AvailabilityGroup `
        -StartTime $StartTime `
        -EndTime $EndTime `
        -Targets $targets `
        -Incidents $incidents `
        -PrimaryTimeline $primaryChain.Timeline `
        -PrimaryChainText $primaryChain.ChainText `
        -SkippedReplicas $skippedReplicaText

    $result = [pscustomobject]@{}
    $result | Add-Member -NotePropertyName AvailabilityGroup -NotePropertyValue ([string]$AvailabilityGroup)
    $result | Add-Member -NotePropertyName SeedInstance -NotePropertyValue ([string]$SeedInstance)
    $result | Add-Member -NotePropertyName StartTime -NotePropertyValue ([datetime]$StartTime)
    $result | Add-Member -NotePropertyName EndTime -NotePropertyValue ([datetime]$EndTime)
    $result | Add-Member -NotePropertyName ReplicaTargets -NotePropertyValue @($targets)
    $result | Add-Member -NotePropertyName SkippedReplicas -NotePropertyValue @($skippedReplicaText)
    $result | Add-Member -NotePropertyName EventCount -NotePropertyValue ([int]$sortedEvents.Count)
    $result | Add-Member -NotePropertyName CategoryCounts -NotePropertyValue @($categoryCounts)
    $result | Add-Member -NotePropertyName RoleTransitions -NotePropertyValue @($roleTransitions)
    $result | Add-Member -NotePropertyName PrimaryTimeline -NotePropertyValue @($primaryChain.Timeline)
    $result | Add-Member -NotePropertyName PrimaryChainText -NotePropertyValue ([string]$primaryChain.ChainText)
    $result | Add-Member -NotePropertyName InitialPrimary -NotePropertyValue $primaryChain.InitialPrimary
    $result | Add-Member -NotePropertyName FinalPrimary -NotePropertyValue $primaryChain.FinalPrimary
    $result | Add-Member -NotePropertyName IncidentCount -NotePropertyValue ([int]$incidents.Count)
    $result | Add-Member -NotePropertyName Incidents -NotePropertyValue @($incidents)
    $result | Add-Member -NotePropertyName SummaryText -NotePropertyValue ([string]$summaryText)
    $result | Add-Member -NotePropertyName Events -NotePropertyValue @($sortedEvents)

    if ($null -ne $HtmlPath -or $OpenHtml) {
        if ([string]::IsNullOrWhiteSpace($HtmlPath)) {
            $timestamp = Get-Date -Format 'yyyyMMddHHmmss'
            $HtmlPath = Join-Path $env:TEMP ("{0}_AG_Report_{1}.html" -f $AvailabilityGroup, $timestamp)
        }

        try {
            Export-AgFailureHtml -Report $result -Path $HtmlPath | Out-Null
            Write-Verbose "HTML report written to $HtmlPath"

            if ($OpenHtml) {
                Start-Process -FilePath $HtmlPath | Out-Null
            }
        }
        catch {
            Write-Warning "Failed to export or open HTML report: $($_.Exception.Message)"
        }
    }

    if ($ShowEvents -and $sortedEvents.Count -gt 0) {
        $sortedEvents |
            Select-Object LogTime, Instance, Phase, Category, Source, Message |
            Format-Table -AutoSize |
            Out-Host
    }

    return $result
}
