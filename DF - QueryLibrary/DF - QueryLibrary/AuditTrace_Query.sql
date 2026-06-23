declare @starttime datetime =GETUTCDATE()
SELECT distinct username,
*,DATEADD(mi, DATEDIFF(mi, GETUTCDATE(), GETDATE()), starttimeutc) as ESTTime
FROM  admindb..audittrace (nolock)
where  starttimeutc between dateadd(day,-2,@starttime) and  @starttime 
  and  (username  like '%corpadds%'
OR username  like '%custadds%')
and   statement like '%update%'
order by starttimeutc desc