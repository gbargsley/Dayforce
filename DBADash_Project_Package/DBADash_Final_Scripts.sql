USE DBADashDB;
GO

/*
================================================================================
DBADash final scripts package
================================================================================
Contents:
  1) dbo.usp_GetSlowQueries_LatestSnapshot_v1
  2) dbo.usp_GetBlockingSnapshotChanges_v1

Design goals:
  - Slow query output uses the latest snapshot per session inside the requested
    window, so CPU / reads / writes / duration reflect the newest captured state.
  - Blocking output analyzes every snapshot in the window and shows snapshot-to-
    snapshot differences, plus root blocker details and optional SPID-focused
    chain output.
  - Friendly names only: InstanceName and DatabaseName.
  - Optional local-time input conversion.
  - Optional query text in output.
================================================================================
*/

IF OBJECT_ID('dbo.usp_GetSlowQueries_LatestSnapshot_v1', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_GetSlowQueries_LatestSnapshot_v1;
GO

CREATE PROCEDURE dbo.usp_GetSlowQueries_LatestSnapshot_v1
    @StartUTC          DATETIME2,
    @EndUTC            DATETIME2,
    @InstanceName      NVARCHAR(256) = NULL,
    @DatabaseName      NVARCHAR(256) = NULL,
    @MinSeconds        INT = 5,
    @Aggregate         BIT = 0,
    @MaxRows           INT = NULL,
    @IncludeQueryText  BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    IF @StartUTC IS NULL OR @EndUTC IS NULL OR @EndUTC < @StartUTC
    BEGIN
        RAISERROR('Invalid StartUTC / EndUTC parameters.', 16, 1);
        RETURN;
    END;

    DECLARE @MinMs INT = CASE WHEN ISNULL(@MinSeconds, 0) <= 0 THEN 0 ELSE @MinSeconds * 1000 END;

    IF @Aggregate = 0
    BEGIN
        ;WITH LatestPerSession AS (
            SELECT
                rq.*,
                ROW_NUMBER() OVER (
                    PARTITION BY rq.InstanceID, rq.session_id
                    ORDER BY rq.SnapshotDateUTC DESC
                ) AS rn
            FROM dbo.RunningQueries rq
            WHERE rq.SnapshotDateUTC >= @StartUTC
              AND rq.SnapshotDateUTC <= @EndUTC
              AND NOT (rq.status = 'sleeping' AND rq.command IS NULL)
        ),
        Latest AS (
            SELECT *
            FROM LatestPerSession
            WHERE rn = 1
        ),
        Named AS (
            SELECT
                l.InstanceID,
                i.[Instance] AS InstanceName,
                l.database_id,
                d.name AS DatabaseName,
                l.SnapshotDateUTC,
                l.session_id,
                l.status,
                l.command,
                l.login_name,
                l.host_name,
                l.program_name,
                l.client_interface_name,
                l.start_time_utc,
                l.last_request_start_time_utc,
                l.sql_handle,
                l.plan_handle,
                l.query_hash,
                l.query_plan_hash,
                l.cpu_time,
                l.logical_reads,
                l.reads,
                l.writes,
                l.granted_query_memory,
                l.percent_complete,
                l.open_transaction_count,
                l.transaction_isolation_level,
                l.wait_time,
                l.wait_type,
                l.wait_resource,
                l.blocking_session_id,
                l.total_elapsed_time,
                l.tempdb_alloc_page_count,
                l.tempdb_dealloc_page_count,
                CASE WHEN @IncludeQueryText = 1 THEN qt.[text] END AS query_text
            FROM Latest l
            LEFT JOIN dbo.Instances i
                ON i.InstanceID = l.InstanceID
            LEFT JOIN dbo.Databases d
                ON d.InstanceID = l.InstanceID
               AND d.database_id = l.database_id
            LEFT JOIN dbo.QueryText qt
                ON qt.sql_handle = l.sql_handle
            WHERE (@InstanceName IS NULL OR i.[Instance] = @InstanceName)
              AND (@DatabaseName IS NULL OR d.name = @DatabaseName)
              AND (
                    @MinMs = 0
                 OR l.cpu_time >= @MinMs
                 OR l.total_elapsed_time >= @MinMs
              )
        )
        SELECT
            n.InstanceName,
            n.DatabaseName,
            n.SnapshotDateUTC,
            n.session_id,
            n.status,
            n.command,
            n.login_name,
            n.host_name,
            n.program_name,
            n.client_interface_name,
            n.start_time_utc,
            n.last_request_start_time_utc,
            n.sql_handle,
            n.plan_handle,
            n.query_hash,
            n.query_plan_hash,
            n.cpu_time AS cpu_time_ms,
            CAST(n.cpu_time AS FLOAT) / 1000.0 AS cpu_seconds,
            n.logical_reads,
            n.reads AS physical_reads,
            n.writes,
            n.granted_query_memory,
            n.percent_complete,
            n.open_transaction_count,
            n.transaction_isolation_level,
            n.wait_time,
            n.wait_type,
            n.wait_resource,
            n.blocking_session_id,
            n.total_elapsed_time AS duration_ms,
            CAST(n.total_elapsed_time AS FLOAT) / 1000.0 AS duration_seconds,
            n.tempdb_alloc_page_count,
            n.tempdb_dealloc_page_count,
            n.query_text
        FROM Named n
        ORDER BY n.SnapshotDateUTC DESC, n.cpu_time DESC
        OFFSET 0 ROWS
        FETCH NEXT ISNULL(@MaxRows, 2147483647) ROWS ONLY
        OPTION (RECOMPILE);
    END
    ELSE
    BEGIN
        ;WITH LatestPerSession AS (
            SELECT
                rq.*,
                ROW_NUMBER() OVER (
                    PARTITION BY rq.InstanceID, rq.session_id
                    ORDER BY rq.SnapshotDateUTC DESC
                ) AS rn
            FROM dbo.RunningQueries rq
            WHERE rq.SnapshotDateUTC >= @StartUTC
              AND rq.SnapshotDateUTC <= @EndUTC
              AND NOT (rq.status = 'sleeping' AND rq.command IS NULL)
        ),
        Latest AS (
            SELECT *
            FROM LatestPerSession
            WHERE rn = 1
        ),
        Named AS (
            SELECT
                l.InstanceID,
                i.[Instance] AS InstanceName,
                l.database_id,
                d.name AS DatabaseName,
                l.SnapshotDateUTC,
                l.session_id,
                l.sql_handle,
                l.plan_handle,
                l.query_hash,
                l.query_plan_hash,
                l.cpu_time,
                l.logical_reads,
                l.reads,
                l.writes,
                l.total_elapsed_time,
                CASE WHEN @IncludeQueryText = 1 THEN qt.[text] END AS query_text
            FROM Latest l
            LEFT JOIN dbo.Instances i
                ON i.InstanceID = l.InstanceID
            LEFT JOIN dbo.Databases d
                ON d.InstanceID = l.InstanceID
               AND d.database_id = l.database_id
            LEFT JOIN dbo.QueryText qt
                ON qt.sql_handle = l.sql_handle
            WHERE (@InstanceName IS NULL OR i.[Instance] = @InstanceName)
              AND (@DatabaseName IS NULL OR d.name = @DatabaseName)
              AND (
                    @MinMs = 0
                 OR l.cpu_time >= @MinMs
                 OR l.total_elapsed_time >= @MinMs
              )
        )
        SELECT
            n.InstanceName,
            n.DatabaseName,
            n.sql_handle,
            n.plan_handle,
            n.query_hash,
            n.query_plan_hash,
            COUNT(*) AS samples,
            MAX(n.SnapshotDateUTC) AS last_seen,
            SUM(n.cpu_time) AS total_cpu_ms,
            CAST(SUM(n.cpu_time) AS FLOAT) / 1000.0 AS total_cpu_seconds,
            SUM(n.logical_reads) AS total_logical_reads,
            SUM(n.reads) AS total_physical_reads,
            SUM(n.writes) AS total_writes,
            SUM(n.total_elapsed_time) AS total_duration_ms,
            CAST(SUM(n.total_elapsed_time) AS FLOAT) / 1000.0 AS total_duration_seconds,
            MAX(n.query_text) AS sample_query_text
        FROM Named n
        GROUP BY
            n.InstanceName,
            n.DatabaseName,
            n.sql_handle,
            n.plan_handle,
            n.query_hash,
            n.query_plan_hash
        ORDER BY total_duration_ms DESC;
    END
END
GO

IF OBJECT_ID('dbo.usp_GetBlockingSnapshotChanges_v1', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_GetBlockingSnapshotChanges_v1;
GO

CREATE PROCEDURE dbo.usp_GetBlockingSnapshotChanges_v1
    @StartUTC           DATETIME2,
    @EndUTC             DATETIME2,
    @InstanceName       NVARCHAR(256) = NULL,
    @DatabaseName       NVARCHAR(256) = NULL,
    @MaxDepth           INT = 10,
    @InputIsLocal       BIT = 0,
    @LocalOffsetMinutes INT = NULL,
    @SessionID          INT = NULL,
    @IncludeQueryText   BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    IF @InputIsLocal = 1
    BEGIN
        IF @LocalOffsetMinutes IS NULL
        BEGIN
            RAISERROR('When @InputIsLocal = 1 you must provide @LocalOffsetMinutes.', 16, 1);
            RETURN;
        END;

        SET @StartUTC = DATEADD(MINUTE, -@LocalOffsetMinutes, @StartUTC);
        SET @EndUTC   = DATEADD(MINUTE, -@LocalOffsetMinutes, @EndUTC);
    END;

    IF @StartUTC IS NULL OR @EndUTC IS NULL OR @EndUTC < @StartUTC
    BEGIN
        RAISERROR('Invalid StartUTC / EndUTC parameters.', 16, 1);
        RETURN;
    END;

    IF @MaxDepth IS NULL OR @MaxDepth < 1
        SET @MaxDepth = 10;

    IF OBJECT_ID('tempdb..#Snap') IS NOT NULL DROP TABLE #Snap;
    IF OBJECT_ID('tempdb..#RelatedSessions') IS NOT NULL DROP TABLE #RelatedSessions;
    IF OBJECT_ID('tempdb..#RootMap') IS NOT NULL DROP TABLE #RootMap;

    ;WITH Base AS (
        SELECT
            rq.*,
            LAG(rq.blocking_session_id) OVER (
                PARTITION BY rq.InstanceID, rq.session_id
                ORDER BY rq.SnapshotDateUTC
            ) AS prev_blocking_session_id,
            LAG(rq.wait_type) OVER (
                PARTITION BY rq.InstanceID, rq.session_id
                ORDER BY rq.SnapshotDateUTC
            ) AS prev_wait_type,
            LAG(rq.wait_resource) OVER (
                PARTITION BY rq.InstanceID, rq.session_id
                ORDER BY rq.SnapshotDateUTC
            ) AS prev_wait_resource,
            LAG(rq.status) OVER (
                PARTITION BY rq.InstanceID, rq.session_id
                ORDER BY rq.SnapshotDateUTC
            ) AS prev_status,
            LAG(rq.total_elapsed_time) OVER (
                PARTITION BY rq.InstanceID, rq.session_id
                ORDER BY rq.SnapshotDateUTC
            ) AS prev_total_elapsed_time,
            LAG(rq.cpu_time) OVER (
                PARTITION BY rq.InstanceID, rq.session_id
                ORDER BY rq.SnapshotDateUTC
            ) AS prev_cpu_time
        FROM dbo.RunningQueries rq
        WHERE rq.SnapshotDateUTC >= @StartUTC
          AND rq.SnapshotDateUTC <= @EndUTC
          AND NOT (rq.status = 'sleeping' AND rq.command IS NULL)
    )
    SELECT
        b.InstanceID,
        i.[Instance] AS InstanceName,
        b.database_id,
        d.name AS DatabaseName,
        b.SnapshotDateUTC,
        b.session_id,
        b.blocking_session_id,
        b.prev_blocking_session_id,
        CASE
            WHEN ISNULL(b.prev_blocking_session_id, -1) <> ISNULL(b.blocking_session_id, -1)
              OR ISNULL(b.prev_wait_type, '') <> ISNULL(b.wait_type, '')
              OR ISNULL(b.prev_wait_resource, '') <> ISNULL(b.wait_resource, '')
              OR ISNULL(b.prev_status, '') <> ISNULL(b.status, '')
            THEN 1 ELSE 0
        END AS blocking_changed,
        b.status,
        b.command,
        b.wait_type,
        b.wait_resource,
        b.wait_time,
        b.cpu_time,
        b.logical_reads,
        b.reads,
        b.writes,
        b.total_elapsed_time,
        b.login_name,
        b.host_name,
        b.program_name,
        b.sql_handle,
        b.query_hash,
        b.plan_handle,
        b.start_time_utc,
        b.last_request_start_time_utc,
        CASE WHEN @IncludeQueryText = 1 THEN qt.[text] END AS query_text
    INTO #Snap
    FROM Base b
    LEFT JOIN dbo.Instances i
        ON i.InstanceID = b.InstanceID
    LEFT JOIN dbo.Databases d
        ON d.InstanceID = b.InstanceID
       AND d.database_id = b.database_id
    LEFT JOIN dbo.QueryText qt
        ON qt.sql_handle = b.sql_handle
    WHERE (@InstanceName IS NULL OR i.[Instance] = @InstanceName)
      AND (@DatabaseName IS NULL OR d.name = @DatabaseName);

    CREATE TABLE #RelatedSessions (
        session_id INT NOT NULL PRIMARY KEY
    );

    IF @SessionID IS NOT NULL
    BEGIN
        ;WITH Rel AS (
            SELECT
                s.session_id,
                s.blocking_session_id,
                0 AS level,
                CAST('|' + CAST(s.session_id AS VARCHAR(20)) + '|' AS VARCHAR(MAX)) AS path
            FROM #Snap s
            WHERE s.session_id = @SessionID

            UNION ALL

            SELECT
                s2.session_id,
                s2.blocking_session_id,
                r.level + 1,
                CAST(r.path + CAST(s2.session_id AS VARCHAR(20)) + '|' AS VARCHAR(MAX))
            FROM #Snap s2
            JOIN Rel r
              ON s2.session_id = r.blocking_session_id
              OR s2.blocking_session_id = r.session_id
            WHERE r.level + 1 <= @MaxDepth
              AND CHARINDEX('|' + CAST(s2.session_id AS VARCHAR(20)) + '|', r.path) = 0
        )
        INSERT INTO #RelatedSessions (session_id)
        SELECT DISTINCT session_id
        FROM Rel
        OPTION (MAXRECURSION 0);
    END;

    ;WITH RootChain AS (
        SELECT
            s.InstanceID,
            s.SnapshotDateUTC,
            s.session_id AS blocked_session_id,
            s.session_id AS current_session_id,
            s.blocking_session_id AS next_session_id,
            0 AS level,
            CAST('|' + CAST(s.session_id AS VARCHAR(20)) + '|' AS VARCHAR(MAX)) AS path
        FROM #Snap s
        WHERE s.blocking_session_id IS NOT NULL
          AND s.blocking_session_id <> 0
          AND (
                @SessionID IS NULL
             OR EXISTS (SELECT 1 FROM #RelatedSessions r WHERE r.session_id = s.session_id)
             OR s.session_id = @SessionID
             OR s.blocking_session_id = @SessionID
          )

        UNION ALL

        SELECT
            rc.InstanceID,
            rc.SnapshotDateUTC,
            rc.blocked_session_id,
            p.session_id AS current_session_id,
            p.blocking_session_id AS next_session_id,
            rc.level + 1 AS level,
            CAST(rc.path + CAST(p.session_id AS VARCHAR(20)) + '|' AS VARCHAR(MAX))
        FROM RootChain rc
        JOIN #Snap p
          ON p.InstanceID = rc.InstanceID
         AND p.SnapshotDateUTC = rc.SnapshotDateUTC
         AND p.session_id = rc.next_session_id
        WHERE rc.level + 1 <= @MaxDepth
          AND CHARINDEX('|' + CAST(p.session_id AS VARCHAR(20)) + '|', rc.path) = 0
    ),
    RootPick AS (
        SELECT
            rc.*,
            ROW_NUMBER() OVER (
                PARTITION BY rc.InstanceID, rc.SnapshotDateUTC, rc.blocked_session_id
                ORDER BY rc.level DESC
            ) AS rn
        FROM RootChain rc
    )
    SELECT
        s.InstanceName,
        s.DatabaseName,
        s.SnapshotDateUTC,
        s.session_id,
        s.prev_blocking_session_id,
        s.blocking_session_id,
        s.blocking_changed,
        s.status,
        s.command,
        s.wait_type,
        s.wait_resource,
        s.wait_time,
        s.cpu_time AS cpu_time_ms,
        s.logical_reads,
        s.reads AS physical_reads,
        s.writes,
        s.total_elapsed_time AS duration_ms,
        CAST(s.total_elapsed_time AS FLOAT) / 1000.0 AS duration_seconds,
        s.login_name,
        s.host_name,
        s.program_name,
        s.sql_handle,
        s.query_hash,
        s.plan_handle,
        s.query_text,
        rp.current_session_id AS root_blocker_session_id,
        rb.command AS head_blocker_command,
        rb.wait_type AS head_blocker_wait_type,
        rb.wait_resource AS head_blocker_wait_resource,
        CASE WHEN @IncludeQueryText = 1 THEN rb.query_text END AS head_blocker_query_text,
        rp.level AS root_chain_depth,
        REPLACE(SUBSTRING(rp.path, 2, LEN(rp.path) - 2), '|', ' -> ') AS chain_path
    FROM #Snap s
    LEFT JOIN RootPick rp
      ON rp.InstanceID = s.InstanceID
     AND rp.SnapshotDateUTC = s.SnapshotDateUTC
     AND rp.blocked_session_id = s.session_id
     AND rp.rn = 1
    LEFT JOIN #Snap rb
      ON rb.InstanceID = s.InstanceID
     AND rb.SnapshotDateUTC = s.SnapshotDateUTC
     AND rb.session_id = rp.current_session_id
    WHERE (s.blocking_session_id <> 0 OR s.blocking_changed = 1)
      AND (
            @SessionID IS NULL
         OR EXISTS (SELECT 1 FROM #RelatedSessions r WHERE r.session_id = s.session_id)
         OR s.session_id = @SessionID
         OR s.blocking_session_id = @SessionID
      )
    ORDER BY s.SnapshotDateUTC DESC, s.wait_time DESC
    OPTION (MAXRECURSION 0);

    IF @SessionID IS NOT NULL
    BEGIN
        ;WITH RootChain AS (
            SELECT
                s.InstanceName,
                s.DatabaseName,
                s.SnapshotDateUTC,
                s.session_id AS blocked_session_id,
                s.session_id AS current_session_id,
                s.blocking_session_id AS next_session_id,
                0 AS level,
                CAST('|' + CAST(s.session_id AS VARCHAR(20)) + '|' AS VARCHAR(MAX)) AS path
            FROM #Snap s
            WHERE s.blocking_session_id IS NOT NULL
              AND s.blocking_session_id <> 0
              AND (
                    EXISTS (SELECT 1 FROM #RelatedSessions r WHERE r.session_id = s.session_id)
                 OR s.session_id = @SessionID
                 OR s.blocking_session_id = @SessionID
              )

            UNION ALL

            SELECT
                rc.InstanceName,
                rc.DatabaseName,
                rc.SnapshotDateUTC,
                rc.blocked_session_id,
                p.session_id AS current_session_id,
                p.blocking_session_id AS next_session_id,
                rc.level + 1 AS level,
                CAST(rc.path + CAST(p.session_id AS VARCHAR(20)) + '|' AS VARCHAR(MAX))
            FROM RootChain rc
            JOIN #Snap p
              ON p.InstanceName = rc.InstanceName
             AND p.DatabaseName = rc.DatabaseName
             AND p.SnapshotDateUTC = rc.SnapshotDateUTC
             AND p.session_id = rc.next_session_id
            WHERE rc.level + 1 <= @MaxDepth
              AND CHARINDEX('|' + CAST(p.session_id AS VARCHAR(20)) + '|', rc.path) = 0
        )
        SELECT
            InstanceName,
            DatabaseName,
            SnapshotDateUTC,
            blocked_session_id,
            current_session_id AS chain_node_session_id,
            next_session_id AS chain_node_parent_session_id,
            level,
            REPLACE(SUBSTRING(path, 2, LEN(path) - 2), '|', ' -> ') AS chain_path,
            CASE WHEN @IncludeQueryText = 1 THEN s.query_text END AS query_text,
            s.status,
            s.wait_type,
            s.wait_resource,
            s.cpu_time,
            s.total_elapsed_time AS duration_ms
        FROM RootChain rc
        LEFT JOIN #Snap s
          ON s.InstanceName = rc.InstanceName
         AND s.DatabaseName = rc.DatabaseName
         AND s.SnapshotDateUTC = rc.SnapshotDateUTC
         AND s.session_id = rc.current_session_id
        ORDER BY InstanceName, DatabaseName, SnapshotDateUTC DESC, blocked_session_id, level
        OPTION (MAXRECURSION 0);
    END;

    DROP TABLE IF EXISTS #Snap;
    DROP TABLE IF EXISTS #RelatedSessions;
    DROP TABLE IF EXISTS #RootMap;
END;
GO

/*
================================================================================
Example usage
================================================================================

-- Slow queries (latest snapshot per session), today in UTC
EXEC dbo.usp_GetSlowQueries_LatestSnapshot_v1
    @StartUTC = '2026-01-01T00:00:00',
    @EndUTC   = '2026-01-01T23:59:59.999',
    @MinSeconds = 5,
    @IncludeQueryText = 1;

-- Slow queries, aggregate by query, latest snapshot only
EXEC dbo.usp_GetSlowQueries_LatestSnapshot_v1
    @StartUTC = '2026-01-01T00:00:00',
    @EndUTC   = '2026-01-01T23:59:59.999',
    @Aggregate = 1,
    @IncludeQueryText = 1;

-- Blocking analysis using local time input (example CST = UTC-6)
DECLARE @LocalStart DATETIME2 = DATEADD(hour, -1, SYSDATETIME());
DECLARE @LocalEnd   DATETIME2 = SYSDATETIME();

EXEC dbo.usp_GetBlockingSnapshotChanges_v1
    @StartUTC = @LocalStart,
    @EndUTC   = @LocalEnd,
    @InputIsLocal = 1,
    @LocalOffsetMinutes = -360,
    @IncludeQueryText = 1;

-- Blocking analysis focused on one SPID (second resultset appears only when SessionID is supplied)
EXEC dbo.usp_GetBlockingSnapshotChanges_v1
    @StartUTC = '2026-01-01T00:00:00',
    @EndUTC   = '2026-01-01T23:59:59.999',
    @SessionID = 52,
    @IncludeQueryText = 1;
================================================================================
*/
