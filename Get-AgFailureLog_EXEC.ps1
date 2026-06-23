. .\Get-AgFailureLog2.ps1

$results = Invoke-DbaAgErrorLogReview `
    -SqlInstance 'azg1dfcsql83dnn.custadds.com' `
    -AvailabilityGroup 'Prod_AG' `
    -StartTime (Get-Date '2026-04-01 00:00:00') `
    -EndTime   (Get-Date '2026-04-01 23:59:59') `
    -Verbose

$results | Sort-Object LogTime | Format-Table -AutoSize


##Get-DbaAgReplica -SqlInstance 'azg1dfcsql83d,31433' | Select-Object Name, ComputerName, InstanceName, SqlInstance

##Get-DbaAvailabilityGroup -SqlInstance 'azg1dfcsql83dnn' -AvailabilityGroup 'Prod_AG'


$result = Invoke-DbaAgErrorLogReview `
    -SqlInstance 'azg1dfcsql83dnn.custadds.com' `
    -AvailabilityGroup 'Prod_AG' `
    -StartTime (Get-Date '2026-04-01 00:00:00') `
    -EndTime   (Get-Date '2026-04-01 23:59:59') `
    -Verbose

$result.Events | Sort-Object LogTime | Format-Table -AutoSize
$result.SummaryText



. .\Get-AgFailureLog7.ps1
$result = Invoke-DbaAgErrorLogReview `
    -SqlInstance 'azg1gussql7dnn.custadds.com' `
    -AvailabilityGroup 'Prod_AG' `
    -StartTime (Get-Date '2026-06-15 00:00:00') `
    -EndTime   (Get-Date '2026-06-15 23:59:59') `
    -HtmlPath 'F:\Temp\GB\Prod_AG_Report_azg1gussql7dnn.html' `
    -OpenHtml -Verbose