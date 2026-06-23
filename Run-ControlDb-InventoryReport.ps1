<#
.SYNOPSIS
  Resolves a list of control databases to their hosting ControlServerName and runs two inventory queries per database.
  Produces both HTML and Excel output.

.PREREQS
  - dbatools
  - ImportExcel (optional, for XLSX output)

.NOTES
  Update $CentralRepositoryInstance to point at the SQL Server instance that hosts the DBAInternalDataAccess database.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$CentralRepositoryInstance = 'AZG1DBASQL011',

    [Parameter()]
    [string]$CentralRepositoryDatabase = 'DBAInternalDataAccess',

    [Parameter()]
    [string]$OutputFolder = (Join-Path $PSScriptRoot 'ControlDbReportOutput')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Dependencies ---
if (-not (Get-Module -ListAvailable -Name dbatools)) {
    throw 'dbatools is not installed. Install-Module dbatools -Scope CurrentUser'
}

$HasImportExcel = [bool](Get-Module -ListAvailable -Name ImportExcel)

Import-Module dbatools -ErrorAction Stop
if ($HasImportExcel) {
    Import-Module ImportExcel -ErrorAction Stop
}

# --- Inputs ---
$ControlDatabases = @(
    'apjdemocontrol',
    'canconfig261control',
    'canstage252control',
    'canstage261control',
    'cantrain261control',
    'emeademocontrol',
    'nademocontrol',
    'predemocontrol',
    'ptdemocontrol',
    'salestrainingdemocontrol',
    'uatcontrol',
    'upspayrollbocontrol',
    'upspayrollconfig2control',
    'upspayrollconfigcontrol',
    'upspayrollstage2control',
    'upspayrollstage3control',
    'upspayrollstagecontrol',
    'upspayrolltestcontrol',
    'upspayrolltraincontrol',
    'ustest251control',
    'ustest252control',
    'ustest261control',
    'uzsup252hcm1control',
    'uzsup252hcm2control',
    'uzsup252hcm3control',
    'uzsup261hcm1control',
    'uzsup261hcm2control',
    'uzsup261hcm3control'
)

# Queries to run against each control database
$SiteSettingQuery = @"
SELECT
    Name,
    Value
FROM dbo.SiteSetting WITH (NOLOCK)
WHERE Name LIKE '%purpose%'
   OR Name = 'BJE.PayrollCommittedTopic'
   OR Name = 'BJE.PayrollVoidTopic'
   OR Name = 'BJE.PayrollAggregatorCompletedTopic'
   OR Name = 'PayrollFileEntryImportTopic'
ORDER BY Name;
"@

$ExternalSystemQuery = @"
SELECT
    ExternalSystemName,
    ServiceUrl,
    UserName
FROM dbo.ExternalSystem WITH (NOLOCK)
WHERE ExternalSystemName LIKE 'DayforceIdentity%'
   OR ExternalSystemName LIKE 'PayrollFrontEndBridgeServiceAPI%'
   OR ExternalSystemName LIKE 'PayrollInfoServiceAPI-%'
   OR ExternalSystemName LIKE 'PayrollInfoService-%'
   OR ExternalSystemName LIKE 'PayrollServiceBaseUrl-%'
   OR ExternalSystemName LIKE 'PayrollVersionedServiceBaseUrl-%'
   OR ExternalSystemName LIKE 'PayrollHyperscaleKafkaServer%'
   OR ExternalSystemName LIKE 'Payroll-AdminService%'
   OR ExternalSystemName LIKE 'Payroll-DayforceIdentit%'
ORDER BY ExternalSystemName;
"@

function Get-ControlDbServerName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ControlDbName
    )

    $lookupQuery = @"
SELECT TOP (1)
    ControlDBName,
    ControlServerName,
    CollectedTimeStamp
FROM dbo.Vw_ClientDBInfo_PreProd
WHERE ControlDBName = '$ControlDbName'
  AND CAST(CollectedTimeStamp AS date) = CAST(GETDATE() AS date)
