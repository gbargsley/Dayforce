USE [master] 

RESTORE DATABASE pp4l150 
FROM URL = N'https://app122cacsqlbackupsshort.blob.core.windows.net/full/azc1dfcsql36cl$Prod_AG/pp4l150/full/azc1dfcsql36cl$Prod_AG_pp4l150_full_20260613_172824.bak'
	--,URL = N'https://app121dfpcbackupsshort.blob.core.windows.net/full/azg1gussql08cl$Prod_AG/griffith/full/azg1gussql08cl$Prod_AG_griffith_full_20260606_170615_2.bak'
	--,URL = N'https://app121dfpcbackupsshort.blob.core.windows.net/full/azg1gussql08cl$Prod_AG/griffith/full/azg1gussql08cl$Prod_AG_griffith_full_20260606_170615_3.bak'
	--,URL = N'https://app121dfpcbackupsshort.blob.core.windows.net/full/azg1dfcsql11cl$Prod_AG/bluegreen/full/azg1dfcsql11cl$Prod_AG_bluegreen_full_20260509_170004_4.bak'
	--,URL = N'https://app121dfpcbackupsshort.blob.core.windows.net/full/azg1dfcsql11cl$Prod_AG/bluegreen/full/azg1dfcsql11cl$Prod_AG_bluegreen_full_20260509_170004_5.bak'
	--,URL = N'https://app121dfpcbackupsshort.blob.core.windows.net/full/azg1dfcsql11cl$Prod_AG/bluegreen/full/azg1dfcsql11cl$Prod_AG_bluegreen_full_20260509_170004_6.bak'
WITH 
	FILE = 1
	--,  NORECOVERY
	,  NOUNLOAD
	,  STATS = 5 
GO


--Scrub Server 2019 US - azg2dfcscb002
--Scrub Server 2019 CA - azc2dfcscb001 
--Scrub Server 2022 US - azg2dfcscb005
--Scrub Server 2022 CA - azc2dfcscb003






