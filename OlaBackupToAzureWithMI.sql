    EXECUTE admindb.dbo.DatabaseBackup
        @Databases = 'AZhcm2Support038',
        @URL = 'https://app521npaue01auesql.blob.core.windows.net/full',
        @BackupType = 'full',
        @LogToTable = 'N',
        @MaxTransferSize = 4194304,
        @BlockSize = 65536,
        @Compress = 'Y',
        @MaxFileSize = 153600,
        @DatabasesInParallel = 'Y',
        @Execute = 'Y';


EXEC dbo.RunOlaBackupPerfTest
    @DatabaseName = 'AZhcm2Support038',
    @URL = 'https://app521npaue01auesql.blob.core.windows.net/full',
    @BackupType = 'FULL',
    @Compress = 1,
    @MaxTransferSize = 4194304,
    --@BufferCount = 8,
    --@NumberOfFiles = 4,
    @CopyOnly = 0,
    @Verify = 0,
    @CheckSum = 1;
