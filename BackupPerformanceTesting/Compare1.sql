-- Summary by Matrix (aggregates + median + p95)
WITH runs AS (
    SELECT
        s.MatrixID,
        s.MatrixName,
        t.TestID,
        t.DurationSeconds,
        t.MBPerSec,
        t.SizeMB,
        t.CompressedSizeMB,
        CASE WHEN t.ErrorMessage IS NOT NULL THEN 1 ELSE 0 END AS IsError
    FROM dbo.BackupPerformanceTest t
    LEFT JOIN dbo.BackupPerformanceSummary s ON t.RunBatchID = s.RunBatchID
    WHERE t.MBPerSec IS NOT NULL OR t.DurationSeconds IS NOT NULL
)
, stats AS (
    SELECT
        MatrixID,
        MatrixName,
        COUNT(*) AS Runs,
        SUM(IsError) AS Failures,
        AVG(DurationSeconds) AS AvgDuration,
        STDEV(DurationSeconds) AS StdevDuration,
        AVG(MBPerSec) AS AvgMBPerSec,
        STDEV(MBPerSec) AS StdevMBPerSec,
        AVG(SizeMB) AS AvgSizeMB,
        AVG(CompressedSizeMB) AS AvgCompressedSizeMB,
        1.0 * SUM(IsError) / NULLIF(COUNT(*),0) AS FailRate
    FROM runs
    GROUP BY MatrixID, MatrixName
)
SELECT
    st.*,
    -- percentiles using PERCENTILE_CONT window function (compute per-row then pick distinct)
    p.MedianMBPerSec,
    p.P95MBPerSec
FROM stats st
CROSS APPLY (
    SELECT
        MAX(CASE WHEN pct = 0.50 THEN val END) AS MedianMBPerSec,
        MAX(CASE WHEN pct = 0.95 THEN val END) AS P95MBPerSec
    FROM (
        SELECT DISTINCT
           PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY MBPerSec) OVER (PARTITION BY MatrixID) AS val, 0.50 AS pct, MatrixID
        FROM runs r WHERE r.MatrixID = st.MatrixID AND r.MBPerSec IS NOT NULL
        UNION ALL
        SELECT DISTINCT
           PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY MBPerSec) OVER (PARTITION BY MatrixID) AS val, 0.95 AS pct, MatrixID
        FROM runs r WHERE r.MatrixID = st.MatrixID AND r.MBPerSec IS NOT NULL
    ) x
) p
ORDER BY AvgMBPerSec DESC;
