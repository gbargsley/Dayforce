##
## Copyright (c) Microsoft Corporation.
## Licensed under the MIT license.
##
## Written by the SQL Server Network Support Team
## GitHub Site: https://github.com/microsoft/CSS_SQL_Networking_Tools/wiki
##

## Set-ExecutionPolicy Unrestricted -Scope CurrentUser

#=======================================Script parameters =====================================

# Several mutually exclusive parameter sets are defined
#
# .\SQLTrace.ps1 -Help
# .\SQLTrace.ps1 -Setup [-INIFile SQLTrace.ini]
# .\SQLTrace.ps1 -Start [-INIFile SQLTrace.ini] [-LogFolder folderpath] [-StopAfter minutes]
# .\SQLTrace.ps1 -Stop [-INIFile SQLTrace.ini]
# .\SQLTrace.ps1 -Cleanup [-INIFile SQLTrace.ini]
#

param
(
    [Parameter(ParameterSetName = 'Help', Mandatory=$true)]
    [switch] $Help,
     
    [Parameter(ParameterSetName = 'Setup', Mandatory=$true)]
    [switch] $Setup,

    [Parameter(ParameterSetName = 'Start', Mandatory=$true)]
    [switch] $Start,

    [Parameter(ParameterSetName = 'Start', Mandatory=$false)]
    [int] $StopAfter = [int]::Parse("0"),

    [Parameter(ParameterSetName = 'Stop', Mandatory=$true)]
    [switch] $Stop,

    [Parameter(ParameterSetName = 'Cleanup', Mandatory=$true)]
    [switch] $Cleanup,

    [Parameter(ParameterSetName = 'Setup', Mandatory=$false)]
    [Parameter(ParameterSetName = 'Start', Mandatory=$false)]
    [Parameter(ParameterSetName = 'Stop', Mandatory=$false)]
    [Parameter(ParameterSetName = 'Cleanup', Mandatory=$false)]
    [string] $INIFile = "SQLTrace.ini",

    [Parameter(ParameterSetName = 'Start', Mandatory=$false)]
    [string] $LogFolder = ""

)


#======================================= Globals =====================================

# [console]::TreatControlCAsInput = $false   # may change this later
[string]$global:CurrentFolder = Get-Location
[string]$global:LogFolderName = ""
[string]$global:LogProgressFileName = ""
[string]$global:LogFolderEnvName = "SQLTraceLogFolder"

$global:EventSourceName = "MSSQL-SQLTrace"   # For logging to the Application Event log
$global:INISettings = $null                  # set in ReadINIFile
$global:StopAfterMinutes = 0                 # set in StartTraces

$PathsToClean = @{}                          # for DeleteOldFiles


#======================================= Code =====================================

Function Main
{
	$OutputEncoding = [console]::OutputEncoding    # Prevents mix of UNICODE and ANSI logs in SQLTrace.log
    if (PreReqsOkay)
    {
        ReadINIFile
        RegisterEventLog

        if     ($Setup)    { DisplayLicenseAndHeader; DisplayINIValues; SetupTraces }                       # set BID Trace :Path registry if asked for in the INI file
        elseif ($Start)    { SetLogFolderName; DisplayLicenseAndHeader; DisplayINIValues; StartTraces }     # set BID Trace registry if not already set, then pause and prompt to restart app
        elseif ($Stop)     { GetLogFolderName; StopTraces }
        elseif ($Cleanup)  { CleanupTraces }
        else               { DisplayLicenseAndHeader; DisplayHelpMessage }
    }
}

Function DisplayLicenseAndHeader
{
# Text is left-justified to prevent leading spaces. Column width not to exceed 79 for smaller console sizes.
LogRaw "
  _________________   .____   ___________                              
 /   _____/\_____  \  |    |  \__    ___/_______ _____     ____   ____
 \_____  \  /  / \  \ |    |    |    |   \_  __ \\__  \  _/ ___\_/ __ \
 /        \/   \_/.  \|    |___ |    |    |  | \/ / __ \_\  \___\  ___/
/_______  /\_____\ \_/|_______ \|____|    |__|   (____  / \___  >\___  >
        \/        \__>        \/                      \/      \/     \/

                  SQLTrace.ps1 version 1.0.0234.0
               by the Microsoft SQL Server Networking Team
"

Start-Sleep -Milliseconds 1500

LogRaw "
MIT License

Copyright (c) Microsoft Corporation.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the 'Software'), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE

Disclaimers

This tool does not communicate with any external systems or with Microsoft.
This tool does not make a connection to SQL Server, IIS, or other services.
This tool DOES take network traces and other traces on the local machine and
records them to the local folder. This is controlled by the SQLTrace.ini file.
"
}

Function DisplayHelpMessage
{
"
Usage:

   .\SQLTrace.ps1 -Help
   .\SQLTrace.ps1 -Setup [-INIFile SQLTrace.ini]
   .\SQLTrace.ps1 -Start [-INIFile SQLTrace.ini] [-LogFolder folderpath] [-StopAfter minutes]
   .\SQLTrace.ps1 -Stop [-INIFile SQLTrace.ini]
   .\SQLTrace.ps1 -Cleanup [-INIFile SQLTrace.ini]
"
#    .\SQLTrace.ps1 -Start [-StopAfter 0] [-INIFile SQLTrace.ini] [-LogFolder folderpath]
}

Function ReadINIFile
{
    $global:INISettings =   @{                                     # a "splat" aka Dictionary
                                BidTrace         = "No"            # No | Yes
                                BidWow           = "No"            # No | Yes | Both
                                BidProviderList  = ""              # Empty default

                                NetTrace         = "No"
                                PSNetCapture     = "No"
                                Netsh            = "No"
                                Netmon           = "No"
                                Wireshark        = "No"
                                Pktmon           = "No"
                                TruncatePackets  = "No"
                                TCPEvents        = "No"
                                FilterString     = ""              # Empty default

                                AuthTrace        = "No"
                                SSL              = "No"
                                Kerberos         = "No"
                                LSA              = "No"
                                Credssp          = "No"

                                FlushTickets     = "No"
                                EventViewer      = "No"
                                SQLErrorLog      = "No"
                                SQLXEventLog     = "No"
                                DeleteOldFiles   = "No"
                                MinFiles         = "20"
                                MinMinutes       = "30"
                                SQLCheck         = "Yes"
                                SQLCheckPath     = ".\"            # default to current folder
                            }

    $fileName = $INIFile

    $fileData = get-content $fileName

    foreach ($line in $fileData)
    {
        # trim leading and trailing spaces and comments
        [String]$l = $line
        $l = $l.Trim()
        $hashPos = $l.IndexOf('#')
        if ($hashPos -ge 0) { $l = $l.SubString(0, $hashPos) }
        if ($l.Trim() -eq "") { continue }

        # $l contains some text, split it on the = character and trim the parts

        [String[]]$lineParts = $l.Split('=', 2)   # filter strings may have one or more = signs embedded in the filter. Split to max of 2 parts, key name and value

        if ($lineParts.Length -ne 2)
        {
            "Badly formatted setting: $l"
            continue
        }

        $keyWord = $lineParts[0].Trim()
        $value = $lineParts[1].Trim()

        
        switch($keyWord)
        {
            "BIDTrace"          { $global:INISettings.BIDTrace           = $value }
            "BIDWow"            { $global:INISettings.BIDWow             = $value }
            "BIDProviderList"   { $global:INISettings.BIDProviderList    = $value ; while ( $global:INISettings.BIDProviderList.IndexOf("  ") -gt 0) { $global:INISettings.BIDProviderList = $global:INISettings.BIDProviderList.Replace("  ", " ") } } # remove extra spaces between provider names
            "NETTrace"          { $global:INISettings.NetTrace           = $value }
            "NETSH"             { $global:INISettings.NETSH              = $value }
            "PSNETCAPTURE"      { $global:INISettings.PSNETCAPTURE       = $value }
            "NETMON"            { $global:INISettings.NETMON             = $value }
            "WireShark"         { $global:INISettings.WireShark          = $value }
            "PktMon"            { $global:INISettings.PktMon             = $value }
            "TruncatePackets"   { $global:INISettings.TruncatePackets    = $value }
            "TCPEvents"         { $global:INISettings.TCPEvents          = $value }
            "FilterString"      { $global:INISettings.FilterString       = $value }
            "AuthTrace"         { $global:INISettings.AuthTrace          = $value }
            "SSL"               { $global:INISettings.SSL                = $value }
            "CredSSP_NTLM"      { $global:INISettings.CredSSP            = $value }
            "Kerberos"          { $global:INISettings.Kerberos           = $value }
            "LSA"               { $global:INISettings.LSA                = $value }
            "FlushTickets"      { $global:INISettings.FlushTickets       = $value }
            "EventViewer"       { $global:INISettings.EventViewer        = $value }
            "SQLErrorLog"       { $global:INISettings.SQLErrorLog        = $value }
            "SQLXEventLog"      { $global:INISettings.SQLXEventLog       = $value }
            "DeleteOldFiles"    { $global:INISettings.DeleteOldFiles     = $value }
            "MinFiles"          { $global:INISettings.MinFiles           = $value }
            "MinMinutes"        { $global:INISettings.MinMinutes         = $value }
            "SQLCheck"          { $global:INISettings.SQLCheck           = $value }
            "SQLCheckPath"      { $global:INISettings.SQLCheckPath       = $value }
            default             { "Unknown keyword $keyWord in line: $l" }
        }
    }
}

Function DisplayINIValues
{
    LogInfo ""
	LogInfo "Read the ini file:  $INIFile"
    LogInfo ""
    LogInfo "BIDTrace            $($global:INISettings.BIDTrace)"
    LogInfo "BIDWow              $($global:INISettings.BIDWow)"
    LogInfo "BIDProviderList     $($global:INISettings.BIDProviderList)"
    LogInfo ""
    LogInfo "NETTrace            $($global:INISettings.NETTrace)"
    LogInfo "NETSH               $($global:INISettings.NETSH)"
    LogInfo "PSNETCAPTURE        $($global:INISettings.PSNETCAPTURE)"
    LogInfo "NETMON              $($global:INISettings.NETMON)"
    LogInfo "WireShark           $($global:INISettings.WireShark)"
    LogInfo "PktMon              $($global:INISettings.PktMon)"
    LogInfo "TruncatePackets     $($global:INISettings.TruncatePackets)"
    LogInfo "TCPEvents           $($global:INISettings.TCPEvents)"
    LogInfo "FilterString        $($global:INISettings.FilterString)"
    LogInfo ""
    LogInfo "AuthTrace           $($global:INISettings.AuthTrace)"
    LogInfo "SSL                 $($global:INISettings.SSL)"
    LogInfo "CredSSP_NTLM        $($global:INISettings.CredSSP)"
    LogInfo "Kerberos            $($global:INISettings.Kerberos)"
    LogInfo "LSA                 $($global:INISettings.LSA)"
    LogInfo ""
    LogInfo "FlushTickets        $($global:INISettings.FlushTickets)"
    LogInfo "EventViewer         $($global:INISettings.EventViewer)"
    LogInfo "SQLErrorLog         $($global:INISettings.SQLErrorLog)"
    LogInfo "SQLXEventLog        $($global:INISettings.SQLXEventLog)"
    LogInfo "DeleteOldFiles      $($global:INISettings.DeleteOldFiles)"
    LogInfo "MinFiles            $($global:INISettings.MinFiles)"
    LogInfo "MinMinutes          $($global:INISettings.MinMinutes)"
    LogInfo "SQLCheck            $($global:INISettings.SQLCheck)"
    LogInfo "SQLCheckPath        $($global:INISettings.SQLCheckPath)"
}

function RegisterEventLog
{
    $ErrorActionPreference = "SilentlyContinue"
    if(!(Get-Eventlog -LogName "Application" -Source $global:EventSourceName -Newest 1))
    {
        New-Eventlog -LogName "Application" -Source $global:EventSourceName | Out-Null
    }
    $ErrorActionPreference = "Continue"
}

