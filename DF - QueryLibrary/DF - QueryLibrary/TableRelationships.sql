DECLARE @EmployeeID INT = 66707;          -- Employee ID to check
--DECLARE @SchemaName SYSNAME = N'cv';    -- Schema of Employee table
DECLARE @TableName SYSNAME = N'Employee';
DECLARE @sql NVARCHAR(MAX) = N'';
 
-- Temporary results table
IF OBJECT_ID('tempdb..#RefCheck') IS NOT NULL DROP TABLE #RefCheck;
CREATE TABLE #RefCheck (
    TableName NVARCHAR(256),
    Status NVARCHAR(4000)
);
 
-- Build dynamic SQL for each referencing table
SELECT @sql = @sql + '
BEGIN TRY
    IF EXISTS (
        SELECT 1
        FROM ' + QUOTENAME(SCHEMA_NAME(tp.schema_id)) + '.' + QUOTENAME(tp.name) + ' 
        WHERE ' + QUOTENAME(cp.name) + ' = ' + CAST(@EmployeeID AS NVARCHAR(20)) + '
    )
        INSERT INTO #RefCheck(TableName, Status)
        VALUES (''' + QUOTENAME(SCHEMA_NAME(tp.schema_id)) + '.' + QUOTENAME(tp.name) + ''', ''Referenced'');
    ELSE
        INSERT INTO #RefCheck(TableName, Status)
        VALUES (''' + QUOTENAME(SCHEMA_NAME(tp.schema_id)) + '.' + QUOTENAME(tp.name) + ''', ''Not Referenced'');
END TRY
BEGIN CATCH
    INSERT INTO #RefCheck(TableName, Status)
    VALUES (''' + QUOTENAME(SCHEMA_NAME(tp.schema_id)) + '.' + QUOTENAME(tp.name) + ''', ''Error: '' + ERROR_MESSAGE());
END CATCH
'
FROM sys.foreign_keys AS fk
INNER JOIN sys.foreign_key_columns AS fkc 
    ON fk.object_id = fkc.constraint_object_id
INNER JOIN sys.tables AS tp 
    ON fkc.parent_object_id = tp.object_id
INNER JOIN sys.columns AS cp 
    ON fkc.parent_object_id = cp.object_id 
       AND fkc.parent_column_id = cp.column_id
INNER JOIN sys.tables AS tr 
    ON fkc.referenced_object_id = tr.object_id
INNER JOIN sys.schemas AS sr 
    ON tr.schema_id = sr.schema_id
WHERE tr.name = @TableName
-- AND sr.name = @SchemaName;
 
-- Execute dynamic SQL
EXEC sp_executesql @sql;
 
-- Show complete results
SELECT TableName, Status
FROM #RefCheck where status='Referenced'
ORDER BY Status DESC, TableName;