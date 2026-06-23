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
        [datetime]$EndTime
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

    if ($StartTime -ge $EndTime) {
        throw "StartTime must be earlier than EndTime."
    }

    $ag = Get-DbaAvailabilityGroup -SqlInstance $SeedInstance -AvailabilityGroup $AvailabilityGroup -EnableException
    if (-not $ag) {
        throw "Availability group '$AvailabilityGroup' was not found on '$SeedInstance'."
    }

    $replicas = $ag | Get-DbaAgReplica -EnableException |
        Select-Object Name, ComputerName, InstanceName, Role

    Write-Verbose ("Replicas found: " + (($replicas | ForEach-Object {
        "{0} [{1}] {2}\{3}" -f $_.Name, $_.Role, $_.ComputerName, $_.InstanceName
    }) -join " | "))

    $targets = $replicas | ForEach-Object {
        if ([string]::IsNullOrWhiteSpace($_.Name)) {
            return
        }

        if ([string]::IsNullOrWhiteSpace($_.Name) -or $_.InstanceName -eq 'MSSQLSERVER') {
            $_.Name
        }
        else {
            "$($_.Name)\$($_.InstanceName)"
        }
    } | Where-Object { $_ } | Sort-Object -Unique

    Write-Verbose ("Resolved targets: " + ($targets -join ", "))

    if (-not $targets) {
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

    foreach ($instance in $targets) {
        Write-Verbose "Searching error log on [$instance]"

        Get-DbaErrorLog -SqlInstance $instance -After $StartTime -Before $EndTime -EnableException |
            Where-Object {
                $text = $_.Text

                $matchesInclude = Test-AnyPatternMatch -Text $text -Patterns $includePatterns
                $matchesExclude = Test-AnyPatternMatch -Text $text -Patterns $excludePatterns

                $isAgRelated =
                    $text -match [regex]::Escape($AvailabilityGroup) -or
                    $text -match 'availability group|availability replica|lease timeout|health check|RESOLVING|PRIMARY_PENDING|PRIMARY_NORMAL'

                $isAgRelated -and $matchesInclude -and (-not $matchesExclude)
            } |
            ForEach-Object {
                $text = $_.Text
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

                [pscustomobject]@{
                    Instance          = $instance
                    LogTime           = $_.LogDate
                    AvailabilityGroup = $AvailabilityGroup
                    Category          = $category
                    Source            = $_.Source
                    Message           = ($text -replace '\s+', ' ').Trim()
                }
            }
    }
}