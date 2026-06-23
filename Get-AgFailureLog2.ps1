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
        [switch]$ShowEvents
    )

    function Test-AnyPatternMatch {
        param(
            [string]$Text,
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
        param(
            [string]$Category,
            [string]$Message
        )

        $combined = "$Category $Message"

        switch -Regex ($combined) {
            'Lease timeout|lease expired|lease mechanism' {
                return 'Failure / lease loss'
            }
            'Health check timeout|sp_server_diagnostics|diagnostics heartbeat' {
                return 'Detection / health probe failure'
            }
            'Failover / role transition|transition(ed)? to the primary role|transition(ed)? to the resolving role|PRIMARY_NORMAL|PRIMARY_PENDING|RESOLVING' {
                return 'Role transition'
            }
            'Connectivity / endpoint issue|endpoint|connection timeout|timeout occurred while waiting|not synchronizing' {
                return 'Connectivity problem'
            }
            default {
                return 'Other AG event'
            }
        }
    }

    function Convert-ToAgNarrative {
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

            [object[]]$SkippedReplicas = @()
        )

        if (-not $Events -or $Events.Count -eq 0) {
            $lines = @(
                "AG Incident Summary: $AvailabilityGroup"
                "Window: {0} to {1}" -f $StartTime.ToString('yyyy-MM-dd HH:mm:ss'), $EndTime.ToString('yyyy-MM-dd HH:mm:ss')
                "Replicas scanned: $($Targets.Count)"
                if ($SkippedReplicas -and $SkippedReplicas.Count -gt 0) {
                    "Skipped replicas: " + (($SkippedReplicas | ForEach-Object { "{0} ({1})" -f $_.Name, $_.Reason }) -join ', ')
                }
                else {
                    "Skipped replicas: none"
                }
                "Events found: 0"
                "Assessment: No AG-related failover or timeout events were found in the selected window."
            )

            return ($lines -join [Environment]::NewLine)
        }

        $ordered = $Events | Sort-Object LogTime
        $first = $ordered | Select-Object -First 1
        $last  = $ordered | Select-Object -Last 1

        $firstTimeout = $ordered | Where-Object {
            $_.Category -in 'Lease timeout','Health check timeout','Connectivity / endpoint issue'
        } | Select-Object -First 1

        $firstTransition = $ordered | Where-Object {
            $_.Category -eq 'Failover / role transition'
        } | Select-Object -First 1

        $replicasSeen = $ordered.Instance | Sort-Object -Unique
        $categoriesSeen = $ordered.Category | Sort-Object -Unique

        $topCounts = $ordered |
            Group-Object Category |
            Sort-Object Count -Descending |
            ForEach-Object { "{0}={1}" -f $_.Name, $_.Count }

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
        $lines.Add(("Replicas with events: {0}" -f ($replicasSeen -join ', '))) | Out-Null
        $lines.Add(("Categories seen: {0}" -f ($categoriesSeen -join ', '))) | Out-Null
        $lines.Add(("Category counts: {0}" -f ($topCounts -join '; '))) | Out-Null
        $lines.Add("") | Out-Null

        $lines.Add("Likely workflow:") | Out-Null
        if ($firstTimeout) {
            $lines.Add(("1. {0} on {1} - {2}" -f $firstTimeout.LogTime.ToString('yyyy-MM-dd HH:mm:ss'), $firstTimeout.Instance, $firstTimeout.Category)) | Out-Null
        }
        if ($firstTransition) {
            $lines.Add(("2. {0} on {1} - first role transition observed" -f $firstTransition.LogTime.ToString('yyyy-MM-dd HH:mm:ss'), $firstTransition.Instance)) | Out-Null
        }

        $primaryPending = $ordered | Where-Object { $_.Message -match 'PRIMARY_PENDING' } | Select-Object -First 1
        $primaryNormal   = $ordered | Where-Object { $_.Message -match 'PRIMARY_NORMAL' } | Select-Object -First 1
        $secondaryNormal = $ordered | Where-Object { $_.Message -match 'SECONDARY_NORMAL' } | Select-Object -First 1

        if ($primaryPending) {
            $lines.Add(("3. {0} on {1} - primary entered PRIMARY_PENDING" -f $primaryPending.LogTime.ToString('yyyy-MM-dd HH:mm:ss'), $primaryPending.Instance)) | Out-Null
        }
        if ($primaryNormal) {
            $lines.Add(("4. {0} on {1} - primary returned to PRIMARY_NORMAL" -f $primaryNormal.LogTime.ToString('yyyy-MM-dd HH:mm:ss'), $primaryNormal.Instance)) | Out-Null
        }
        if ($secondaryNormal) {
            $lines.Add(("5. {0} on {1} - secondary reached SECONDARY_NORMAL" -f $secondaryNormal.LogTime.ToString('yyyy-MM-dd HH:mm:ss'), $secondaryNormal.Instance)) | Out-Null
        }

        $assessment = "Assessment: Role transition behavior was observed."
        if ($firstTimeout -and $firstTimeout.Category -eq 'Lease timeout') {
            $assessment = "Assessment: The AG likely experienced a lease-related event that triggered failover or recovery."
        }
        elseif ($firstTimeout -and $firstTimeout.Category -eq 'Health check timeout') {
            $assessment = "Assessment: The AG likely experienced a health-check failure that triggered failover or recovery."
        }
        elseif ($firstTimeout -and $firstTimeout.Category -eq 'Connectivity / endpoint issue') {
            $assessment = "Assessment: Connectivity or endpoint instability may have contributed to the AG event."
        }

        $lines.Add("") | Out-Null
        $lines.Add($assessment) | Out-Null

        return ($lines -join [Environment]::NewLine)
    }
    if ($StartTime -ge $EndTime) {
        throw "StartTime must be earlier than EndTime."
    }

    $ag = Get-DbaAvailabilityGroup -SqlInstance $SeedInstance -AvailabilityGroup $AvailabilityGroup -EnableException
    if (-not $ag) {
        throw "Availability group '$AvailabilityGroup' was not found on '$SeedInstance'."
    }

    $replicas = $ag | Get-DbaAgReplica -EnableException |
        Select-Object Name, Role

    # Use the replica Name values, and append the secondary port you want to search.
    $targets = @(
        foreach ($r in $replicas) {
            if ([string]::IsNullOrWhiteSpace($r.Name)) {
                continue
            }

            if ($r.Role -match 'Secondary') {
                if ($r.Name -match ',\d+$') {
                    $r.Name
                }
                else {
                    "$($r.Name),31433"
                }
            }
            else {
                $r.Name
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

    $sortedEvents = $allEvents | Sort-Object LogTime

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

    $skippedForNarrative = if ($skippedReplicas.Count -gt 0) { $skippedReplicas } else { $null }

    $summaryText = Convert-ToAgNarrative `
        -Events $sortedEvents `
        -AvailabilityGroup $AvailabilityGroup `
        -StartTime $StartTime `
        -EndTime $EndTime `
        -Targets $targets `
        -SkippedReplicas $skippedForNarrative

    $summary = [pscustomobject]@{
        AvailabilityGroup = $AvailabilityGroup
        SeedInstance      = $SeedInstance
        StartTime         = $StartTime
        EndTime           = $EndTime
        ReplicaTargets    = $targets
        SkippedReplicas   = $skippedReplicas
        EventCount        = $sortedEvents.Count
        CategoryCounts    = $categoryCounts
        SummaryText       = $summaryText
        Events            = $sortedEvents
    }

    if ($ShowEvents) {
        $summary.Events | Sort-Object LogTime
    }
    else {
        $summary.SummaryText
    }
}