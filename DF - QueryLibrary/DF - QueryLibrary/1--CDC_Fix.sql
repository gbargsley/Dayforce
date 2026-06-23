select log_reuse_wait_desc, * from sys.databases where name = 'apacdfapp01config'

use apacdfapp01config
go

checkpoint


IF EXISTS (SELECT 1 FROM master.sys.databases WHERE [name] = 'uzhcm3support045' AND is_cdc_enabled = 1)
BEGIN
EXEC [uzhcm3support045]..sp_repldone @xactid = NULL, @xact_segno = NULL, @numtrans = 0, @time = 0, @reset = 1;
EXEC [uzhcm3support045]..sp_replflush
END