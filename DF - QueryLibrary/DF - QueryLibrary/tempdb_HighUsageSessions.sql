-- Map high tempdb usage sessions to host / app / login
SELECT s.session_id, s.login_name, s.host_name, s.program_name, s.client_interface_name,
       s.login_time, s.last_request_start_time, s.last_request_end_time,
       s.status
FROM sys.dm_exec_sessions s
WHERE s.session_id IN ( -- put session ids you found earlier
    SELECT TOP 50 session_id
    FROM sys.dm_db_session_space_usage
    WHERE internal_objects_alloc_page_count > 0
    ORDER BY internal_objects_alloc_page_count DESC
);
