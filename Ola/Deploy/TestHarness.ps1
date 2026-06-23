$instance = 'aza2corsql002'

# 1) Connectivity + version check
Test-DbaConnection -SqlInstance $instance |
    Select-Object SqlInstance, ConnectSuccess, SqlVersion, AuthType, ConnectingAsUser |
    Format-List

# 2) SMO object inspection
$server = Connect-DbaInstance -SqlInstance aza2corsql002

$server | Select-Object Name, VersionMajor, Version, ConnectedAs |
    Format-List

# 3) Direct SQL query fallback
Invoke-DbaQuery -SqlInstance $instance -Query "
SELECT
    CAST(SERVERPROPERTY('ProductVersion') AS varchar(30)) AS ProductVersion,
    CAST(SERVERPROPERTY('Edition') AS varchar(128)) AS Edition,
    @@VERSION AS FullVersion;
"