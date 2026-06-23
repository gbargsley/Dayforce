SELECT s.session_id,
       s.login_name,
       SUM(u.user_objects_alloc_page_count + u.internal_objects_alloc_page_count) * 8 AS tempdb_kb
FROM sys.dm_db_session_space_usage AS u
JOIN sys.dm_exec_sessions AS s WITH (NOLOCK) ON u.session_id = s.session_id
GROUP BY s.session_id, s.login_name
ORDER BY tempdb_kb DESC;
