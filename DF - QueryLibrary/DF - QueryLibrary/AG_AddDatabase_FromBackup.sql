-- Restore the full on the primary AG node
RESTORE DATABASE [SR2511100040010255]
FROM URL = N'https://app123euwsqlbackupsshort.blob.core.windows.net/full/azm1geusql06d/SR2511100040010255/full/azm1geusql06d_SR2511100040010255_full_20251211_190315.bak'

-- Run this on the primary AG after the restore is complete on all AG's
USE master
ALTER AVAILABILITY GROUP Prod_AG ADD DATABASE [test];

-- Run this restore on all secondary nodes
RESTORE DATABASE [test]
FROM URL = N'https://app121dfpcbackupsshort.blob.core.windows.net/full/azg1dfcsql55e/test/full/azg1dfcsql55e_test_full_20260530_170009.bak'
WITH
	NORECOVERY

-- Run this on the secondary AG node if you have already joined the database on the primary
USE master
ALTER DATABASE [test] SET HADR AVAILABILITY GROUP = Prod_AG