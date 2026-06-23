use tempdb
GO

--DBCC FREEPROCCACHE -- clean cache
DBCC DROPCLEANBUFFERS -- clean buffers
DBCC FREESYSTEMCACHE ('ALL') -- clean system cache
DBCC FREESESSIONCACHE -- clean session cache
GO

CHECKPOINT

USE tempdb;
GO
-- shrink a specific file (replace tempdev with your file name)
DBCC SHRINKFILE (N'tempdev', 102400); -- target 102400 MB
GO
DBCC SHRINKFILE (N'temp2', 102400); -- target 102400 MB
GO
DBCC SHRINKFILE (N'temp3', 102400); -- target 102400 MB
GO
DBCC SHRINKFILE (N'temp4', 102400); -- target 102400 MB
GO
DBCC SHRINKFILE (N'temp5', 102400); -- target 102400 MB
GO
DBCC SHRINKFILE (N'temp6', 102400); -- target 102400 MB
GO
DBCC SHRINKFILE (N'temp7', 102400); -- target 102400 MB
GO
DBCC SHRINKFILE (N'temp8', 102400); -- target 102400 MB
GO


-- shrink log file if needed (templog)
DBCC SHRINKFILE (N'templog', 10240); -- target 512 MB
GO


-- report the new file sizes
SELECT name, size
FROM sys.master_files
WHERE database_id = DB_ID(N'tempdb');
GO





