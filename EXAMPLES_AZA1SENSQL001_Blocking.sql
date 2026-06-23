--AZA1SENSQL001

USE AdminDB;

DECLARE @LocalStart DATETIME2 = DATEADD(minute, -4415, SYSDATETIME());
DECLARE @LocalEnd   DATETIME2 = SYSDATETIME();

EXEC dbo.ap_GetBlocking
    @StartUTC = @LocalStart,
    @EndUTC   = @LocalEnd,
    @InputIsLocal = 1,
    @LocalOffsetMinutes = -360;




--DECLARE @S DATETIME2 = DATEADD(hour, -10, SYSUTCDATETIME());
--DECLARE @E DATETIME2 = SYSUTCDATETIME();

DECLARE @S DATETIME2 = '2026-01-26 17:49:00.5100000';
DECLARE @E DATETIME2 = '2026-01-26 17:49:00.5100000';


EXEC dbo.ap_GetBlocking
    @StartUTC = @S,
    @EndUTC   = @E,
    --@InputIsLocal = 1,
    --@LocalOffsetMinutes = -360,
    @InstanceName = 'aza1sensql001',  -- CST = UTC-6 * 60
    @DatabaseName = 'DBADashDB',
    @SessionID = 61;

   