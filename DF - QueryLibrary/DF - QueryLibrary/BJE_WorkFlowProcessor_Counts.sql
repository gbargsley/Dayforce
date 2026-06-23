-- Find Control Database from Watchtower

select AllocatedAgentHostName, shortname, [Namespace],count(*) as job_count from BackgroundJobWorkArchive

where shortname = 'workflow processor'

and [Namespace] like 'kpdn'

and

FinishedTimeUTC between '2026-02-11 14:00:00.000' and '2026-02-11 14:37:00.000' --can be adjusted based on timeperiod

--and AllocatedAgentHostName in ('azm1g70bje001','azm1g70bje002','azm1g70bje003')

group by AllocatedAgentHostName,shortname,[Namespace]

order by 1