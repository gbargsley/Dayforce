<#
.SYNOPSIS
  Compare tables and indexes between source and destination SQL Server databases using dbatools.

.DESCRIPTION
  - Requires the dbatools PowerShell module.
  - Produces:
      * TableDifferences.csv  -> tables only in source, only in dest, or in both
      * IndexDifferences.csv  -> per-table index diffs (source-only, dest-only, same-name/different-definition)
      * Summary.json          -> numeric summary: table counts, index counts, difference counts
  - Normalizes index signature (key cols w/order, included cols, uniqueness, type, filter, compression)
#>

param(
    [Parameter(Mandatory=$true)] [string] $SourceInstance,
    [Parameter(Mandatory=$true)] [string] $SourceDatabase,
    [Parameter(Mandatory=$true)] [string] $DestInstance,
    [Parameter(Mandatory=$true)] [string] $DestDatabase,
    [string] $OutputFolder = ".\CompareOutput",
    [switch] $InstallDbatoolsIfMissing
)

# --- Setup / dependencies ---
if (-not (Get-Module -ListAvailable -Name dbatools)) {
    if ($InstallDbatoolsIfMissing) {
        Write-Host "dbatools not found. Installing (CurrentUser)..." -ForegroundColor Yellow
        Install-Module -Name dbatools -Scope CurrentUser -Force -AllowClobber
    } else {
        Throw "dbatools module not installed. Either install it or rerun with -InstallDbatoolsIfMissing."
    }
}
Import-Module dbatools -ErrorAction Stop

# Create output folder
$OutputFolder = (Resolve-Path -Path $OutputFolder).Path
New-Item -Path $OutputFolder -ItemType Directory -Force | Out-Null

# Helper: normalized full table name
function FullName([string]$Schema, [string]$Table) { return "$($Schema).$($Table)" }

# Helper: produce a deterministic signature for an index object from Get-DbaHelpIndex
function Get-IndexSignature {
    param($idx)

    # idx usually contains: IndexType, IsUnique, IsPrimaryKey, KeyColumns (string or array), IncludeColumns, FilterDefinition, DataCompression
    # Normalize key column ordering and formatting
    $keyCols = @()
    if ($idx.KeyColumns) {
        # KeyColumns may be a string like "Col1 ASC, Col2 DESC" or array; normalize spacing & case
        if ($idx.KeyColumns -is [string]) {
            $keyCols = $idx.KeyColumns -split ',' | ForEach-Object {
                (($_ -replace '\s+',' ')).Trim()
}
        } else {
            $keyCols = $idx.KeyColumns
        }
    }
    $keyColsNormalized = ($keyCols | ForEach-Object { $_.Trim() }) -join '|'

    $includeCols = @()
    if ($idx.IncludeColumns) {
        if ($idx.IncludeColumns -is [string]) {
            $includeCols = $idx.IncludeColumns -split ',' | ForEach-Object { $_.Trim() }
        } else {
            $includeCols = $idx.IncludeColumns
        }
    }
    $includeColsNormalized = ($includeCols | Sort-Object | ForEach-Object { $_ }) -join '|'

    $isUnique = [string]($idx.IsUnique -eq $true)
    $isPK     = [string]($idx.IsPrimaryKey -eq $true)
    $type     = ($idx.IndexType -as [string]) -replace '\s+',' '
    $filter   = if ($idx.FilterDefinition) { ($idx.FilterDefinition -replace '\s+',' ') } else { '' }
    $compression = if ($idx.DataCompression) { $idx.DataCompression } else { '' }

    # Signature string
    $sig = "Name:$($idx.IndexName);Type:$type;Unique:$isUnique;PK:$isPK;Keys:$keyColsNormalized;Includes:$includeColsNormalized;Filter:$filter;Compression:$compression"
    return $sig
}

# --- Get tables ---
Write-Host "Loading tables from source..." -ForegroundColor Cyan
$srcTablesRaw = Get-DbaDbTable -SqlInstance $SourceInstance -Database $SourceDatabase
Write-Host "Loading tables from destination..." -ForegroundColor Cyan
$dstTablesRaw = Get-DbaDbTable -SqlInstance $DestInstance -Database $DestDatabase

