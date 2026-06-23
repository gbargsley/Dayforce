<#
.SYNOPSIS
  Checks whether AdminDB compatibility level matches the SQL Server major version,
  logs non-OK results to an inventory table, and optionally auto-fixes mismatches.

.DESCRIPTION
  - Reads SQL instances from a text file (one per line).
  - Sanitizes input (BOM/whitespace), ignores comments (# even with leading whitespace).
  - Normalizes host,port to tcp:host,port for dbatools/SMO consistency.
  - Connects using dbatools, determines:
      * SQL major version
      * Expected compat level for that major version
      * Actual AdminDB compatibility level (or missing DB)
  - Collects non-OK rows (Mismatch / DatabaseMissing / UnknownExpected / ConnectionOrQueryFailed)
  - Writes results to AZG1DBASQL01.ServerInventory.dbo.AdminDBCompaCheck
  - Tracks each run with a BatchId and stores a snapshot of the server list used.
  - Optional auto-fix: Set AdminDB compatibility to expected when status is Mismatch (and expected known).

.REQUIREMENTS
  - PowerShell 5.1+ or 7+
  - dbatools module installed (Install-Module dbatools)
  - Permissions:
      * connect to each target instance
      * read database properties
      * (optional) alter database compatibility level
      * write into inventory database table

USAGE EXAMPLES
  # Windows auth
  .\Check-AdminDBCompat.ps1 -ServerListPath .\servers.txt

  # SQL auth to targets + inventory
  $cred = Get-Credential
  .\Check-AdminDBCompat.ps1 -ServerListPath .\servers.txt -UseSqlAuth -SqlCredential $cred

  # Auto-fix mismatches
  .\Check-AdminDBCompat.ps1 -ServerListPath .\servers.txt -AutoFix

#>

[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)]
  [string]$ServerListPath,

  [string]$DatabaseName = "AdminDB",

  # Auth for TARGET instances (and also used for inventory if -InventoryUseSqlAuth not specified)
  [switch]$UseSqlAuth,
  [pscredential]$SqlCredential,

  # Inventory destination (where results are stored)
  [string]$InventoryInstance = "AZG1DBASQL011",
  [string]$InventoryDatabase = "ServerInventory",
  [string]$InventoryTable    = "dbo.AdminDBCompaCheck",

  # If you need different credentials for the inventory instance, set these:
  [switch]$InventoryUseSqlAuth,
  [pscredential]$InventorySqlCredential,

  # Optional CSV export (still handy for ad-hoc runs)
  [string]$OutCsvPath = ".\AdminDB_Compat_Mismatches.csv",

  # If set, attempts to remediate Mismatch by setting AdminDB compatibility level to expected.
  [switch]$AutoFix
)

function Get-ExpectedCompatLevel {
  param([int]$Major)
  switch ($Major) {
    11 { 110 } # SQL 2012
    12 { 120 } # SQL 2014
    13 { 130 } # SQL 2016
    14 { 140 } # SQL 2017
    15 { 150 } # SQL 2019
    16 { 160 } # SQL 2022
    default { $null } # unknown/future
  }
}

# --- Validate inputs ---
if (-not (Test-Path -LiteralPath $ServerListPath)) {
  throw "Server list file not found: $ServerListPath"
}

if ($UseSqlAuth -and -not $SqlCredential) {
  throw "When -UseSqlAuth is specified, you must also pass -SqlCredential (Get-Credential)."
}

if ($InventoryUseSqlAuth -and -not $InventorySqlCredential) {
  throw "When -InventoryUseSqlAuth is specified, you must also pass -InventorySqlCredential (Get-Credential)."
}

if (-not (Get-Module -ListAvailable -Name dbatools)) {
  throw "dbatools is not installed. Run: Install-Module dbatools -Scope CurrentUser"
}

Import-Module dbatools -ErrorAction Stop

# --- Read + sanitize server list ---
$rawServerLines = Get-Content -LiteralPath $ServerListPath

$servers = $rawServerLines | ForEach-Object {
  $line = ($_ -replace '^\uFEFF','').Trim()

  # Skip blank
  if ($line.Length -eq 0) { return }

  # Skip comments (even if whitespace before #)
  if ($line -match '^\s*#') { return }

  # Normalize host,port -> tcp:host,port for dbatools/SMO consistency
  if ($line -match '^[^\\]+,\d+$' -and $line -notmatch '^tcp:') {
    "tcp:$line"
  } else {
    $line
  }
} | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique

if (-not $servers -or $servers.Count -eq 0) {
  throw "No valid server instances found in file: $ServerListPath"
}

# Create a BatchId for this run (GUID makes it unique across time/runs)
$BatchId = [guid]::NewGuid()
$CheckDateUtc = [DateTime]::UtcNow

# Store a snapshot of the server list used (one string; easy to query later)
$ServerListSnapshot = ($servers -join ';')

