-- Per-task view for fine-grain mapping
SELECT
    r.session_id,
    r.request_id,
    tsku.internal_objects_alloc_page_count,
    tsku.user_objects_alloc_page_count,
    r.status,
    r.command,
    r.wait_type,
    SUBSTRING(qt.text, (r.statement_start_offset/2)+1, 
        (CASE WHEN r.statement_end_offset = -1 THEN DATALENGTH(qt.text) ELSE r.statement_end_offset END - r.statement_start_offset)/2 + 1) AS statement_text
FROM sys.dm_db_task_space_usage tsku
JOIN sys.dm_exec_requests r ON tsku.session_id = r.session_id AND tsku.request_id = r.request_id
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) qt
WHERE tsku.internal_objects_alloc_page_count > 0
ORDER BY tsku.internal_objects_alloc_page_count DESC;