# Normalize table collections (Schema and Name properties)
$srcTables = $srcTablesRaw | ForEach-Object {
    [PSCustomObject]@{
        Schema = $_.Schema
        Table  = $_.Name
        Full   = FullName $_.Schema $_.Name
    }
}
$dstTables = $dstTablesRaw | ForEach-Object {
    [PSCustomObject]@{
        Schema = $_.Schema
        Table  = $_.Name
        Full   = FullName $_.Schema $_.Name
    }
}

$srcTableSet = $srcTables.Full | Sort-Object
$dstTableSet = $dstTables.Full | Sort-Object

# Table diffs
$tablesOnlyInSource = $srcTableSet | Where-Object { $_ -notin $dstTableSet }
$tablesOnlyInDest   = $dstTableSet | Where-Object { $_ -notin $srcTableSet }
$tablesInBoth       = $srcTableSet | Where-Object { $_ -in $dstTableSet }

# Persist table diff CSV
$tableDiffRows = @()
foreach ($t in $tablesOnlyInSource) { $tableDiffRows += [PSCustomObject]@{ Table = $t; Location = 'SourceOnly' } }
foreach ($t in $tablesOnlyInDest)    { $tableDiffRows += [PSCustomObject]@{ Table = $t; Location = 'DestOnly' } }
foreach ($t in $tablesInBoth)        { $tableDiffRows += [PSCustomObject]@{ Table = $t; Location = 'Both' } }
$tableDiffFile = Join-Path $OutputFolder 'TableDifferences.csv'
$tableDiffRows | Sort-Object Location, Table | Export-Csv -Path $tableDiffFile -NoTypeInformation -Force
Write-Host "Table diff saved to: $tableDiffFile"

# --- Compare indexes for tables present in both ---
$indexDiffRows = @()
$totalIndexesSource = 0
$totalIndexesDest = 0
$totalIndexDifferences = 0

# We'll cache indexes per table for both sides to avoid repeated calls
foreach ($table in $tablesInBoth) {
    $schema, $tbl = $table.Split('.',2)

    # Fetch indexes
    $srcIdxRaw = Get-DbaHelpIndex -SqlInstance $SourceInstance -Database $SourceDatabase -ObjectName $table -IncludeStats:$false -ErrorAction Stop
    $dstIdxRaw = Get-DbaHelpIndex -SqlInstance $DestInstance -Database $DestDatabase -ObjectName $table -IncludeStats:$false -ErrorAction Stop

    # Standardize into objects keyed by IndexName and by Signature
    $srcIdx = @()
    foreach ($i in $srcIdxRaw) {
        $sig = Get-IndexSignature -idx $i
        $srcIdx += [PSCustomObject]@{
            IndexName = $i.IndexName
            Signature = $sig
            Raw       = $i
        }
    }
    $dstIdx = @()
    foreach ($i in $dstIdxRaw) {
        $sig = Get-IndexSignature -idx $i
        $dstIdx += [PSCustomObject]@{
            IndexName = $i.IndexName
            Signature = $sig
            Raw       = $i
        }
    }

    $totalIndexesSource += $srcIdx.Count
    $totalIndexesDest   += $dstIdx.Count

    # Compare by index name and by signature
    $srcNames = $srcIdx.IndexName
    $dstNames = $dstIdx.IndexName

    $namesOnlyInSource = $srcNames | Where-Object { $_ -notin $dstNames }
    $namesOnlyInDest   = $dstNames | Where-Object { $_ -notin $srcNames }
    $namesInBoth       = $srcNames | Where-Object { $_ -in $dstNames }

    # Report name-only diffs
    foreach ($n in $namesOnlyInSource) {
        $row = [PSCustomObject]@{
            Table = $table; IndexName = $n; Side = 'SourceOnly'; Detail = ($srcIdx | Where-Object IndexName -eq $n | Select-Object -ExpandProperty Signature)
        }
        $indexDiffRows += $row
        $totalIndexDifferences++
    }
    foreach ($n in $namesOnlyInDest) {
        $row = [PSCustomObject]@{
            Table = $table; IndexName = $n; Side = 'DestOnly'; Detail = ($dstIdx | Where-Object IndexName -eq $n | Select-Object -ExpandProperty Signature)
        }
        $indexDiffRows += $row
        $totalIndexDifferences++
    }

    # For names that exist in both, check if their signatures match
    foreach ($n in $namesInBoth) {
        $sSig = ($srcIdx | Where-Object IndexName -eq $n).Signature
        $dSig = ($dstIdx | Where-Object IndexName -eq $n).Signature
        if ($sSig -ne $dSig) {
            $row = [PSCustomObject]@{
                Table = $table; IndexName = $n; Side = 'NameMatch_ButDefinitionDiff'; SourceSignature = $sSig; DestSignature = $dSig
            }
            $indexDiffRows += $row
            $totalIndexDifferences++
        }
    }

    # Additional check: same signature but different names (index exists on both sides by definition but names differ)
    $srcSignatures = $srcIdx.Signature
    $dstSignatures = $dstIdx.Signature

    # find signatures in src not in dest
    $signOnlyInSource = $srcSignatures | Where-Object { $_ -notin $dstSignatures }
    $signOnlyInDest   = $dstSignatures | Where-Object { $_ -notin $srcSignatures }

    foreach ($sig in $signOnlyInSource) {
        # If signature is not represented on dest, it's already covered by name-only diff; but this helps catch renamed indexes
        $srcNamesForSig = ($srcIdx | Where-Object Signature -eq $sig).IndexName -join ','
        $row = [PSCustomObject]@{
            Table = $table; IndexName = $srcNamesForSig; Side = 'SourceDefOnlyBySignature'; Detail = $sig
        }
        $indexDiffRows += $row
        # note: careful not to double count - only increment if this signature truly has no match by signature in dest
        if (($dstIdx | Where-Object Signature -eq $sig).Count -eq 0) { $totalIndexDifferences++ }
    }
    foreach ($sig in $signOnlyInDest) {
        $dstNamesForSig = ($dstIdx | Where-Object Signature -eq $sig).IndexName -join ','
        $row = [PSCustomObject]@{
            Table = $table; IndexName = $dstNamesForSig; Side = 'DestDefOnlyBySignature'; Detail = $sig
        }
        $indexDiffRows += $row
        if (($srcIdx | Where-Object Signature -eq $sig).Count -eq 0) { $totalIndexDifferences++ }
    }
}

