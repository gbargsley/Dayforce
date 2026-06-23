USE master
GO

DROP TABLE IF EXISTS #TargetTraceFlags;
DROP TABLE IF EXISTS #ActiveTraceFlags;

CREATE TABLE #TargetTraceFlags (TraceFlag INT);
INSERT INTO #TargetTraceFlags (TraceFlag)
VALUES (1117),(1118),(1800),(1820),(3101),(3895),(3899),(8032),(8121)

CREATE TABLE #ActiveTraceFlags (TraceFlag INT, Status INT, GlobalScope BIT, SessionScope BIT)
INSERT INTO #ActiveTraceFlags 
EXEC ('DBCC TRACESTATUS(-1) WITH NO_INFOMSGS'); 

SELECT *, CASE WHEN a.TraceFlag IS NULL THEN 'DBCC TRACEON (' + CONVERT(VARCHAR(12), t.TraceFlag) + ', -1);' ELSE NULL END AS EnableFlagStatement
FROM #TargetTraceFlags t
LEFT OUTER JOIN #ActiveTraceFlags a ON t.TraceFlag = a.TraceFlag
ORDER BY t.TraceFlag

DROP TABLE IF EXISTS #TargetTraceFlags;
DROP TABLE IF EXISTS #ActiveTraceFlags;
GO

------------------------------

SELECT
 *,
 CASE WHEN cntr_value = 0 THEN '*** Resource Pool Not In Use ***' ELSE 'Resource Pool Is In Use' END AS ResourcePoolStatus
FROM sys.dm_os_performance_counters 
WHERE object_name LIKE '%Resource Pool Stats%' 
AND counter_name = 'Used Memory (KB)' 
and instance_name ='tempdb_resource_pool'
GO