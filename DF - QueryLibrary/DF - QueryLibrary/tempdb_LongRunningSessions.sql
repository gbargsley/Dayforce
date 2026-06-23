-- Long running transactions that may keep version store pinned
SELECT *--, at.transaction_id, at.transaction_begin_time, at.database_id, at.database_transaction_begin_time, at.is_snapshot
FROM sys.dm_tran_active_snapshot_database_transactions at
--ORDER BY at.transaction_begin_time;
