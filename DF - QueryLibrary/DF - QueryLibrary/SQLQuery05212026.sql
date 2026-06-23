EXEC [DFWALLET_FTPortal].[FTPortal].[dbo].[uspArchiveAndDeleteOldTransactionDetails]
	@MaxRunTimeMinutes = 5,		
	@RowsPerBatch = 5000,
		
	@DelayMilliseconds = 10,
        
	@StartDate = '20230101',
	    
	@EndDate  = '20241231';
GO
