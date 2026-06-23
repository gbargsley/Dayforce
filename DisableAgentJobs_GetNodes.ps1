# Requires: dbatools
# Install-Module dbatools -Scope CurrentUser

param(
    [Parameter(Mandatory)]
    [string[]]$AgListeners,

    [Parameter()]
    [string]$JobNamePattern = 'z_DBA_Kill_EmployeeAttributes_Job_Temporary',

    [Parameter()]
    [pscredential]$SqlCredential
)

$results = New-Object System.Collections.Generic.List[object]
$seenReplicas = @{}

foreach ($listener in $AgListeners) {
    try {
        $agList = if ($SqlCredential) {
            Get-DbaAvailabilityGroup -SqlInstance $listener -SqlCredential $SqlCredential
        }
        else {
            Get-DbaAvailabilityGroup -SqlInstance $listener
        }
    }
    catch {
        $results.Add([pscustomobject]@{
            Listener           = $listener
            AvailabilityGroup  = $null
            Replica            = $null
            SqlInstance        = $null
            JobName            = $null
            Action             = 'Failed'
            BeforeEnabled      = $null
            AfterEnabled       = $null
            Message            = "Failed to read AG info: $($_.Exception.Message)"
        })
        continue
    }

    foreach ($ag in $agList) {
        try {
            $replicas = $ag | Get-DbaAgReplica
        }
        catch {
            $results.Add([pscustomobject]@{
                Listener           = $listener
                AvailabilityGroup  = $ag.Name
                Replica            = $null
                SqlInstance        = $null
                JobName            = $null
                Action             = 'Failed'
                BeforeEnabled      = $null
                AfterEnabled       = $null
                Message            = "Failed to read replicas: $($_.Exception.Message)"
            })
            continue
        }

        foreach ($replica in $replicas) {
            $targetInstance = "$($replica.SqlInstance),31433"

            if ($seenReplicas.ContainsKey($targetInstance)) {
                continue
            }
            $seenReplicas[$targetInstance] = $true

            try {
                if ($SqlCredential) {
                    $jobs = Get-DbaAgentJob -SqlInstance $targetInstance -SqlCredential $SqlCredential | Where-Object { $_.Name -like "*$JobNamePattern*" }
                }
                else {
                    $jobs = Get-DbaAgentJob -SqlInstance $targetInstance | Where-Object { $_.Name -like "*$JobNamePattern*" }
                }
            }
            catch {
                $results.Add([pscustomobject]@{
                    Listener           = $listener
                    AvailabilityGroup  = $ag.Name
                    Replica            = $replica.Name
                    SqlInstance        = $targetInstance
                    JobName            = $null
                    Action             = 'Failed'
                    BeforeEnabled      = $null
                    AfterEnabled       = $null
                    Message            = "Failed to read jobs: $($_.Exception.Message)"
                })
                continue
            }

            if (-not $jobs) {
                $results.Add([pscustomobject]@{
                    Listener           = $listener
                    AvailabilityGroup  = $ag.Name
                    Replica            = $replica.Name
                    SqlInstance        = $targetInstance
                    JobName            = $null
                    Action             = 'NotFound'
                    BeforeEnabled      = $null
                    AfterEnabled       = $null
                    Message            = "No matching jobs found"
                })
                continue
            }

            foreach ($job in $jobs) {
                $before = [bool]$job.Enabled

                try {
                    if ($SqlCredential) {
                        Set-DbaAgentJob -SqlInstance $targetInstance -SqlCredential $SqlCredential -Job $job.Name -Disabled | Out-Null
                    }
                    else {
                        Set-DbaAgentJob -SqlInstance $targetInstance -Job $job.Name -Disabled | Out-Null
                    }

                    $after = $false
                    $action = if ($before) { 'Disabled' } else { 'AlreadyDisabled' }

                    $results.Add([pscustomobject]@{
                        Listener           = $listener
                        AvailabilityGroup  = $ag.Name
                        Replica            = $replica.Name
                        SqlInstance        = $targetInstance
                        JobName            = $job.Name
                        Action             = $action
                        BeforeEnabled      = $before
                        AfterEnabled       = $after
                        Message            = 'Success'
                    })
                }
                catch {
                    $results.Add([pscustomobject]@{
                        Listener           = $listener
                        AvailabilityGroup  = $ag.Name
                        Replica            = $replica.Name
                        SqlInstance        = $targetInstance
                        JobName            = $job.Name
                        Action             = 'Failed'
                        BeforeEnabled      = $before
                        AfterEnabled       = $null
                        Message            = $_.Exception.Message
                    })
                }
            }
        }
    }
}

# Formatted output
$results |
    Sort-Object Listener, AvailabilityGroup, Replica, JobName |
    Format-Table Listener, AvailabilityGroup, Replica, SqlInstance, JobName, Action, BeforeEnabled, AfterEnabled, Message -AutoSize