DROP TABLE IF EXISTS [SR2511100040010255].[dbo].[tempdb_dm_db_xtp_memory_consumers]                             

DROP TABLE IF EXISTS [SR2511100040010255].[dbo].[tempdb_dm_db_xtp_object_stats]                                         

DROP TABLE IF EXISTS [SR2511100040010255].[dbo].[tempdb_dm_db_xtp_table_memory_stats]             

DROP TABLE IF EXISTS [SR2511100040010255].[dbo].[tempdb_dm_db_xtp_transactions]                                        

DROP TABLE IF EXISTS [SR2511100040010255].[dbo].[tempdb_dm_tran_active_transactions]  

DROP TABLE IF EXISTS [SR2511100040010255].[dbo].[tempdb_dm_tran_database_transactions]             

DROP TABLE IF EXISTS [SR2511100040010255].[dbo].[tempdb_dm_tran_session_transactions]

DROP TABLE IF EXISTS [SR2511100040010255].[dbo].[tempdb_dm_xtp_gc_queue_stats]                                         

DROP TABLE IF EXISTS [SR2511100040010255].[dbo].[tempdb_dm_xtp_system_memory_consumers]      

DROP TABLE IF EXISTS [SR2511100040010255].[dbo].[tempdb_dm_xtp_transaction_recent_rows]            

DROP TABLE IF EXISTS [SR2511100040010255].[dbo].[tempdb_dm_xtp_transaction_stats]                       

DROP TABLE IF EXISTS [SR2511100040010255].[dbo].[trk_Transactions]

DROP TABLE IF EXISTS [SR2511100040010255].[dbo].[dm_os_memory_clerks]

DROP TABLE IF EXISTS [SR2511100040010255].[dbo].[dm_resource_governor_resource_pools]

 

CREATE TABLE [SR2511100040010255].[dbo].[dm_os_memory_clerks]                                                                     ([ServerName] [nvarchar](128) NULL,[ServerDate] [datetimeoffset](7) NULL,[memory_clerk_address] [varbinary](8) NULL,[type] [nvarchar](60) NULL,[name] [nvarchar](256) NULL,[memory_node_id] [smallint] NULL,[pages_kb] [bigint] NULL,[virtual_memory_reserved_kb] [bigint] NULL,[virtual_memory_committed_kb] [bigint] NULL,[awe_allocated_kb] [bigint] NULL,[shared_memory_reserved_kb] [bigint] NULL,[shared_memory_committed_kb] [bigint] NULL,[page_size_in_bytes] [bigint] NULL,[page_allocator_address] [varbinary](8) NULL,[host_address] [varbinary](8) NULL,[parent_memory_broker_type] [nvarchar](60) NULL) ON [PRIMARY]

CREATE TABLE [SR2511100040010255].[dbo].[dm_resource_governor_resource_pools]   ([ServerName] [nvarchar](128) NULL,[ServerDate] [datetimeoffset](7) NULL,[pool_id] [int]  NULL, [name] [nvarchar](256)  NULL, [statistics_start_time] [datetime]  NULL, [total_cpu_usage_ms] [bigint]  NULL, [cache_memory_kb] [bigint]  NULL, [compile_memory_kb] [bigint]  NULL, [used_memgrant_kb] [bigint]  NULL, [total_memgrant_count] [bigint]  NULL, [total_memgrant_timeout_count] [bigint]  NULL, [active_memgrant_count] [int]  NULL, [active_memgrant_kb] [bigint]  NULL, [memgrant_waiter_count] [int]  NULL, [max_memory_kb] [bigint]  NULL, [used_memory_kb] [bigint]  NULL, [target_memory_kb] [bigint]  NULL, [out_of_memory_count] [bigint]  NULL, [min_cpu_percent] [int]  NULL, [max_cpu_percent] [int]  NULL, [min_memory_percent] [int]  NULL, [max_memory_percent] [int]  NULL, [cap_cpu_percent] [int]  NULL, [min_iops_per_volume] [int] NULL, [max_iops_per_volume] [int] NULL, [read_io_queued_total] [int] NULL, [read_io_issued_total] [int] NULL, [read_io_completed_total] [int]  NULL, [read_io_throttled_total] [int] NULL, [read_bytes_total] [bigint]  NULL, [read_io_stall_total_ms] [bigint]  NULL, [read_io_stall_queued_ms] [bigint] NULL, [write_io_queued_total] [int] NULL, [write_io_issued_total] [int] NULL, [write_io_completed_total] [int]  NULL, [write_io_throttled_total] [int] NULL, [write_bytes_total] [bigint]  NULL, [write_io_stall_total_ms] [bigint]  NULL, [write_io_stall_queued_ms] [bigint] NULL, [io_issue_violations_total] [int] NULL, [io_issue_delay_total_ms] [bigint] NULL, [io_issue_ahead_total_ms] [bigint] NULL, [reserved_io_limited_by_volume_total] [int] NULL, [io_issue_delay_non_throttled_total_ms] [bigint] NULL, [total_cpu_delayed_ms] [bigint]  NULL, [total_cpu_active_ms] [bigint]  NULL, [total_cpu_violation_delay_ms] [bigint]  NULL, [total_cpu_violation_sec] [bigint]  NULL, [total_cpu_usage_preemptive_ms] [bigint]  NULL) ON [PRIMARY]