Function PreReqsOkay
{
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal( [Security.Principal.WindowsIdentity]::GetCurrent( ) )
    if ( -not ($currentPrincipal.IsInRole( [Security.Principal.WindowsBuiltInRole]::Administrator ) ) )
    {
	    LogError "SQLTrace requires elevated privileges. Please run the PowerShell command prompt ""As Administrator""."
        return $false
    }
    return $true
}

Function SetLogFolderName
{
    if ($LogFolder.Length -gt 0)
    {
        # Cannot resolve the [potential] relative path until the folder is created
        mkdir $LogFolder | out-null
        $global:LogFolderName = Resolve-Path $LogFolder
    }
    else  # generate a name in the current folder
    {
       $global:LogFolderName = "$($global:CurrentFolder)\SQLTrace_$(Get-Date -Format ""yyyyMMdd_HHmmss"")"
       mkdir $global:LogFolderName | out-null
    }
    [System.Environment]::SetEnvironmentVariable($global:LogFolderEnvName,$global:LogFolderName, [System.EnvironmentVariableTarget]::Machine)
    $global:LogProgressFileName = "$($global:LogFolderName)\SQLTrace.log"
    # LogInfo "Log folder name: $($global:LogFolderName)"
    # LogInfo "Progress Log name: $($global:LogProgressFileName)"
}

Function GetLogFolderName
{
    $global:LogFolderName = [System.Environment]::GetEnvironmentVariable($global:LogFolderEnvName, [System.EnvironmentVariableTarget]::Machine)
    $global:LogProgressFileName = "$($global:LogFolderName)\SQLTrace.log"
    LogInfo "Log folder name: $($global:LogFolderName)"
    LogInfo "Progress Log name: $($global:LogProgressFileName)"
}


# ======================================= Setup Traces =========================================

Function SetupTraces
{
	SetupBIDRegistry
}

Function SetupBIDRegistry
{
	if($global:INISettings.BidTrace -eq "Yes")
    {
        if (-not(HasBIDBeenSet))
		{
			SetBIDRegistry
			LogWarning "Restart the application to be traced if it is a service or desktop application."
			LogRaw ""
		}
    }
    else
    {
        LogInfo "BID Tracing is not enabled for this trace."
		LogRaw ""
    }
}

Function HasBIDBeenSet
{
	$BIDPath = "HKLM:\Software\Microsoft\BidInterface\Loader"
	$BID32Path = "HKLM:\Software\WOW6432Node\Microsoft\BidInterface\Loader"

	# 32-bit test
	if ($global:INISettings.BidWow -eq "Only" -or $global:INISettings.BidWow -eq "Both")
	{
		$Path = Get-ItemProperty $BID32Path -Name ":Path" -ErrorAction SilentlyContinue  # $Path will be $null if :Path does not exist
		if ($Path -eq $null) { return $false }
		if ($Path.":Path" -ne "MSDADIAG.DLL") { return $false }   # case insensitive comparison
	}

	# 64-bit test
	if ($global:INISettings.BidWow -eq "Both" -or $global:INISettings.BidWow -eq "No")
	{
		$Path = Get-ItemProperty $BIDPath -Name ":Path" -ErrorAction SilentlyContinue  # $Path will be $null if :Path does not exist
		if ($Path -eq $null) { return $false }
		if ($Path.":Path" -ne "MSDADIAG.DLL") { return $false }   # case insensitive comparison
	}

	return $true
}

Function SetBIDRegistry
{
	LogInfo "Setting BID trace registry keys ..."
	if($global:INISettings.BidWow -eq "Only")
	{
		LogInfo "BIDTrace - Set BIDInterface WOW64 MSDADIAG.DLL"
		reg add HKLM\Software\WOW6432Node\Microsoft\BidInterface\Loader /v :Path /t  REG_SZ  /d MsdaDiag.DLL /f
	}
	elseif($global:INISettings.BidWow -eq "Both")
	{
		LogInfo "BIDTrace - Set BIDInterface MSDADIAG.DLL"
		reg add HKLM\Software\Microsoft\BidInterface\Loader /v :Path /t  REG_SZ  /d MsdaDiag.DLL /f
		LogInfo "BIDTrace - Set BIDInterface WOW64 MSDADIAG.DLL"
		reg add HKLM\Software\WOW6432Node\Microsoft\BidInterface\Loader /v :Path /t  REG_SZ  /d MsdaDiag.DLL /f
	}
	else ## BIDWOW = No
	{
	LogInfo "BIDTrace - Set BIDInterface MSDADIAG.DLL"
	reg  add HKLM\Software\Microsoft\BidInterface\Loader /v :Path /t  REG_SZ  /d MsdaDiag.DLL /f
	}
}

# ======================================= Start Traces =========================================

Function StartTraces
{
    Write-EventLog -LogName Application -Source $global:EventSourceName -EventID 3001 -Message "SQLTrace is starting."
    LogInfo "Starting traces ..."
    LogRaw ""
    LogInfo "Log folder name: $($global:LogFolderName)"
    LogInfo "Progress Log name: $($global:LogProgressFileName)"

    # $PSDefaultParameterValues['*:Encoding'] = 'Ascii'

    FlushExistingTraces
    FlushCaches

    # Run SQLCheck

    if($global:INISettings.SQLCheck -eq "Yes")
    {
        if((Test-Path "$($global:INISettings.SQLCheckPath)SQLCheck.exe" -PathType Leaf) -eq $false)
        {
            LogWarning "SQLCheck not found at the following location: $($global:INISettings.SQLCheckPath)SQLCheck.exe"
        }
        else
        {
			LogInfo "Starting SQLCheck."
            $cmd = (get-item "$($global:INISettings.SQLCheckPath)SQLCheck.exe").FullName           # absolute path to SQLCheck, e.g. .\sqlcheck.exe -> c:\msdata\sqlcheck.exe
            Push-Location "$($global:LogFolderName)"                                               # change to the log folder and preserve the path
            $result = invoke-expression $cmd                                                       # log is written to the current [log folder] location
            LogInfo "SQLCheck: $result"
            Pop-Location                                                                           # return to the last folder before the Push-Location
        }
    }
    else
    {
        LogInfo "SQLCheck not run."
    }

    tasklist > "$($global:LogFolderName)\TasklistAtStart.txt"
    netstat -abon > "$($global:LogFolderName)\NetStatAtStart.txt"
	ipconfig -all > "$($global:LogFolderName)\IPCONFIG.txt"
    StartBIDTraces
	StartNetworkTraces
    StartAuthenticationTraces

    if ($global:INISettings.DeleteOldFiles -eq "Yes")
    {
        if ($PathsToClean.Count -gt 0)
        {
            StartDeleteOldFiles $PathsToClean
        }
    }

    LogInfo "Traces have started..."
    Write-EventLog -LogName Application -Source $global:EventSourceName -EventID 3002 -Message "SQLTrace has started."

    # StopAfter logic

    if ($StopAfter -gt 0)
    {
        $global:StopAfterMinutes = $StopAfter
        while ($global:StopAfterMinutes -gt 0)
        {
            LogInfo "The trace will automatically stop in $($global:StopAfterMinutes) minutes."
            Start-Sleep -Seconds 60
            $global:StopAfterMinutes--
        }
        StopTraces
    }
    else
    {
        LogInfo "The trace will run until manually terminated with: .\SqlTrace.ps1 -stop"
    }
}

Function FlushExistingTraces
{
    # flush everything regardless of settings - may interfere with custom tracing

    LogInfo "Stopping previously running traces ..."

    # stop any PowerShell Net Event Session traces
    $sessions = get-neteventsession
    foreach ($session in $sessions)
    {
        if ($session.name -eq "PSTraceNDIS")
        {
            Stop-NetEventSession -Name $session.name
            Remove-NetEventSession -Name $session.name
        }
    }

    logman stop SQLTraceBID -ets  2>&1 | Out-Null

    logman stop SQLTraceNDIS -ets  2>&1 | Out-Null
    netsh trace stop  2>&1 | Out-Null
    nslookup "stopsqltrace.microsoft.com" 2>&1 | Out-Null     # Why the 2>&1 pipe? Do we still need that?
    Stop-Process -Name "dumpcap" -Force  2>&1 | Out-Null

    logman stop "SQLTraceKerberos" -ets  2>&1 | Out-Null
    reg delete HKLM\SYSTEM\CurrentControlSet\Control\LSA\Kerberos\Parameters /v LogLevel /f  2>&1 | Out-Null
    logman stop "SQLTraceNtlm_CredSSP" -ets  2>&1 | Out-Null
    logman stop "SQLTraceSSL" -ets  2>&1 | Out-Null

    nltest /dbflag:0x0  2>&1 | Out-Null
    
    reg delete HKLM\SYSTEM\CurrentControlSet\Control\LSA /v SPMInfoLevel /f  2>&1 | Out-Null
    reg delete HKLM\SYSTEM\CurrentControlSet\Control\LSA /v LogToFile /f  2>&1 | Out-Null
    reg delete HKLM\SYSTEM\CurrentControlSet\Control\LSA /v NegEventMask /f  2>&1 | Out-Null
    reg delete HKLM\SYSTEM\CurrentControlSet\Control\LSA\NegoExtender\Parameters /v InfoLevel /f  2>&1 | Out-Null
    reg delete HKLM\SYSTEM\CurrentControlSet\Control\LSA\Pku2u\Parameters /v InfoLevel /f  2>&1 | Out-Null
    reg delete HKLM\SYSTEM\CurrentControlSet\Control\LSA /v LspDbgInfoLevel /f  2>&1 | Out-Null
    reg delete HKLM\SYSTEM\CurrentControlSet\Control\LSA /v LspDbgTraceOptions /f  2>&1 | Out-Null
            
    logman stop "SQLTraceLSA" -ets  2>&1 | Out-Null
}

Function FlushCaches
{
    LogInfo (IPCONFIG /flushdns)
    LogInfo (NBTSTAT -R)

    if ($global:INISettings.FlushTickets -eq "Yes")
    {
        Get-WmiObject Win32_LogonSession | Where-Object {$_.AuthenticationPackage -ne 'NTLM'} | ForEach-Object { LogInfo(c:\windows\system32\klist.exe purge -li ([Convert]::ToString($_.LogonId, 16))) }
    }

    StopDeleteOldFiles
}

