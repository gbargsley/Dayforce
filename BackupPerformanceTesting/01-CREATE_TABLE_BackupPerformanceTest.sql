-- 1) Matrix table that stores permutations to run
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'BackupTestMatrix' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE dbo.BackupTestMatrix
    (
        MatrixID INT IDENTITY PRIMARY KEY,
        MatrixName NVARCHAR(200) NULL,
        Databases NVARCHAR(400) NOT NULL,          -- pass-through to RunOlaBackupPerfTest
        [URL] NVARCHAR(400) NULL,
        BackupType VARCHAR(16) DEFAULT 'FULL',
        LogToTable CHAR(1) DEFAULT 'N',
        MaxTransferSize BIGINT NULL,
        BlockSize INT NULL,
        MaxFileSize BIGINT NULL,
        CompressChar CHAR(1) DEFAULT 'Y',          -- 'Y'/'N'
        DatabasesInParallel CHAR(1) DEFAULT 'Y',
        ExecuteFlag CHAR(1) DEFAULT 'Y',
        CopyOnly BIT DEFAULT 0,
        [Verify] BIT DEFAULT 0,
        CheckSum BIT DEFAULT 0,
        NumberOfFiles INT DEFAULT 1,
        RunCount INT DEFAULT 3,                    -- how many times to run each config
        DelayBetweenSeconds INT DEFAULT 5,         -- optional delay between runs to let system settle
        IsActive BIT DEFAULT 1,
        CreatedBy SYSNAME DEFAULT SUSER_SNAME(),
        CreatedDate DATETIME2 DEFAULT SYSUTCDATETIME()
    );
END
GO

-- 2) Summary table to store aggregated results per matrix row
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'BackupPerformanceSummary' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE dbo.BackupPerformanceSummary
    (
        SummaryID INT IDENTITY PRIMARY KEY,
        MatrixID INT NOT NULL,
        MatrixName NVARCHAR(200) NULL,
        RunsRequested INT,
        RunsCompleted INT,
        AvgDurationSeconds DECIMAL(18,2) NULL,
        AvgMBPerSec DECIMAL(18,2) NULL,
        AvgSessionCpuMs DECIMAL(18,2) NULL,
        AvgIoBytesWritten BIGINT NULL,
        AvgIoBytesRead BIGINT NULL,
        AvgCompressedRatio DECIMAL(18,4) NULL, -- (CompressedSize / Size)
        FirstRunDate DATETIME2 NULL,
        LastRunDate DATETIME2 NULL,
        RawTestStartTestID INT NULL,
        RawTestEndTestID INT NULL,
        CreatedBy SYSNAME DEFAULT SUSER_SNAME(),
        CreatedDate DATETIME2 DEFAULT SYSUTCDATETIME()
    );

    ALTER TABLE dbo.BackupPerformanceSummary
    ADD CONSTRAINT FK_BackupPerformanceSummary_BackupTestMatrix FOREIGN KEY (MatrixID)
        REFERENCES dbo.BackupTestMatrix(MatrixID);
END
GO
