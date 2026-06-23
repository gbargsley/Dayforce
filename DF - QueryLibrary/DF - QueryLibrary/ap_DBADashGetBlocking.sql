USE AdminDB;
GO

IF OBJECT_ID('dbo.ap_DBADashGetSlowQueries', 'P') IS NOT NULL
    DROP PROCEDURE dbo.ap_DBADashGetBlocking;
GO
CREATE PROCEDURE dbo.ap_DBADashGetBlocking
    @DBADashDB SYSNAME = 'DBADashDB',
    @StartUTC DATETIME2,
    @EndUTC DATETIME2,
    @InstanceName NVARCHAR(256) = NULL,
    @DatabaseName NVARCHAR(256) = NULL,
    @SessionID INT = NULL,
    @LatestOnly BIT = 0,
    @InputIsLocal BIT = 0,
    @LocalOffsetMinutes INT = NULL,
    @MaxDepth INT = 10
AS
BEGIN
    SET NOCOUNT ON;

    IF @InputIsLocal = 1
    BEGIN
        IF @LocalOffsetMinutes IS NULL
        BEGIN
            RAISERROR('When @InputIsLocal = 1, @LocalOffsetMinutes must be provided.', 16, 1);
            RETURN;
        END

        SET @StartUTC = DATEADD(MINUTE, -@LocalOffsetMinutes, @StartUTC);
        SET @EndUTC   = DATEADD(MINUTE, -@LocalOffsetMinutes, @EndUTC);
    END

    IF @StartUTC IS NULL OR @EndUTC IS NULL OR @EndUTC < @StartUTC
    BEGIN
        RAISERROR('StartUTC and EndUTC must be supplied and EndUTC must be >= StartUTC.', 16, 1);
        RETURN;
    END

    IF @MaxDepth IS NULL OR @MaxDepth < 1
        SET @MaxDepth = 10;

    DECLARE @QueryTextColumn SYSNAME = NULL;

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

    IF OBJECT_ID('tempdb..#Rows') IS NOT NULL DROP TABLE #Rows;
    CREATE TABLE #Rows
    (
        InstanceID INT NOT NULL,
        database_id INT NULL,
        InstanceName NVARCHAR(256) NOT NULL,
        DatabaseName NVARCHAR(256) NULL,
        SnapshotDateUTC DATETIME2 NOT NULL,
        session_id SMALLINT NOT NULL,
        blocking_session_id SMALLINT NULL,
        status NVARCHAR(30) NULL,
        command NVARCHAR(32) NULL,
        cpu_time INT NULL,
        total_elapsed_time INT NULL,
        logical_reads BIGINT NULL,
        reads BIGINT NULL,
        writes BIGINT NULL,
        wait_type NVARCHAR(60) NULL,
        wait_resource NVARCHAR(256) NULL,
        login_name NVARCHAR(256) NULL,
        host_name NVARCHAR(256) NULL,
        program_name NVARCHAR(256) NULL,
        sql_handle VARBINARY(64) NULL,
        query_hash BINARY(8) NULL,
        plan_handle VARBINARY(64) NULL,
        query_text NVARCHAR(MAX) NULL,
        rn_session INT NOT NULL
    );

    DECLARE @InsertSQL NVARCHAR(MAX) = N'
        INSERT INTO #Rows
        (
            InstanceID,
            database_id,
            InstanceName,
            DatabaseName,
            SnapshotDateUTC,
            session_id,
            blocking_session_id,
            status,
            command,
            cpu_time,
            total_elapsed_time,
            logical_reads,
            reads,
            writes,
            wait_type,
            wait_resource,
            login_name,
            host_name,
            program_name,
            sql_handle,
            query_hash,
            plan_handle,
            query_text,
            rn_session
        )
        SELECT
            rq.InstanceID,
            rq.database_id,
            i.[Instance] AS InstanceName,
            d.name AS DatabaseName,
            rq.SnapshotDateUTC,
            rq.session_id,
            rq.blocking_session_id,
            rq.status,
            rq.command,
            rq.cpu_time,
            rq.total_elapsed_time,
            rq.logical_reads,
            rq.reads,
            rq.writes,
            rq.wait_type,
            rq.wait_resource,
            rq.login_name,
            rq.host_name,
            rq.program_name,
            rq.sql_handle,
            rq.query_hash,
            rq.plan_handle,' +
            CASE WHEN @QueryTextColumn IS NOT NULL
                 THEN N'
            qt.' + QUOTENAME(@QueryTextColumn) + N' AS query_text,'
                 ELSE N'
            NULL AS query_text,' END + N'
            ROW_NUMBER() OVER
            (
                PARTITION BY rq.InstanceID, rq.session_id
                ORDER BY rq.SnapshotDateUTC DESC
            ) AS rn_session
        FROM ' + QUOTENAME(@DBADashDB) + N'.dbo.RunningQueries AS rq
        LEFT JOIN ' + QUOTENAME(@DBADashDB) + N'.dbo.Instances AS i
            ON i.InstanceID = rq.InstanceID
        LEFT JOIN ' + QUOTENAME(@DBADashDB) + N'.dbo.Databases AS d
            ON d.InstanceID = rq.InstanceID
           AND d.database_id = rq.database_id' +
           CASE WHEN @QueryTextColumn IS NOT NULL THEN N'
        LEFT JOIN ' + QUOTENAME(@DBADashDB) + N'.dbo.QueryText AS qt
            ON qt.sql_handle = rq.sql_handle' ELSE N'' END + N'
        WHERE rq.SnapshotDateUTC BETWEEN @StartUTC AND @EndUTC
          AND NOT (rq.status = ''sleeping'' AND rq.command IS NULL)
          AND (@InstanceName IS NULL OR i.[Instance] = @InstanceName)
          AND (@DatabaseName IS NULL OR d.name = @DatabaseName);
    ';

    EXEC sp_executesql
        @InsertSQL,
        N'@StartUTC DATETIME2,
          @EndUTC DATETIME2,
          @InstanceName NVARCHAR(256),
          @DatabaseName NVARCHAR(256)',
        @StartUTC = @StartUTC,
        @EndUTC = @EndUTC,
        @InstanceName = @InstanceName,
        @DatabaseName = @DatabaseName;

    IF OBJECT_ID('tempdb..#RelatedSessions') IS NOT NULL DROP TABLE #RelatedSessions;
    CREATE TABLE #RelatedSessions
    (
        session_id SMALLINT NOT NULL PRIMARY KEY
    );

    IF @SessionID IS NOT NULL
    BEGIN
        ;WITH Rel AS
        (
            SELECT
                r.session_id,
                r.blocking_session_id,
                0 AS level
            FROM #Rows AS r
            WHERE r.session_id = @SessionID

            UNION ALL

            SELECT
                r2.session_id,
                r2.blocking_session_id,
                rel.level + 1 AS level
            FROM #Rows AS r2
            JOIN Rel AS rel
              ON r2.session_id = rel.blocking_session_id
              OR r2.blocking_session_id = rel.session_id
            WHERE rel.level + 1 <= @MaxDepth
        )
        INSERT INTO #RelatedSessions (session_id)
        SELECT DISTINCT session_id
        FROM Rel
        OPTION (MAXRECURSION 0);
    END

    ;WITH DiffRows AS
    (
        SELECT
            r.*,
            LAG(r.blocking_session_id) OVER
            (
                PARTITION BY r.InstanceID, r.session_id
                ORDER BY r.SnapshotDateUTC
            ) AS prev_blocking_session_id,
            LAG(r.wait_type) OVER
            (
                PARTITION BY r.InstanceID, r.session_id
                ORDER BY r.SnapshotDateUTC
            ) AS prev_wait_type,
            LAG(r.wait_resource) OVER
            (
                PARTITION BY r.InstanceID, r.session_id
                ORDER BY r.SnapshotDateUTC
            ) AS prev_wait_resource
        FROM #Rows AS r
    ),
    FilteredDiffRows AS
    (
        SELECT *
        FROM DiffRows
        WHERE (@LatestOnly = 0 OR rn_session = 1)
    )
    SELECT
        f.InstanceName,
        f.DatabaseName,
        f.SnapshotDateUTC,
        f.session_id,
        f.blocking_session_id,
        f.prev_blocking_session_id,
        CASE WHEN ISNULL(f.blocking_session_id, 0) <> ISNULL(f.prev_blocking_session_id, 0) THEN 1 ELSE 0 END AS blocking_changed,
        f.status,
        f.command,
        f.wait_type,
        f.prev_wait_type,
        f.wait_resource,
        f.prev_wait_resource,
        f.cpu_time AS cpu_time_ms,
        f.total_elapsed_time AS duration_ms,
        f.logical_reads,
        f.reads,
        f.writes,
        f.query_text,
        hb.query_text AS head_blocker_query_text
    FROM FilteredDiffRows AS f
    LEFT JOIN #Rows AS hb
      ON hb.InstanceID = f.InstanceID
     AND hb.SnapshotDateUTC = f.SnapshotDateUTC
     AND hb.session_id = f.blocking_session_id
    WHERE
        (
            @SessionID IS NULL
            OR EXISTS (SELECT 1 FROM #RelatedSessions AS r WHERE r.session_id = f.session_id)
            OR EXISTS (SELECT 1 FROM #RelatedSessions AS r WHERE r.session_id = f.blocking_session_id)
        )
        AND
        (
               f.blocking_session_id <> 0
            OR ISNULL(f.prev_blocking_session_id, 0) <> 0
            OR ISNULL(f.wait_type, N'') <> ISNULL(f.prev_wait_type, N'')
            OR ISNULL(f.wait_resource, N'') <> ISNULL(f.prev_wait_resource, N'')
        )
    ORDER BY f.InstanceName, f.DatabaseName, f.SnapshotDateUTC, f.session_id
    OPTION (RECOMPILE);

    IF @SessionID IS NOT NULL
    BEGIN
        ;WITH Chains AS
        (
            SELECT
                r.InstanceID,
                r.InstanceName,
                r.DatabaseName,
                r.SnapshotDateUTC,
                r.session_id AS origin_session_id,
                r.session_id AS current_session_id,
                r.blocking_session_id AS current_parent_session_id,
                0 AS chain_depth,
                CAST(CAST(r.session_id AS VARCHAR(20)) AS VARCHAR(MAX)) AS blocking_chain
            FROM #Rows AS r
            WHERE r.session_id = @SessionID
               OR EXISTS (SELECT 1 FROM #RelatedSessions AS rs WHERE rs.session_id = r.session_id)
               OR EXISTS (SELECT 1 FROM #RelatedSessions AS rs WHERE rs.session_id = r.blocking_session_id)
              AND r.blocking_session_id IS NOT NULL
              AND r.blocking_session_id <> 0

            UNION ALL

            SELECT
                c.InstanceID,
                c.InstanceName,
                c.DatabaseName,
                p.SnapshotDateUTC,
                c.origin_session_id,
                p.session_id AS current_session_id,
                p.blocking_session_id AS current_parent_session_id,
                c.chain_depth + 1 AS chain_depth,
                CAST(c.blocking_chain + ' -> ' + CAST(p.session_id AS VARCHAR(20)) AS VARCHAR(MAX)) AS blocking_chain
            FROM Chains AS c
            JOIN #Rows AS p
              ON p.InstanceID = c.InstanceID
             AND p.SnapshotDateUTC = c.SnapshotDateUTC
             AND p.session_id = c.current_parent_session_id
            WHERE c.chain_depth + 1 <= @MaxDepth
        )
        SELECT
            c.InstanceName,
            c.DatabaseName,
            c.SnapshotDateUTC,
            c.origin_session_id AS blocked_session_id,
            c.current_session_id AS chain_node_session_id,
            c.current_parent_session_id AS chain_node_parent_session_id,
            c.chain_depth,
            c.blocking_chain,
            hb.query_text AS head_blocker_query_text
        FROM Chains AS c
        LEFT JOIN #Rows AS hb
          ON hb.InstanceID = c.InstanceID
         AND hb.SnapshotDateUTC = c.SnapshotDateUTC
         AND hb.session_id = c.current_parent_session_id
        WHERE
            (
                @SessionID IS NULL
                OR EXISTS (SELECT 1 FROM #RelatedSessions AS rs WHERE rs.session_id = c.origin_session_id)
                OR EXISTS (SELECT 1 FROM #RelatedSessions AS rs WHERE rs.session_id = c.current_session_id)
            )
        ORDER BY c.InstanceName, c.DatabaseName, c.SnapshotDateUTC, c.origin_session_id, c.chain_depth
        OPTION (RECOMPILE, MAXRECURSION 0);
    END

    DROP TABLE IF EXISTS #Rows;
    DROP TABLE IF EXISTS #RelatedSessions;
END
GO