CREATE TABLE [SR2511100040010255].[dbo].[tempdb_dm_db_xtp_memory_consumers]                          ([ServerName] [nvarchar](128) NULL,[ServerDate] [datetimeoffset](7) NULL, [memory_consumer_id] [bigint]  NULL,[memory_consumer_type] [int]  NULL,[memory_consumer_type_desc] [nvarchar](16)  NULL,[memory_consumer_desc] [nvarchar](64) NULL,[object_id] [int] NULL,[xtp_object_id] [int] NULL,[index_id] [int] NULL,[allocated_bytes] [bigint]  NULL,[used_bytes] [bigint]  NULL,[allocation_count] [bigint]  NULL,[partition_count] [int]  NULL,[sizeclass_count] [int]  NULL,[min_sizeclass] [int]  NULL,[max_sizeclass] [int]  NULL,[memory_consumer_address] [varbinary](8)  NULL) ON [PRIMARY]

CREATE TABLE [SR2511100040010255].[dbo].[tempdb_dm_db_xtp_object_stats]                                       ([ServerName] [nvarchar](128) NULL,[ServerDate] [datetimeoffset](7) NULL, [object_id] [int]  NULL,[xtp_object_id] [int]  NULL,[row_insert_attempts] [bigint]  NULL,[row_update_attempts] [bigint]  NULL,[row_delete_attempts] [bigint]  NULL,[write_conflicts] [bigint]  NULL, [unique_constraint_violations] [bigint]  NULL,[object_address] [varbinary](8)  NULL) ON [PRIMARY]

CREATE TABLE [SR2511100040010255].[dbo].[tempdb_dm_db_xtp_table_memory_stats]          ([ServerName] [nvarchar](128) NULL,[ServerDate] [datetimeoffset](7) NULL, [object_id] [int] NULL,[memory_allocated_for_table_kb] [bigint] NULL,[memory_used_by_table_kb] [bigint] NULL,[memory_allocated_for_indexes_kb] [bigint] NULL,[memory_used_by_indexes_kb] [bigint] NULL) ON [PRIMARY]

CREATE TABLE [SR2511100040010255].[dbo].[tempdb_dm_db_xtp_transactions]                                      ([ServerName] [nvarchar](128) NULL,[ServerDate] [datetimeoffset](7) NULL, [node_id] [smallint]  NULL, [xtp_transaction_id] [bigint]  NULL, [transaction_id] [bigint]  NULL, [session_id] [smallint]  NULL, [begin_tsn] [bigint]  NULL, [end_tsn] [bigint]  NULL, [state] [int]  NULL, [state_desc] [nvarchar](16)  NULL, [result] [int]  NULL, [result_desc] [nvarchar](24)  NULL, [xtp_parent_transaction_node_id] [smallint]  NULL, [xtp_parent_transaction_id] [bigint]  NULL, [last_error] [int]  NULL, [is_speculative] [bit]  NULL, [is_prepared] [bit]  NULL, [is_delayed_durability] [bit]  NULL, [memory_address] [varbinary](8)  NULL, [database_address] [varbinary](8)  NULL, [thread_id] [int]  NULL, [read_set_row_count] [int]  NULL, [write_set_row_count] [int]  NULL, [scan_set_count] [int]  NULL, [savepoint_garbage_count] [int]  NULL, [log_bytes_required] [bigint]  NULL, [count_of_allocations] [int]  NULL, [allocated_bytes] [int]  NULL, [reserved_bytes] [int]  NULL, [commit_dependency_count] [int]  NULL, [commit_dependency_total_attempt_count] [int]  NULL, [scan_area] [int]  NULL, [scan_area_desc] [nvarchar](16)  NULL, [scan_location] [int]  NULL, [dependent_1_address] [varbinary](8)  NULL, [dependent_2_address] [varbinary](8)  NULL, [dependent_3_address] [varbinary](8)  NULL, [dependent_4_address] [varbinary](8)  NULL, [dependent_5_address] [varbinary](8)  NULL, [dependent_6_address] [varbinary](8)  NULL, [dependent_7_address] [varbinary](8)  NULL, [dependent_8_address] [varbinary](8)  NULL) ON [PRIMARY]

CREATE TABLE [SR2511100040010255].[dbo].[tempdb_dm_tran_active_transactions]               ([ServerName] [nvarchar](128) NULL,[ServerDate] [datetimeoffset](7) NULL, [transaction_id] [bigint]  NULL, [name] [nvarchar](32)  NULL, [transaction_begin_time] [datetime]  NULL, [transaction_type] [int]  NULL, [transaction_uow] [uniqueidentifier] NULL, [transaction_state] [int]  NULL, [transaction_status] [int]  NULL, [transaction_status2] [int]  NULL, [dtc_state] [int]  NULL, [dtc_status] [int]  NULL, [dtc_isolation_level] [int]  NULL, [filestream_transaction_id] [varbinary](128) NULL) ON [PRIMARY]

 

