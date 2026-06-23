
-- If you are changing te TDE certificate between two environments you will 
--need to perform the following steps to be able to restore on the destination

-- 1.) Execute repldone to make sure all data is committed in CDC
EXEC sp_repldone
    @xactid = NULL,
    @xact_seqno = NULL,
    @numtrans = 0,
    @time = 0,
    @reset = 1;

-- 2.) Next Disable CDC on the source database that you are changing the certificate on
EXEC sys.sp_cdc_disable_db;

--3.) You will now swap the certificate to the one on the destination server
-- Swap TDE Certificate with correct environment
USE DB;
GO
ALTER DATABASE ENCRYPTION KEY
ENCRYPTION BY SERVER CERTIFICATE CertificateName;



select * from sys.certificates