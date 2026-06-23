SET NOCOUNT ON;

CREATE TABLE #Results
(
    ServerName     sysname,
    DatabaseName   sysname,
    SchemaName     sysname,
    ProcedureName  sysname,
    CreateDate     datetime,
    ModifyDate     datetime
);

DECLARE @sql nvarchar(max) = N'';

SELECT @sql += N'
BEGIN TRY
    INSERT INTO #Results
    (
        ServerName,
        DatabaseName,
        SchemaName,
        ProcedureName,
        CreateDate,
        ModifyDate
    )
    SELECT
        @@SERVERNAME,
        ' + QUOTENAME(d.name, '''') + N',
        s.name,
        p.name,
        p.create_date,
        p.modify_date
    FROM ' + QUOTENAME(d.name) + N'.sys.procedures AS p
    INNER JOIN ' + QUOTENAME(d.name) + N'.sys.schemas AS s
        ON s.schema_id = p.schema_id
    WHERE p.name LIKE ''QS_SoSSE30%'';
END TRY
BEGIN CATCH
    -- Skip databases that are inaccessible or error during scan
END CATCH;
'
FROM sys.databases AS d
WHERE d.database_id > 4
  AND d.state_desc = 'ONLINE'
  AND HAS_DBACCESS(d.name) = 1;

EXEC sys.sp_executesql @sql;

SELECT
    ServerName,
    DatabaseName,
    SchemaName,
    ProcedureName,
    CreateDate,
    ModifyDate
FROM #Results
ORDER BY
    ServerName,
    DatabaseName,
    SchemaName,
    ProcedureName;

DROP TABLE #Results;