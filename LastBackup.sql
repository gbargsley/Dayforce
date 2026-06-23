SELECT top 2 
s.database_name,
m.physical_device_name,
CAST(s.backup_size / 1048576 AS INT)   AS bkSize_MB,
CAST(s.compressed_backup_size / 1048576 AS INT)   AS comp_bkSize_MB,
CAST(DATEDIFF(second, s.backup_start_date,
s.backup_finish_date) AS VARCHAR(10)) + ' ' + 'Seconds' TimeTaken,
s.backup_start_date,
s.backup_finish_date,
CAST(s.first_lsn AS VARCHAR(50)) AS first_lsn,
CAST(s.last_lsn AS VARCHAR(50)) AS last_lsn,
CASE s.[type]
WHEN 'D' THEN 'Full'
WHEN 'I' THEN 'Differential'
WHEN 'L' THEN 'Transaction Log'
END AS BackupType
--,s.server_name,
--s.recovery_model
FROM msdb.dbo.backupset s
INNER JOIN msdb.dbo.backupmediafamily m ON s.media_set_id = m.media_set_id
where backup_start_date > getdate()-10
AND s.[type] ='D'
and cast(backup_start_date as date) ='2026-04-27'
and s.database_name  ='msdb'
ORDER BY backup_start_date DESC, backup_finish_date