CREATE TABLE [SR2511100040010255].[dbo].[tempdb_dm_tran_database_transactions]          ([ServerName] [nvarchar](128) NULL,[ServerDate] [datetimeoffset](7) NULL, [transaction_id] [bigint]  NULL, [database_id] [int]  NULL, [database_transaction_begin_time] [datetime] NULL, [database_transaction_type] [int]  NULL,[database_transaction_state] [int]  NULL, [database_transaction_status] [int]  NULL, [database_transaction_status2] [int]  NULL, [database_transaction_log_record_count] [bigint]  NULL, [database_transaction_replicate_record_count] [int]  NULL, [database_transaction_log_bytes_used] [bigint]  NULL, [database_transaction_log_bytes_reserved] [bigint]  NULL, [database_transaction_log_bytes_used_system] [int]  NULL, [database_transaction_log_bytes_reserved_system] [int]  NULL, [database_transaction_begin_lsn] [numeric](25, 0) NULL, [database_transaction_last_lsn] [numeric](25, 0) NULL, [database_transaction_most_recent_savepoint_lsn] [numeric](25, 0) NULL, [database_transaction_commit_lsn] [numeric](25, 0) NULL, [database_transaction_last_rollback_lsn] [numeric](25, 0) NULL, [database_transaction_next_undo_lsn] [numeric](25, 0) NULL) ON [PRIMARY]

CREATE TABLE [SR2511100040010255].[dbo].[tempdb_dm_tran_session_transactions]             ([ServerName] [nvarchar](128) NULL,[ServerDate] [datetimeoffset](7) NULL, [session_id] [int]  NULL, [transaction_id] [bigint]  NULL, [transaction_descriptor] [binary](8)  NULL, [enlist_count] [int]  NULL, [is_user_transaction] [bit]  NULL, [is_local] [bit]  NULL, [is_enlisted] [bit]  NULL, [is_bound] [bit]  NULL, [open_transaction_count] [int]  NULL) ON [PRIMARY]

CREATE TABLE [SR2511100040010255].[dbo].[tempdb_dm_xtp_gc_queue_stats]                                       ([ServerName] [nvarchar](128) NULL,[ServerDate] [datetimeoffset](7) NULL, [queue_id] [int]  NULL, [total_enqueues] [bigint]  NULL, [total_dequeues] [bigint]  NULL, [current_queue_depth] [bigint]  NULL, [maximum_queue_depth] [bigint]  NULL, [last_service_ticks] [bigint]  NULL) ON [PRIMARY]

CREATE TABLE [SR2511100040010255].[dbo].[tempdb_dm_xtp_system_memory_consumers]   ([ServerName] [nvarchar](128) NULL,[ServerDate] [datetimeoffset](7) NULL, [memory_consumer_id] [bigint]  NULL, [memory_consumer_type] [int]  NULL, [memory_consumer_type_desc] [nvarchar](16)  NULL, [memory_consumer_desc] [nvarchar](64) NULL, [lookaside_id] [bigint] NULL, [allocated_bytes] [bigint]  NULL, [used_bytes] [bigint]  NULL, [allocation_count] [bigint]  NULL, [partition_count] [int]  NULL, [sizeclass_count] [int]  NULL, [min_sizeclass] [int]  NULL, [max_sizeclass] [int]  NULL, [memory_consumer_address] [varbinary](8)  NULL) ON [PRIMARY]

CREATE TABLE [SR2511100040010255].[dbo].[tempdb_dm_xtp_transaction_recent_rows]         ([ServerName] [nvarchar](128) NULL,[ServerDate] [datetimeoffset](7) NULL, [node_id] [smallint]  NULL, [xtp_transaction_id] [bigint]  NULL,[row_address] [varbinary](8)  NULL, [table_address] [varbinary](8)  NULL, [before_begin] [bigint]  NULL, [before_end] [bigint]  NULL, [before_links] [int]  NULL, [before_time] [bigint]  NULL, [after_begin] [bigint]  NULL, [after_end] [bigint]  NULL, [after_links] [int]  NULL, [after_time] [bigint]  NULL, [outcome] [varbinary](8)  NULL) ON [PRIMARY]

CREATE TABLE [SR2511100040010255].[dbo].[tempdb_dm_xtp_transaction_stats]                    ([ServerName] [nvarchar](128) NULL,[ServerDate] [datetimeoffset](7) NULL, [total_count] [bigint]  NULL, [read_only_count] [bigint]  NULL, [total_aborts] [bigint]  NULL, [system_aborts] [bigint]  NULL, [validation_failures] [bigint]  NULL, [dependencies_taken] [bigint]  NULL, [dependencies_failed] [bigint]  NULL, [savepoint_create] [bigint]  NULL, [savepoint_rollbacks] [bigint]  NULL, [savepoint_refreshes] [bigint]  NULL, [log_bytes_written] [bigint]  NULL, [log_IO_count] [bigint]  NULL, [phantom_scans_started] [bigint]  NULL, [phantom_scans_retries] [bigint]  NULL, [phantom_rows_touched] [bigint]  NULL, [phantom_rows_expiring] [bigint]  NULL, [phantom_rows_expired] [bigint]  NULL, [phantom_rows_expired_removed] [bigint]  NULL, [scans_started] [bigint]  NULL, [scans_retried] [bigint]  NULL, [rows_returned] [bigint]  NULL, [rows_touched] [bigint]  NULL, [rows_expiring] [bigint]  NULL, [rows_expired] [bigint]  NULL, [rows_expired_removed] [bigint]  NULL, [row_insert_attempts] [bigint]  NULL, [row_update_attempts] [bigint]  NULL, [row_delete_attempts] [bigint]  NULL, [write_conflicts] [bigint]  NULL, [unique_constraint_violations] [bigint]  NULL, [drop_table_memory_attempts] [bigint]  NULL, [drop_table_memory_failures] [bigint]  NULL) ON [PRIMARY]

