--AZA1SENSQL001


-- Main execution using date range above and 30 second run time 
DECLARE @StartUTC DATETIME2 = DATEADD(hour, -1, SYSUTCDATETIME());
DECLARE @EndUTC   DATETIME2 = SYSUTCDATETIME();

EXEC dbo.ap_GetSlowQueries
    @StartUTC   = @StartUTC,
    @EndUTC     = @EndUTC,
    @MinSeconds = 30,
    @Aggregate  = 0,
    @MaxRows    = 200,
    @IncludeQueryText = 1;

-- Aggregate data with high use queries
DECLARE @StartUTC DATETIME2 = DATEADD(hour, -1, SYSUTCDATETIME());
DECLARE @EndUTC   DATETIME2 = SYSUTCDATETIME();

EXEC dbo.ap_GetSlowQueries
    @StartUTC   = @StartUTC,
    @EndUTC     = @EndUTC,
    @Aggregate = 1;

-- Slow queries per database
DECLARE @StartUTC DATETIME2 = DATEADD(hour, -10, SYSUTCDATETIME());
DECLARE @EndUTC   DATETIME2 = SYSUTCDATETIME();

EXEC dbo.ap_GetSlowQueries
    @StartUTC   = @StartUTC,
    @EndUTC     = @EndUTC,
    @DatabaseName = 'pacstage';

-- Slow queries per instance
DECLARE @StartUTC DATETIME2 = DATEADD(hour, -1000, SYSUTCDATETIME());
DECLARE @EndUTC   DATETIME2 = SYSUTCDATETIME();

EXEC dbo.ap_GetSlowQueries
    @StartUTC   = @StartUTC,
    @EndUTC     = @EndUTC,
    @InstanceName = 'aza2stgsql001',
    @DatabaseName = 'pacstage';