Write-Host "BatchId: $BatchId" -ForegroundColor Yellow
Write-Host "Servers: $($servers.Count)" -ForegroundColor Yellow
Write-Host "AutoFix: $AutoFix" -ForegroundColor Yellow

# --- Ensure inventory table exists (auto-create) ---
# NOTE: This will create the table with the needed columns if it doesn't exist.
# If your DBAs prefer to pre-create via SQL, you can remove this block.
$createTableSql = @"
IF NOT EXISTS (
    SELECT 1
    FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE t.name = 'AdminDBCompaCheck'
      AND s.name = 'dbo'
)
BEGIN
    CREATE TABLE dbo.AdminDBCompaCheck
    (
        AdminDBCompaCheckID int IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_AdminDBCompaCheck PRIMARY KEY,

        BatchId             uniqueidentifier NOT NULL,
        CheckDateUtc        datetime2(0) NOT NULL,
        ServerListSnapshot  nvarchar(max) NULL,

        ServerInstance      nvarchar(256) NOT NULL,
        ProductVersion      nvarchar(128) NULL,
        MajorVersion        int NULL,
        ExpectedCompatLevel int NULL,
        ActualCompatLevel   int NULL,
        Status              nvarchar(50) NOT NULL,
        DatabaseName        sysname NOT NULL,
        Error               nvarchar(4000) NULL,

        FixAttempted        bit NOT NULL CONSTRAINT DF_AdminDBCompaCheck_FixAttempted DEFAULT (0),
        FixSucceeded        bit NOT NULL CONSTRAINT DF_AdminDBCompaCheck_FixSucceeded DEFAULT (0),
        FixMessage          nvarchar(4000) NULL
    );
END;
"@

try {
  if ($InventoryUseSqlAuth) {
    Invoke-DbaQuery -SqlInstance $InventoryInstance -Database $InventoryDatabase -SqlCredential $InventorySqlCredential -Query $createTableSql -EnableException
  } else {
    # Use target cred if provided, otherwise Windows
    if ($UseSqlAuth) {
      Invoke-DbaQuery -SqlInstance $InventoryInstance -Database $InventoryDatabase -SqlCredential $SqlCredential -Query $createTableSql -EnableException
    } else {
      Invoke-DbaQuery -SqlInstance $InventoryInstance -Database $InventoryDatabase -Query $createTableSql -EnableException
    }
  }
}
catch {
  throw "Failed to ensure inventory table exists on $InventoryInstance.$InventoryDatabase. Error: $($_.Exception.Message)"
}

# --- Main check loop ---
$results = New-Object System.Collections.Generic.List[object]

