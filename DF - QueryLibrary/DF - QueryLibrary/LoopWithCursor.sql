
--ran in prod

DECLARE @SQL1 varchar(max),@SQL2 varchar(max),@SQL3 varchar(max),@SQL4 varchar(max),@SQL5 varchar(max), @sql6 varchar(max)
DECLARE @DB sysname
DECLARE curDB CURSOR FORWARD_ONLY STATIC FOR  
   SELECT s.name 
   FROM master..sysdatabases s
   join master.sys.databases sd on s.name=sd.name
   WHERE s.name NOT IN ('model', 'tempdb','msdb','master','AdminDB') 
   and sd.state_desc <> 'OFFLINE'
   --and s.name not in ('subway') 
   and s.name  LIKE ('cfa%')
   ORDER BY s.name 
     
OPEN curDB  
FETCH NEXT FROM curDB INTO @DB  
WHILE @@FETCH_STATUS = 0  
BEGIN  
    set @SQL1 = '
    UPDATE [' + @DB + '].dbo.SystemPropertyBagValue SET [Value] = 2 WHERE CodeName = ''LaborCostEngine.MaximumNumberOfComputeThreads''
    '
--set @SQL1 = '
--if exists(select top 1 1 from ['+@DB+']..prpayrolltaxformrunresultdatapermanent a (nolock) 
--join ['+@DB+']..prpayrolltaxformrunresultpermanent c (nolock) on a.prpayrolltaxformrunresultid = c.prpayrolltaxformrunresultid
--join ['+@DB+']..PRYearEndLegalEntitySnapshot b (nolock) on c.legalentityid = b.legalentityid
--where a.PRPayrollTaxFormDefFieldid in (select PRPayrollTaxFormDefFieldid from ['+@DB+']..PRPayrollTaxFormDefField (nolock)
--WHERE PRPayrollTaxFormDefId = (SELECT def.PRPayrollTaxFormDefId
--    FROM ['+@DB+']..PRPayrollTaxFormDef def (nolock)
--    inner join ['+@DB+']..PRPayrollTaxForm t on t.PRPayrollTaxFormId = def.PRPayrollTaxFormId
--    where def.EffectiveStart = ''2025-01-01''
--    and t.CodeName = ''W2'')
--AND CodeName IN (''Box_14_AL_OT'',''Box_14_CO_FAMLI'',''Box_14_CTPL'',''Box_14_MEPFML'',''Box_14_NYS_HWB'',''Box_14_ORPMFL'',
--''Box_14_Qual_Tips'',''Box_14_TTOC'',''Box_14_VT_CCCEE'',''Box_14_Qual_OT'',''Box_12_II'')) 
--AND b.PublishTaxFormToThirdParty=1 and b.lastmodifiedtimestamp >= ''2026-01-01'' and b.lastmodifiedtimestamp < ''2026-02-06'')

--begin

--	DROP TABLE IF EXISTS ['+@DB+']..tmpReplacePackage_PRTaxFormPublishEvent_20260205
--	DROP TABLE IF EXISTS ['+@DB+']..tmpReplacePackage_PRTaxFormPublishEventMessage_20260205
--	DROP TABLE IF EXISTS ['+@DB+']..tmpReplacePackage_TaxFormGuidsPermanent_20260205
--	DROP TABLE IF EXISTS ['+@DB+']..tmpReplacePackage_TaxFormGuidsArchive_20260205

--	DECLARE @taxyear int = 2025
--	DECLARE @countrycode nvarchar(3) = ''USA''
--	DECLARE @geocountryid int = (select geocountryid from ['+@DB+']..geocountry where countrycode = @countrycode)
--	DECLARE @lastCreatedPackageId uniqueidentifier = (select top(1) PackageId from ['+@DB+']..prtaxformpublishevent where taxyear = @taxyear and geocountryid = @geocountryid order by lastmodifiedtimestamp desc)
--	DECLARE @BackgroundJobCodeName NVARCHAR(128) = ''PublishTaxFormsToAffiliate''
--	'
--	set @sql2 = '
--	----# BACKUP THE DATA TO BE PURGED
--	select PackageId, LastModifiedTimestamp, ReplacesPackageId, PackageSubscribedBusinessNumbers, PackageNumberOfMessages, PackageNumberOfEmployees, PackageNumberOfForms, PackageNumberOfPages, TaxYear, GeoCountryId
--	into ['+@DB+']..tmpReplacePackage_PRTaxFormPublishEvent_20260205
--	from ['+@DB+']..prtaxformpublishevent with (nolock) 
--	where PackageId = @lastCreatedPackageId

