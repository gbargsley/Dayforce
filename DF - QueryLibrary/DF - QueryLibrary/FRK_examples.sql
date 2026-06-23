exec admindb..ap_blitz @checkserverinfo = 1

exec admindb..ap_blitz @CheckServerInfo = 1,
@OutputDatabaseName = 'master',
@OutputSchemaName = 'dbo',
@OutputTableName = 'Blitz'


SELECT YEAR(CheckDate) AS 'Year', MONTH(CheckDate) AS 'Month', COUNT(DISTINCT ServerName) AS Servers, SUM(1) AS Warnings
FROM master.dbo.Blitz
GROUP BY YEAR(CheckDate), MONTH(CheckDate)
ORDER BY 1, 2

exec admindb..ap_blitz @checkuserdatabaseobjects = 0

exec admindb..ap_blitz @outputtype = 'markdown'


exec admindb..ap_blitzfirst

exec admindb..ap_blitzfirst @ExpertMode = 1, @Seconds = 60,
@OutputDatabaseName = 'master', @OutputSchemaName = 'dbo', 
@OutputTableName = 'BlitzFirst'

exec admindb..ap_blitzfirst @SinceStartup = 1


exec admindb..ap_blitzindex @GetAllDatabases = 1
exec admindb..ap_blitzindex @GetAllDatabases = 1, @Mode = 2, @SortOrder = 'size'

exec admindb..ap_BlitzCache @SortOrder = 'cpu'

exec admindb..ap_BlitzCache @databasename = 'guitarcenter'

exec admindb..ap_BlitzLock @databasename = 'eliorna'