CREATE TABLE [SR2511100040010255].[dbo].[trk_Transactions]                                                                                              ([ServerName] [nvarchar](128) NULL,[ServerDate] [datetimeoffset](7) NULL,[transaction_begin_time] [datetime] NULL,[login_time] [datetime] NULL,[login_name] [nvarchar](128) NULL,[status] [nvarchar](30) NULL,[command] [nvarchar](32) NULL,[XactName] [nvarchar](32) NULL,[host_name] [nvarchar](128) NULL,[program_name] [nvarchar](128) NULL,[session_id] [smallint] NULL,[Database] [nvarchar](128) NULL,[last_request_start_time] [datetime] NULL,[last_request_end_time] [datetime] NULL,[Type] [varchar](12) NULL,[State] [varchar](32) NULL,[is_user_transaction] [bit] NULL,[is_local] [bit] NULL,[open_transaction_count] [int] NULL,[blocking_session_id] [smallint] NULL,[wait_type] [nvarchar](60) NULL,[wait_time] [int] NULL,[last_wait_type] [nvarchar](60) NULL,[wait_resource] [nvarchar](256) NULL,[transaction_isolation_level] [smallint] NULL,[prev_error] [int] NULL,[text] [nvarchar](max) NULL)

 

USE [SR2511100040010255]

GO

CREATE CLUSTERED INDEX [CIX_dm_os_memory_clerks] ON [dbo].[dm_os_memory_clerks] ([ServerDate] ASC) WITH (PAD_INDEX = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, DATA_COMPRESSION=PAGE)                                                       

CREATE CLUSTERED INDEX [CIX_dm_resource_governor_resource_pools] ON [dbo].[dm_resource_governor_resource_pools] ([ServerDate] ASC) WITH (PAD_INDEX = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, DATA_COMPRESSION=PAGE)                                                       

CREATE CLUSTERED INDEX [CIX_tempdb_dm_db_xtp_memory_consumers] ON [dbo].[tempdb_dm_db_xtp_memory_consumers] ([ServerDate] ASC) WITH (PAD_INDEX = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, DATA_COMPRESSION=PAGE)

CREATE CLUSTERED INDEX [CIX_tempdb_dm_db_xtp_object_stats] ON [dbo].[tempdb_dm_db_xtp_object_stats] ([ServerDate] ASC) WITH (PAD_INDEX = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, DATA_COMPRESSION=PAGE)                               

CREATE CLUSTERED INDEX [CIX_tempdb_dm_db_xtp_table_memory_stats] ON [dbo].[tempdb_dm_db_xtp_table_memory_stats] ([ServerDate] ASC) WITH (PAD_INDEX = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, DATA_COMPRESSION=PAGE)        

CREATE CLUSTERED INDEX [CIX_tempdb_dm_db_xtp_transactions] ON [dbo].[tempdb_dm_db_xtp_transactions] ([ServerDate] ASC) WITH (PAD_INDEX = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, DATA_COMPRESSION=PAGE)                               

CREATE CLUSTERED INDEX [CIX_tempdb_dm_tran_active_transactions] ON [dbo].[tempdb_dm_tran_active_transactions] ([ServerDate] ASC) WITH (PAD_INDEX = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, DATA_COMPRESSION=PAGE)

CREATE CLUSTERED INDEX [CIX_tempdb_dm_tran_database_transactions] ON [dbo].[tempdb_dm_tran_database_transactions] ([ServerDate] ASC) WITH (PAD_INDEX = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, DATA_COMPRESSION=PAGE)        

CREATE CLUSTERED INDEX [CIX_tempdb_dm_tran_session_transactions] ON [dbo].[tempdb_dm_tran_session_transactions] ([ServerDate] ASC) WITH (PAD_INDEX = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, DATA_COMPRESSION=PAGE)        

CREATE CLUSTERED INDEX [CIX_tempdb_dm_xtp_gc_queue_stats] ON [dbo].[tempdb_dm_xtp_gc_queue_stats] ([ServerDate] ASC) WITH (PAD_INDEX = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, DATA_COMPRESSION=PAGE)                               

CREATE CLUSTERED INDEX [CIX_tempdb_dm_xtp_system_memory_consumers] ON [dbo].[tempdb_dm_xtp_system_memory_consumers] ([ServerDate] ASC) WITH (PAD_INDEX = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, DATA_COMPRESSION=PAGE)      

CREATE CLUSTERED INDEX [CIX_tempdb_dm_xtp_transaction_recent_rows] ON [dbo].[tempdb_dm_xtp_transaction_recent_rows] ([ServerDate] ASC) WITH (PAD_INDEX = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, DATA_COMPRESSION=PAGE)       

CREATE CLUSTERED INDEX [CIX_tempdb_dm_xtp_transaction_stats] ON [dbo].[tempdb_dm_xtp_transaction_stats] ([ServerDate] ASC) WITH (PAD_INDEX = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, DATA_COMPRESSION=PAGE)                            

CREATE CLUSTERED INDEX [CIX_trk_Transactions] ON [dbo].[trk_Transactions] ([ServerDate] ASC) WITH (PAD_INDEX = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, DATA_COMPRESSION=PAGE)                                                                                   

 

 

USE [SR2511100040010255]

GO

CREATE OR ALTER PROCEDURE [dbo].[MonitorValues]

 

AS

BEGIN

SET NOCOUNT ON;

 

----------------------------------- sys.dm_os_memory_clerks