--	select MessageId, PackageId, LastModifiedTimestamp, PRTaxFormMessagePublishStatusId, MessageNumber, MessageNumberOfEmployees, MessageNumberOfForms, MessageNumberOfPages
--	into ['+@DB+']..tmpReplacePackage_PRTaxFormPublishEventMessage_20260205
--	from ['+@DB+']..prtaxformpublisheventmessage with (nolock) 
--	where PackageId = @lastCreatedPackageId

--	select prr.MessagePublishGuid, prr.TaxFormGuid
--	into ['+@DB+']..tmpReplacePackage_TaxFormGuidsPermanent_20260205
--	from ['+@DB+']..prpayrolltaxformrunresultpermanent prr with(nolock)
--	where exists 
--	(
--		select top(1) 1 
--		from ['+@DB+']..tmpReplacePackage_PRTaxFormPublishEventMessage_20260205 as msg
--		where msg.messageid = prr.messagepublishguid
--	)
--'
--set @sql3 = '
--	select prr.MessagePublishGuid, prr.TaxFormGuid
--	into ['+@DB+']..tmpReplacePackage_TaxFormGuidsArchive_20260205
--	from ['+@DB+']..prpayrolltaxformrunresultarchive prr with(nolock)
--	where exists 
--	(
--		select top(1) 1 
--		from ['+@DB+']..tmpReplacePackage_PRTaxFormPublishEventMessage_20260205 as msg
--		where msg.messageid = prr.messagepublishguid
--	)


--	--# NOW PURGE THE PACKAGE DATA
--	UPDATE prr
--	SET MessagePublishGuid = NULL
--	FROM ['+@DB+']..prpayrolltaxformrunresultpermanent prr
--	INNER JOIN ['+@DB+']..tmpReplacePackage_TaxFormGuidsPermanent_20260205 tmp
--		ON tmp.TaxFormGuid = prr.TaxFormGuid

--	UPDATE prr
--	SET MessagePublishGuid = NULL
--	FROM ['+@DB+']..prpayrolltaxformrunresultarchive prr
--	INNER JOIN ['+@DB+']..tmpReplacePackage_TaxFormGuidsArchive_20260205 tmp
--		ON tmp.TaxFormGuid = prr.TaxFormGuid

--	DELETE FROM ['+@DB+']..prtaxformpublishevent
--	where exists 
--	(
--		select top(1) 1 
--		from ['+@DB+']..tmpReplacePackage_PRTaxFormPublishEvent_20260205 AS tmp 
--		WHERE tmp.PackageId = prtaxformpublishevent.PackageId
--	)

--	DELETE FROM ['+@DB+']..prtaxformpublisheventmessage
--	where exists 
--	(
--		select top(1) 1 
--		from ['+@DB+']..tmpReplacePackage_PRTaxFormPublishEventMessage_20260205 AS tmp 
--		WHERE tmp.MessageId = prtaxformpublisheventmessage.MessageId
--	)
--'
--set @sql4 = '
--	----PART 2/SCRIPT 2

--	--# RETURN THE PACKAGE ID TO BE REPLACED - this would need to be plugged into the relevant replace package parameter of the PublishTaxFormsToAffiliate job in order to perform a full package replacement
--	DECLARE @PackageIdToBeReplaced uniqueidentifier
--	DECLARE @PackageTBRLastModifiedTimestamp datetime

--	select top(1)
--		@PackageIdToBeReplaced = PackageId,
--		@PackageTBRLastModifiedTimestamp = LastModifiedTimestamp
--	from ['+@DB+']..tmpReplacePackage_PRTaxFormPublishEvent_20260205

--	--StartDate = GETDATE()
--	--EndDate = GETDATE() + 2 days
--	--cron job expr to sometime in future

--	--WHEN TO RUN
--	DECLARE @CronExpression nvarchar(50) = N''0 0 0 1 10 ?'' --1-Oct in future (placeholder)
--	DECLARE @StartDate DATETIME = CURRENT_TIMESTAMP
--	DECLARE @EndDate DATETIME = DATEADD(DAY, 2, @StartDate) --A couple days buffer in case script is ran but the deployment of the BJE is delayed.

