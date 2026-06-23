-- Active Connections
SELECT @@servername,DB_NAME(req.database_id) DBName,es.host_name as Host,login_name as [Login]
,sqltext.TEXT as SQLQuery,SQLStatement = SUBSTRING (sqltext.text, req.statement_start_offset/2, (CASE WHEN req.statement_end_offset = -1    
                THEN LEN(CONVERT(nvarchar(MAX), sqltext.text)) * 2 ELSE req.statement_end_offset END - req.statement_start_offset)/2 )    
--,Substring(sqltext.TEXT, patindex('%Report name%',sqltext.TEXT),200)   as ReportQuery
--,'KILL ' +  CAST(req.session_ID as varchar(25))
,req.session_id as SPID,req.blocking_session_ID as BlkBy
,req.cpu_time cpu_ms --req.cpu_time/1000 as cpu_ms
,req.total_elapsed_time/(1000) as Dur_sec--,wt.wait_duration_ms,wt.wait_type
,req.status,req.command ,req.reads+req.logical_reads as IOReads,req.writes as IOWrites,req.start_time,es.program_name
--,req.reads,req.logical_reads,percent_complete,estimated_completion_time
FROM sys.dm_exec_requests req 
left join sys.dm_exec_sessions es on req.session_id = es.session_id
--left join sys.dm_os_waiting_tasks wt on wt.session_id =es.session_id
CROSS APPLY sys.dm_exec_sql_text(sql_handle) AS sqltext
--WHERE es.program_name ='Reportingsvc' and datediff(Second,req.start_time,getdate()) >30  --and  req.total_elapsed_time/(1000) > 5 --and es.host_name not like '%mon%'
order by req.cpu_time desc


-- kill 242 

-- sp_WhoIsActive
exec AdminDB..ap_WhoIsActive

-- sp_WhoIsActive - SPID
exec AdminDB..ap_WhoIsActive 171

-- sp_WhoIsActive - Plans
exec AdminDB..ap_WhoIsActive @get_plans = 1

-- sp_WhoIsActive - Locks
exec AdminDB..ap_WhoIsActive @get_locks = 1

-- sp_WhoIsActive - Block Leaders
exec AdminDB..ap_WhoIsActive @find_block_leaders = 1, @sort_order = '[blocked_session_count] DESC'

-- sp_WhoIsActive - Show Sleeping SPIDS
exec AdminDB..ap_WhoIsActive @show_sleeping_spids = 1

-- sp_WhoIsActive - Filter by Login
exec AdminDB..ap_WhoIsActive @filter_type = 'login', @filter = 'CUSTADDS\G1SQLJobsAgt$';

-- sp_WhoIsActive - Filter by Database
exec AdminDB..ap_WhoIsActive @filter_type = 'database', @filter = 'nademo5a';

-- sp_WhoIsActive - Filter by Program Name
exec AdminDB..ap_WhoIsActive @filter_type = 'program', @filter = 'Fivetran%';


-- Database list
select name, log_reuse_wait_desc, * from sys.databases
where log_reuse_wait_desc <> 'NOTHING'
    and name = 'UZhcm1support156'


-- Trace Flags active
DBCC TRACESTATUS (-1)


-- Check on Server Connection Counts
SELECT  COUNT(sP.spid) AS total_database_connections, getdate()
FROM sys.sysprocesses sP

SELECT  *
FROM sys.sysprocesses sP
where status = 'sleeping'


SELECT  program_name, count(*)
FROM sys.sysprocesses sP
where status = 'sleeping'
group by program_name

SELECT  hostname, count(*)
FROM sys.sysprocesses sP
where status = 'sleeping'
group by hostname


/*
SELECT cp.plan_handle,
       cp.objtype,
       st.text AS sql_text
FROM sys.dm_exec_cached_plans AS cp
CROSS APPLY sys.dm_exec_sql_text(cp.plan_handle) AS st
WHERE st.text LIKE '%
 SELECT DISTINCT
                                ees.employeeid,
                                ees.EffectiveStart as StatusEffectiveStart,
                                ees.EffectiveEnd as StatusEffectiveEnd%';

DBCC FREEPROCCACHE (0x02000000754A17380E076ABF12FCEC3394A5BA489AD539AD0000000000000000000000000000000000000000);

*/


USE UZhcm1support156;
GO

DBCC OPENTRAN;

checkpoint