-- List tempdb files on F:\Data
SELECT
    db_name(database_id) AS database_name,
    name AS logical_name,
    physical_name,
    file_id,
    size/128.0 AS size_MB
FROM sys.master_files
WHERE database_id = DB_ID('tempdb')
  AND physical_name LIKE 'D:\tempdb\%';

  checkpoint
-- 1) switch to tempdb context
USE tempdb;
GO

-- 2) try to empty the file (migrates allocation to other files)
DBCC SHRINKFILE (N'tempdev', EMPTYFILE);
GO

-- 3) remove the file from tempdb metadata
ALTER DATABASE tempdb REMOVE FILE tempdb_data87;
GO

-- 4) verify removal
SELECT name, physical_name FROM sys.master_files WHERE database_id = DB_ID('tempdb');



/*  - Find Object ID for page 
DBCC TRACEON(3604);
DBCC PAGE (tempdb, 82, 3182736, 3);
*/