Function GETBIDTraceGuid($bidProvider)
{
    
    switch($bidProvider)
    {
       "MSDADIAG"                         { return "{8B98D3F2-3CC6-0B9C-6651-9649CCE5C752} 0x630ff  0   MSDADIAG.ETW "}
       "ADODB"                            { return "{04C8A86F-3369-12F8-4769-24E484A9E725} 0x630ff  0   ADODB.1 "}
       "ADOMD"                            { return "{7EA56435-3F2F-3F63-A829-F0B35B5CAD41} 0x630ff  0   ADOMD.1 "}
       "BCP"                              { return "{24722B88-DF97-4FF6-E395-DB533AC42A1E} 0x630ff  0   BCP.1 "}
       "BCP10"                            { return "{ED303448-5479-CA3F-5686-E020BA4F47F9} 0x630ff  0   BCP10.1 "}
       "DBNETLIB"                         { return "{BD568F20-FCCD-B948-054E-DB3421115D61} 0x630ff  0   DBNETLIB.1 "}
       "MSADCE"                           { return "{76DBA919-5A36-FC80-2CAD-3185532B7CB1} 0x630ff  0   MSADCE.1 "}
       "MSADCF"                           { return "{101C0E21-EBBA-A60A-EC3D-58797788928A} 0x630ff  0   MSADCF.1 "}
       "MSADCO"                           { return "{5C6CE734-1B3E-705E-C2AB-B272D99AAF8F} 0x630ff  0   MSADCO.1 "}
       "MSADDS"                           { return "{13CD7F92-5BAA-8C7C-3D72-B69FAC139A46} 0x630ff  0   MSADDS.1 "}
       "MSADOX"                           { return "{6C770D53-0441-AFD4-DCAB-1D89155FECFC} 0x630ff  0   MSADOX.1 "}
       "MSDAORA"                          { return "{F02A5DAC-6DB2-F77F-F6A8-6404FE697B7D} 0x630ff  0   MSDAORA.1 "}
       "MSDAPRST"                         { return "{64A552E0-6C60-B907-E59C-10F1DFF76B0D} 0x630ff  0   MSDAPRST.1 "}
       "MSDAREM"                          { return "{564F1E24-FC86-28E1-74F8-5CA0D950BEE0} 0x630ff  0   MSDAREM.1 "}
       "MSDART"                           { return "{CEB7253C-BB96-9DFE-51D1-53D966D0CF8B} 0x630ff  0   MSDART.1 "}
       "MSDASQL"                          { return "{B6501BA0-C61A-C4E6-6FA2-A4E7F8C8E7A0} 0x630ff  0   MSDASQL.1 "}
       "MSDATL3"                          { return "{87B93A44-1F73-EC83-7261-2DFC972D9B1E} 0x630ff  0   MSDATL3.1 "}
       "ODBC"                             { return "{F34765F6-A1BE-4B9D-1400-B8A12921F704} 0x630ff  0   ODBC.1 "}
       "ODBCBCP"                          { return "{932B59F1-90C2-D8BA-0956-3975C344AE2B} 0x630ff  0   ODBCBCP.1 "}
       "OLEDB"                            { return "{0DD082C4-66F2-271F-74BA-2BF1F9F65C66} 0x630ff  0   OLEDB.1 "}
       "RowsetHelper"                     { return "{74A75B02-36D8-EDE6-D10E-95B691503408} 0x630ff  0   RowsetHelper.1 "}
       "SQLBROWSER"                       { return "{FC9F92E6-D521-9C9A-1D8C-D8980B9978A9} 0x630ff  0   SQLBROWSER.1 "}
       "SQLOLEDB"                         { return "{C5BFFE2E-9D87-D568-A09E-08FC83D0C7C2} 0x630ff  0   SQLOLEDB.1 "}
       "SQLNCLI"                          { return "{BA798F36-2325-EC5B-ECF8-76958A2AF9B5} 0x630ff  0   SQLNCLI.1 "}
       "SQLNCLI10"                        { return "{A9377239-477A-DD22-6E21-75912A95FD08} 0x630ff  0   SQLNCLI10.1 "}
       "SQLNCLI11"                        { return "{2DA81B52-908E-7DB6-EF81-76856BB47C4F} 0x630ff  0   SQLNCLI11.1 "}
       "SQLSERVER.SNI"                    { return "{AB6D5EEB-0132-74AB-C5F5-B23E1644DADA} 0x630ff  0   SQLSERVER.SNI.1 "}
       "SQLSERVER.SNI10"                  { return "{48D59D84-105B-00FA-6B49-03462F696737} 0x630ff  0   SQLSERVER.SNI10.1 "}
       "SQLSERVER.SNI11"                  { return "{B2A28C42-A7C2-1563-97CC-3BE49FDA19F9} 0x630ff  0   SQLSERVER.SNI11.1 "}
       "SQLSERVER.SNI12"                  { return "{5BD84A98-C66F-1694-6E42-B18A6243602B} 0x630ff  0   SQLSERVER.SNI12.1 "}
       "SQLSRV32"                         { return "{4B647745-F438-0A42-F870-5DBD29949C99} 0x630ff  0   SQLSRV32.1 "}
       "MSODBCSQL11"                      { return "{7C360F7F-7102-250A-A233-F9BEBB9875C2} 0x630ff  0   MSODBCSQL11.1 "}
       "MSODBCSQL13"                      { return "{85DC6E48-9394-F805-45C9-C8B2ACA2E7FE} 0x630ff  0   MSODBCSQL13.1 "}
       "MSODBCSQL17"                      { return "{053A11C4-BC2B-F7CE-4A10-9D2602643DA0} 0x630ff  0   MSODBCSQL17.1 "}
	   "MSODBCSQL18"                      { return "{1a1283ad-c65d-28ef-d729-39794ffdab32} 0x630ff  0   MSODBCSQL18.1 "}
       "System.Data"                      { return "{914ABDE2-171E-C600-3348-C514171DE148} 0x630ff  0   System.Data.1 "}
       "System.Data.OracleClient"         { return "{DCD90923-4953-20C2-8708-01976FB15287} 0x630ff  0   System.Data.OracleClient.1 "}
       "System.Data.SNI"                  { return "{C9996FA5-C06F-F20C-8A20-69B3BA392315} 0x630ff  0   System.Data.SNI.1 "}
       "System.Data.Entity"               { return "{A68D8BB7-4F92-9A7A-D50B-CEC0F44C4808} 0x630ff  0   System.Data.Entity.1 "}
       "SQLJDBC_XA"                       { return "{172E580D-9BEF-D154-EABB-83429A6F3718} 0x630ff  0   SQLJDBC_XA.1 "}
       "MSOLEDBSQL"                       { return "{EE7FB59C-D3E8-9684-AEAC-B214EFD91B31} 0x630ff  0   MSOLEDBSQL.1 "}
       "MSOLEDBSQL19"                     { return "{699773CA-18E7-57DF-5718-C244760A9F44} 0x630ff  0   MSOLEDBSQL19.1 "}
    }
	return ""  # provider not found
}

Function StartBIDTraces
{
    $vGUIDs = [System.Collections.ArrayList]::new()
    if($global:INISettings.BidTrace -eq "Yes")
    {
		if (-not (HasBIDBeenSet))
		{
			SetBIDRegistry
			LogWarning "Please retart the application being traced if it is a desktop application or a service."
			LogWarning "Press Enter once restarted."
			Read-Host
		}

        LogInfo "Starting BID Traces ..."

        ## Get Provider GUIDs - Add MSDIAG by default
        $guid = GETBIDTraceGUID("MSDADIAG")
        $vGUIDs.Add($guid) | out-null

        ## Add the ones listed in the INI file
        $global:INISettings.BidProviderList.Split(" ") | ForEach { $guid = GETBIDTraceGUID($_); $vGUIDs.Add($guid) | out-null }

        if((Test-Path "$($global:LogFolderName)\BIDTraces" -PathType Container) -eq $false)
		{
			md "$($global:LogFolderName)\BIDTraces" > $null
        }
        
        # Add DNS GUID and then add BID Trace Providers
        "{1c95126e-7eea-49a9-a3fe-a378b03ddb4d} 0xc0001ffff0000100  0x04   Microsoft-Windows-DNS-Client " | Out-File -FilePath "$($global:LogFolderName)\BIDTraces\ctrl.guid" -Encoding Ascii

        foreach($guid in $vGUIDs)
        { 
            $guid | Out-File -FilePath "$($global:LogFolderName)\BIDTraces\ctrl.guid" -Append -Encoding Ascii
        }

        $result = logman start SQLTraceBID -pf "$($global:LogFolderName)\BIDTraces\ctrl.guid" -o "$($global:LogFolderName)\BIDTraces\bidtrace%d.etl" -bs 1024 -nb 1024 1024 -mode NewFile -max 300 -ets
        LogInfo "LOGMAN: $result"

        # Values for DeleteOldFiles
        $CleanupValues = "$($global:LogFolderName)\BIDTraces\bidtrace*.etl", $global:INISettings.MinMinutes, $global:INISettings.MinFiles    # Filespec, min_minutes, min_files
        $PathsToClean.Add("BID", $CleanupValues)

    }
}

Function StartWireshark
{
    ## Get Number of Devices
    $WiresharkPath = Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\Wireshark.exe\' -Name Path
    $WiresharkCmd = $WiresharkPath + "\dumpcap.exe"
    $DeviceList = invoke-expression '& $WiresharkCmd -D'
    $truncatePackets = ""
    if ($global:INISettings.TruncatePackets -eq "Yes") { $truncatePackets = "-s 180"; }
    $ArgumentList = ""
    For($cDevices=0;$cDevices -lt $DeviceList.Count;$cDevices++) { $ArgumentList = $ArgumentList + " -i " + ($cDevices+1) }
    ##Prepare command arguments 
    $ArgumentList = " $truncatePackets " + $ArgumentList + " -w `"$($global:LogFolderName)\NetworkTraces\nettrace.pcap`" -b filesize:300000 $($global:INISettings.FilterString)"
    LogInfo "Dumpcap Args: $ArgumentList"
    [System.Diagnostics.Process] $WiresharkProcess = Start-Process $WiresharkCmd -PassThru -NoNewWindow -RedirectStandardOutput "$($global:LogFolderName)\NetworkTraces\Console.txt" -ArgumentList $ArgumentList
    LogInfo "Wireshark is running with PID: " + $WiresharkProcess.ID

    # Values for DeleteOldFiles
    $CleanupValues = "$($global:LogFolderName)\NetworkTraces\*.pcap", $global:INISettings.MinMinutes, $global:INISettings.MinFiles    # Filespec, min_minutes, min_files
    $PathsToClean.Add("WireShark", $CleanupValues)
}


Function StartNetworkMonitor
{

    $trucatePackets = ""
    if ($global:INISettings.TruncatePackets -eq "Yes") { $truncatePackets = "/maxframelength 180"; }

    #Look for the path where Wireshark is installed
    $NMCap = Get-ItemPropertyValue -Path 'HKLM:\HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Netmon3\' -Name InstallDir

    $NMCap = '"' + $NMCap + "nmcap.exe" + '" '
    $ArgumentList = "/network * /capture $($global:INISettings.FilterString) /file `"$($global:LogFolderName)\NetworkTraces\nettrace.chn:300M`" /StopWhen /Frame dns.qrecord.questionname.Contains('stopsqltrace') $truncatePackets"
    LogInfo "NMCAP Args: $ArgumentList"

    #Start the capture
    [System.Diagnostics.Process] $NetmonProcess = Start-Process $NMCap -PassThru -NoNewWindow -RedirectStandardOutput "$($global:LogFolderName)\NetworkTraces\Console.txt" -ArgumentList $ArgumentList
    LogInfo "Network Monitor is running with PID: " + $NetmonProcess.ID
    LogWarning "Killing this process will corrupt the most recent capture file."
    LogWarning "Run SQLTrace.ps1 with the -stop option to terminate safely."
    LogRaw ""

    # Values for DeleteOldFiles
    $CleanupValues = "$($global:LogFolderName)\NetworkTraces\*.cap", $global:INISettings.MinMinutes, $global:INISettings.MinFiles    # Filespec, min_minutes, min_files
    $PathsToClean.Add("NMCAP", $CleanupValues)
}

