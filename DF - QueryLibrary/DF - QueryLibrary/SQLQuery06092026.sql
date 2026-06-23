SELECT 
	sj.name
	,sjs.last_run_outcome
	, *
FROM
	msdb..sysjobs sj
INNER JOIN msdb..sysjobsteps sjs
	ON sj.job_id = sjs.job_id
WHERE 
	sjs.command LIKE '%DatabaseBackup%'
	AND sj.enabled = 1
	AND sjs.last_run_outcome = 1