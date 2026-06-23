--use upspayroll

select @@servername,DB_NAME() as DBName, j.ShortName ,b.QueueTime ,b.ExecStartTime,b.ExecEndTime
--,cast(Datediff(hour,b.ExecStartTime ,b.ExecEndTime )/24 as Int) DD
, DatePart(hour,(b.ExecEndTime -b.ExecStartTime)) HH ,DatePart(minute,(b.ExecEndTime -b.ExecStartTime)) MM ,DatePart(second,(b.ExecEndTime -b.ExecStartTime)) SS
,bjs.shortname as JobStatus,substring(JobThreadLog,30,17) as HostName, b.ParameterXml,errordescription 
--,(DATALENGTH(jobthreadlog)-DATALENGTH(REPLACE(jobthreadlog,'deadlock victim','')))/DATALENGTH('deadlock victim') as deadlock_victim
--,(DATALENGTH(jobthreadlog)-DATALENGTH(REPLACE(jobthreadlog,'Execution Timeout Expired','')))/DATALENGTH('Execution Timeout Expired') as timeout_expired
--,Substring(jobthreadlog, patindex('%Rendering adhoc report:%',jobthreadlog),100)   as ReportQuery
--substring(Substring(jobthreadlog, patindex('%Rendering adhoc report:%',jobthreadlog),100),1,patindex ('%2023%',Substring(jobthreadlog, patindex('%Rendering adhoc report:%',jobthreadlog),100)))   as ReportQuery
--,JobThreadLog
from BackgroundJobLog b (nolock) join backgroundjob j  (nolock) on j.BackgroundJobId=b.BackgroundJobId 
join backgroundjobstatus bjs(nolock) on b.BackgroundJobStatusId =bjs.BackgroundJobStatusId 
where 
	--ExecStartTime > dateadd(hour,-8, getdate())
	ExecStartTime between '2026-05-19 00:00:00.000' and '2026-05-19 23:59:00.000'
	--and bjs.ShortName <> 'Completed'
	and j.ShortName like '%recalc%'
----and j.shortname  like '%jobname%'  --and  b.BackgroundJobStatusId =3
----and j.ShortName like '%report%' and JobThreadLog like '%Rendering adhoc report:%'
----and ( (bjs.BackgroundJobStatusId =3 and j.shortname ='calculate payroll') OR (  b.ExecEndTime > '2021-10-27 09:49:14.310' and substring(JobThreadLog,30,17)  like '%BJE002%' and b.ExecStartTime < '2021-10-27 09:50:14.310') ) --deadlock issue
---- and   b.ExecEndTime between '2023-04-28 18:32:03.263' and '2023-04-28 19:55:04.263' and b.execstarttime  < '2023-04-28 18:33:04.263' and substring(JobThreadLog,30,17) like '%bje001%' -----deadlock issue
----and  datename(weekday,ExecStartTime) in ('monday','tuesday') --and datepart(hour,execendtime) between 9 and 18 
----and b.BackgroundJobStatusId =3 --and errordescription like '%There is insufficient system memory in resource pool%'
--and ( --DatePart(hour,(b.ExecEndTime -b.ExecStartTime)) > 0  OR DatePart(minute,(b.ExecEndTime -b.ExecStartTime)) > 0  OR DatePart(second,(b.ExecEndTime -b.ExecStartTime)) >30 OR
--and b.ExecEndTime  IS NULL  --OR  b.BackgroundJobStatusId in (4,5) 
----OR  datediff(second,b.ExecStartTime,b.ExecEndTime) >30
--)
and b.JobThreadLog like '%azg1tjsbje003%'
--and bjs.ShortName not like 'completed'
--and b.ParameterXml like '%869%'
order by ExecStartTime desc --datediff(second,b.QueueTime ,b.ExecStartTime) desc --datediff(second,b.ExecStartTime ,b.ExecEndTime) desc

