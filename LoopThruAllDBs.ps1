<#  Query 1
drop table IF exists admindb.dbo.SanTempDataCollectNov04
go
create table admindb.dbo.SanTempDataCollectNov12 
( ID int identity (1,1),
servername varchar(500), 
databasename varchar(500), 
Column1 varchar(8000), 
Column2 varchar(8000),
Column3 varchar(8000),
Column4 varchar(8000),
Column5 varchar(8000),
Column6 varchar(8000),
Column7 varchar(8000),
Column8 varchar(8000),
Column9 varchar(8000),
Column10 varchar(8000),
Column11 varchar(8000),
Column12 varchar(8000),
Column13 varchar(8000),
Column14 varchar(8000),
Column15 varchar(8000),
Column16 varchar(8000),
Column17 varchar(8000),
Column18 varchar(8000),  ---- 18 columns in select statement
)
go
select * from admindb.dbo.SanTempDataCollectNov12
(),
#>


$starttime = get-date

function Write-DataTable 
{ 
    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$true)] [string]$ServerInstance, 
    [Parameter(Position=1, Mandatory=$true)] [string]$Database, 
    [Parameter(Position=2, Mandatory=$true)] [string]$TableName, 
    [Parameter(Position=3, Mandatory=$true)] $Data, 
    [Parameter(Position=4, Mandatory=$false)] [string]$Username, 
    [Parameter(Position=5, Mandatory=$false)] [string]$Password, 
    [Parameter(Position=6, Mandatory=$false)] [Int32]$BatchSize=50000, 
    [Parameter(Position=7, Mandatory=$false)] [Int32]$QueryTimeout=0, 
    [Parameter(Position=8, Mandatory=$false)] [Int32]$ConnectionTimeout=15 
    ) 
     
    $conn=new-object System.Data.SqlClient.SQLConnection 
 
    if ($Username) 
    { $ConnectionString = "Server={0};Database={1};User ID={2};Password={3};Trusted_Connection=False;Connect Timeout={4}" -f $ServerInstance,$Database,$Username,$Password,$ConnectionTimeout } 
    else 
    { $ConnectionString = "Server={0};Database={1};Integrated Security=True;Connect Timeout={2}" -f $ServerInstance,$Database,$ConnectionTimeout } 
 
    $conn.ConnectionString=$ConnectionString 
 
    try 
    { 
        $conn.Open() 
        $bulkCopy = new-object ("Data.SqlClient.SqlBulkCopy") $connectionString 
        $bulkCopy.DestinationTableName = $tableName 
        $bulkCopy.BatchSize = $BatchSize 
        $bulkCopy.BulkCopyTimeout = $QueryTimeOut 

        #added columnmappings for identity column  ( number of columns in select statement +2 for servername and DBName ( do not count ID column)
        $ColumnMap1 = New-Object System.Data.SqlClient.SqlBulkCopyColumnMapping(0, 1)
        $ColumnMap2 = New-Object System.Data.SqlClient.SqlBulkCopyColumnMapping(1, 2)
        $ColumnMap3 = New-Object System.Data.SqlClient.SqlBulkCopyColumnMapping(2, 3)
        $ColumnMap4 = New-Object System.Data.SqlClient.SqlBulkCopyColumnMapping(3, 4)
        $ColumnMap5 = New-Object System.Data.SqlClient.SqlBulkCopyColumnMapping(4, 5)
        $ColumnMap6 = New-Object System.Data.SqlClient.SqlBulkCopyColumnMapping(5, 6)
        $ColumnMap7 = New-Object System.Data.SqlClient.SqlBulkCopyColumnMapping(6, 7)
        $ColumnMap8 = New-Object System.Data.SqlClient.SqlBulkCopyColumnMapping(7, 8)
        $ColumnMap9 = New-Object System.Data.SqlClient.SqlBulkCopyColumnMapping(8, 9)
        $ColumnMap10 = New-Object System.Data.SqlClient.SqlBulkCopyColumnMapping(9, 10)
        $ColumnMap11 = New-Object System.Data.SqlClient.SqlBulkCopyColumnMapping(10, 11)
        $ColumnMap12 = New-Object System.Data.SqlClient.SqlBulkCopyColumnMapping(11, 12)
        $ColumnMap13 = New-Object System.Data.SqlClient.SqlBulkCopyColumnMapping(12, 13)
        $ColumnMap14 = New-Object System.Data.SqlClient.SqlBulkCopyColumnMapping(13, 14)
        $ColumnMap15 = New-Object System.Data.SqlClient.SqlBulkCopyColumnMapping(14, 15)
        $ColumnMap16 = New-Object System.Data.SqlClient.SqlBulkCopyColumnMapping(15, 16)
        $ColumnMap17 = New-Object System.Data.SqlClient.SqlBulkCopyColumnMapping(16, 17)
        $ColumnMap18 = New-Object System.Data.SqlClient.SqlBulkCopyColumnMapping(17, 18)
        $ColumnMap19 = New-Object System.Data.SqlClient.SqlBulkCopyColumnMapping(18, 19)
        $ColumnMap20 = New-Object System.Data.SqlClient.SqlBulkCopyColumnMapping(19, 20)
          

    #added select statement has 18 columns so total 18+servername+dbname =20 ( exclude ID column)
        $bulkCopy.ColumnMappings.Add($ColumnMap1) | Out-Null
        $bulkCopy.ColumnMappings.Add($ColumnMap2) | Out-Null
        $bulkCopy.ColumnMappings.Add($ColumnMap3) | Out-Null
        $bulkCopy.ColumnMappings.Add($ColumnMap4) | Out-Null
        $bulkCopy.ColumnMappings.Add($ColumnMap5) | Out-Null
        $bulkCopy.ColumnMappings.Add($ColumnMap6) | Out-Null
        $bulkCopy.ColumnMappings.Add($ColumnMap7) | Out-Null
        $bulkCopy.ColumnMappings.Add($ColumnMap8) | Out-Null
        $bulkCopy.ColumnMappings.Add($ColumnMap9) | Out-Null
        $bulkCopy.ColumnMappings.Add($ColumnMap10) | Out-Null
        $bulkCopy.ColumnMappings.Add($ColumnMap11) | Out-Null
        $bulkCopy.ColumnMappings.Add($ColumnMap12) | Out-Null
        $bulkCopy.ColumnMappings.Add($ColumnMap13) | Out-Null
        $bulkCopy.ColumnMappings.Add($ColumnMap14) | Out-Null
        $bulkCopy.ColumnMappings.Add($ColumnMap15) | Out-Null
        $bulkCopy.ColumnMappings.Add($ColumnMap16) | Out-Null
        $bulkCopy.ColumnMappings.Add($ColumnMap17) | Out-Null
        $bulkCopy.ColumnMappings.Add($ColumnMap18) | Out-Null
        $bulkCopy.ColumnMappings.Add($ColumnMap19) | Out-Null
        $bulkCopy.ColumnMappings.Add($ColumnMap20) | Out-Null
        

        $bulkCopy.WriteToServer($Data) 
        $conn.Close() 
    } 
    catch 
    { 
        $ex = $_.Exception 
        Write-Error "$ex.Message" 
        continue 
    } 
 
} #Write-DataTable