INSERT INTO [SR2511100040010255].[dbo].[dm_os_memory_clerks]

                     ([ServerName],                     [ServerDate], [memory_clerk_address], [type], [name], [memory_node_id], [pages_kb], [virtual_memory_reserved_kb], [virtual_memory_committed_kb], [awe_allocated_kb], [shared_memory_reserved_kb], [shared_memory_committed_kb], [page_size_in_bytes], [page_allocator_address], [host_address], [parent_memory_broker_type])

SELECT @@ServerName as ServerName, SYSDATETIMEOFFSET() as ServerDate, [memory_clerk_address], [type], [name], [memory_node_id], [pages_kb], [virtual_memory_reserved_kb], [virtual_memory_committed_kb], [awe_allocated_kb], [shared_memory_reserved_kb], [shared_memory_committed_kb], [page_size_in_bytes], [page_allocator_address], [host_address], [parent_memory_broker_type]

FROM sys.dm_os_memory_clerks

 

----------------------------------- sys.dm_resource_governor_resource_pools

INSERT INTO [SR2511100040010255].[dbo].[dm_resource_governor_resource_pools]

                      ([ServerName],                        [ServerDate], [pool_id], [name], [statistics_start_time], [total_cpu_usage_ms], [cache_memory_kb], [compile_memory_kb], [used_memgrant_kb], [total_memgrant_count], [total_memgrant_timeout_count], [active_memgrant_count], [active_memgrant_kb], [memgrant_waiter_count], [max_memory_kb], [used_memory_kb], [target_memory_kb], [out_of_memory_count], [min_cpu_percent], [max_cpu_percent], [min_memory_percent], [max_memory_percent], [cap_cpu_percent], [min_iops_per_volume], [max_iops_per_volume], [read_io_queued_total], [read_io_issued_total], [read_io_completed_total], [read_io_throttled_total], [read_bytes_total], [read_io_stall_total_ms], [read_io_stall_queued_ms], [write_io_queued_total], [write_io_issued_total], [write_io_completed_total], [write_io_throttled_total], [write_bytes_total], [write_io_stall_total_ms], [write_io_stall_queued_ms], [io_issue_violations_total], [io_issue_delay_total_ms], [io_issue_ahead_total_ms], [reserved_io_limited_by_volume_total], [io_issue_delay_non_throttled_total_ms], [total_cpu_delayed_ms], [total_cpu_active_ms], [total_cpu_violation_delay_ms], [total_cpu_violation_sec], [total_cpu_usage_preemptive_ms])

SELECT @@ServerName as [ServerName], SYSDATETIMEOFFSET() as [ServerDate], [pool_id], [name], [statistics_start_time], [total_cpu_usage_ms], [cache_memory_kb], [compile_memory_kb], [used_memgrant_kb], [total_memgrant_count], [total_memgrant_timeout_count], [active_memgrant_count], [active_memgrant_kb], [memgrant_waiter_count], [max_memory_kb], [used_memory_kb], [target_memory_kb], [out_of_memory_count], [min_cpu_percent], [max_cpu_percent], [min_memory_percent], [max_memory_percent], [cap_cpu_percent], [min_iops_per_volume], [max_iops_per_volume], [read_io_queued_total], [read_io_issued_total], [read_io_completed_total], [read_io_throttled_total], [read_bytes_total], [read_io_stall_total_ms], [read_io_stall_queued_ms], [write_io_queued_total], [write_io_issued_total], [write_io_completed_total], [write_io_throttled_total], [write_bytes_total], [write_io_stall_total_ms], [write_io_stall_queued_ms], [io_issue_violations_total], [io_issue_delay_total_ms], [io_issue_ahead_total_ms], [reserved_io_limited_by_volume_total], [io_issue_delay_non_throttled_total_ms], [total_cpu_delayed_ms], [total_cpu_active_ms], [total_cpu_violation_delay_ms], [total_cpu_violation_sec], [total_cpu_usage_preemptive_ms]

FROM sys.dm_resource_governor_resource_pools

 

---------------------------------------- tempdb.sys.dm_db_xtp_memory_consumers

INSERT INTO  [SR2511100040010255].[dbo].[tempdb_dm_db_xtp_memory_consumers]

                      ([ServerName],                        [ServerDate], [memory_consumer_id], [memory_consumer_type], [memory_consumer_type_desc], [memory_consumer_desc], [object_id], [xtp_object_id], [index_id], [allocated_bytes], [used_bytes], [allocation_count], [partition_count], [sizeclass_count], [min_sizeclass], [max_sizeclass], [memory_consumer_address])

SELECT @@ServerName as [ServerName], SYSDATETIMEOFFSET() as [ServerDate], [memory_consumer_id], [memory_consumer_type], [memory_consumer_type_desc], [memory_consumer_desc], [object_id], [xtp_object_id], [index_id], [allocated_bytes], [used_bytes], [allocation_count], [partition_count], [sizeclass_count], [min_sizeclass], [max_sizeclass], [memory_consumer_address]

FROM tempdb.sys.dm_db_xtp_memory_consumers  ORDER BY allocated_bytes DESC

 

---------------------------------------- tempdb.sys.dm_db_xtp_object_stats

INSERT INTO  [SR2511100040010255].[dbo].[tempdb_dm_db_xtp_object_stats]

                     ([ServerName],                         [ServerDate], [object_id], [xtp_object_id], [row_insert_attempts], [row_update_attempts], [row_delete_attempts], [write_conflicts], [unique_constraint_violations], [object_address] )

