## Set subscription
Get-AzSubscription | Select-Object Name, Id, State  
Set-AzContext -SubscriptionId "4a86632f-9a69-4a3a-9db4-f3aaa65e062a"


## Query storage account 
$storageAccountName = "app141dfhubn"
$containers = @("resources-eur2")
$thresholdBytes = 35MB

$ctx = New-AzStorageContext -StorageAccountName $storageAccountName -UseConnectedAccount

$results = foreach ($container in $containers) {
    Get-AzStorageBlob -Container $container -Context $ctx |
        Where-Object { $_.Length -gt $thresholdBytes } |
        Select-Object @{Name='Container';Expression={$container}}, Name, Length, LastModified
}

$results | Sort-Object Container, Length -Descending | Format-Table -AutoSize


## Save results to csv
$results | Sort-Object Container, Length -Descending | Export-Csv -Path "./large-blobs4.csv" -NoTypeInformation