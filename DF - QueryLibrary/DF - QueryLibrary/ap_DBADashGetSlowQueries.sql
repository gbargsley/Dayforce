USE AdminDB;
GO

IF OBJECT_ID('dbo.ap_DBADashGetSlowQueries', 'P') IS NOT NULL
    DROP PROCEDURE dbo.ap_DBADashGetSlowQueries;
GO

CREATE PROCEDURE dbo.ap_DBADashGetSlowQueries
    @DBADashDB SYSNAME = 'DBADashDB',
    @StartUTC DATETIME2,
    @EndUTC DATETIME2,
    @InstanceName NVARCHAR(256) = NULL,
    @DatabaseName NVARCHAR(256) = NULL,
    @MinSeconds INT = 5,
    @LatestOnly BIT = 1,
    @IncludeQueryText BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    IF @StartUTC IS NULL OR @EndUTC IS NULL OR @EndUTC < @StartUTC
    BEGIN
        RAISERROR('StartUTC and EndUTC must be supplied and EndUTC must be >= StartUTC.', 16, 1);
        RETURN;
    END

    DECLARE @MinMs BIGINT = CASE WHEN ISNULL(@MinSeconds, 0) <= 0 THEN 0 ELSE CAST(@MinSeconds AS BIGINT) * 1000 END;
    DECLARE @QueryTextColumn SYSNAME = NULL;

    IF @IncludeQueryText = 1
    BEGIN
        DECLARE @MetaSQL NVARCHAR(MAX) =
            N'SELECT TOP (1) @QueryTextColumnOut = c.name
              FROM ' + QUOTENAME(@DBADashDB) + N'.sys.columns AS c
              JOIN ' + QUOTENAME(@DBADashDB) + N'.sys.objects AS o
                ON c.object_id = o.object_id
              WHERE o.name = ''QueryText''
                AND o.type = ''U''
                AND c.name IN (''text'',''query_text'',''sql_text'',''sqltext'',''QueryText'')
              ORDER BY CASE c.name
                  WHEN ''text'' THEN 1
                  WHEN ''query_text'' THEN 2
                  WHEN ''sql_text'' THEN 3
                  WHEN ''sqltext'' THEN 4
                  WHEN ''QueryText'' THEN 5
                  ELSE 100
              END;';

        EXEC sp_executesql
            @MetaSQL,
            N'@QueryTextColumnOut SYSNAME OUTPUT',
            @QueryTextColumnOut = @QueryTextColumn OUTPUT;

        IF @QueryTextColumn IS NULL
        BEGIN
            RAISERROR('QueryText table exists, but no supported text column was found.', 16, 1);
            RETURN;
        END
    END

    DECLARE @SQL NVARCHAR(MAX) = N'
    ;WITH BaseRows AS
    (
        SELECT
            rq.InstanceID,
            rq.database_id,
            rq.SnapshotDateUTC,
            rq.session_id,
            rq.status,
            rq.command,
            rq.cpu_time,
            rq.total_elapsed_time,
            rq.logical_reads,
            rq.reads,
            rq.writes,
            rq.wait_type,
            rq.wait_resource,
            rq.blocking_session_id,
            rq.login_name,
            rq.host_name,
            rq.program_name,
            rq.sql_handle,
            rq.query_hash,
            rq.plan_handle,
            i.[Instance] AS InstanceName,
            d.name AS DatabaseName,
            ROW_NUMBER() OVER
            (
                PARTITION BY rq.InstanceID, rq.session_id
                ORDER BY rq.SnapshotDateUTC DESC
            ) AS rn
        FROM ' + QUOTENAME(@DBADashDB) + N'.dbo.RunningQueries AS rq
        LEFT JOIN ' + QUOTENAME(@DBADashDB) + N'.dbo.Instances AS i
            ON i.InstanceID = rq.InstanceID
        LEFT JOIN ' + QUOTENAME(@DBADashDB) + N'.dbo.Databases AS d
            ON d.InstanceID = rq.InstanceID
           AND d.database_id = rq.database_id
        WHERE rq.SnapshotDateUTC BETWEEN @StartUTC AND @EndUTC
          AND NOT (rq.status = ''sleeping'' AND rq.command IS NULL)
          AND (@InstanceName IS NULL OR i.[Instance] = @InstanceName)
          AND (@DatabaseName IS NULL OR d.name = @DatabaseName)
    )
    SELECT
        br.InstanceName,
        br.DatabaseName,
        br.SnapshotDateUTC,
        br.session_id,
        br.status,
        br.command,
        br.cpu_time AS cpu_time_ms,
        br.total_elapsed_time AS duration_ms,
        br.logical_reads,
        br.reads,
        br.writes,
        br.wait_type,
        br.wait_resource,
        br.blocking_session_id,
        br.login_name,
        br.host_name,
        br.program_name,
        br.query_hash,
        br.plan_handle' +
        CASE WHEN @IncludeQueryText = 1 THEN N',
        qt.' + QUOTENAME(@QueryTextColumn) + N' AS query_text'
             ELSE N'' END + N'
    FROM BaseRows AS br' +
    CASE WHEN @IncludeQueryText = 1 THEN N'
    LEFT JOIN ' + QUOTENAME(@DBADashDB) + N'.dbo.QueryText AS qt
        ON qt.sql_handle = br.sql_handle'
         ELSE N'' END + N'
    WHERE (@LatestOnly = 0 OR br.rn = 1)
      AND (
            @MinMs = 0
         OR br.cpu_time >= @MinMs
         OR br.total_elapsed_time >= @MinMs
      )
    ORDER BY br.SnapshotDateUTC DESC, br.total_elapsed_time DESC, br.cpu_time DESC;
    ';

    EXEC sp_executesql
        @SQL,
        N'@StartUTC DATETIME2,
          @EndUTC DATETIME2,
          @MinMs BIGINT,
          @InstanceName NVARCHAR(256),
          @DatabaseName NVARCHAR(256),
          @LatestOnly BIT',
        @StartUTC = @StartUTC,
        @EndUTC = @EndUTC,
        @MinMs = @MinMs,
        @InstanceName = @InstanceName,
        @DatabaseName = @DatabaseName,
        @LatestOnly = @LatestOnly;
END
GO

IF OBJECT_ID('dbo.ap_DBADashGetBlocking', 'P') IS NOT NULL
    DROP PROCEDURE dbo.ap_DBADashGetBlocking;
GO