# Save index diff CSV
$indexDiffFile = Join-Path $OutputFolder 'IndexDifferences.csv'
$indexDiffRows | Sort-Object Table, IndexName | Export-Csv -Path $indexDiffFile -NoTypeInformation -Force
Write-Host "Index diffs saved to: $indexDiffFile"

# --- Summary ---
$summary = [PSCustomObject]@{
    SourceInstance        = $SourceInstance
    SourceDatabase        = $SourceDatabase
    DestInstance          = $DestInstance
    DestDatabase          = $DestDatabase
    SourceTableCount      = $srcTableSet.Count
    DestTableCount        = $dstTableSet.Count
    TablesOnlyInSource    = $tablesOnlyInSource.Count
    TablesOnlyInDest      = $tablesOnlyInDest.Count
    TablesInBoth          = $tablesInBoth.Count
    SourceIndexCount      = $totalIndexesSource
    DestIndexCount        = $totalIndexesDest
    TotalIndexDifferences = $totalIndexDifferences
    GeneratedAt           = (Get-Date).ToString("s")
}

$summaryFile = Join-Path $OutputFolder 'Summary.json'
$summary | ConvertTo-Json -Depth 5 | Out-File -FilePath $summaryFile -Encoding utf8
Write-Host "Summary saved to: $summaryFile"

# Print console summary
"--- Summary ---"
"Source: $($SourceInstance)\$db = $SourceDatabase"
"Dest:   $($DestInstance)\$db = $DestDatabase"
"Tables: Source=$($summary.SourceTableCount)  Dest=$($summary.DestTableCount)  InBoth=$($summary.TablesInBoth)"
"Table diffs: SourceOnly=$($summary.TablesOnlyInSource)  DestOnly=$($summary.TablesOnlyInDest)"
"Indexes: Source=$($summary.SourceIndexCount)  Dest=$($summary.DestIndexCount)"
"Index differences found: $($summary.TotalIndexDifferences)"
"Outputs in $OutputFolder"

# Exit with code 0
return $summary