Function StartNetworkTraces
{
    
    if($global:INISettings.NETTrace -eq "Yes")
    {

        LogInfo "Starting Network Traces..."
        if((Test-Path "$($global:LogFolderName)\NetworkTraces" -PathType Container) -eq $false)
        {
            md "$($global:LogFolderName)\NetworkTraces" > $null
        }

        if($global:INISettings.NETSH -eq "Yes")
        {
            LogInfo "Starting NETSH..."

            # NETSH often won't collect on the first invocation
            # Dummy NETSH collection so the next one will be reliable

            $cmd = "netsh trace start capture=yes maxsize=1 report=disabled TRACEFILE=`"$($global:LogFolderName)\NetworkTraces\deletemeD.etl`""
            LogInfo "NETSH dummy start: $cmd"

            $result = invoke-expression $cmd
            LogInfo "NETSH: $result"
            
            $result = netsh trace stop
            LogInfo "NETSH dummy stop: $result"
            
            # remove files generated by the dummy run

            if (Test-Path "$($global:LogFolderName)\NetworkTraces\deletemeD.etl")
            {
               del "$($global:LogFolderName)\NetworkTraces\deletemeD.etl"
            }
             
            if (Test-Path "$($global:LogFolderName)\NetworkTraces\deleteme.cab")
            {
               del "$($global:LogFolderName)\NetworkTraces\deletemeD.cab"
            }

            # NETSH second invocation and real data capture to be logged by LOGMAN in a chained set of files

            $truncatePackets = ""
            if ($global:INISettings.TruncatePackets -eq "Yes") { $truncatePackets = "PACKETTRUNCATEBYTES=250"; }
            
            $cmd = "netsh trace start capture=yes $($global:INISettings.FilterString) maxsize=1 report=disabled TRACEFILE=`"$($global:LogFolderName)\NetworkTraces\deleteme.etl`" $truncatePackets" # Faster netsh shutdown clintonw #53
            LogInfo "NETSH: $cmd"

            $result = invoke-expression $cmd
            LogInfo "NETSH: $result"
			
            $result = logman start SQLTraceNDIS -p Microsoft-Windows-NDIS-PacketCapture -mode newfile -max 300 -o "$($global:LogFolderName)\NetworkTraces\nettrace%d.etl" -ets
            LogInfo "LOGMAN: $result"

            if ($global:INISettings.TCPEvents -eq "Yes")
            {
                $result = logman update trace SQLTraceNDIS -p Microsoft-Windows-Winsock-AFD -ets
                LogInfo "LOGMAN Winsock AFD Events: $result"
                $result = logman update trace SQLTraceNDIS -p Microsoft-Windows-TCPIP -ets
                LogInfo "LOGMAN TCPIP Events: $result"
                $result = logman update trace SQLTraceNDIS -p Microsoft-Windows-WFP -ets
                LogInfo "LOGMAN Windows Firewall Events: $result"
                $result = logman update trace SQLTraceNDIS -p Microsoft-Windows-Winsock-NameResolution -ets
                LogInfo "LOGMAN DNS Events: $result"
            }

            # Values for DeleteOldFiles
            $CleanupValues = "$($global:LogFolderName)\NetworkTraces\nettrace*.etl", $global:INISettings.MinMinutes, $global:INISettings.MinFiles    # Filespec, min_minutes, min_files
            $PathsToClean.Add("NETSH", $CleanupValues)

        }
        if($global:INISettings.PSNETCAPTURE -eq "Yes")
        {
            LogInfo "Starting PowerShell NetEvent NDIS packet capture ..."

            New-NetEventSession -Name "PSTraceNDIS" -CaptureMode SaveToFile -LocalFilePath "$($global:LogFolderName)\NetworkTraces\deleteme.etl" -TraceBufferSize 1024 -MaxFileSize 1

            $PacketSize = 0   # collect full packet
            if ($global:INISettings.TruncatePackets -eq "Yes") { $PacketSize = 250; }   # same as netsh

            Add-NetEventPacketCaptureProvider -SessionName "PSTraceNDIS" -TruncationLength $PacketSize

            if ($global:INISettings.FilterString -ne "")
            {
                $cmd = "Set-NetEventPacketCaptureProvider -SessionName PSTraceNDIS $($global:INISettings.FilterString)"
                LogInfo "Adding filter: $cmd"

                $result = invoke-expression $cmd
                LogInfo "Filter: $result"
            }
            
            Start-NetEventSession -Name "PSTraceNDIS"

            $result = logman start SQLTraceNDIS -p Microsoft-Windows-NDIS-PacketCapture -mode newfile -max 300 -o "$($global:LogFolderName)\NetworkTraces\nettrace%d.etl" -ets
            LogInfo "LOGMAN: $result"

            if ($global:INISettings.TCPEvents -eq "Yes")
            {
                $result = logman update trace SQLTraceNDIS -p Microsoft-Windows-Winsock-AFD -ets
                LogInfo "LOGMAN Winsock AFD Events: $result"
                $result = logman update trace SQLTraceNDIS -p Microsoft-Windows-TCPIP -ets
                LogInfo "LOGMAN TCPIP Events: $result"
                $result = logman update trace SQLTraceNDIS -p Microsoft-Windows-WFP -ets
                LogInfo "LOGMAN Windows Firewall Events: $result"
                $result = logman update trace SQLTraceNDIS -p Microsoft-Windows-Winsock-NameResolution -ets
                LogInfo "LOGMAN DNS Events: $result"
            }

            # Values for DeleteOldFiles
            $CleanupValues = "$($global:LogFolderName)\NetworkTraces\nettrace*.etl", $global:INISettings.MinMinutes, $global:INISettings.MinFiles    # Filespec, min_minutes, min_files
            $PathsToClean.Add("PSTrace", $CleanupValues)

        }
        if($global:INISettings.NETMON -eq "Yes")
        {
            LogInfo "Starting Network Monitor..."
            StartNetworkMonitor
        }
        if($global:INISettings.WIRESHARK -eq "Yes")
        {
            LogInfo "Starting Wireshark..."
            StartWireshark
        }
        if($global:INISettings.PKTMON -eq "Yes")
        {
            LogInfo "Starting Pktmon..."
            $result = pktmon list --all --include-hidden > "$($global:LogFolderName)\NetworkTraces\tracepoints.txt"
            LogInfo "PKTMON trace points: $result"
            if ($global:INISettings.FilterString -ne "")
            {
                $cmd = "pktmon filter add $($global:INISettings.FilterString)"
                $result = invoke-expression $cmd
                LogInfo "PKTMON Filter '$($global:INISettings.FilterString)' added: $result"
            }
            $PacketSize = 0   # collect full packet
            if ($global:INISettings.TruncatePackets -eq "Yes") { $PacketSize = 250; }   # same as netsh
            if ($global:INISettings.TCPEvents -eq "Yes")
            {                
                $result = pktmon start -c -m multi-file --file-size 300 --pkt-size $PacketSize -t -p Microsoft-Windows-TCPIP -p Microsoft-Windows-Winsock-AFD -p Microsoft-Windows-Winsock-NameResolution -p Microsoft-Windows-WFP -f "$($global:LogFolderName)\NetworkTraces\pktmon.etl"
                LogInfo "PKTMON with TCPIP and Winsock events: $result"
            }
            else
            {
                $result = pktmon start -c -m multi-file --file-size 300 --pkt-size $PacketSize -f "$($global:LogFolderName)\NetworkTraces\pktmon.etl"
                LogInfo "PKTMON: $result"
            }

            # Values for DeleteOldFiles
            $CleanupValues = "$($global:LogFolderName)\NetworkTraces\*.pcap", $global:INISettings.MinMinutes, $global:INISettings.MinFiles    # Filespec, min_minutes, min_files
            $PathsToClean.Add("PKTMON", $CleanupValues)
        }
    }
}

