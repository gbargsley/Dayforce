-- Top sessions by tempdb usage (internal = worktable / spill / versioning)
SET NOCOUNT ON;

SELECT
    ssu.session_id,
    ses.login_name,
    ses.host_name,
    ses.program_name,
    ISNULL(ssu.internal_objects_alloc_page_count,0) AS internal_pages,
    ISNULL(ssu.user_objects_alloc_page_count,0) AS user_pages,
    r.status,
    r.command,
    r.blocking_session_id,
    COALESCE( SUBSTRING(qt.text, 
        (r.statement_start_offset/2)+1,
        ((CASE WHEN r.statement_end_offset = -1 THEN DATALENGTH(qt.text) ELSE r.statement_end_offset END 
          - r.statement_start_offset)/2)+1),
      qt.text) AS current_statement,
    qt.text AS full_batch_text
FROM sys.dm_db_session_space_usage ssu
LEFT JOIN sys.dm_exec_sessions ses
    ON ssu.session_id = ses.session_id
LEFT JOIN sys.dm_exec_requests r
    ON ssu.session_id = r.session_id
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) qt
ORDER BY internal_pages DESC, user_pages DESC;


--kill 179