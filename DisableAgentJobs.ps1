# Ensure dbatools is available
# Install-Module dbatools -Scope CurrentUser

# Variables
$SqlInstance = "azm1lidsql02e,31433"   # e.g. "Server01\SQL2019"
$SearchString = "DefaultEmployeeProperties"

# Get matching SQL Agent jobs
$jobs = Get-DbaAgentJob -SqlInstance $SqlInstance |
    Where-Object { $_.Name -like "*$SearchString*" }

if (-not $jobs) {
    Write-Host "No jobs found containing '$SearchString' on $SqlInstance" -ForegroundColor Yellow
    return
}

# Disable the jobs
foreach ($job in $jobs) {
    try {
        Set-DbaAgentJob -SqlInstance $SqlInstance -Job $job.Name -Disabled -Confirm:$false
        Write-Host "Disabled job: $($job.Name)" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to disable job: $($job.Name). Error: $_" -ForegroundColor Red
    }
}
