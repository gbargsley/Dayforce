set deadlock_priority low
set transaction isolation level read uncommitted

use traderjoes

declare @payrolldate datetime =  '2026-05-19 10:00:00.000'   --- yy--mm--dd
select --dt2.PayGroupName AS PayGroupName,dt1.ExecStartTime,dt1.ExecEndTime
dt2.PayGroupName AS PayGroupName,dt1.PayrunID, dt2.comments as EECount,dt1.QueueTime ,dt1.ExecStartTime,dt1.ExecEndTime,
dt1.HH, dt1.MM,dt1.SS
,((isnull(dt1.HH,0)*3600) + (isnull(dt1.MM,0)*60)+(isnull(dt1.ss,0))) PyaCommit_Secs
,dt1.JobShortname as jobstatus,substring(dt1.JobThreadLog,30,16)  as JobThreadLog1,ErrorDescription,dt1.JobThreadLog,dt1.DBName, dt1.ShortName
from
(
select DB_NAME() as DBName, j.ShortName , QueueTime ,b.ExecStartTime,b.ExecEndTime,
LTRIM(RTRIM(replace(substring(b.ParameterXml,(patindex('%PayrunID%',cast(b.ParameterXml as varchar(8000)))+10),5),'"',''))) as PayrunID
, DatePart(hour,(b.ExecEndTime -b.ExecStartTime)) HH
,DatePart(minute,(b.ExecEndTime -b.ExecStartTime)) MM
,DatePart(second,(b.ExecEndTime -b.ExecStartTime)) SS
, b.ParameterXml,bjs.BackgroundJobStatusId
,bjs.shortname as JobShortname,b.JobThreadLog as JobThreadLog,ErrorDescription
from BackgroundJobLog b (nolock)
join backgroundjob j (nolock) on j.BackgroundJobId=b.BackgroundJobId
inner join backgroundjobstatus bjs(nolock) on b.BackgroundJobStatusId =bjs.BackgroundJobStatusId
where ExecStartTime between @payrolldate  and dateadd(hour,8,@payrolldate)  and
j.shortname like '%pay%dis%'
and  b.parameterxml   like '%8,9,10,19,25%'
--and bjs.BackgroundJobStatusId  =1
) dt1
inner join (
SELECT distinct pr.prpayrunid  AS PayRunId,
pg.shortname AS PayGroupName,pr.comments
FROM   prPayRun pr WITH(nolock)
JOIN PayGroup pg WITH(nolock)
ON pr.PayGroupId = pg.PayGroupId
WHERE  --pr.payrollcommitteddate between @payrolldate  and dateadd(hour,8,@payrolldate)  AND
pr.PayGroupId NOT IN ( 5, 18, 1, 15 )
) dt2 on dt2.PayRunId = dt1.PayrunID
Order by  dt2.PayGroupName