SELECT @@ServerName as [ServerName], SYSDATETIMEOFFSET() as [ServerDate], [object_id], [xtp_object_id], [row_insert_attempts], [row_update_attempts], [row_delete_attempts], [write_conflicts], [unique_constraint_violations], [object_address]

FROM tempdb.sys.dm_db_xtp_object_stats

 

----------------------------------------  tempdb.sys.dm_db_xtp_table_memory_stats

INSERT INTO  [SR2511100040010255].[dbo].[tempdb_dm_db_xtp_table_memory_stats]

                      ([ServerName],                        [ServerDate], [object_id], [memory_allocated_for_table_kb], [memory_used_by_table_kb], [memory_allocated_for_indexes_kb], [memory_used_by_indexes_kb])

SELECT @@ServerName as [ServerName], SYSDATETIMEOFFSET() as [ServerDate], [object_id], [memory_allocated_for_table_kb], [memory_used_by_table_kb], [memory_allocated_for_indexes_kb], [memory_used_by_indexes_kb]

FROM tempdb.sys.dm_db_xtp_table_memory_stats ORDER BY memory_allocated_for_table_kb DESC

 

----------------------------------------  tempdb.sys.dm_db_xtp_transactions

INSERT INTO  [SR2511100040010255].[dbo].[tempdb_dm_db_xtp_transactions]

                      ([ServerName],                        [ServerDate], [node_id], [xtp_transaction_id], [transaction_id], [session_id], [begin_tsn], [end_tsn], [state], [state_desc], [result], [result_desc], [xtp_parent_transaction_node_id], [xtp_parent_transaction_id], [last_error], [is_speculative], [is_prepared], [is_delayed_durability], [memory_address], [database_address], [thread_id], [read_set_row_count], [write_set_row_count], [scan_set_count], [savepoint_garbage_count], [log_bytes_required], [count_of_allocations], [allocated_bytes], [reserved_bytes], [commit_dependency_count], [commit_dependency_total_attempt_count], [scan_area], [scan_area_desc], [scan_location], [dependent_1_address], [dependent_2_address], [dependent_3_address], [dependent_4_address], [dependent_5_address], [dependent_6_address], [dependent_7_address], [dependent_8_address])

SELECT @@ServerName as [ServerName], SYSDATETIMEOFFSET() as [ServerDate], [node_id], [xtp_transaction_id], [transaction_id], [session_id], [begin_tsn], [end_tsn], [state], [state_desc], [result], [result_desc], [xtp_parent_transaction_node_id], [xtp_parent_transaction_id], [last_error], [is_speculative], [is_prepared], [is_delayed_durability], [memory_address], [database_address], [thread_id], [read_set_row_count], [write_set_row_count], [scan_set_count], [savepoint_garbage_count], [log_bytes_required], [count_of_allocations], [allocated_bytes], [reserved_bytes], [commit_dependency_count], [commit_dependency_total_attempt_count], [scan_area], [scan_area_desc], [scan_location], [dependent_1_address], [dependent_2_address], [dependent_3_address], [dependent_4_address], [dependent_5_address], [dependent_6_address], [dependent_7_address], [dependent_8_address]

FROM tempdb.sys.dm_db_xtp_transactions

 

---------------------------------------- tempdb.sys.dm_tran_active_transactions

INSERT INTO  [SR2511100040010255].[dbo].[tempdb_dm_tran_active_transactions]

                      ([ServerName],                        [ServerDate], [transaction_id], [name], [transaction_begin_time], [transaction_type], [transaction_uow], [transaction_state], [transaction_status], [transaction_status2], [dtc_state], [dtc_status], [dtc_isolation_level], [filestream_transaction_id])

SELECT @@ServerName as [ServerName], SYSDATETIMEOFFSET() as [ServerDate], [transaction_id], [name], [transaction_begin_time], [transaction_type], [transaction_uow], [transaction_state], [transaction_status], [transaction_status2], [dtc_state], [dtc_status], [dtc_isolation_level], [filestream_transaction_id]

FROM tempdb.sys.dm_tran_active_transactions

 

---------------------------------------- tempdb.sys.dm_tran_database_transactions

INSERT INTO  [SR2511100040010255].[dbo].[tempdb_dm_tran_database_transactions]

                      ([ServerName],                        [ServerDate], [transaction_id], [database_id], [database_transaction_begin_time], [database_transaction_type], [database_transaction_state], [database_transaction_status], [database_transaction_status2], [database_transaction_log_record_count], [database_transaction_replicate_record_count], [database_transaction_log_bytes_used], [database_transaction_log_bytes_reserved], [database_transaction_log_bytes_used_system], [database_transaction_log_bytes_reserved_system], [database_transaction_begin_lsn], [database_transaction_last_lsn], [database_transaction_most_recent_savepoint_lsn], [database_transaction_commit_lsn], [database_transaction_last_rollback_lsn], [database_transaction_next_undo_lsn] )

SELECT @@ServerName as [ServerName], SYSDATETIMEOFFSET() as [ServerDate], [transaction_id], [database_id], [database_transaction_begin_time], [database_transaction_type], [database_transaction_state], [database_transaction_status], [database_transaction_status2], [database_transaction_log_record_count], [database_transaction_replicate_record_count], [database_transaction_log_bytes_used], [database_transaction_log_bytes_reserved], [database_transaction_log_bytes_used_system], [database_transaction_log_bytes_reserved_system], [database_transaction_begin_lsn], [database_transaction_last_lsn], [database_transaction_most_recent_savepoint_lsn], [database_transaction_commit_lsn], [database_transaction_last_rollback_lsn], [database_transaction_next_undo_lsn]

