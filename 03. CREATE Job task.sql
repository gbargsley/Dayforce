USE [msdb]
GO

/****** Object:  Job [MS - SQL_Server_LogScout]    Script Date: 1/20/2026 11:36:07 AM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [MS Monitoring Health]    Script Date: 1/20/2026 11:36:08 AM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'MS Monitoring Health' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'MS Monitoring Health'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'MS - SQL_Server_LogScout', 
		@enabled=0, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Collects infomration regarding SQL_Server_Mem_Stats.sql and SQL_Server_PerfStats.sql using same baseline used in LogScoutand created to troubleshoot memory conention issue reported from 2511100040010255.
SQL_Server_PerfStats.sql is collected every 10 seconds. 
SQL_Server_Mem_Stats.sql is collected every 2 minutes.', 
		@category_name=N'MS Monitoring Health', 
		@owner_login_name=N'dfdbsa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Update Output FileName]    Script Date: 1/20/2026 11:36:09 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Update Output FileName', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DECLARE @PerfStats nvarchar(200), @MemStats nvarchar(200), @token varchar(11)= SUBSTRING(REPLACE(REPLACE(REPLACE(CONVERT(VARCHAR(19), GETDATE(), 120), ''-'', ''''), '':'', ''''), '' '', ''_''),1,11)
SELECT @PerfStats=ISNULL(output_file_name,'''') FROM msdb.dbo.sysjobsteps WHERE job_id=(SELECT job_id FROM msdb.dbo.sysjobs WHERE name =''MS - SQL_Server_LogScout'') AND step_name=''Collect PerfStats''
SELECT @MemStats =ISNULL(output_file_name,'''') FROM msdb.dbo.sysjobsteps WHERE job_id=(SELECT job_id FROM msdb.dbo.sysjobs WHERE name =''MS - SQL_Server_LogScout'') AND step_name=''Collect MemStats''
IF (''%''+@token+''%''  NOT LIKE  @PerfStats) BEGIN 
SET @PerfStats=N''D:\MSDiagnosticDataCapture\PerfStats_''+@@SERVERNAME+''_''+@token+''00.out''
EXEC msdb.dbo.sp_update_jobstep @job_name=N''MS - SQL_Server_LogScout'', @step_id =2, @output_file_name=@PerfStats, @flags=2 END 

IF (''%''+@token+''%''  NOT LIKE  @MemStats) BEGIN 
SET @MemStats=N''D:\MSDiagnosticDataCapture\Mem_Stats_''+@@SERVERNAME+''_''+@token+''00.out''
EXEC msdb.dbo.sp_update_jobstep @job_name=N''MS - SQL_Server_LogScout'', @step_id =3, @output_file_name=@MemStats, @flags=2 END

PRINT ''====================   '' + NCHAR(10) +''@PerfStats: '' + @PerfStats + NCHAR(10) + ''====================   '' + NCHAR(10) + ''@MemStats: '' + @MemStats', 
		@database_name=N'msdb', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Collect PerfStats]    Script Date: 1/20/2026 11:36:09 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Collect PerfStats', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'EXEC dbo.sp_Run_PerfStats', 
		@database_name=N'AdminDB', 
		@output_file_name=N'D:\MSDiagnosticDataCapture\PerfStats_azm1geusql06e_20260120_1700.out', 
		@flags=2
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Collect MemStats]    Script Date: 1/20/2026 11:36:09 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Collect MemStats', 
		@step_id=3, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'IF (DATEPART(MINUTE, GETDATE()) % 2)=0 AND (DATEPART(SECOND, GETDATE())) BETWEEN 0 AND 9
BEGIN 
	EXEC AdminDB.dbo.sp_Run_MemStats ''0:2:0''
END 
', 
		@database_name=N'AdminDB', 
		@output_file_name=N'D:\MSDiagnosticDataCapture\Mem_Stats_azm1geusql06e_20260120_1700.out', 
		@flags=2
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Clear Job history]    Script Date: 1/20/2026 11:36:09 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Clear Job history', 
		@step_id=4, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'IF (DATEPART(HOUR, GETDATE()) % 2)=0 AND (DATEPART(MINUTE, GETDATE())BETWEEN 0 AND 9)  AND (DATEPART(SECOND, GETDATE())) BETWEEN 0 AND 9  BEGIN 
	DECLARE @oldest_date DATETIME=DATEADD(HOUR,-1,GETDATE())
	EXECUTE msdb.dbo.sp_purge_jobhistory @job_name = N''MS - SQL_Server_LogScout'', @oldest_date=@oldest_date	
END ', 
		@database_name=N'msdb', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Purge files older  than 24 hours old]    Script Date: 1/20/2026 11:36:09 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Purge files older  than 24 hours old', 
		@step_id=5, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'CmdExec', 
		@command=N'powershell.exe -File "D:\MSDiagnosticDataCapture\Remove-OldFiles.ps1" -Path "D:\MSDiagnosticDataCapture" -CutoffHours 24 -Recurse -LogPath "D:\MSDiagnosticDataCapture\DeletedFiles.log"', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Collect Ev 10 sec', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=2, 
		@freq_subday_interval=10, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20251125, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'bb4a0227-a389-4c31-9a43-84027f94f425'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


