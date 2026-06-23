-- AZG1DBASQL011.ServerInventory  --- PRODUCTION ---
SELECT 
	*
FROM [ServerInventory].[dbo].[Vw_AzureProductionServerList]


-- AZG1DBASQL011.ServerInventory  --- PRE-PROD ---
SELECT 
	*
FROM [ServerInventory].[dbo].[Vw_AzurePreProductionServerList]
ORDER BY ServerName



-- AZG1DBASQL011.ServerInventory  --- NON-PROD ---
SELECT 
	*
FROM [ServerInventory].[dbo].[Vw_AzureNonProductionServerList]
  where ServerName NOT LIKE '%SND%'