FROM tempdb.sys.dm_tran_database_transactions

 

---------------------------------------- tempdb.sys.dm_tran_session_transactions

INSERT INTO  [SR2511100040010255].[dbo].[tempdb_dm_tran_session_transactions]

                      ([ServerName],                        [ServerDate], [session_id], [transaction_id], [transaction_descriptor], [enlist_count], [is_user_transaction], [is_local], [is_enlisted], [is_bound], [open_transaction_count] )

SELECT @@ServerName as [ServerName], SYSDATETIMEOFFSET() as [ServerDate], [session_id], [transaction_id], [transaction_descriptor], [enlist_count], [is_user_transaction], [is_local], [is_enlisted], [is_bound], [open_transaction_count]

FROM tempdb.sys.dm_tran_session_transactions

 

---------------------------------------- tempdb.sys.dm_xtp_gc_queue_stats 

INSERT INTO  [SR2511100040010255].[dbo].[tempdb_dm_xtp_gc_queue_stats]

                      ([ServerName],                        [ServerDate], [queue_id], [total_enqueues], [total_dequeues], [current_queue_depth], [maximum_queue_depth], [last_service_ticks])

SELECT @@ServerName as [ServerName], SYSDATETIMEOFFSET() as [ServerDate], [queue_id], [total_enqueues], [total_dequeues], [current_queue_depth], [maximum_queue_depth], [last_service_ticks]

FROM tempdb.sys.dm_xtp_gc_queue_stats  

 

---------------------------------------- tempdb.sys.dm_xtp_system_memory_consumers

INSERT INTO  [SR2511100040010255].[dbo].[tempdb_dm_xtp_system_memory_consumers]

                      ([ServerName],                        [ServerDate], [memory_consumer_id], [memory_consumer_type], [memory_consumer_type_desc], [memory_consumer_desc], [lookaside_id], [allocated_bytes], [used_bytes], [allocation_count], [partition_count], [sizeclass_count], [min_sizeclass], [max_sizeclass], [memory_consumer_address] )

SELECT @@ServerName as [ServerName], SYSDATETIMEOFFSET() as [ServerDate], [memory_consumer_id], [memory_consumer_type], [memory_consumer_type_desc], [memory_consumer_desc], [lookaside_id], [allocated_bytes], [used_bytes], [allocation_count], [partition_count], [sizeclass_count], [min_sizeclass], [max_sizeclass], [memory_consumer_address]

FROM tempdb.sys.dm_xtp_system_memory_consumers 

 

---------------------------------------- tempdb.sys.dm_xtp_transaction_recent_rows

INSERT INTO  [SR2511100040010255].[dbo].[tempdb_dm_xtp_transaction_recent_rows]

                      ([ServerName],                        [ServerDate], [node_id], [xtp_transaction_id], [row_address], [table_address], [before_begin], [before_end], [before_links], [before_time], [after_begin], [after_end], [after_links], [after_time], [outcome])

SELECT @@ServerName as [ServerName], SYSDATETIMEOFFSET() as [ServerDate], [node_id], [xtp_transaction_id], [row_address], [table_address], [before_begin], [before_end], [before_links], [before_time], [after_begin], [after_end], [after_links], [after_time], [outcome]

FROM tempdb.sys.dm_xtp_transaction_recent_rows

 

---------------------------------------- tempdb.sys.dm_xtp_transaction_stats

INSERT INTO  [SR2511100040010255].[dbo].[tempdb_dm_xtp_transaction_stats]

                      ([ServerName],                        [ServerDate], [total_count], [read_only_count], [total_aborts], [system_aborts], [validation_failures], [dependencies_taken], [dependencies_failed], [savepoint_create], [savepoint_rollbacks], [savepoint_refreshes], [log_bytes_written], [log_IO_count], [phantom_scans_started], [phantom_scans_retries], [phantom_rows_touched], [phantom_rows_expiring], [phantom_rows_expired], [phantom_rows_expired_removed], [scans_started], [scans_retried], [rows_returned], [rows_touched], [rows_expiring], [rows_expired], [rows_expired_removed], [row_insert_attempts], [row_update_attempts], [row_delete_attempts], [write_conflicts], [unique_constraint_violations], [drop_table_memory_attempts], [drop_table_memory_failures])

SELECT @@ServerName as [ServerName], SYSDATETIMEOFFSET() as [ServerDate], [total_count], [read_only_count], [total_aborts], [system_aborts], [validation_failures], [dependencies_taken], [dependencies_failed], [savepoint_create], [savepoint_rollbacks], [savepoint_refreshes], [log_bytes_written], [log_IO_count], [phantom_scans_started], [phantom_scans_retries], [phantom_rows_touched], [phantom_rows_expiring], [phantom_rows_expired], [phantom_rows_expired_removed], [scans_started], [scans_retried], [rows_returned], [rows_touched], [rows_expiring], [rows_expired], [rows_expired_removed], [row_insert_attempts], [row_update_attempts], [row_delete_attempts], [write_conflicts], [unique_constraint_violations], [drop_table_memory_attempts], [drop_table_memory_failures]

FROM tempdb.sys.dm_xtp_transaction_stats  

 

---------------------------------------- Transactions