ORDER BY CollectedTimeStamp DESC;
"@

    $row = Invoke-DbaQuery -SqlInstance $CentralRepositoryInstance -Database $CentralRepositoryDatabase -Query $lookupQuery

    if (-not $row) {
        return $null
    }

    if ($row.PSObject.Properties.Name -contains 'ControlServerName' -and $row.ControlServerName) {
        return [string]$row.ControlServerName
    }

    $fallbackProps = @('ServerName', 'SQLServerName', 'InstanceName', 'SqlInstance', 'Server', 'ComputerName')
    foreach ($prop in $fallbackProps) {
        if ($row.PSObject.Properties.Name -contains $prop -and $row.$prop) {
            return [string]$row.$prop
        }
    }

    $bestMatch = $row.PSObject.Properties |
        Where-Object { $_.Name -match 'server|instance|sql' -and $_.Value } |
        Select-Object -First 1

    if ($bestMatch) {
        return [string]$bestMatch.Value
    }

    return $null
}

function Invoke-InventoryQuery {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SqlInstance,

        [Parameter(Mandatory)]
        [string]$Database,

        [Parameter(Mandatory)]
        [string]$Query
    )

    Invoke-DbaQuery -SqlInstance $SqlInstance -Database $Database -Query $Query
}

# --- Main ---
New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
$RunStamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$HtmlPath = Join-Path $OutputFolder "ControlDbInventory_$RunStamp.html"
$XlsxPath = Join-Path $OutputFolder "ControlDbInventory_$RunStamp.xlsx"

$summary = New-Object System.Collections.Generic.List[object]
$siteSettingAll = New-Object System.Collections.Generic.List[object]
$externalSystemAll = New-Object System.Collections.Generic.List[object]
$detailBlocks = New-Object System.Collections.Generic.List[string]

