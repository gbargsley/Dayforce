USE [sherwin];

select @@servername,DB_NAME() as DBName, j.ShortName ,b.QueueTime ,b.ExecStartTime,b.ExecEndTime
, DatePart(hour,(b.ExecEndTime -b.ExecStartTime)) HH ,DatePart(minute,(b.ExecEndTime -b.ExecStartTime)) MM ,DatePart(second,(b.ExecEndTime -b.ExecStartTime)) SS
,bjs.shortname as JobStatus,substring(JobThreadLog,30,17) as HostName, b.ParameterXml,errordescription 
--,JobThreadLog
from BackgroundJobLog b (nolock) join backgroundjob j  (nolock) on j.BackgroundJobId=b.BackgroundJobId 
join backgroundjobstatus bjs(nolock) on b.BackgroundJobStatusId =bjs.BackgroundJobStatusId 
--where ExecStartTime > dateadd(hour,-8, getdate())
where ExecStartTime >= '2026-01-01'
and j.shortname  like '%Payroll Data Export%'  
--and  b.BackgroundJobStatusId =1
order by ExecStartTime desc


--- 1:Completed 2:Queued 3:Error 4:In Progress 5:Paused 6:Cancelled


