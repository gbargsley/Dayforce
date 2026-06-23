-- Lookup by Instance + session_id (used by PARTITION/ROW_NUMBER and direct joins)
CREATE NONCLUSTERED INDEX IX_RunningQueries_Instance_Session
ON dbo.RunningQueries (InstanceID, session_id)
INCLUDE (SnapshotDateUTC, blocking_session_id, cpu_time, total_elapsed_time, status, command)
WITH (FILLFACTOR = 90);  -- optional, tune per insert rate
GO

-- Lookup parent/children by Instance + blocking_session_id
CREATE NONCLUSTERED INDEX IX_RunningQueries_Instance_BlockingSession
ON dbo.RunningQueries (InstanceID, blocking_session_id)
INCLUDE (session_id, SnapshotDateUTC, cpu_time, total_elapsed_time, status, command)
WITH (FILLFACTOR = 90);
GO

CREATE NONCLUSTERED INDEX IX_RunningQueries_Snapshot_Instance_Db
ON dbo.RunningQueries (SnapshotDateUTC, InstanceID, database_id)
INCLUDE (session_id, cpu_time, total_elapsed_time, blocking_session_id, status, command, sql_handle, query_hash, plan_handle, wait_time, wait_type)
WITH (FILLFACTOR = 90);
GO
