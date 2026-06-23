
USE msdb;
GO

SELECT  
    bs.database_name,  
    bs.backup_start_date,  
    bs.backup_finish_date,  
    CAST(bs.backup_size / 1024 / 1024 AS DECIMAL(10,2)) AS backup_size_MB,  
    bmf.physical_device_name AS backup_file_path
FROM  
    dbo.backupset AS bs
INNER JOIN  
    dbo.backupmediafamily AS bmf  
    ON bs.media_set_id = bmf.media_set_id
WHERE  
    bs.type IN ('D', 'I')  -- 'D' = Full database backup
    and bs.database_name IN ( 'PTAGTF', 'PTAUS')
ORDER BY  
    bs.backup_finish_date DESC;


