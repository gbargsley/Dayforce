Import-Module SQLPS
$SqlServer = 'an1prddfcsql016'
$oldDatabaseName = 'eausa'
$newDatabaseName = 'ggainc'
$DatabasePassword = 'LqsCm3Hx'
$AdminServiceDB = 'dfhcmadminservice'
$adminServiceDBServer = 'an1prdcorsql001' 
$ctrlserver = 'an1prdcorsql003'
$ctrldb = 'usr58control'
$ClientId=39545
$Logfile = 'D:\temp\namespacechange\' + $newDatabaseName + '.txt'

 
function DisplayLog {
    param(
        [string]$message,
        [switch]$separator,
        [switch]$error)
    if ($separator) {
        Write-Host ("***********************************************************") 
        Add-Content  $Logfile "`n***********************************************************"
    }
    if ($errormessage) {
        Write-Host ("|")
        Add-Content  $Logfile "`n|"
        Write-Error("| ---- > $message")    
        Add-Content  $Logfile "`n| ---- > $message"
        Write-Host ("|")
        Add-Content  $Logfile "`n|"
    }
    else {
        Write-Host ("|")
        Add-Content  $Logfile "`n|"
        Write-Host ("| ---- > $message")    
        Add-Content  $Logfile "`n| ---- > $message"
        Write-Host ("|")
        Add-Content $Logfile "`n|"
    }
}

