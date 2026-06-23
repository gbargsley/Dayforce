<#
.SYNOPSIS
    Compare disk/volume usage between two SQL Server instances.

.DESCRIPTION
    Connects to both servers, runs the T-SQL summary, and shows a merged comparison by VolumeMountPoint.

.PREREQS
    - PowerShell with the SqlServer module (Install-Module SqlServer)
    - Network access to both SQL Servers
    - Permissions to run sys.dm_os_volume_stats (VIEW SERVER STATE)
#>

param(
    [Parameter(Mandatory=$true)][string]$ServerA,
    [Parameter(Mandatory=$true)][string]$ServerB,
    [Parameter(Mandatory=$false)][int]$TimeoutSeconds = 30
)

# T-SQL query (same as above)
$query = @"
SET NOCOUNT ON;
SELECT
    vs.volume_mount_point AS VolumeMountPoint,
    vs.logical_volume_name AS VolumeLabel,
    SUM(mf.size) * 8.0 / 1024 AS AllocatedMB,
    MAX(vs.total_bytes) / 1024.0 / 1024.0 AS TotalMB,
    MAX(vs.available_bytes) / 1024.0 / 1024.0 AS FreeMB,
    (MAX(vs.total_bytes) - MAX(vs.available_bytes)) / 1024.0 / 1024.0 AS UsedMB,
    CASE WHEN MAX(vs.total_bytes) > 0
         THEN ROUND(100.0 * ( (MAX(vs.total_bytes) - MAX(vs.available_bytes)) / CAST(MAX(vs.total_bytes) AS float) ), 2)
         ELSE NULL
    END AS PercentUsed,
    CASE WHEN SUM(mf.size) * 8.0 / 1024.0 > 0 AND MAX(vs.total_bytes) > 0
         THEN ROUND(100.0 * ( (SUM(mf.size) * 8.0 / 1024.0) / (MAX(vs.total_bytes) / 1024.0 / 1024.0) ), 2)
         ELSE NULL
    END AS PercentAllocatedToSQLFiles
FROM sys.master_files AS mf
CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.file_id) AS vs
GROUP BY vs.volume_mount_point, vs.logical_volume_name
ORDER BY VolumeMountPoint;
"@


function Get-ServerVolumes {
    param($Server)

    try {
        # Using Invoke-Sqlcmd (SqlServer module)
        $rows = Invoke-Sqlcmd -ServerInstance $Server -Query $query -QueryTimeout $TimeoutSeconds -ErrorAction Stop -TrustServerCertificate
        # Normalize volume mount point to upper and trim
        $rows | ForEach-Object {
            $_ | Add-Member -NotePropertyName Server -NotePropertyValue $Server -Force
            $_.VolumeMountPoint = ($_.VolumeMountPoint -as [string]).Trim().ToUpper()
            $_
        }
    } catch {
        Write-Warning "Failed to query $Server : $($_.Exception.Message)"
        return @()
    }
}

$A = Get-ServerVolumes -Server $ServerA
$B = Get-ServerVolumes -Server $ServerB

# Build a union of volume mount points present across both servers
$allVolumes = ($A.VolumeMountPoint + $B.VolumeMountPoint) | Where-Object { $_ } | Sort-Object -Unique

$result = foreach ($vol in $allVolumes) {
    $rowA = $A | Where-Object { $_.VolumeMountPoint -eq $vol } | Select-Object -First 1
    $rowB = $B | Where-Object { $_.VolumeMountPoint -eq $vol } | Select-Object -First 1

    [PSCustomObject]@{
        VolumeMountPoint = $vol
        ServerA = $ServerA
        TotalMB_A = if ($rowA) { [math]::Round($rowA.TotalMB,2) } else { $null }
        FreeMB_A  = if ($rowA) { [math]::Round($rowA.FreeMB,2) } else { $null }
        UsedMB_A  = if ($rowA) { [math]::Round($rowA.UsedMB,2) } else { $null }
        PctUsed_A = if ($rowA) { $rowA.PercentUsed } else { $null }
        AllocMB_A = if ($rowA) { [math]::Round($rowA.AllocatedMB,2) } else { $null }
        PctAlloc_A= if ($rowA) { $rowA.PercentAllocatedToSQLFiles } else { $null }

        ServerB = $ServerB
        TotalMB_B = if ($rowB) { [math]::Round($rowB.TotalMB,2) } else { $null }
        FreeMB_B  = if ($rowB) { [math]::Round($rowB.FreeMB,2) } else { $null }
        UsedMB_B  = if ($rowB) { [math]::Round($rowB.UsedMB,2) } else { $null }
        PctUsed_B = if ($rowB) { $rowB.PercentUsed } else { $null }
        AllocMB_B = if ($rowB) { [math]::Round($rowB.AllocatedMB,2) } else { $null }
        PctAlloc_B= if ($rowB) { $rowB.PercentAllocatedToSQLFiles } else { $null }

        # Differences (A - B)
        TotalDiffMB = if ($rowA -and $rowB) { [math]::Round($rowA.TotalMB - $rowB.TotalMB,2) } else { $null }
        FreeDiffMB  = if ($rowA -and $rowB) { [math]::Round($rowA.FreeMB - $rowB.FreeMB,2) } else { $null }
        UsedDiffMB  = if ($rowA -and $rowB) { [math]::Round($rowA.UsedMB - $rowB.UsedMB,2) } else { $null }
        AllocDiffMB = if ($rowA -and $rowB) { [math]::Round($rowA.AllocatedMB - $rowB.AllocatedMB,2) } else { $null }
    }
}

# Output a table. You can export to CSV with | Export-Csv -Path compare.csv -NoTypeInformation
$result | Format-Table -AutoSize
