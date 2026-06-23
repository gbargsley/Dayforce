-- Replace with the two RunBatchIDs you want to compare
DECLARE @A UNIQUEIDENTIFIER = '1A9DE73C-2C9B-4BAF-9D57-3CA90515145E';
DECLARE @B UNIQUEIDENTIFIER = '0D1AE840-EC47-4400-8D1E-24CB7E6BFB87';

WITH agg AS (
    SELECT
        RunBatchID,
        COUNT(*) AS Runs,
        AVG(DurationSeconds) AS AvgDuration,
        AVG(MBPerSec) AS AvgMBPerSec,
        AVG(SessionCpuMs) AS AvgSessionCpuMs,
        AVG(IoBytesRead) AS AvgIoBytesRead,
        AVG(IoBytesWritten) AS AvgIoBytesWritten,
        SUM(CASE WHEN ErrorMessage IS NOT NULL THEN 1 ELSE 0 END) AS Errors
    FROM dbo.BackupPerformanceTest
    WHERE RunBatchID IN (@A, @B)
    GROUP BY RunBatchID
)
SELECT
    a.RunBatchID as BatchA,
    b.RunBatchID as BatchB,
    a.Runs AS RunsA, b.Runs AS RunsB,
    a.AvgDuration AS AvgDurationA, b.AvgDuration AS AvgDurationB,
    100.0 * (b.AvgDuration - a.AvgDuration) / NULLIF(a.AvgDuration,0) AS PctChange_Duration,
    a.AvgMBPerSec AS AvgMBPerSecA, b.AvgMBPerSec AS AvgMBPerSecB,
    100.0 * (b.AvgMBPerSec - a.AvgMBPerSec) / NULLIF(a.AvgMBPerSec,0) AS PctChange_MBPerSec,
    a.AvgSessionCpuMs, b.AvgSessionCpuMs,
    a.AvgIoBytesRead, b.AvgIoBytesRead,
    a.Errors AS ErrorsA, b.Errors AS ErrorsB
FROM agg a
JOIN agg b ON a.RunBatchID = @A AND b.RunBatchID = @B;