--	--NextScheduleTimeUTC - Today + the time from PackageTBRLastModifiedTimestamp
--	DECLARE @Offset INT = DATEDIFF(MINUTE, GETUTCDATE(), GETDATE());
--	DECLARE @TargetDateTimeLocal DATETIME = CAST(CAST(GETDATE() AS DATE) AS DATETIME) + CAST(CAST(@PackageTBRLastModifiedTimestamp AS TIME) AS DATETIME);
--	SET @TargetDateTimeLocal = DATEADD(DAY, 1, @TargetDateTimeLocal); --Add a day
--	DECLARE @NextScheduleTimeUTC DATETIME = DATEADD(MINUTE, -@Offset, @TargetDateTimeLocal);


--	--Insert the background job
--	DECLARE @BackgroundJobId INT
--	DECLARE @ScheduleId INT
--	DECLARE @ScheduleName NVARCHAR(MAX)
--	DECLARE @ParameterXML nvarchar(200) = N''<Parameter TaxYear="'' + CONVERT(NVARCHAR(4), @taxyear) + ''" Country="'' + @countrycode + ''" ReplacePackageId="'' + CONVERT(NVARCHAR(36), @PackageIdToBeReplaced) + ''"/>''
--'
--set @sql5 = '
--	SET @BackgroundJobId = (SELECT TOP 1 BackgroundJobId FROM ['+@DB+']..BackgroundJob WHERE CodeName= @BackgroundJobCodeName);
--	IF (@BackgroundJobId > 0)
--	BEGIN
--	 SET @ScheduleName = N''Initial Run - PublishTaxFormsToAffiliate'';
--	 IF NOT EXISTS (SELECT 1 FROM ['+@DB+']..BackgroundSchedule WHERE ShortName=@ScheduleName)
--	 BEGIN
--	  INSERT INTO ['+@DB+']..BackgroundSchedule(ShortName,LongName,LastModifiedUserId,LastModifiedTimestamp, StartDate,EndDate,CronExpr,NextScheduleTimeUTC,SendNotificationEmail) 
--	  VALUES (
--	   @ScheduleName, --ShortName
--	   @ScheduleName, --LongName
--	   0, --LastModifiedUserId
--	   CURRENT_TIMESTAMP, --LastModifiedTimestamp
--	   @StartDate, --StartDate
--	   @EndDate, --EndDate
--	   @CronExpression, --CronExpr
--	   @NextScheduleTimeUTC, --NextScheduleTimeUTC
--	   1 --SendNotificationEmail
--	  )
--	 END
--	 '
--	 set @sql6 = '
--	 SET @ScheduleId = (SELECT TOP 1 ScheduleId FROM ['+@DB+']..BackgroundSchedule WHERE ShortName=@ScheduleName);
--	 IF NOT EXISTS (SELECT 1 FROM ['+@DB+']..BackgroundJobSchedule WHERE BackgroundJobId=@BackgroundJobId AND ScheduleId=@ScheduleId)
--	 BEGIN
--	  INSERT INTO ['+@DB+']..BackgroundJobSchedule(BackgroundJobId,ScheduleId,ContextXml,ParameterXML,LastModifiedUserId,LastModifiedTimestamp,IsActive, ScheduledJobName) 
--	  VALUES (
--	   @BackgroundJobId, --BackgroundJobId
--	   @ScheduleId, --ScheduleId
--	   null, --ContextXml
--	   @ParameterXML, --ParameterXML
--	   0, --LastModifiedUserId
--	   CURRENT_TIMESTAMP, --LastModifiedTimestamp
--	   1, --IsActive
--	   @BackgroundJobCodeName --ScheduledJobName
--	  )	
--END
--END
--END
--'
--print @sql1+@sql2+@sql3+@sql4+@sql5
--print @sql6
exec (@sql1) --+@sql2+@sql3+@sql4+@sql5+@sql6)
	  FETCH NEXT FROM curDB INTO @DB  
   END  
    
CLOSE curDB  
DEALLOCATE curDB



----- test----
--drop table if exists #tableSize
--create table #tableSize
--(DBName varchar(100),
--sjobname nvarchar(500)
--)
--exec sp_MSforeachdb 'use [?]
-- IF exists ( select  1 from sys.tables where name like ''backgroundjobschedule'')
--begin 
--Insert into #tableSize
--select DB_NAME(),parameterxml from backgroundjobschedule (nolock) where scheduledjobname = ''PublishTaxFormsToAffiliate''
--end '
----drop table #tableSize
--select * from #tableSize where sjobname is null