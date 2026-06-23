-- pick the slowest runs (by Duration or lowest MBPerSec)
SELECT TOP(20) TestID, TestDate, RunBatchID, DatabaseName, DurationSeconds, MBPerSec, ErrorMessage
FROM dbo.BackupPerformanceTest
ORDER BY DurationSeconds DESC;

-- then inspect waits/io JSON for a specific TestID
DECLARE @tid BIGINT = 4;
SELECT WaitsJson, IoJson FROM dbo.BackupPerformanceTest WHERE TestID = @tid;

-- parse WaitsJson
SELECT *
FROM dbo.BackupPerformanceTest t
CROSS APPLY OPENJSON(t.WaitsJson) WITH (wait_type nvarchar(128), delta_ms bigint)
WHERE t.TestID = @tid;
