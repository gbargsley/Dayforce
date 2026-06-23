
;WITH XMLNAMESPACES 
(
    DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan'
),
PlanCpu AS 
(
    SELECT
        qs.plan_handle,
        qs.total_worker_time,
        qp.query_plan
    FROM sys.dm_exec_query_stats qs
    CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
),
PlanCpuFinal AS
(
    SELECT
        obj.value('@Database', 'nvarchar(128)') AS DatabaseName,
        obj.value('@Schema', 'nvarchar(128)') AS SchemaName,
        obj.value('@Table', 'nvarchar(128)') AS ObjectName,
        p.total_worker_time AS TotalWorkerTime
        --,
        --SUM(p.total_worker_time) AS total_worker_time,
        --SUM(p.total_worker_time) * 1.0 / SUM(SUM(p.total_worker_time)) OVER() * 100.0 AS pct_of_sampled_cpu
    FROM PlanCpu p
    CROSS APPLY p.query_plan.nodes('//Object') AS T(obj)
)

SELECT
    DatabaseName,
    SchemaName,
    ObjectName,
    SUM(p.TotalWorkerTime) AS TotalWorkerTime,
    SUM(p.TotalWorkerTime) * 1.0 / SUM(SUM(p.TotalWorkerTime)) OVER() * 100.0 AS PctOfSampledCpu
FROM PlanCpuFinal p
WHERE DatabaseName NOT IN ('[msdb]','[master]','[mssqlsystemresource]')
AND SchemaName NOT IN ('[sys]')
GROUP BY
    DatabaseName,
    SchemaName,
    ObjectName
ORDER BY TotalWorkerTime DESC;
 