foreach ($instance in $servers) {
  Write-Host "Checking $instance ..." -ForegroundColor Cyan

  if ([string]::IsNullOrWhiteSpace($instance)) {
    $results.Add([pscustomobject]@{
      BatchId             = $BatchId
      CheckDateUtc        = $CheckDateUtc
      ServerListSnapshot  = $ServerListSnapshot
      ServerInstance      = $instance
      ProductVersion      = $null
      MajorVersion        = $null
      ExpectedCompatLevel = $null
      ActualCompatLevel   = $null
      Status              = "InputInvalid"
      DatabaseName        = $DatabaseName
      Error               = "Instance name was null/empty after sanitization."
      FixAttempted        = 0
      FixSucceeded        = 0
      FixMessage          = $null
    })
    continue
  }

  try {
    $server = if ($UseSqlAuth) {
      Connect-DbaInstance -SqlInstance $instance -SqlCredential $SqlCredential -ErrorAction Stop
    } else {
      Connect-DbaInstance -SqlInstance $instance -ErrorAction Stop
    }

    $major = [int]$server.VersionMajor
    $expected = Get-ExpectedCompatLevel -Major $major

    $db = if ($UseSqlAuth) {
      Get-DbaDatabase -SqlInstance $server -Database $DatabaseName -SqlCredential $SqlCredential -ErrorAction Stop
    } else {
      Get-DbaDatabase -SqlInstance $server -Database $DatabaseName -ErrorAction Stop
    }

    if (-not $db) {
      $results.Add([pscustomobject]@{
        BatchId             = $BatchId
        CheckDateUtc        = $CheckDateUtc
        ServerListSnapshot  = $ServerListSnapshot
        ServerInstance      = $instance
        ProductVersion      = $server.VersionString
        MajorVersion        = $major
        ExpectedCompatLevel = $expected
        ActualCompatLevel   = $null
        Status              = "DatabaseMissing"
        DatabaseName        = $DatabaseName
        Error               = $null
        FixAttempted        = 0
        FixSucceeded        = 0
        FixMessage          = $null
      })
      continue
    }

    $actual = [int]$db.CompatibilityLevel

    $status =
      if ($expected -eq $null) { "UnknownExpected" }
      elseif ($actual -ne $expected) { "Mismatch" }
      else { "OK" }

    # Optional remediation
    $fixAttempted = 0
    $fixSucceeded = 0
    $fixMessage   = $null

    if ($AutoFix -and $status -eq "Mismatch" -and $expected -ne $null) {
      $fixAttempted = 1
      try {
        if ($UseSqlAuth) {
          Set-DbaDbCompatibility -SqlInstance $server -Database $DatabaseName -Compatibility $expected -SqlCredential $SqlCredential -Confirm:$false -EnableException
        } else {
          Set-DbaDbCompatibility -SqlInstance $server -Database $DatabaseName -Compatibility $expected -Confirm:$false -EnableException
        }

        # Re-read to confirm
        $db2 = if ($UseSqlAuth) {
          Get-DbaDatabase -SqlInstance $server -Database $DatabaseName -SqlCredential $SqlCredential -ErrorAction Stop
        } else {
          Get-DbaDatabase -SqlInstance $server -Database $DatabaseName -ErrorAction Stop
        }

        $actual2 = [int]$db2.CompatibilityLevel
        if ($actual2 -eq $expected) {
          $fixSucceeded = 1
          $fixMessage = "Compatibility updated from $actual to $actual2."
          # After fix, status becomes OK for this run (but we still record the fact it was fixed)
          $status = "Fixed"
          $actual = $actual2
        } else {
          $fixSucceeded = 0
          $fixMessage = "Attempted update, but compatibility is still $actual2 (expected $expected)."
        }
      }
      catch {
        $fixSucceeded = 0
        $fixMessage = $_.Exception.Message
      }
    }

    # Record only non-OK outcomes (Mismatch/DatabaseMissing/UnknownExpected/Fixed) to keep table focused.
    if ($status -ne "OK") {
      $results.Add([pscustomobject]@{
        BatchId             = $BatchId
        CheckDateUtc        = $CheckDateUtc
        ServerListSnapshot  = $ServerListSnapshot
        ServerInstance      = $instance
        ProductVersion      = $server.VersionString
        MajorVersion        = $major
        ExpectedCompatLevel = $expected
        ActualCompatLevel   = $actual
        Status              = $status
        DatabaseName        = $DatabaseName
        Error               = $null
        FixAttempted        = $fixAttempted
        FixSucceeded        = $fixSucceeded
        FixMessage          = $fixMessage
      })
    }
  }
  catch {
    $results.Add([pscustomobject]@{
      BatchId             = $BatchId
      CheckDateUtc        = $CheckDateUtc
      ServerListSnapshot  = $ServerListSnapshot
      ServerInstance      = $instance
      ProductVersion      = $null
      MajorVersion        = $null
      ExpectedCompatLevel = $null
      ActualCompatLevel   = $null
      Status              = "ConnectionOrQueryFailed"
      DatabaseName        = $DatabaseName
      Error               = $_.Exception.Message
      FixAttempted        = 0
      FixSucceeded        = 0
      FixMessage          = $null
    })
  }
}

# --- Output to screen ---
if ($results.Count -eq 0) {
  Write-Host "All checked instances have $DatabaseName at the expected compatibility level." -ForegroundColor Green
} else {
  $results | Sort-Object Status, ServerInstance | Format-Table -AutoSize
}

# --- Optional CSV export ---
if ($OutCsvPath -and $results.Count -gt 0) {
  $results | Export-Csv -NoTypeInformation -Path $OutCsvPath
  Write-Host "Saved CSV: $OutCsvPath" -ForegroundColor Yellow
}

# --- Write to inventory table (append) ---
if ($results.Count -gt 0) {
  Write-Host "Writing $($results.Count) rows to $InventoryInstance.$InventoryDatabase.$InventoryTable" -ForegroundColor Cyan

  try {
    if ($InventoryUseSqlAuth) {
      Write-DbaDataTable `
        -SqlInstance $InventoryInstance `
        -Database $InventoryDatabase `
        -Table $InventoryTable `
        -SqlCredential $InventorySqlCredential `
        -InputObject $results `
        -EnableException
    } else {
      if ($UseSqlAuth) {
        Write-DbaDataTable `
          -SqlInstance $InventoryInstance `
          -Database $InventoryDatabase `
          -Table $InventoryTable `
          -SqlCredential $SqlCredential `
          -InputObject $results `
          -EnableException
      } else {
        Write-DbaDataTable `
          -SqlInstance $InventoryInstance `
          -Database $InventoryDatabase `
          -Table $InventoryTable `
          -InputObject $results `
          -EnableException
      }
    }

    Write-Host "Inventory insert complete. BatchId: $BatchId" -ForegroundColor Green
  }
  catch {
    throw "Failed to write results to inventory table. Error: $($_.Exception.Message)"
  }
}
else {
  Write-Host "No non-OK rows to write to inventory table for BatchId: $BatchId" -ForegroundColor Green
}

# --- Final: print BatchId so it’s easy to query ---
Write-Host "Done. BatchId: $BatchId" -ForegroundColor Yellow
