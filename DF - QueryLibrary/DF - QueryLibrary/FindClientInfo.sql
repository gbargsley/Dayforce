use DBAInternalDataAccess --azg1dbasql011
declare @DatabaseName varchar(500) ='%upspayroll%'
declare @ControlDBName varchar(500) ='%upspayroll%'
--select * from [DBAInternalDataAccess].[dbo].[Vw_ClientDBInfo_NonProd] where databasename like @DatabaseName or controldbname like @ControlDBName and cast(CollectedTimeStamp as date) =cast(getdate() as Date) order by CollectedTimeStamp desc
--select * from [DBAInternalDataAccess].[dbo].[Vw_ClientDBInfo_PreProd]  where databasename like @DatabaseName or controldbname like @ControlDBName and cast(CollectedTimeStamp as date) =cast(getdate() as Date)  order by CollectedTimeStamp desc
select * from  [DBAInternalDataAccess].[dbo].[Vw_ClientDBInfo_Prod]  where databasename like @DatabaseName  or controldbname like @ControlDBName and cast(CollectedTimeStamp as date) =cast(getdate() as Date)order by CollectedTimeStamp desc