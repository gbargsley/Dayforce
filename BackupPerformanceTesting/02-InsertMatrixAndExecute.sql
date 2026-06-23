USE AdminDB_Test
GO;

-- Insert an example matrix row (your original command translated)
INSERT INTO dbo.BackupTestMatrix
(
    MatrixName, Databases, [URL], BackupType, LogToTable, MaxTransferSize, BlockSize, BufferCount, MaxFileSize, CompressChar,
    DatabasesInParallel, ExecuteFlag, NumberOfFiles, RunCount, DelayBetweenSeconds, IsActive
)
VALUES
(
    'AZhcm2Support038 - compress Y 4MB transfer 65K block',  -- Matrix Name
    'AZhcm2Support038',  -- Databases
    'https://app521npaue01auesql.blob.core.windows.net/full',  -- URL
    'FULL',  -- Backup Type
    'Y',  -- Log To Table
    4194304,  -- MaxTransferSize
    65536,  -- BlockSize
    8,  -- BufferCount
    153600,  -- MaxFileSize
    'Y',  -- Compress
    'Y',  -- Parallel
    'Y',  -- Execute
    1,  -- Number of Files
    1,      -- run 3 times
    10,     -- wait 10s between runs
    1   -- IsActive
);

-- Run all active matrix rows (or pass a MatrixID to run just that one)
EXEC dbo.RunBackupTestMatrix;  -- runs all active rows




-- OR run a specific MatrixID:
-- EXEC dbo.RunBackupTestMatrix @MatrixID = 1;
-- Example matrix entries (insert as many variations as you want)
INSERT INTO dbo.BackupTestMatrix (MatrixName, Databases, [URL], BackupType, LogToTable, MaxTransferSize, BlockSize, BufferCount, MaxFileSize, CompressChar, DatabasesInParallel, ExecuteFlag, NumberOfFiles, RunCount, DelayBetweenSeconds, IsActive)
VALUES
('4MB transfer / 65K block / buffer 96 / NumberOfFiles 24 / Database: AZhcm2Support038', 'AZhcm2Support038', 'https://app521npaue01auesql.blob.core.windows.net/full', 'FULL', 'Y', 4194304, 65536, 96, NULL, 'Y', 'Y', 'Y', 24, 1, 10, 1);


-- Show matrix rows
SELECT MatrixID, MatrixName, Databases, MaxTransferSize, BlockSize, BufferCount, MaxFileSize, NumberOfFiles, RunCount, DelayBetweenSeconds FROM dbo.BackupTestMatrix WHERE IsActive = 1;

-- Run everything active
EXEC dbo.RunBackupTestMatrix;

-- Or run a specific MatrixID
-- EXEC dbo.RunBackupTestMatrix @MatrixID = 4;