INSERT INTO [SR2511100040010255].[dbo].[trk_Transactions]

                                (                                                  [ServerName],                        [ServerDate], [transaction_begin_time], [login_time], [login_name],   [status],   [command],         [XactName], [host_name], [program_name], [session_id], [Database], [last_request_start_time], [last_request_end_time], [Type], [State], [is_user_transaction], [is_local], [open_transaction_count], [blocking_session_id], [wait_type], [wait_time], [last_wait_type], [wait_resource], [transaction_isolation_level], [prev_error], [text])

SELECT @@ServerName as [ServerName], SYSDATETIMEOFFSET() as [ServerDate], [transaction_begin_time], [login_time], [login_name], s.[status], r.[command], at.name [XactName], [host_name], [program_name], s.session_id, DB_NAME(s.database_id) [Database], last_request_start_time

, last_request_end_time

, CASE transaction_type  WHEN 1 THEN 'Read/Write' WHEN 2 THEN 'Read-Only' WHEN 3 THEN 'System' WHEN 4 THEN 'Distributed' ELSE 'undocumented' END [Type]

, CASE transaction_state WHEN 0 THEN 'NotYetInitialized' WHEN 1 THEN 'InitNotStarted' WHEN 2 THEN 'Active' WHEN 3 THEN 'Ended (R-O)' WHEN 4 THEN 'Commit initiated (Dist)' WHEN 5 THEN 'Prepared' WHEN 6 THEN 'Committed' WHEN 7 THEN 'Rollback' WHEN 8 THEN 'Rolled back' ELSE 'undocumented' END [State]

, is_user_transaction, is_local, st.open_transaction_count, r.blocking_session_id, r.wait_type, r.wait_time, r.last_wait_type, r.wait_resource, r.transaction_isolation_level, r.prev_error, txt.text

           FROM sys.dm_tran_active_transactions at

           JOIN sys.dm_tran_session_transactions st ON at.transaction_id = st.transaction_id

           JOIN sys.dm_exec_sessions s ON s.session_id = st.session_id

LEFT OUTER JOIN sys.dm_exec_requests r ON r.session_id = s.session_id

    OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) txt

ORDER BY transaction_begin_time DESC

 

 

 

DELETE FROM [SR2511100040010255].[dbo].[dm_os_memory_clerks]                                                                      WITH(TABLOCK) WHERE [ServerDate] < DATEADD(HOUR,-12, SYSDATETIMEOFFSET())

DELETE FROM [SR2511100040010255].[dbo].[dm_resource_governor_resource_pools]    WITH(TABLOCK) WHERE [ServerDate] < DATEADD(HOUR,-12, SYSDATETIMEOFFSET())

DELETE FROM [SR2511100040010255].[dbo].[tempdb_dm_db_xtp_memory_consumers]                           WITH(TABLOCK) WHERE [ServerDate] < DATEADD(HOUR,-12, SYSDATETIMEOFFSET())

DELETE FROM [SR2511100040010255].[dbo].[tempdb_dm_db_xtp_object_stats]                                       WITH(TABLOCK) WHERE [ServerDate] < DATEADD(HOUR,-12, SYSDATETIMEOFFSET())

DELETE FROM [SR2511100040010255].[dbo].[tempdb_dm_db_xtp_table_memory_stats]           WITH(TABLOCK) WHERE [ServerDate] < DATEADD(HOUR,-12, SYSDATETIMEOFFSET())

DELETE FROM [SR2511100040010255].[dbo].[tempdb_dm_db_xtp_transactions]                                      WITH(TABLOCK) WHERE [ServerDate] < DATEADD(HOUR,-12, SYSDATETIMEOFFSET())

DELETE FROM [SR2511100040010255].[dbo].[tempdb_dm_tran_active_transactions]     WITH(TABLOCK) WHERE [ServerDate] < DATEADD(HOUR,-12, SYSDATETIMEOFFSET())

DELETE FROM [SR2511100040010255].[dbo].[tempdb_dm_tran_database_transactions]           WITH(TABLOCK) WHERE [ServerDate] < DATEADD(HOUR,-12, SYSDATETIMEOFFSET())

DELETE FROM [SR2511100040010255].[dbo].[tempdb_dm_tran_session_transactions]              WITH(TABLOCK) WHERE [ServerDate] < DATEADD(HOUR,-12, SYSDATETIMEOFFSET())

DELETE FROM [SR2511100040010255].[dbo].[tempdb_dm_xtp_gc_queue_stats]                                       WITH(TABLOCK) WHERE [ServerDate] < DATEADD(HOUR,-12, SYSDATETIMEOFFSET())

DELETE FROM [SR2511100040010255].[dbo].[tempdb_dm_xtp_system_memory_consumers]    WITH(TABLOCK) WHERE [ServerDate] < DATEADD(HOUR,-12, SYSDATETIMEOFFSET())

DELETE FROM [SR2511100040010255].[dbo].[tempdb_dm_xtp_transaction_recent_rows]          WITH(TABLOCK) WHERE [ServerDate] < DATEADD(HOUR,-12, SYSDATETIMEOFFSET())

DELETE FROM [SR2511100040010255].[dbo].[tempdb_dm_xtp_transaction_stats]                     WITH(TABLOCK) WHERE [ServerDate] < DATEADD(HOUR,-12, SYSDATETIMEOFFSET())

DELETE FROM [SR2511100040010255].[dbo].[trk_Transactions]                                                                                WITH(TABLOCK) WHERE [ServerDate] < DATEADD(HOUR,-12, SYSDATETIMEOFFSET())

 

END