Function StartAuthenticationTraces
{
    if($global:INISettings.AuthTrace -eq "Yes")
    {
 
        if((Test-Path "$($global:LogFolderName)\Auth" -PathType Container) -eq $false)
		{
            md "$($global:LogFolderName)\Auth" > $null
        }
   
        if($global:INISettings.Kerberos -eq "Yes")
        {
            LogInfo "Starting Kerberos ETL Traces..."

            # **Kerberos**
            $KerberosProviders = @(
									  '{6B510852-3583-4e2d-AFFE-A67F9F223438}!0x7ffffff'
									  '{60A7AB7A-BC57-43E9-B78A-A1D516577AE3}!0xffffff'
									  '{FACB33C4-4513-4C38-AD1E-57C1F6828FC0}!0xffffffff'
									  '{97A38277-13C0-4394-A0B2-2A70B465D64F}!0xff'
									  '{8a4fc74e-b158-4fc1-a266-f7670c6aa75d}!0xffffffffffffffff'
									  '{98E6CFCB-EE0A-41E0-A57B-622D4E1B30B1}!0xffffffffffffffff'
								  ) 

            # Kerberos Logging to SYSTEM event log in case this is a client
            reg add HKLM\SYSTEM\CurrentControlSet\Control\LSA\Kerberos\Parameters /v LogLevel /t REG_DWORD /d 1 /f
    
            $result = logman start "SQLTraceKerberos" -o "$($global:LogFolderName)\Auth\Kerberos%d.etl" -mode NewFile -max 300 -ets
            LogInfo "Kerberos: $result"

            ForEach($KerberosProvider in $KerberosProviders)
            {
                # Update Logman Kerberos
                $KerberosParams = $KerberosProvider.Split('!')
                $KerberosSingleTraceGUID = $KerberosParams[0]
                $KerberosSingleTraceFlags = $KerberosParams[1]    
                $result = logman update trace "SQLTraceKerberos" -p `"$KerberosSingleTraceGUID`" $KerberosSingleTraceFlags 0xff -ets
                LogInfo "Kerberos: $result"
            }

            # Values for DeleteOldFiles
            $CleanupValues = "$($global:LogFolderName)\Auth\Kerberos*.etl", $global:INISettings.MinMinutes, $global:INISettings.MinFiles    # Filespec, min_minutes, min_files
            $PathsToClean.Add("Kerberos", $CleanupValues)
        }
        
        if($global:INISettings.Credssp -eq "Yes")
        {

            LogInfo "Starting CredSSP/NTLM Traces..."
            # **Ntlm_CredSSP**
            $Ntlm_CredSSPProviders = @(
										  '{5BBB6C18-AA45-49b1-A15F-085F7ED0AA90}!0x5ffDf'
										  '{AC69AE5B-5B21-405F-8266-4424944A43E9}!0xffffffff'
										  '{6165F3E2-AE38-45D4-9B23-6B4818758BD9}!0xffffffff'
										  '{AC43300D-5FCC-4800-8E99-1BD3F85F0320}!0xffffffffffffffff'
										  '{DAA6CAF5-6678-43f8-A6FE-B40EE096E06E}!0xffffffffffffffff'
									  )

            $result = logman start trace "SQLTraceNtlm_CredSSP" -o "$($global:LogFolderName)\Auth\Ntlm_CredSSP%d.etl" -mode NewFile -max 300 -ets
            LogInfo "NTLM_CredSSP: $result"

            ForEach($Ntlm_CredSSPProvider in $Ntlm_CredSSPProviders)
            {
                # Update Logman Ntlm_CredSSP
                $Ntlm_CredSSPParams = $Ntlm_CredSSPProvider.Split('!')
                $Ntlm_CredSSPSingleTraceGUID = $Ntlm_CredSSPParams[0]
                $Ntlm_CredSSPSingleTraceFlags = $Ntlm_CredSSPParams[1]
        
                $result = logman update trace "SQLTraceNtlm_CredSSP" -p `"$Ntlm_CredSSPSingleTraceGUID`" $Ntlm_CredSSPSingleTraceFlags 0xff -ets
                LogInfo "NTLM_CredSSP: $result"
            }

            # Values for DeleteOldFiles
            $CleanupValues = "$($global:LogFolderName)\Auth\Ntlm_CredSSP*.etl", $global:INISettings.MinMinutes, $global:INISettings.MinFiles    # Filespec, min_minutes, min_files
            $PathsToClean.Add("NTLM", $CleanupValues)
        }
        

        if($global:INISettings.SSL -eq "Yes")
        {
            LogInfo "Starting SSL Traces..."
            # **SSL**
            $SSLProviders = @(
								 '{37D2C3CD-C5D4-4587-8531-4696C44244C8}!0x4000ffff'
							 )

            # Start Logman SSL     
            $result = logman start "SQLTraceSSL" -o "$($global:LogFolderName)\Auth\SSL%d.etl" -mode NewFile -max 300 -ets
            LogInfo "SSL: $result"

            ForEach($SSLProvider in $SSLProviders)
            {
                # Update Logman SSL
                $SSLParams = $SSLProvider.Split('!')
                $SSLSingleTraceGUID = $SSLParams[0]
                $SSLSingleTraceFlags = $SSLParams[1]
        
                $result = logman update trace "SQLTraceSSL" -p `"$SSLSingleTraceGUID`" $SSLSingleTraceFlags 0xff -ets
                LogInfo "SSL: $result"
            }

            # Values for DeleteOldFiles
            $CleanupValues = "$($global:LogFolderName)\Auth\SSL*.etl", $global:INISettings.MinMinutes, $global:INISettings.MinFiles    # Filespec, min_minutes, min_files
            $PathsToClean.Add("SSL", $CleanupValues)
        }

        
        if($global:INISettings.LSA -eq "Yes")
        {
            LogInfo "Starting LSA Traces..."

            # **Netlogon logging**
            $result = nltest /dbflag:0x2EFFFFFF 2>&1
            LogInfo "NLTEST: $result"

            # **LSA**
            $LSAProviders = @(
								 '{D0B639E0-E650-4D1D-8F39-1580ADE72784}!0xC43EFF'
								 '{169EC169-5B77-4A3E-9DB6-441799D5CACB}!0xffffff'
								 '{DAA76F6A-2D11-4399-A646-1D62B7380F15}!0xffffff'
								 '{366B218A-A5AA-4096-8131-0BDAFCC90E93}!0xfffffff'
								 '{4D9DFB91-4337-465A-A8B5-05A27D930D48}!0xff'
								 '{7FDD167C-79E5-4403-8C84-B7C0BB9923A1}!0xFFF'
								 '{CA030134-54CD-4130-9177-DAE76A3C5791}!0xfffffff'
								 '{5a5e5c0d-0be0-4f99-b57e-9b368dd2c76e}!0xffffffffffffffff'
								 '{2D45EC97-EF01-4D4F-B9ED-EE3F4D3C11F3}!0xffffffffffffffff'
								 '{C00D6865-9D89-47F1-8ACB-7777D43AC2B9}!0xffffffffffffffff'
								 '{7C9FCA9A-EBF7-43FA-A10A-9E2BD242EDE6}!0xffffffffffffffff'
								 '{794FE30E-A052-4B53-8E29-C49EF3FC8CBE}!0xffffffffffffffff'
								 '{ba634d53-0db8-55c4-d406-5c57a9dd0264}!0xffffffffffffffff'
							 )
    
            #Registry LSA
            reg add HKLM\SYSTEM\CurrentControlSet\Control\LSA /v SPMInfoLevel /t REG_DWORD /d 0xC43EFF /f 2>&1
            reg add HKLM\SYSTEM\CurrentControlSet\Control\LSA /v LogToFile /t REG_DWORD /d 1 /f 2>&1
            reg add HKLM\SYSTEM\CurrentControlSet\Control\LSA /v NegEventMask /t REG_DWORD /d 0xF /f 2>&1
            
            # NEGOEXT
            reg add HKLM\SYSTEM\CurrentControlSet\Control\Lsa\NegoExtender\Parameters /v InfoLevel /t REG_DWORD /d 0xFFFF /f 2>&1 | Out-Null

            # PKU2U
            reg add HKLM\SYSTEM\CurrentControlSet\Control\Lsa\Pku2u\Parameters /v InfoLevel /t REG_DWORD /d 0xFFFF /f 2>&1 | Out-Null

            # LSP Logging
            reg add HKLM\SYSTEM\CurrentControlSet\Control\LSA /v LspDbgInfoLevel /t REG_DWORD /d 0x41C20800 /f 2>&1 | Out-Null
            reg add HKLM\SYSTEM\CurrentControlSet\Control\LSA /v LspDbgTraceOptions /t REG_DWORD /d 0x1 /f 2>&1 | Out-Null



            # Start Logman LSA
            $LSASingleTraceName = "SQLTraceLSA"
            $result = logman start trace $LSASingleTraceName -o "$($global:LogFolderName)\Auth\LSA%d.etl" -mode NewFile -max 300 -ets
            LogInfo "LSA: $result"

            ForEach($LSAProvider in $LSAProviders)
            {
                # "Updating: $LSAProvider" # debug statement
                # Update Logman LSA
                $LSAParams = $LSAProvider.Split('!')
                $LSASingleTraceGUID = $LSAParams[0]
                $LSASingleTraceFlags = $LSAParams[1]
        
                $result = logman update trace $LSASingleTraceName -p `"$LSASingleTraceGUID`" $LSASingleTraceFlags 0xff -ets
                LogInfo "LSA: $result"
            }

            # Values for DeleteOldFiles
            $CleanupValues = "$($global:LogFolderName)\Auth\LSA*.etl", $global:INISettings.MinMinutes, $global:INISettings.MinFiles    # Filespec, min_minutes, min_files
            $PathsToClean.Add("LSA", $CleanupValues)
        }

    }

    # Not controlled by the Auth Flag
    if($global:INISettings.EventViewer -eq "Yes")
    {

        LogInfo "Enabling/Collecting Event Viewer Logs..."
        # Enable Eventvwr logging
        $result = wevtutil.exe set-log "Microsoft-Windows-CAPI2/Operational" /enabled:true /ms:102400000 2>&1
        LogInfo "CAPI2 events: $result"
        $result = wevtutil.exe set-log "Microsoft-Windows-Kerberos/Operational" /enabled:true /rt:false /q:true 2>&1
        LogInfo "Kerberos events: $result"
    }
}

# ================================================= Stop Traces ====================================================

Function StopTraces
{
    Write-EventLog -LogName Application -Source $global:EventSourceName -EventID 3003 -Message "SQLTrace is stopping."
    LogInfo "Stopping Traces ..."
    netstat -abon > "$($global:LogFolderName)\NetStatAtEnd.txt"
    tasklist > "$($global:LogFolderName)\TasklistAtEnd.txt"
    StopBIDTraces
    StopNetworkTraces
    StopAuthenticationTraces
    StopDeleteOldFiles
    CopySqlErrorLog
    LogInfo "Traces have stopped ..."
    LogRaw ""
    LogRaw "Please ZIP the contents of ""$($global:LogFolderName)"" and upload to Microsoft for analysis."
    LogRaw "Please see our GitHub site for more information: https://github.com/microsoft/CSS_SQL_Networking_Tools"
    Write-EventLog -LogName Application -Source $global:EventSourceName -EventID 3004 -Message "SQLTrace has stopped."
}

Function StopBIDTraces
{
    if($global:INISettings.BidTrace -eq "Yes")
    {
        LogInfo "Stopping BID Traces ..."
		# Do not clear the registry keys in case we run a second trace; use the -cleanup switch explicitly
        logman stop SQLTraceBID -ets
    }
}


Function StopNetworkTraces
{
    
    if($global:INISettings.NETTrace -eq "Yes")
    {

        LogInfo "Stopping Network Traces..."
        if($global:INISettings.NETSH -eq "Yes")
        {
            LogInfo "Stopping NETSH..."
            # netsh trace stop
            logman stop SQLTraceNDIS -ets
            netsh trace stop

            if (Test-Path "$($global:LogFolderName)\NetworkTraces\deleteme.etl")
            {
               del "$($global:LogFolderName)\NetworkTraces\deleteme.etl"
            }
             
            if (Test-Path "$($global:LogFolderName)\NetworkTraces\deleteme.cab")
            {
             Rename-Item "$($global:LogFolderName)\NetworkTraces\deleteme.cab" "network_settings.cab"
            }
        }
        if($global:INISettings.PSNETCAPTURE -eq "Yes")
        {
            logman stop SQLTraceNDIS -ets
            Stop-NetEventSession -Name "PSTraceNDIS"
            Remove-NetEventSession -Name "PSTraceNDIS"

            if (Test-Path "$($global:LogFolderName)\NetworkTraces\deleteme.etl")
            {
               del "$($global:LogFolderName)\NetworkTraces\deleteme.etl"
            }
        }
        if($global:INISettings.NETMON -eq "Yes")
        {
            $NetmonPID = Get-Process -Name "nmcap"
            LogInfo "Stopping Network Monitor with PID: " + $NetmonPID.ID
            nslookup "stopsqltrace.microsoft.com" 2>&1 | Out-Null     # Why the 2>&1 pipe? Do we still need that?
        }
        if($global:INISettings.WIRESHARK -eq "Yes")
        {
            $WiresharkPID = Get-Process -Name "dumpcap"
            LogInfo "Stopping Wireshark with PID: " + $WiresharkPID.ID
            Stop-Process -Name "dumpcap" -Force
        }
        if($global:INISettings.PKTMON -eq "Yes")
        {
            LogInfo "Stopping Pktmon..."
            pktmon stop
            pktmon filter remove
        }
    }
}

Function StopAuthenticationTraces
{

    if($global:INISettings.AuthTrace -eq "Yes")
    {

        if($global:INISettings.Kerberos -eq "Yes")
        {
            LogInfo "Stopping Kerberos ETL Traces..."
            logman stop "SQLTraceKerberos" -ets
            reg delete HKLM\SYSTEM\CurrentControlSet\Control\LSA\Kerberos\Parameters /v LogLevel /f  2>&1
        }
        if($global:INISettings.Credssp -eq "Yes")
        {
            LogInfo "Stopping CredSSP/NTLM Traces..."
            logman stop "SQLTraceNtlm_CredSSP" -ets
        }
        if($global:INISettings.SSL -eq "Yes")
        {
            LogInfo "Stopping SSL Traces..."
            logman stop "SQLTraceSSL" -ets
        }
        if($global:INISettings.LSA -eq "Yes")
        {
            LogInfo "Stopping LSA Traces..."
            #Netlogon
            nltest /dbflag:0x0  2>&1 | Out-Null

            #LSA
            reg delete HKLM\SYSTEM\CurrentControlSet\Control\LSA /v SPMInfoLevel /f  2>&1 | Out-Null
            reg delete HKLM\SYSTEM\CurrentControlSet\Control\LSA /v LogToFile /f  2>&1 | Out-Null
            reg delete HKLM\SYSTEM\CurrentControlSet\Control\LSA /v NegEventMask /f  2>&1 | Out-Null
			
            #NegoExt
            reg delete HKLM\SYSTEM\CurrentControlSet\Control\LSA\NegoExtender\Parameters /v InfoLevel /f  2>&1 | Out-Null
            
            #Pku2u
            reg delete HKLM\SYSTEM\CurrentControlSet\Control\LSA\Pku2u\Parameters /v InfoLevel /f  2>&1 | Out-Null
            
            #LSP
            reg delete HKLM\SYSTEM\CurrentControlSet\Control\LSA /v LspDbgInfoLevel /f  2>&1 | Out-Null
            reg delete HKLM\SYSTEM\CurrentControlSet\Control\LSA /v LspDbgTraceOptions /f  2>&1 | Out-Null
            
            logman stop "SQLTraceLSA" -ets

            Copy-Item -Path "$($env:windir)\debug\Netlogon.*" -Destination "$($global:LogFolderName)\Auth" -Force 2>&1

            if (Test-Path "$($env:windir)\system32\Lsass.log")
            {
                Copy-Item -Path "$($env:windir)\system32\Lsass.log" -Destination "$($global:LogFolderName)\Auth" -Force 2>&1
            }
            else
            {
                LogWarning "File $($env:windir)\system32\Lsass.log does not exist."
            }
        }
    }

    # Not controlled by the Auth Flag
    if($global:INISettings.EventViewer -eq "Yes")
    {
		
		if((Test-Path "$($global:LogFolderName)\Auth" -PathType Container) -eq $false)
		{
            md "$($global:LogFolderName)\Auth" > $null
        }

        LogInfo "Disabling/Collecting Event Viewer Logs..."
			
		# Filter to just the last 24 hours:                                                "/q:*[System[TimeCreated[timediff(@SystemTime) <= 86400000]]]"
		# Alternate filter, events after a set time. Use variables in implementation:      "/q:*[System[TimeCreated[@SystemTime>='2022-08-08T10:00:00']]]"
		$EventLogFilter = "/q:*[System[TimeCreated[timediff(@SystemTime) <= 86400000]]]"
			
        # Event/Operational logs
        wevtutil.exe set-log "Microsoft-Windows-CAPI2/Operational" /enabled:false  2>&1   # stop logging
        wevtutil.exe export-log "Microsoft-Windows-CAPI2/Operational" "$($global:LogFolderName)\Auth\Capi2_Oper.evtx" "$EventLogFilter" /overwrite:true  2>&1  # export recent events to .evtx
		wevtutil.exe query-events "Microsoft-Windows-CAPI2/Operational" "$EventLogFilter" /f:Text > "$($global:LogFolderName)\Auth\Capi2_Oper.txt"             # export recent events to .txt
			
        wevtutil.exe set-log "Microsoft-Windows-Kerberos/Operational" /enabled:false  2>&1   # stop logging
        wevtutil.exe export-log "Microsoft-Windows-Kerberos/Operational" "$($global:LogFolderName)\Auth\Kerb_Oper.evtx" "$EventLogFilter" /overwrite:true  2>&1  # export recent events to .evtx
		wevtutil.exe query-events "Microsoft-Windows-Kerberos/Operational" "$EventLogFilter" /f:Text > "$($global:LogFolderName)\Auth\Kerb_Oper.txt"             # export recent events to .txt

        # Main event logs - security, system, and application
        wevtutil.exe export-log SECURITY "$($global:LogFolderName)\Auth\Security.evtx" "$EventLogFilter" /overwrite:true  2>&1        # export recent events to .evtx
		wevtutil.exe query-events SECURITY "$EventLogFilter" /f:Text > "$($global:LogFolderName)\Auth\Security.txt"                   # export recent events to .txt
			
        wevtutil.exe export-log SYSTEM "$($global:LogFolderName)\Auth\System.evtx" "$EventLogFilter" /overwrite:true  2>&1            # export recent events to .evtx
		wevtutil.exe query-events SYSTEM "$EventLogFilter" /f:Text > "$($global:LogFolderName)\Auth\System.txt"                       # export recent events to .txt
			
        wevtutil.exe export-log APPLICATION "$($global:LogFolderName)\Auth\Application.evtx" "$EventLogFilter" /overwrite:true  2>&1  # export recent events to .evtx
		wevtutil.exe query-events APPLICATION "$EventLogFilter" /f:Text > "$($global:LogFolderName)\Auth\Application.txt"             # export recent events to .txt
    }
}

