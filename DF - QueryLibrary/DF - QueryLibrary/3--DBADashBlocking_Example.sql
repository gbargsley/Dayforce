/*
aza1monsql001 -- DBADashDBProdAUS
azm1monsql001 -- DBADashDBProdEUR
azc1monsql001 -- DBADashDBProdCAN
azg1monsql001 -- DBADashDBProdUS
*/


-- Blocking
EXEC AdminDB.dbo.ap_DBADashGetBlocking
    @DBADashDB = 'DBADashDBProdUS',
    @StartUTC = '2026-06-23 12:00:00',
    @EndUTC = '2026-06-23 16:59:00',
    @InstanceName = 'azg1dfcsql19d',
    @DatabaseName = 'woodmans',
    @LatestOnly = 1;


EXEC AdminDB.dbo.ap_DBADashGetBlocking
    @DBADashDB = 'DBADashDBProdUS',
    @StartUTC = '2026-06-23 16:10:00.3670000',
    @EndUTC = '2026-06-23 16:16:00.3670000',
    @InstanceName = 'azg1dfcsql19d',
    @DatabaseName = 'woodmans',
    --@SessionID = 3691,
    @LatestOnly = 1;


-- High CPU Long Running
EXEC AdminDB.dbo.ap_DBADashGetSlowQueries
    @DBADashDB = 'DBADashDBProdUS',
    @StartUTC = '2026-06-23 00:00:00',
    @EndUTC = '2026-06-23 23:59:00',
    @MinSeconds = 60,
    @IncludeQueryText = 1,
    @InstanceName = 'azg1upssql01d';
