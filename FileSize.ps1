# PowerShell Script: Find Large Files on F:\
# Description: Lists all files larger than 1 GB on the F:\ drive
# Author: Garry Bargsley
# Date: (Insert today's date)

# Define search parameters
$drive = "F:\"
$sizeLimit = 1GB  # 1 GB threshold
$outputFile = "F:\Temp\LargeFilesReport.csv"  # Output report path

# Create output directory if it doesn't exist
if (!(Test-Path (Split-Path $outputFile))) {
    New-Item -ItemType Directory -Path (Split-Path $outputFile) -Force | Out-Null
}

# Find and export large files
Get-ChildItem -Path $drive -Recurse -ErrorAction SilentlyContinue |
    Where-Object { -not $_.PSIsContainer -and $_.Length -gt $sizeLimit } |
    Select-Object FullName,
                  @{Name="SizeGB"; Expression={"{0:N2}" -f ($_.Length / 1GB)}},
                  LastWriteTime |
    Sort-Object SizeGB -Descending |
    Export-Csv -Path $outputFile -NoTypeInformation

Write-Host "Search complete. Results saved to $outputFile"
