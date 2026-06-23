
BEGIN

Declare @html_AG  nvarchar(max)
 Declare @Profile nvarchar(max)=(select concat(@@SERVERNAME,'@ceridian.com'))	

EXEC Admindb..spQueryToHtmlTable @html = @html_AG OUTPUT, 
		@query = N' 
		select * from admindb.dbo.DBServerTotalConnections
	where Collect_Timestamp > dateadd(minute,-5,getdate())
	and ConnCount > 31000
',@orderBy = N'ORDER BY Collect_Timestamp desc';
		 
IF @html_AG IS NOT NULL
	BEGIN
			SET @html_AG  = '<h2 align="left"> DB connections count is close to max limit 32267, please start the investigation immediately.  </h2>' + @html_AG	
				
		EXEC msdb.dbo.sp_send_dbmail 
			@profile_name = @Profile,
			 @recipients = 'Dayforce.PT.Cloud.DBEng.Ops.Dayforce@dayforce.com',
			--@recipients = 'sanjay.singh@ceridian.com;Ryan.Frantz@ceridian.com',
			@subject = 'DB connection count is close to Max allowed value 32267',
			@body = @html_AG,
			@body_format = 'HTML' ;
		END
END
