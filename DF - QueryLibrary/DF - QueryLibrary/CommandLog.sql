select top 1000 * from admindb..CommandLog 
--where CommandType = 'BACKUP_LOG'
order by id desc

select top 1000 * from admindb..CommandLog 
where ErrorNumber <> 0
order by id desc


SELECT  
	ObjectName
	, CAST ( StartTime AS date ) AS 'RunDate'
	, MIN ( StartTime ) AS 'MinDateTime'
	, MAX ( EndTime ) AS 'MaxDateTime'
FROM admindb..CommandLog 
WHERE databasename = 'lululemon'
	AND ObjectName = 'Session'
	AND StartTime >= '2025-11-24 00:00:00.000' AND StartTime <= '2025-12-12 00:00:00.000'
GROUP BY ObjectName, CAST ( StartTime AS date )
