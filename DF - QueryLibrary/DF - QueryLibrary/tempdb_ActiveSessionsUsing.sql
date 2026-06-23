SELECT session_id, request_id,
       user_objects_alloc_page_count * 8 AS user_kb,
       internal_objects_alloc_page_count * 8 AS internal_kb
FROM sys.dm_db_task_space_usage
WHERE (user_objects_alloc_page_count + internal_objects_alloc_page_count) > 0
ORDER BY (user_objects_alloc_page_count + internal_objects_alloc_page_count) DESC;