#get servers
$sql = "
USE [msdb]
GO
SELECT	
		s.[server_name] AS [SQLInstance]
FROM    [dbo].[sysmanagement_shared_server_groups_internal] g
LEFT JOIN [dbo].[sysmanagement_shared_registered_servers_internal] s
	ON	g.[server_group_id] = s.[server_group_id]
WHERE	g.[server_type] = 0 --dbengine group
AND	g.[is_system_object] = 0 --user added only
	                    and g.name in ('nextgen-prod','Azure') -- for  azure env since its not accessible from mon server
                        --and g.name in ('nextgen-prod','london','Melbourne','TORONTO','andover','CTC','Ireland','Sweden')--- non azure 
and s.server_name is not null
                                --and s.server_name  like 'azg1dfcsql22dnn%'
                                --and s.server_name  like 'AN1PRDDFCSQL035%'
ORDER BY [SQLInstance] --alpha sort
GO
"
$serverlist = Invoke-Sqlcmd -ServerInstance AN1PRDDFCMON002 -query $sql -database msdb
$serverlist

$date = get-date #uniform datetime for all records from one gathering instance

#iterate through servers
ForEach ($server in $serverlist)
{
    if ($host.Name -eq "Windows PowerShell ISE Host")
    {
      Write-Host $server.sqlinstance -ForegroundColor Green
    }
      
    #get databases
    $sql = '
use master
select name
from sys.databases
where database_id > 4
and state = 0
order by name
    '
  $dblist = Invoke-Sqlcmd -ServerInstance $server.SQLInstance -query $sql -database master
 
 # Make sure to add these 2 columns at beginning of select statement @@servername,DB_NAME() 
    $sql = "
     IF exists ( select  1 from sys.tables where name like 'prearningcodeelementvalue')
    --and exists ( select  1 from sys.tables where name like 'prdeduction')
	
BEGIN 

 select @@servername,DB_NAME() ,'Earning' as type, pe2.prearningid, pe2.shortname, pec.prearningcodeid c1, pec.shortname [Correct Tax Method], 
	case when pec.prearningcodeid in (select pev.prearningcodeid
										from prearningcodeelementvalue pev (nolock)
											left join dfelementparam dep (nolock) on dep.dfelementparamid = pev.dfelementparamid
										where 1=1
											and dep.codename in ('EarningCodeCAEI')
											and pev.value = 'True')
		 then 'X' else '' end as EI,
	case when pec.prearningcodeid in (select pev.prearningcodeid
										from prearningcodeelementvalue pev (nolock)
											left join dfelementparam dep (nolock) on dep.dfelementparamid = pev.dfelementparamid
										where 1=1
											and dep.codename in ('EarningCodeInsurableHours')
											and pev.value = 'True')
		 then 'X' else '' end as EIHours1,
	case when pec.prearningcodeid in (select pev.prearningcodeid
										from prearningcodeelementvalue pev (nolock)
											left join dfelementparam dep (nolock) on dep.dfelementparamid = pev.dfelementparamid
										where 1=1
											and dep.codename in ('EarningCodeCACPP')
											and pev.value = 'True')
		 then 'X' else '' end as CPP,
	case when pec.prearningcodeid in (select pev.prearningcodeid
										from prearningcodeelementvalue pev (nolock)
											left join dfelementparam dep (nolock) on dep.dfelementparamid = pev.dfelementparamid
										where 1=1
											and dep.codename in ('EarningCodeCAQPP')
											and pev.value = 'True')
		 then 'X' else '' end as QPP,
	case when pec.prearningcodeid in (select pev.prearningcodeid
										from prearningcodeelementvalue pev (nolock)
											left join dfelementparam dep (nolock) on dep.dfelementparamid = pev.dfelementparamid
										where 1=1
											and dep.codename in ('EarningCodeCAQPIP')
											and pev.value = 'True')
		 then 'X' else '' end as QPIP,


	pec2.prearningcodeid c2, pec2.shortname [Incorrect Tax Method],
	case when pec2.prearningcodeid in (select pev.prearningcodeid
										from prearningcodeelementvalue pev (nolock)
											left join dfelementparam dep (nolock) on dep.dfelementparamid = pev.dfelementparamid
										where 1=1
											and dep.codename in ('EarningCodeCAEI')
											and pev.value = 'True')
		 then 'X' else '' end as EI2,
	case when pec2.prearningcodeid in (select pev.prearningcodeid
										from prearningcodeelementvalue pev (nolock)
											left join dfelementparam dep (nolock) on dep.dfelementparamid = pev.dfelementparamid
										where 1=1
											and dep.codename in ('EarningCodeInsurableHours')
											and pev.value = 'True')
		 then 'X' else '' end as EIHours2,
	case when pec2.prearningcodeid in (select pev.prearningcodeid
										from prearningcodeelementvalue pev (nolock)
											left join dfelementparam dep (nolock) on dep.dfelementparamid = pev.dfelementparamid
										where 1=1
											and dep.codename in ('EarningCodeCACPP')
											and pev.value = 'True')
		 then 'X' else '' end as CPP2,
	case when pec2.prearningcodeid in (select pev.prearningcodeid
										from prearningcodeelementvalue pev (nolock)
											left join dfelementparam dep (nolock) on dep.dfelementparamid = pev.dfelementparamid
										where 1=1
											and dep.codename in ('EarningCodeCAQPP')
											and pev.value = 'True')
		 then 'X' else '' end as QPP2,
	case when pec2.prearningcodeid in (select pev.prearningcodeid
										from prearningcodeelementvalue pev (nolock)
											left join dfelementparam dep (nolock) on dep.dfelementparamid = pev.dfelementparamid
										where 1=1
											and dep.codename in ('EarningCodeCAQPIP')
											and pev.value = 'True')
		 then 'X' else '' end as QPIP2,
	case when exists (select 1
					  from prpayrunearning (nolock) 
					  where lastmodifiedtimestamp > (select min(transaction_time) 
													from DFDatabaseIdentificationAudit (nolock) 
													where left(databaseversion,2) = '61'
													)
							 and pe2.prearningid = prearningid)
		then 'X' else '' end as Used
from (
		-- get PREarningCodeID on PREarning table before client upgraded to R61
		select row_number() over (partition by pe.prearningid order by transaction_time desc, operation desc) as rowz, pe.transaction_time, pe.operation, pe.prearningid, pe.prearningcodeid
		from prearningaudit pe (nolock)
			join prearningcodecountry prc (nolock) on pe.prearningid = prc.prearningid
		where 1=1 and pe.operation in (2,4)
			and pe.transaction_time between prc.lastmodifiedtimestamp and (select min(transaction_time) from DFDatabaseIdentificationAudit (nolock) where left(databaseversion,2) = '61')
	) pe
	join prearningcodecountry prc (nolock) on prc.prearningid = pe.prearningid and pe.rowz = 1
	join prearning pe2 (nolock) on pe2.prearningid = pe.prearningid
	left join prearningcode pec (nolock) on pec.prearningcodeid = pe.prearningcodeid
	left join prearningcode pec2 (nolock) on pec2.prearningcodeid = prc.prearningcodeid
where pe.prearningcodeid != prc.prearningcodeid

union

select @@servername,DB_NAME() ,'Deduction' as type, pe2.prdeductionid, pe2.shortname, pec.prdeductioncodeid c1, pec.shortname [Correct Tax Method], '','','','','', pec2.prdeductioncodeid c2, pec2.shortname [Incorrect Tax Method],'','','','','',
	case when exists (select 1 
					  from prpayrundeduction (nolock) 
					  where lastmodifiedtimestamp > (select min(transaction_time) 
													from DFDatabaseIdentificationAudit (nolock) 
													where left(databaseversion,2) = '61'
													)
							 and pe2.prdeductionid = prdeductionid)
		then 'X' else '' end as Used
from (
		-- get PRdeductionCodeID on PRdeduction table before client upgraded to R61
		select row_number() over (partition by pe.prdeductionid order by transaction_time desc, operation desc) as rowz, pe.transaction_time, pe.operation, pe.prdeductionid, pe.prdeductioncodeid
		from prdeductionaudit pe (nolock)
			join prdeductioncodecountry prc (nolock) on pe.prdeductionid = prc.prdeductionid
		where 1=1 and pe.operation in (2,4)
			and pe.transaction_time between prc.lastmodifiedtimestamp and (select min(transaction_time) from DFDatabaseIdentificationAudit (nolock) where left(databaseversion,2) = '61')
	) pe
	join prdeductioncodecountry prc (nolock) on prc.prdeductionid = pe.prdeductionid and pe.rowz = 1
	join prdeduction pe2 (nolock) on pe2.prdeductionid = pe.prdeductionid
	left join prdeductioncode pec (nolock) on pec.prdeductioncodeid = pe.prdeductioncodeid
	left join prdeductioncode pec2 (nolock) on pec2.prdeductioncodeid = prc.prdeductioncodeid
where pe.prdeductioncodeid != prc.prdeductioncodeid
END
   
    "

    #iterate through dbs
    ForEach ($db in $dblist)
    {  
        $tablelist = Invoke-Sqlcmd -ServerInstance $server.SQLInstance -query $sql -database $db.name
        #$dt |Out-GridView
        if ($tablelist)
        {Write-DataTable -ServerInstance AN1PRDDFCMON002 -Database 'admindb' -TableName 'SanTempDataCollectNov12' -Data $tablelist
        
            if ($host.Name -eq "Windows PowerShell ISE Host")
            {
              Write-Host $db.name 'Complete' -foreground Cyan
            }
        }
        
        
       
    }

    if ($host.Name -eq "Windows PowerShell ISE Host")
    {
        Write-Host $server.sqlinstance 'Complete 
    ' -foreground Green
    }
       

}

$endtime = get-date
$duration = New-TimeSpan -end $endtime -start $starttime 

    if ($host.Name -eq "Windows PowerShell ISE Host")
    {
      Write-Host 'Total run time = '$duration -ForegroundColor Yellow
    }
