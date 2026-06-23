SET NOCOUNT ON;

DECLARE @DbName sysname;
DECLARE @LogFile sysname;
DECLARE @SQL nvarchar(max);

DECLARE db_cur CURSOR LOCAL FAST_FORWARD FOR
SELECT name
FROM sys.databases
WHERE database_id > 4
  AND state_desc = 'ONLINE'
  AND is_read_only = 0;

OPEN db_cur;
FETCH NEXT FROM db_cur INTO @DbName;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @LogFile = NULL;

    SELECT @LogFile = mf.name
    FROM sys.master_files mf
    WHERE mf.database_id = DB_ID(@DbName)
      AND mf.type_desc = 'LOG';

    IF @LogFile IS NOT NULL
    BEGIN
        SET @SQL = N'USE ' + QUOTENAME(@DbName) + N';
                    DBCC SHRINKFILE (' + QUOTENAME(@LogFile,'''') + N', 512);';

        PRINT 'Shrinking log file ' + @LogFile + ' in database ' + @DbName;
        EXEC sys.sp_executesql @SQL;
    END

    FETCH NEXT FROM db_cur INTO @DbName;
END

CLOSE db_cur;
DEALLOCATE db_cur;