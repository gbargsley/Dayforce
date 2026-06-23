[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ListenerName,

    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path $_ })]
    [string]$ScriptPath,

    [string]$LogPath = './Logs',

    [int]$SqlPort = 31433,

    [PSCredential]$SqlCredential
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Log {
    param(
        [Parameter(Mandatory)] [string]$Message,
        [ValidateSet('INFO','WARN','ERROR','SUCCESS')] [string]$Level = 'INFO'
    )

    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$ts][$Level] $Message"

    switch ($Level) {
        'INFO'    { Write-Host $line }
        'WARN'    { Write-Warning $Message }
        'ERROR'   { Write-Host $line -ForegroundColor Red }
        'SUCCESS' { Write-Host $line -ForegroundColor Green }
    }

    Add-Content -Path $script:LogFile -Value $line
}

function Get-ReplicaTargets {
    param(
        [Parameter(Mandatory)] [string]$Listener,
        [Parameter(Mandatory)] [int]$Port
    )

    $listenerInstance = "$Listener,$Port"
    Write-Log "Connecting to AG listener '$listenerInstance' to discover replicas..."

    $replicas = Get-DbaAgReplica -SqlInstance $listenerInstance -EnableException
    if (-not $replicas) {
        throw "No replicas were returned from listener '$listenerInstance'."
    }

    $replicas |
        Select-Object -ExpandProperty Name -Unique |
        ForEach-Object { "$($_),$Port" }
}

function Invoke-DeploymentScript {
    param(
        [Parameter(Mandatory)] [string]$Instance,
        [Parameter(Mandatory)] [string]$SqlScript
    )

    Write-Log "Executing deployment on $Instance..."

    $invokeParams = @{
        SqlInstance    = $Instance
        Query          = $SqlScript
        EnableException = $true
    }

    if ($SqlCredential) {
        $invokeParams.SqlCredential = $SqlCredential
    }

    Invoke-DbaQuery @invokeParams | Out-Null
    Write-Log "Completed deployment on $Instance." -Level SUCCESS
}

try {
    if (-not (Get-Module -ListAvailable -Name dbatools)) {
        throw "dbatools is not installed. Install it first with: Install-Module dbatools"
    }

    Import-Module dbatools -ErrorAction Stop

    if (-not (Test-Path $LogPath)) {
        New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
    }

    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $script:LogFile = Join-Path $LogPath "AG_Deploy_${ListenerName}_$timestamp.log"

    Write-Log "Starting deployment for listener '$ListenerName'."
    Write-Log "Script path: $ScriptPath"
    Write-Log "Port suffix: $SqlPort"
    Write-Log "Log file: $script:LogFile"

    $sqlScript = Get-Content -Path $ScriptPath -Raw
    if ([string]::IsNullOrWhiteSpace($sqlScript)) {
        throw "The script file is empty: $ScriptPath"
    }

    $targets = Get-ReplicaTargets -Listener $ListenerName -Port $SqlPort
    Write-Log "Targets discovered: $($targets -join ', ')"

    foreach ($target in $targets) {
        try {
            Invoke-DeploymentScript -Instance $target -SqlScript $sqlScript
        }
        catch {
            Write-Log "Deployment failed on $target. $($_.Exception.Message)" -Level ERROR
        }
    }

    Write-Log "Deployment run finished." -Level SUCCESS
}
catch {
    Write-Log $_.Exception.Message -Level ERROR
    throw
}
