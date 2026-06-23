SELECT
    'DROP PROCEDURE '
    + QUOTENAME(SCHEMA_NAME(schema_id))
    + '.'
    + QUOTENAME(name)
    + ';' AS DropStatement
FROM sys.procedures
WHERE name LIKE 'QS_SoSSE30%';