function controlDBDeactivate {
    param (
        [string]$ctrlserver,
        [string]$ctrldb,
        [string]$oldDatabaseName
    )

    $SQLText = "
    Declare @Databaseconnection int
    Declare @namespaceid int

    select @Databaseconnection=dc.DatabaseConnectionId, @namespaceid=NamespaceId
                    from  DatabaseConnection  dc
                    join Namespace n on n.DatabaseConnectionid=dc.DatabaseConnectionId
                    where [Name]=N'$oldDatabaseName'


                    update namespace
                    set  ScheduleJobs=0,ExecuteWorkflows=0
                    where DatabaseConnectionid=@Databaseconnection


                    update NamespaceAuthentication
                    set StatusCode='i'
                    where Namespaceid=@namespaceid "


    try {
        Invoke-Sqlcmd -ServerInstance $ctrlserver -Database $ctrldb -Query $SQLText -ConnectionTimeout 1000 -verbose
    } 
    catch {
        throw "Failed to set schedulejob and executeworkflow to 0 and update status code to Inactive"
    }
    DisplayLog -message "Schedulejob and executeworkflow have been set to 0 and status code to Inactive  "
}
function createDBUser {
    param(
        [string]$SqlServer,
        [string]$oldDatabaseName,
        [string]$newDatabaseName,
        [String]$DatabasePassword,
        [int]$SQLTimeout)

    $sqlcreateDBUser = "    Declare  @pwd varchar(50);
                                set @pwd='$DatabasePassword' 
                                IF EXISTS (select name from sys.server_principals where name like '$oldDatabaseName')
                                BEGIN
                                alter authorization on database::[$oldDatabaseName] to dfdbsa 
                                exec('DROP LOGIN [$oldDatabaseName]')
                                END      
                                exec('CREATE LOGIN [$newDatabaseName] WITH PASSWORD=N''' + @pwd + ''', DEFAULT_DATABASE=[master], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF');
                                exec('use [$oldDatabaseName]' + 
                                ' CREATE USER [$newDatabaseName] FOR LOGIN [$newDatabaseName]' +
                                ' ALTER ROLE [db_owner] ADD MEMBER [$newDatabaseName]'); 
                                "
    try {
        Invoke-Sqlcmd -ServerInstance $SqlServer -Database "master" -Query $sqlcreateDBUser -QueryTimeout $SQLTimeout -ConnectionTimeout 1000 -verbose
    } 
    catch {
        throw "DB user creation for $newDatabaseName failed" 
    }
    DisplayLog -message "Login $newDatabaseName successfully created and mapped...."
}

function renameDatabase {
    param (
        [string]$SqlServer,
        [string]$oldDatabaseName,
        [string]$newDatabaseName)
    $SQLText = "
    ALTER DATABASE [$oldDatabaseName]SET SINGLE_USER WITH ROLLBACK IMMEDIATE
    EXEC master..sp_renamedb [$oldDatabaseName],[$newDatabaseName]
    ALTER DATABASE [$newDatabaseName] SET MULTI_USER"
    try {
        Invoke-Sqlcmd -ServerInstance $SqlServer -Database "master" -Query $SQLText -ConnectionTimeout 1000 -verbose
    } 
    catch {
        throw "failed to rename $oldDatabaseName "
    }
    DisplayLog -message " $oldDatabaseName  has been successfully renamed to $newDatabaseName  "
}

function renamelogicalName {
    param (
        [string]$SqlServer,
        [string]$newDatabaseName
    )
    $SQLText = "
    SELECT  name, 
    physical_name AS [DB File Path],
    type_desc AS [File Type],
    state_desc AS [State] 
    FROM sys.master_files
    WHERE database_id = DB_ID(N'$newDatabaseName')"
    $files = Invoke-Sqlcmd -ServerInstance $SqlServer -Database "master" -Query $SQLText -ConnectionTimeout 1000 
    $mdf = $files[0].name
    $log = $files[1].name
    $newlogName = $newDatabaseName + '_log'
    
    $SQLRename = "ALTER DATABASE [$newDatabaseName]SET SINGLE_USER WITH ROLLBACK IMMEDIATE
    ALTER DATABASE [$newDatabaseName] MODIFY FILE (NAME=N'$mdf', NEWNAME=N'$newDatabaseName')
    ALTER DATABASE [$newDatabaseName] MODIFY FILE (NAME=N'$log', NEWNAME=N'$newlogName')
    ALTER DATABASE [$newDatabaseName] SET MULTI_USER"
    try {
        Invoke-Sqlcmd -ServerInstance $SqlServer -Database "master" -Query $SQLRename -ConnectionTimeout 1000 -verbose
    } 
    catch {
        throw "failed to rename logical filenames for $oldDatabaseName "
    }
    DisplayLog -message " logical filenames has been successfully renamed  "
    
    
}


function UpdateControlDB {
    param (
        [string]$ctrlserver,
        [string]$ctrldb,
        [string]$newDatabaseName,
        [string]$oldDatabaseName,
        [int]$ClientId
        
    )

    
    $newConnectionString = 'provider=sqloledb;server=' + $SqlServer + ';database=' + $newDatabaseName + ';uid=' + $newDatabaseName + ';pwd=' + $DatabasePassword

    $SQLText = "
    Update Databaseconnection set Name = '$newDatabaseName' where name ='$oldDatabaseName'
   
    update DatabaseConnection set DatabaseConnectionString='$newConnectionString' where name like '$newDatabaseName'
    
    Update Namespace set Namespace ='$newDatabaseName' where Namespace ='$oldDatabaseName' and clientid = $ClientId
     
    Update clientmaster  set ClientShortName ='$newDatabaseName' where ClientShortName ='$oldDatabaseName' and clientid = $ClientId

    update BackgroundJobWork set namespace = '$newDatabaseName' where namespace ='$oldDatabaseName' and clientid = $ClientId
    "


    try {
        Invoke-Sqlcmd -ServerInstance $ctrlserver -Database $ctrldb -Query $SQLText -ConnectionTimeout 1000 -verbose
      
    } 
    catch {
        throw "Failed to set schedulejob and executeworkflow to 0 and update status code to Inactive"
    }
    DisplayLog -message "Schedulejob and executeworkflow have been set to 0 and status code to Inactive  "
}



function getBIDBServer {
    param (
        [string]$ctrlserver,
        [string]$ctrldb
    )
    $BIDBName = $oldDatabaseName + 'bi'
    $SQLText = "select  substring(value,CHARINDEX('=',value)+1,len(value)) As biserver
    from (
    select *
    from DatabaseConnection
    cross apply STRING_SPLIT(DatabaseConnectionString,';')
    where name like '$BIDBName'
    )t where SUBSTRING(value,1,6)='Server'"
    try {
        $server = Invoke-Sqlcmd -ServerInstance $ctrlserver -Database $ctrldb -Query $SQLText -ConnectionTimeout 1000 -verbose
        $BIDBServer = $server.biserver
        return $BIDBServer
    } 
    catch {
        throw "Failed to retrieve the BI DataBase Server"
    }
    DisplayLog -message "BI Database server for $BIDBName is $BIDBServer"
}

function getBIDBPassword {
    param (
        [string]$ctrlserver,
        [string]$ctrldb
    )
    $BIDBName = $oldDatabaseName + 'bi'
    $SQLText = "select  substring(value,CHARINDEX('=',value)+1,len(value)) As biserver
    from (
    select *
    from DatabaseConnection
    cross apply STRING_SPLIT(DatabaseConnectionString,';')
    where name like '$BIDBName'
    )t where SUBSTRING(value,1,3)='pwd'"
    try {
        $server = Invoke-Sqlcmd -ServerInstance $ctrlserver -Database $ctrldb -Query $SQLText -ConnectionTimeout 1000 -verbose
        $BIDBServer = $server.biserver
        return $BIDBServer
    } 
    catch {
        throw "Failed to retrieve the BI DataBase Server"
    }
    DisplayLog -message "BI Database server for $BIDBName is $BIDBServer"
}

function UpdateBITable {
    param (
        [string]$BIDBServer,
        [string]$newBIDBName,
        [string]$BIDBName
        
    )
    $SQLText = "update tbl_company set database_server ='BIDBServer',database_name='$newBIDBName' where database_name='$BIDBName'"
    try {
        Invoke-Sqlcmd -ServerInstance $BIDBServer -Database $newBIDBName -Query $SQLText -ConnectionTimeout 1000 -verbose
      
    } 
    catch {
        throw "Failed to update BI Database tbl_company table"
    }
    DisplayLog -message "BI Database tbl_company table successfully updated"
}
function UpdateControlDBBI {
    param (
        [string]$newBIDBName,
        [string]$BIDBName,
        [string]$BIDBServer
        
    )

    
    $newConnectionString = 'provider=sqloledb;server=' + $BIDBServer + ';database=' + $newBIDBName + ';uid=' + $newBIDBName + ';pwd=' + $BIDBPassword

    $SQLText = "
    Update Databaseconnection set Name = '$newBIDBName' where name ='$BIDBName'
   
    update DatabaseConnection set DatabaseConnectionString='$newConnectionString' where name like '$newBIDBName'"

    try {
        Invoke-Sqlcmd -ServerInstance $ctrlserver -Database $ctrldb -Query $SQLText -ConnectionTimeout 1000 -verbose
      
    } 
    catch {
        throw "Failed to change connection string for BI Database"
    }
    DisplayLog -message "Succefully change connection string for BI Database"
}


Function updateBIDB {
    $BIDBName = $oldDatabaseName + 'bi'
    $newBIDBName = $newDatabaseName + 'bi'
    $BIDBServer = getBIDBServer -ctrlserver $ctrlserver -ctrldb $ctrldb 
    $BIDBPassword = getBIDBPassword -ctrlserver $ctrlserver -ctrldb $ctrldb 
    if ($null -ne $BIDBServer) {
        DisplayLog -message "Proceeding with Database Name Change for BI Database"
        CreateDBUser -SqlServer $BIDBServer -oldDatabaseName $BIDBName -newDatabaseName $newBIDBName -DatabasePassword $BIDBPassword -SQLTimeout 120 
        renameDatabase -SqlServer $BIDBServer -oldDatabaseName $BIDBName -newDatabaseName $newBIDBName
        renamelogicalName -SqlServer $BIDBServer -newDatabaseName $newBIDBName
        UpdateBITable -BIDBServer $BIDBServer -newBIDBName $newBIDBName -BIDBName $BIDBName 
        UpdateControlDBBI -BIDBName $BIDBName -newBIDBName $newBIDBName -BIDBServer $BIDBServer
    }
    else {
        DisplayLog -message "No BI DB for this client"
    }
}


function UpdateClienTable {
    param (
        [string]$SqlServer,
        [string]$newDatabaseName,
        [int]$ClientId
        
    )
    $SQLText = "update client set shortname='$newDatabaseName', namespace = '$newDatabaseName', SoftwareUpdatePath = 'D:\Ceridian\Clocks\$newDatabaseName\clockupdate', ClockDeviceLogPath='D:\Ceridian\Clocks\$newDatabaseName\clocklog'  where clientid =$clientId"

    try {
        Invoke-Sqlcmd -ServerInstance $SqlServer -Database $newDatabaseName -Query $SQLText -ConnectionTimeout 1000 -verbose
      
    } 
    catch {
        throw "client table has not been updated"
    }
    DisplayLog -message "client table has been updated  "
}

function UpdateAdminService {
    param (
        
        [string]$newDatabaseName,
        [string]$oldDatabaseName,
        [string]$AdminServiceDB,
        [string]$adminServiceDBServer       
    )
    $SQLText = "Update admclientSite set Namespace ='$newDatabasename' Where Namespace ='$oldDatabasename'"
    try {
        Invoke-Sqlcmd -ServerInstance $adminServiceDBServer -Database $AdminServiceDB -Query $SQLText -ConnectionTimeout 1000 -verbose    
    } 
    catch {
        throw "admin client not updated"
    }
    DisplayLog -message "admin client updated"
}



function controlDBActivate {
    param (
        [string]$ctrlserver,
        [string]$ctrldb,
        [string]$newDatabaseName
    )
    $SQLText = "
    Declare @Databaseconnection int
    Declare @namespaceid int

    select @Databaseconnection=dc.DatabaseConnectionId, @namespaceid=NamespaceId
                    from  DatabaseConnection  dc
                    join Namespace n on n.DatabaseConnectionid=dc.DatabaseConnectionId
                    where [Name]=N'$newDatabaseName'


                    update namespace
                    set  ScheduleJobs=1,ExecuteWorkflows=1
                    where DatabaseConnectionid=@Databaseconnection


                    update NamespaceAuthentication
                    set StatusCode='a'
                    where Namespaceid=@namespaceid"
    try {
        Invoke-Sqlcmd -ServerInstance $ctrlserver -Database $ctrldb -Query $SQLText -ConnectionTimeout 1000 -verbose
    } 
    catch {
        throw "could not activate in control"
    }
    DisplayLog -message "has been able to activate in control"
}


<#controlDBDeactivate  -ctrlserver $ctrlserver -ctrldb $ctrldb -oldDatabaseName $oldDatabaseName
CreateDBUser -SqlServer $SqlServer -oldDatabaseName $oldDatabaseName -newDatabaseName $newDatabaseName -DatabasePassword $DatabasePassword -SQLTimeout 120 
renameDatabase -SqlServer $SqlServer -oldDatabaseName $oldDatabaseName -newDatabaseName $newDatabaseName
renamelogicalName -SqlServer $SqlServer -newDatabaseName $newDatabaseName
UpdateControlDB -ctrlserver $ctrlserver -ctrldb $ctrldb -newDatabaseName $newDatabaseName  -oldDatabaseName $oldDatabaseName -clientid $ClientId
#updateBIDB
UpdateClienTable -SqlServer $SqlServer  -newDatabaseName $newDatabaseName -clientid $ClientId#>
UpdateAdminService -adminServiceDBServer $adminServiceDBServer  -newDatabaseName $newDatabaseName -oldDatabaseName $oldDatabaseName -AdminServiceDB $AdminServiceDB
controlDBActivate -ctrlserver $ctrlserver -ctrldb $ctrldb -newDatabaseName $newDatabaseName




























 

 