foreach ($controlDb in $ControlDatabases) {
    Write-Host "Processing $controlDb ..." -ForegroundColor Cyan

    $serverName = $null
    try {
        $serverName = Get-ControlDbServerName -ControlDbName $controlDb

        if (-not $serverName) {
            Write-Host ("[{0}] No ControlServerName found for '{1}'" -f (Get-Date -Format 'HH:mm:ss'), $controlDb) -ForegroundColor Yellow

            $summary.Add([pscustomobject]@{
                ControlDBName      = $controlDb
                ControlServerName  = $null
                Status             = 'Lookup failed'
                SiteSettingRows    = $null
                ExternalSystemRows = $null
                Error              = 'No matching row found in Vw_ClientDBInfo_PreProd for today.'
            })
            continue
        }

        Write-Host ("[{0}] ControlDB '{1}' resolved to ControlServerName '{2}'" -f (Get-Date -Format 'HH:mm:ss'), $controlDb, $serverName) -ForegroundColor Cyan
        Write-Host ("[{0}] Attempting queries on '{1}' for database '{2}'" -f (Get-Date -Format 'HH:mm:ss'), $serverName, $controlDb) -ForegroundColor DarkCyan

        $siteSettingRows = @(Invoke-InventoryQuery -SqlInstance $serverName -Database $controlDb -Query $SiteSettingQuery)
        $externalSystemRows = @(Invoke-InventoryQuery -SqlInstance $serverName -Database $controlDb -Query $ExternalSystemQuery)

        foreach ($r in $siteSettingRows) {
            $siteSettingAll.Add([pscustomobject]@{
                ControlDBName      = $controlDb
                ControlServerName  = $serverName
                Name               = $r.Name
                Value              = $r.Value
            })
        }

        foreach ($r in $externalSystemRows) {
            $externalSystemAll.Add([pscustomobject]@{
                ControlDBName      = $controlDb
                ControlServerName  = $serverName
                ExternalSystemName = $r.ExternalSystemName
                ServiceUrl         = $r.ServiceUrl
                UserName           = $r.UserName
            })
        }

        $summary.Add([pscustomobject]@{
            ControlDBName      = $controlDb
            ControlServerName  = $serverName
            Status             = 'Success'
            SiteSettingRows    = $siteSettingRows.Count
            ExternalSystemRows = $externalSystemRows.Count
            Error              = $null
        })

        $ssHtml = if ($siteSettingRows.Count -gt 0) {
            $siteSettingRows | Select-Object Name, Value | ConvertTo-Html -Fragment -PreContent '<h3>SiteSetting</h3>'
        }
        else {
            '<p>No SiteSetting rows returned.</p>'
        }

        $esHtml = if ($externalSystemRows.Count -gt 0) {
            $externalSystemRows | Select-Object ExternalSystemName, ServiceUrl, UserName | ConvertTo-Html -Fragment -PreContent '<h3>ExternalSystem</h3>'
        }
        else {
            '<p>No ExternalSystem rows returned.</p>'
        }

        $detailBlocks.Add(@"
<section>
  <h2>$controlDb</h2>
  <p><strong>ControlServerName:</strong> $serverName</p>
  $ssHtml
  $esHtml
</section>
"@)
    }
    catch {
        Write-Host ("[{0}] Failed for '{1}' on '{2}': {3}" -f (Get-Date -Format 'HH:mm:ss'), $controlDb, $serverName, $_.Exception.Message) -ForegroundColor Red

        $summary.Add([pscustomobject]@{
            ControlDBName      = $controlDb
            ControlServerName  = $serverName
            Status             = 'Failed'
            SiteSettingRows    = $null
            ExternalSystemRows = $null
            Error              = $_.Exception.Message
        })
    }
}

# --- HTML output ---
$summaryHtml = $summary |
    Select-Object ControlDBName, ControlServerName, Status, SiteSettingRows, ExternalSystemRows, Error |
    ConvertTo-Html -Fragment -PreContent '<h2>Summary</h2>'

$html = @"
<!DOCTYPE html>
<html>
<head>
<meta charset='utf-8' />
<title>Control DB Inventory Report</title>
<style>
    body { font-family: Segoe UI, Arial, sans-serif; margin: 24px; color: #1f1f1f; }
    h1, h2, h3 { margin-bottom: 0.35em; }
    section { margin: 28px 0 40px 0; padding: 18px; border: 1px solid #d9d9d9; border-radius: 8px; background: #fafafa; }
    table { border-collapse: collapse; width: 100%; margin: 10px 0 18px 0; }
    th, td { border: 1px solid #d0d0d0; padding: 8px 10px; text-align: left; vertical-align: top; }
    th { background: #f2f5f7; }
    tr:nth-child(even) td { background: #fcfcfc; }
    .meta { color: #555; margin-bottom: 18px; }
</style>
</head>
<body>
<h1>Control DB Inventory Report</h1>
<p class='meta'>Generated: $(Get-Date) | Central repository: $CentralRepositoryInstance / $CentralRepositoryDatabase</p>
$summaryHtml
$($detailBlocks -join "`r`n")
</body>
</html>
"@

Set-Content -Path $HtmlPath -Value $html -Encoding UTF8

# --- Excel output ---
if ($HasImportExcel) {
    $summary | Export-Excel -Path $XlsxPath -WorksheetName 'Summary' -AutoSize -FreezeTopRow -BoldTopRow -ClearSheet

    $siteSettingAll |
        Export-Excel -Path $XlsxPath -WorksheetName 'SiteSetting_All' -AutoSize -FreezeTopRow -BoldTopRow -Append

    $externalSystemAll |
        Export-Excel -Path $XlsxPath -WorksheetName 'ExternalSystem_All' -AutoSize -FreezeTopRow -BoldTopRow -Append
}

Write-Host ""
Write-Host 'Report generated:' -ForegroundColor Green
Write-Host "HTML: $HtmlPath"
if ($HasImportExcel) {
    Write-Host "XLSX: $XlsxPath"
}
else {
    Write-Host 'XLSX was skipped because ImportExcel is not installed.' -ForegroundColor Yellow
}