# Function CopySQLErrorLog
# Searches for the Log folder of each SQL instance installed on the server
# Makes a copy of ERRORLOG and Extended Events as long as the file size is lower than 500MB
Function CopySQLErrorLog()
{
    if(($global:INISettings.SQLErrorLog -eq "Yes") -or ($global:INISettings.SQLXEventLog -eq "Yes"))
    {
        LogInfo "Saving SQL Server files"

        if (!(Test-Path "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL"))
        {
            LogInfo "No SQL Server instances were found on this machine."
            return;
        }

        $SQLKey = Get-Item "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL"
        $ValueNames = $SQLKey.GetValueNames()
        cd $($global:LogFolderName)
        mkdir "SQLLogFolder" | out-null
        cd "SQLLogFolder" | out-null
        ForEach ($ValueName in $ValueNames)
        {
           LogInfo("Copying SQL files for instance: $ValueName")
           mkdir $ValueName | out-null
           $instanceFolderName = $SQLKey.GetValue($ValueName); #Get Instance Folder Name
           $errorLogPath = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$instanceFolderName\MSSQLServer\Parameters\").psobject.properties |
              where {$_.value -like "*ERRORLOG*"} |
                select value

            #Remove any parameter prior to the path
            $errorLogPath = $($errorLogPath.Value.ToString()).Substring(2)
            #Clear the error log from the string
            $errorLogPath = $errorLogPath.Substring(0,$errorLogPath.LastIndexOf('\')+1)
        
            if ($global:INISettings.SQLErrorLog -eq "Yes")
            {
                #Copy Error Log files as long as they are less than 500Mb
                $items=Get-ChildItem $errorLogPath -filter ERRORLOG* | Where { $_.Length -lt 500MB}
                Foreach($item in $items){
                copy-item $item.fullname .\$ValueName -force
                }
            }

            if ($global:INISettings.SQLXEventLog -eq "Yes")
            {
                #Copy XEvents Log files as long as they are less than 500Mb
                $items=Get-ChildItem $errorLogPath -filter *.xel | Where { $_.Length -lt 500MB}
                Foreach($item in $items){
                copy-item $item.fullname .\$ValueName -force
                }
            }

        }

        cd .. | out-null
        cd .. | out-null
    }

}

# ======================================= Cleanup Traces =========================================

Function CleanupTraces
{
	CleanEnvironment
	ClearBIDRegistry
}

Function CleanEnvironment
{
    # After we stop tracing, clear the environment variable, so we do not re-use the folder name
    [System.Environment]::SetEnvironmentVariable($global:LogFolderEnvName, $null, [System.EnvironmentVariableTarget]::Machine)
}

Function ClearBIDRegistry
{
	LogInfo "Clearing BID trace registry keys ..."
	if($global:INISettings.BidWow -eq "Only")
	{
		LogInfo "BIDTrace - Unset BIDInterface WOW64 MSDADIAG.DLL"
		reg delete HKLM\Software\WOW6432Node\Microsoft\BidInterface\Loader /v :Path /f
	}
	elseif($global:INISettings.BidWow -eq "Both")
	{
		LogInfo "BIDTrace - Unset BIDInterface MSDADIAG.DLL"
		reg delete HKLM\Software\Microsoft\BidInterface\Loader /v :Path /f

		LogInfo "BIDTrace - Unset BIDInterface WOW64 MSDADIAG.DLL"
		reg delete HKLM\Software\WOW6432Node\Microsoft\BidInterface\Loader /v :Path /f
	}
	else ## BIDWOW = No
	{
		LogInfo "BIDTrace - Unset BIDInterface MSDADIAG.DLL"
		reg delete HKLM\Software\Microsoft\BidInterface\Loader /v :Path /f
	}
}

# ============================= Background Job DeleteOldFiles ===================

Function StartDeleteOldFiles
{
    param ($FilesToDelete)

    LogInfo "DeleteOldFiles job starting ..."
    LogInfo "Files being monitored:"
    foreach ($Name in $FilesToDelete.Keys)
    {
        $PathToClean = $FilesToDelete[$Name]
        $FileSpec = $PathToClean[0]
        $MinMinutes = $PathToClean[1]
        $MinFiles = $PathToClean[2]
        LogInfo "$Name=$fileSpec, Min Minutes=$MinMinutes, Min Files=$MinFiles"
    }

    $jobname = "DeleteOldFiles"
  
    $job=Register-ScheduledJob  -Name "DeleteOldFiles" -scriptblock {  
        Param ( $FilesToDelete )
        foreach ($Name in $FilesToDelete.Keys)
        {
            $PathToClean = $FilesToDelete[$Name]
            $FileSpec = $PathToClean[0]
            $MinMinutes = $PathToClean[1] -as [int]
            $MinFiles = $PathToClean[2] -as  [int]
            get-item $FileSpec | sort-object -property LastWriteTime -descending | select -skip $MinFiles | where-object {$_.LastWriteTime -lt ((get-date).AddMinutes($MinMinutes * -1))}  | remove-item -force
        }
    } -ArgumentList $FilesToDelete
    $job.Options.RunElevated=$True
    $cleanupJob=New-JobTrigger -Once -At (get-date).AddSeconds(2) -RepetitionInterval (New-TimeSpan -Minutes 5) -RepeatIndefinitely   # runs once every 5 minutes
    Add-JobTrigger -Trigger $cleanupjob -Name $jobname    
}

Function StopDeleteOldFiles
{
	LogInfo "DeleteOldFiles job stopping ..."
	$jobname = "DeleteOldFiles"
    try
    {
        Stop-Job $jobname -ErrorAction SilentlyContinue
        Remove-Job $jobname -Force -ErrorAction SilentlyContinue
        Remove-JobTrigger $jobname -ErrorAction SilentlyContinue
        UnRegister-ScheduledJob -Name $jobname -Force -ErrorAction SilentlyContinue
		LogInfo "Stopped the DeleteOldFiles job."
    }
    catch { LogInfo "Error stopping the DeleteOldFiles job." }
}

# ======================================= Logging ===============================

Function LogMessage($Message, $LogLevel = "info")
{
    # Determine colors from log level - defaults are for info or any unknown log level
    $ForeColor = "White"

    # Build raw message or decorated message
    if ($LogLevel -eq "Raw")
    {
        $LogMessage = $Message
    }
    else
    {
        $LevelText = "INFO"
        switch ($LogLevel)
        {
            "Warning" { $ForeColor = "Yellow"; $LevelText = "WARN"; }
            "Error"   { $ForeColor = "Red";    $LevelText = "ERR "; }
        }

        # timestamp prefix
        $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss.fff")

        $LogMessage = "$Stamp $LevelText    $Message"
    }

	Write-Host $LogMessage -ForegroundColor $ForeColor
    if ($global:LogFolderName.Length -gt 0) { $LogMessage >> $global:LogProgressFileName }
}

Function LogRaw($Message)     { LogMessage $Message "Raw";     }
Function LogInfo($Message)    { LogMessage $Message "Info";    }
Function LogWarning($Message) { LogMessage $Message "Warning"; }
Function LogError($Message)   { LogMessage $Message "Error";   }

# ================================= start everything here =======================
Main
# ===============================================================================
# SIG # Begin signature block
# MIIoQwYJKoZIhvcNAQcCoIIoNDCCKDACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDneZxaNWVBkDEQ
# AyFlTkpIA5f7wB6uZo4294TP5HglyKCCDXYwggX0MIID3KADAgECAhMzAAAEBGx0
# Bv9XKydyAAAAAAQEMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMjQwOTEyMjAxMTE0WhcNMjUwOTExMjAxMTE0WjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQC0KDfaY50MDqsEGdlIzDHBd6CqIMRQWW9Af1LHDDTuFjfDsvna0nEuDSYJmNyz
# NB10jpbg0lhvkT1AzfX2TLITSXwS8D+mBzGCWMM/wTpciWBV/pbjSazbzoKvRrNo
# DV/u9omOM2Eawyo5JJJdNkM2d8qzkQ0bRuRd4HarmGunSouyb9NY7egWN5E5lUc3
# a2AROzAdHdYpObpCOdeAY2P5XqtJkk79aROpzw16wCjdSn8qMzCBzR7rvH2WVkvF
# HLIxZQET1yhPb6lRmpgBQNnzidHV2Ocxjc8wNiIDzgbDkmlx54QPfw7RwQi8p1fy
# 4byhBrTjv568x8NGv3gwb0RbAgMBAAGjggFzMIIBbzAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQU8huhNbETDU+ZWllL4DNMPCijEU4w
# RQYDVR0RBD4wPKQ6MDgxHjAcBgNVBAsTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEW
# MBQGA1UEBRMNMjMwMDEyKzUwMjkyMzAfBgNVHSMEGDAWgBRIbmTlUAXTgqoXNzci
# tW2oynUClTBUBgNVHR8ETTBLMEmgR6BFhkNodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpb3BzL2NybC9NaWNDb2RTaWdQQ0EyMDExXzIwMTEtMDctMDguY3JsMGEG
# CCsGAQUFBwEBBFUwUzBRBggrBgEFBQcwAoZFaHR0cDovL3d3dy5taWNyb3NvZnQu
# Y29tL3BraW9wcy9jZXJ0cy9NaWNDb2RTaWdQQ0EyMDExXzIwMTEtMDctMDguY3J0
# MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQELBQADggIBAIjmD9IpQVvfB1QehvpC
# Ge7QeTQkKQ7j3bmDMjwSqFL4ri6ae9IFTdpywn5smmtSIyKYDn3/nHtaEn0X1NBj
# L5oP0BjAy1sqxD+uy35B+V8wv5GrxhMDJP8l2QjLtH/UglSTIhLqyt8bUAqVfyfp
# h4COMRvwwjTvChtCnUXXACuCXYHWalOoc0OU2oGN+mPJIJJxaNQc1sjBsMbGIWv3
# cmgSHkCEmrMv7yaidpePt6V+yPMik+eXw3IfZ5eNOiNgL1rZzgSJfTnvUqiaEQ0X
# dG1HbkDv9fv6CTq6m4Ty3IzLiwGSXYxRIXTxT4TYs5VxHy2uFjFXWVSL0J2ARTYL
# E4Oyl1wXDF1PX4bxg1yDMfKPHcE1Ijic5lx1KdK1SkaEJdto4hd++05J9Bf9TAmi
# u6EK6C9Oe5vRadroJCK26uCUI4zIjL/qG7mswW+qT0CW0gnR9JHkXCWNbo8ccMk1
# sJatmRoSAifbgzaYbUz8+lv+IXy5GFuAmLnNbGjacB3IMGpa+lbFgih57/fIhamq
# 5VhxgaEmn/UjWyr+cPiAFWuTVIpfsOjbEAww75wURNM1Imp9NJKye1O24EspEHmb
# DmqCUcq7NqkOKIG4PVm3hDDED/WQpzJDkvu4FrIbvyTGVU01vKsg4UfcdiZ0fQ+/
# V0hf8yrtq9CkB8iIuk5bBxuPMIIHejCCBWKgAwIBAgIKYQ6Q0gAAAAAAAzANBgkq
# hkiG9w0BAQsFADCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24x
# EDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlv
# bjEyMDAGA1UEAxMpTWljcm9zb2Z0IFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5
# IDIwMTEwHhcNMTEwNzA4MjA1OTA5WhcNMjYwNzA4MjEwOTA5WjB+MQswCQYDVQQG
# EwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSgwJgYDVQQDEx9NaWNyb3NvZnQg
# Q29kZSBTaWduaW5nIFBDQSAyMDExMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIIC
# CgKCAgEAq/D6chAcLq3YbqqCEE00uvK2WCGfQhsqa+laUKq4BjgaBEm6f8MMHt03
# a8YS2AvwOMKZBrDIOdUBFDFC04kNeWSHfpRgJGyvnkmc6Whe0t+bU7IKLMOv2akr
# rnoJr9eWWcpgGgXpZnboMlImEi/nqwhQz7NEt13YxC4Ddato88tt8zpcoRb0Rrrg
# OGSsbmQ1eKagYw8t00CT+OPeBw3VXHmlSSnnDb6gE3e+lD3v++MrWhAfTVYoonpy
# 4BI6t0le2O3tQ5GD2Xuye4Yb2T6xjF3oiU+EGvKhL1nkkDstrjNYxbc+/jLTswM9
# sbKvkjh+0p2ALPVOVpEhNSXDOW5kf1O6nA+tGSOEy/S6A4aN91/w0FK/jJSHvMAh
# dCVfGCi2zCcoOCWYOUo2z3yxkq4cI6epZuxhH2rhKEmdX4jiJV3TIUs+UsS1Vz8k
# A/DRelsv1SPjcF0PUUZ3s/gA4bysAoJf28AVs70b1FVL5zmhD+kjSbwYuER8ReTB
# w3J64HLnJN+/RpnF78IcV9uDjexNSTCnq47f7Fufr/zdsGbiwZeBe+3W7UvnSSmn
# Eyimp31ngOaKYnhfsi+E11ecXL93KCjx7W3DKI8sj0A3T8HhhUSJxAlMxdSlQy90
# lfdu+HggWCwTXWCVmj5PM4TasIgX3p5O9JawvEagbJjS4NaIjAsCAwEAAaOCAe0w
# ggHpMBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBRIbmTlUAXTgqoXNzcitW2o
# ynUClTAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTALBgNVHQ8EBAMCAYYwDwYD
# VR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBRyLToCMZBDuRQFTuHqp8cx0SOJNDBa
# BgNVHR8EUzBRME+gTaBLhklodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2Ny
# bC9wcm9kdWN0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFfMDNfMjIuY3JsMF4GCCsG
# AQUFBwEBBFIwUDBOBggrBgEFBQcwAoZCaHR0cDovL3d3dy5taWNyb3NvZnQuY29t
# L3BraS9jZXJ0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFfMDNfMjIuY3J0MIGfBgNV
# HSAEgZcwgZQwgZEGCSsGAQQBgjcuAzCBgzA/BggrBgEFBQcCARYzaHR0cDovL3d3
# dy5taWNyb3NvZnQuY29tL3BraW9wcy9kb2NzL3ByaW1hcnljcHMuaHRtMEAGCCsG
# AQUFBwICMDQeMiAdAEwAZQBnAGEAbABfAHAAbwBsAGkAYwB5AF8AcwB0AGEAdABl
# AG0AZQBuAHQALiAdMA0GCSqGSIb3DQEBCwUAA4ICAQBn8oalmOBUeRou09h0ZyKb
# C5YR4WOSmUKWfdJ5DJDBZV8uLD74w3LRbYP+vj/oCso7v0epo/Np22O/IjWll11l
# hJB9i0ZQVdgMknzSGksc8zxCi1LQsP1r4z4HLimb5j0bpdS1HXeUOeLpZMlEPXh6
# I/MTfaaQdION9MsmAkYqwooQu6SpBQyb7Wj6aC6VoCo/KmtYSWMfCWluWpiW5IP0
# wI/zRive/DvQvTXvbiWu5a8n7dDd8w6vmSiXmE0OPQvyCInWH8MyGOLwxS3OW560
# STkKxgrCxq2u5bLZ2xWIUUVYODJxJxp/sfQn+N4sOiBpmLJZiWhub6e3dMNABQam
# ASooPoI/E01mC8CzTfXhj38cbxV9Rad25UAqZaPDXVJihsMdYzaXht/a8/jyFqGa
# J+HNpZfQ7l1jQeNbB5yHPgZ3BtEGsXUfFL5hYbXw3MYbBL7fQccOKO7eZS/sl/ah
# XJbYANahRr1Z85elCUtIEJmAH9AAKcWxm6U/RXceNcbSoqKfenoi+kiVH6v7RyOA
# 9Z74v2u3S5fi63V4GuzqN5l5GEv/1rMjaHXmr/r8i+sLgOppO6/8MO0ETI7f33Vt
# Y5E90Z1WTk+/gFcioXgRMiF670EKsT/7qMykXcGhiJtXcVZOSEXAQsmbdlsKgEhr
# /Xmfwb1tbWrJUnMTDXpQzTGCGiMwghofAgEBMIGVMH4xCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNp
# Z25pbmcgUENBIDIwMTECEzMAAAQEbHQG/1crJ3IAAAAABAQwDQYJYIZIAWUDBAIB
# BQCgga4wGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEO
# MAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIChfLtVFadngL4+sjtHf1i8W
# siA2YN1HOkYbUdxDciMiMEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8A
# cwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEB
# BQAEggEAQW9L4B2X2z3DlOZN0M8hk2Io+Ox3Josbc7CB5tZFKJBVp4Btoods6S07
# rtp0yWRpWRZ9E4BQBV12mOlU5Z2r12ZNlf8gP3HVfac91mqAUbSiEdP1SqxaZQvI
# 0cv0gNOUA96tzKvQohWt6SBTZv3UZF3OjTFOXDIe07Wq7v64KXE4AApsr2dVPubZ
# cT+THtfV6MT/PrVJ9sGmwc90lvC7K1QxpbHXPd0hYGi74iqfu6NP6jq3NoFs/2th
# 8xRMu8ARDIptxkXjr+GefmPfdCtjEg+KhKt+PaThh4UrZPWUBoKyf+9qn0Fr0GiP
# iy5qmNc9/8f5geI0lxjyo6Feht678KGCF60wghepBgorBgEEAYI3AwMBMYIXmTCC
# F5UGCSqGSIb3DQEHAqCCF4YwgheCAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFaBgsq
# hkiG9w0BCRABBKCCAUkEggFFMIIBQQIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFl
# AwQCAQUABCDFRohc9nYAYgqI+R/nWos9ZlyAFJgVDA0aL+vZJUZs9wIGZzu/Dkl1
# GBMyMDI0MTEyMDIxMjgxMi4yNjNaMASAAgH0oIHZpIHWMIHTMQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMS0wKwYDVQQLEyRNaWNyb3NvZnQgSXJl
# bGFuZCBPcGVyYXRpb25zIExpbWl0ZWQxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVT
# TjozMjFBLTA1RTAtRDk0NzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAg
# U2VydmljZaCCEfswggcoMIIFEKADAgECAhMzAAAB+KOhJgwMQEj+AAEAAAH4MA0G
# CSqGSIb3DQEBCwUAMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9u
# MRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRp
# b24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMB4XDTI0
# MDcyNTE4MzEwOFoXDTI1MTAyMjE4MzEwOFowgdMxCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xLTArBgNVBAsTJE1pY3Jvc29mdCBJcmVsYW5kIE9w
# ZXJhdGlvbnMgTGltaXRlZDEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjMyMUEt
# MDVFMC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNl
# MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAxR23pXYnD2BuODdeXs2C
# u/T5kKI+bAw8cbtN50Cm/FArjXyL4RTqMe6laQ/CqeMTxgckvZr1JrW0Mi4F15rx
# /VveGhKBmob45DmOcV5xyx7h9Tk59NAl5PNMAWKAIWf270SWAAWxQbpVIhhPWCnV
# V3otVvahEad8pMmoSXrT5Z7Nk1RnB70A2bq9Hk8wIeC3vBuxEX2E8X50IgAHsyaR
# 9roFq3ErzUEHlS8YnSq33ui5uBcrFOcFOCZILuVFVTgEqSrX4UiX0etqi7jUtKyp
# gIflaZcV5cI5XI/eCxY8wDNmBprhYMNlYxdmQ9aLRDcTKWtddWpnJtyl5e3gHuYo
# j8xuDQ0XZNy7ESRwJIK03+rTZqfaYyM4XSK1s0aa+mO69vo/NmJ4R/f1+KucBPJ4
# yUdbqJWM3xMvBwLYycvigI/WK4kgPog0UBNczaQwDVXpcU+TMcOvWP8HBWmWJQIm
# TZInAFivXqUaBbo3wAfPNbsQpvNNGu/12pg0F8O/CdRfgPHfOhIWQ0D8ALCY+Lsi
# wbzcejbrVl4N9fn2wOg2sDa8RfNoD614I0pFjy/lq1NsBo9V4GZBikzX7ZjWCRgd
# 1FCBXGpfpDikHjQ05YOkAakdWDT2bGSaUZJGVYtepIpPTAs1gd/vUogcdiL51o7s
# huHIlB6QSUiQ24XYhRbbQCECAwEAAaOCAUkwggFFMB0GA1UdDgQWBBS9zsZzz57Q
# lT5nrt/oitLv1OQ7tjAfBgNVHSMEGDAWgBSfpxVdAF5iXYP05dJlpxtTNRnpcjBf
# BgNVHR8EWDBWMFSgUqBQhk5odHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3Bz
# L2NybC9NaWNyb3NvZnQlMjBUaW1lLVN0YW1wJTIwUENBJTIwMjAxMCgxKS5jcmww
# bAYIKwYBBQUHAQEEYDBeMFwGCCsGAQUFBzAChlBodHRwOi8vd3d3Lm1pY3Jvc29m
# dC5jb20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMFRpbWUtU3RhbXAlMjBQQ0El
# MjAyMDEwKDEpLmNydDAMBgNVHRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUF
# BwMIMA4GA1UdDwEB/wQEAwIHgDANBgkqhkiG9w0BAQsFAAOCAgEAYfk8GzzpEVnG
# l7y6oXoytCb42Hx6TOA0+dkaBI36ftDE9tLubUa/xMbHB5rcNiRhFHZ93RefdPpc
# 4+FF0DAl5lP8xKAO+293RWPKDFOFIxgtZY08t8D9cSQpgGUzyw3lETZebNLEA17A
# /CTpA2F9uh8j84KygeEbj+bidWDiEfayoH2A5/5ywJJxIuLzFVHacvWxSCKoF9hl
# SrZSG5fXWS3namf4tt690UT6AGyWLFWe895coFPxm/m0UIMjjp9VRFH7nb3Ng2Q4
# gPS9E5ZTMZ6nAlmUicDj0NXAs2wQuQrnYnbRAJ/DQW35qLo7Daw9AsItqjFhbMcG
# 68gDc4j74L2KYe/2goBHLwzSn5UDftS1HZI0ZRsqmNHI0TZvvUWX9ajm6SfLBTEt
# oTo6gLOX0UD/9rrhGjdkiCw4SwU5osClgqgiNMK5ndk2gxFlDXHCyLp5qB6BoPpc
# 82RhO0yCzoP9gv7zv2EocAWEsqE5+0Wmu5uarmfvcziLfU1SY240OZW8ld4sS8fn
# ybn/jDMmFAhazV1zH0QERWEsfLSpwkOXaImWNFJ5lmcnf1VTm6cmfasScYtElpjq
# Z9GooCmk1XFApORPs/PO43IcFmPRwagt00iQSw+rBeIH00KQq+FJT/62SB70g9g/
# R8TS6k6b/wt2UWhqrW+Q8lw6Xzgex/YwggdxMIIFWaADAgECAhMzAAAAFcXna54C
# m0mZAAAAAAAVMA0GCSqGSIb3DQEBCwUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UE
# CBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9z
# b2Z0IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUm9vdCBDZXJ0aWZp
# Y2F0ZSBBdXRob3JpdHkgMjAxMDAeFw0yMTA5MzAxODIyMjVaFw0zMDA5MzAxODMy
# MjVaMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQH
# EwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNV
# BAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMIICIjANBgkqhkiG9w0B
# AQEFAAOCAg8AMIICCgKCAgEA5OGmTOe0ciELeaLL1yR5vQ7VgtP97pwHB9KpbE51
# yMo1V/YBf2xK4OK9uT4XYDP/XE/HZveVU3Fa4n5KWv64NmeFRiMMtY0Tz3cywBAY
# 6GB9alKDRLemjkZrBxTzxXb1hlDcwUTIcVxRMTegCjhuje3XD9gmU3w5YQJ6xKr9
# cmmvHaus9ja+NSZk2pg7uhp7M62AW36MEBydUv626GIl3GoPz130/o5Tz9bshVZN
# 7928jaTjkY+yOSxRnOlwaQ3KNi1wjjHINSi947SHJMPgyY9+tVSP3PoFVZhtaDua
# Rr3tpK56KTesy+uDRedGbsoy1cCGMFxPLOJiss254o2I5JasAUq7vnGpF1tnYN74
# kpEeHT39IM9zfUGaRnXNxF803RKJ1v2lIH1+/NmeRd+2ci/bfV+AutuqfjbsNkz2
# K26oElHovwUDo9Fzpk03dJQcNIIP8BDyt0cY7afomXw/TNuvXsLz1dhzPUNOwTM5
# TI4CvEJoLhDqhFFG4tG9ahhaYQFzymeiXtcodgLiMxhy16cg8ML6EgrXY28MyTZk
# i1ugpoMhXV8wdJGUlNi5UPkLiWHzNgY1GIRH29wb0f2y1BzFa/ZcUlFdEtsluq9Q
# BXpsxREdcu+N+VLEhReTwDwV2xo3xwgVGD94q0W29R6HXtqPnhZyacaue7e3Pmri
# Lq0CAwEAAaOCAd0wggHZMBIGCSsGAQQBgjcVAQQFAgMBAAEwIwYJKwYBBAGCNxUC
# BBYEFCqnUv5kxJq+gpE8RjUpzxD/LwTuMB0GA1UdDgQWBBSfpxVdAF5iXYP05dJl
# pxtTNRnpcjBcBgNVHSAEVTBTMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIB
# FjNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9y
# eS5odG0wEwYDVR0lBAwwCgYIKwYBBQUHAwgwGQYJKwYBBAGCNxQCBAweCgBTAHUA
# YgBDAEEwCwYDVR0PBAQDAgGGMA8GA1UdEwEB/wQFMAMBAf8wHwYDVR0jBBgwFoAU
# 1fZWy4/oolxiaNE9lJBb186aGMQwVgYDVR0fBE8wTTBLoEmgR4ZFaHR0cDovL2Ny
# bC5taWNyb3NvZnQuY29tL3BraS9jcmwvcHJvZHVjdHMvTWljUm9vQ2VyQXV0XzIw
# MTAtMDYtMjMuY3JsMFoGCCsGAQUFBwEBBE4wTDBKBggrBgEFBQcwAoY+aHR0cDov
# L3d3dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNSb29DZXJBdXRfMjAxMC0w
# Ni0yMy5jcnQwDQYJKoZIhvcNAQELBQADggIBAJ1VffwqreEsH2cBMSRb4Z5yS/yp
# b+pcFLY+TkdkeLEGk5c9MTO1OdfCcTY/2mRsfNB1OW27DzHkwo/7bNGhlBgi7ulm
# ZzpTTd2YurYeeNg2LpypglYAA7AFvonoaeC6Ce5732pvvinLbtg/SHUB2RjebYIM
# 9W0jVOR4U3UkV7ndn/OOPcbzaN9l9qRWqveVtihVJ9AkvUCgvxm2EhIRXT0n4ECW
# OKz3+SmJw7wXsFSFQrP8DJ6LGYnn8AtqgcKBGUIZUnWKNsIdw2FzLixre24/LAl4
# FOmRsqlb30mjdAy87JGA0j3mSj5mO0+7hvoyGtmW9I/2kQH2zsZ0/fZMcm8Qq3Uw
# xTSwethQ/gpY3UA8x1RtnWN0SCyxTkctwRQEcb9k+SS+c23Kjgm9swFXSVRk2XPX
# fx5bRAGOWhmRaw2fpCjcZxkoJLo4S5pu+yFUa2pFEUep8beuyOiJXk+d0tBMdrVX
# VAmxaQFEfnyhYWxz/gq77EFmPWn9y8FBSX5+k77L+DvktxW/tM4+pTFRhLy/AsGC
# onsXHRWJjXD+57XQKBqJC4822rpM+Zv/Cuk0+CQ1ZyvgDbjmjJnW4SLq8CdCPSWU
# 5nR0W2rRnj7tfqAxM328y+l7vzhwRNGQ8cirOoo6CGJ/2XBjU02N7oJtpQUQwXEG
# ahC0HVUzWLOhcGbyoYIDVjCCAj4CAQEwggEBoYHZpIHWMIHTMQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMS0wKwYDVQQLEyRNaWNyb3NvZnQgSXJl
# bGFuZCBPcGVyYXRpb25zIExpbWl0ZWQxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVT
# TjozMjFBLTA1RTAtRDk0NzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAg
# U2VydmljZaIjCgEBMAcGBSsOAwIaAxUAtkQt/ebWSQ5DnG+aKRzPELCFE9GggYMw
# gYCkfjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYD
# VQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDANBgkqhkiG9w0BAQsF
# AAIFAOroN6owIhgPMjAyNDExMjAxMDI1NDZaGA8yMDI0MTEyMTEwMjU0NlowdDA6
# BgorBgEEAYRZCgQBMSwwKjAKAgUA6ug3qgIBADAHAgEAAgIeBDAHAgEAAgITODAK
# AgUA6umJKgIBADA2BgorBgEEAYRZCgQCMSgwJjAMBgorBgEEAYRZCgMCoAowCAIB
# AAIDB6EgoQowCAIBAAIDAYagMA0GCSqGSIb3DQEBCwUAA4IBAQBsdjW/Y+K6KiE0
# crhGuxRkUi8TwOIhZtHl9WpApAREWmUIgvY/HkfZ/FBA/jPdE6fTMhNTk4KKCBmy
# hK9DlcDOVwNigP5dX027W4vOZ2X33HujSydRx+RL88J4eSmely7Jkay3JhChFJYn
# 6+EHSOhHRfaPdBi+sOUOJg9l/RqsidT3Ycgj9mCqyRbldDj1UnsPcTbdtDdShAG5
# AM8GXTLMFFhIRvoVLIXasUUlWKuaAjzE+GZ5uBHgeDKFfqhpZg22pL1tCCRQ23V1
# ZV1QRXKTCqGCF+qFMGcz+Tp/KAsynY6taNHN7pqsepExOqg6KhpJrdeW1Mencjjb
# W4k9YFO/MYIEDTCCBAkCAQEwgZMwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldh
# c2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBD
# b3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIw
# MTACEzMAAAH4o6EmDAxASP4AAQAAAfgwDQYJYIZIAWUDBAIBBQCgggFKMBoGCSqG
# SIb3DQEJAzENBgsqhkiG9w0BCRABBDAvBgkqhkiG9w0BCQQxIgQg/2OW+vS76EW2
# tntcdDP7pzKERwsAhqk8WSZ2VU2acZQwgfoGCyqGSIb3DQEJEAIvMYHqMIHnMIHk
# MIG9BCDvzDPyXw1UkAUFYt8bR4UdjM90Qv5xnVaiKD3I0Zz3WjCBmDCBgKR+MHwx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1p
# Y3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAAB+KOhJgwMQEj+AAEAAAH4
# MCIEIJocicykAATiy550TST7xkDExAPUOTc4+DBz+ggoxnMXMA0GCSqGSIb3DQEB
# CwUABIICAJSEwQRXAG57ZMJHmWr15HO3ZOLL45q88Xlya6HwwAfOAK40aCMixWmD
# Xg2KBkMFKqTeZX1CRZOix4PgrW5blBd3h+0OdyZ93he+Xjf7cZVhklFP90MXkdbg
# aD1Gxx3Sva0FoRpuvFWtEOfJ+JfsD+wEOoH2oCieEa4hJ2G6+CRamPSLy+JfNlnD
# bm9Vm7ih2zrq/QfRyJdxGmXuG/WnoDrzGeb5Cg7mU/RTvLip+pWrgIdo6tEDWEjp
# fLR8yAvC5EYV3naqiTOYb3cFUOXH3aSwt11AakgG2gJSF0KCu9rvzgrAOFtLx0yY
# CDgtryhGozgRnKRX6+AwdkRn8Uxb+c7c5O9zhhvKnD5GrIZ9FjQ0P9ncbDiC1HaW
# FFinwuLhFVq+Bx3PaieuZ9yzLFKmApGiQq3QY0lNBU3+d9Vxm8VfrEjy9wtuw5Sq
# DQDQ81vatSmmtk2HSgvHloVb4QHsgGmWDjfItmRzPIKChk1/aBtxqrLFVGx+KH45
# z75/FWDQeuncL+4PtyqRlN2xJMEg/XP8rvphWoQpJNtxM8kzjPEDdKM0zXriWZcA
# lXsgF8qWttVYpaHAvCyCgbDmgfe5TykbMXnEycH+BGtlw8BSUbR1Xn8f+Mivd7pJ
# 50UdqxPlZA83mGsOEI9gyAn9Fam10rNOPWMbX7RewlVVhIOp4EpI
# SIG # End signature block
