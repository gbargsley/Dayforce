-- AN1PRDDFCMON002

with level1 as (
select * from msdb.[dbo].[sysmanagement_shared_registered_servers_internal]
where server_group_id in
(select server_group_id  from msdb.[dbo].[sysmanagement_shared_server_groups_internal] 
 where name in ('NextGen_Prod','azure','AzureCAN'))
) 
select distinct server_name from level1  order by Server_Name


-- $servers=invoke-sqlcmd -querytimeout 3600 -query $query -database msdb -serverinstance AN1PRDDFCMON002

--foreach ($server in $servers) 
--{
--    $servername=$server[0]
--    $servername
--    $sql_select= "		
      SELECT  COUNT(sP.spid) AS total_database_connections, getdate()
    FROM sys.sysprocesses sP
   --- having COUNT(sP.spid) >10000
 "

    try
    {    
         $Count_result=invoke-sqlcmd -querytimeout 3600 -query $sql_select -database master -serverinstance $servername
     }
     catch
     {
           $Count_result=$null    
     }

    if ($Count_result -ne $null) 
    {
     #$servername 
     foreach ($db in $count_result) 
     {
      $total_database_connections=$db[0]
     $Collect_Timestamp=$db[1]
     
    
     $sql_insert="insert into AdminDB.dbo.DBServerTotalConnections (Servername,ConnCount,Collect_Timestamp)
     Values('$servername','$total_database_connections','$Collect_Timestamp')"
 invoke-sqlcmd -querytimeout 36000 -query $sql_insert -database AdminDB -serverinstance AN1PRDDFCMON002
   }
   }
  # }
}

