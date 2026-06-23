/*
Resources:

https://dayforce.atlassian.net/wiki/spaces/AR/pages/723001026/Data+Manager+Logging
https://dayforce.atlassian.net/wiki/spaces/AR/pages/736265139/Production+DataManager+Logging+Guide+for+DBAs

*/

-- Get ControlDB location for client
-- Server: an1prddfcmon002.dforce1.navisite.net

USE AdminDB;

SELECT * FROM [dbo].[ClientDBConfigInfo] WHERE namespace = 'mul'


-- Get SiteSettings info from ControlDB
-- Example Server: azg1gcrsql01dnn.custadds.com
-- Example ControlDB: wkdus252control

USE wkdus261control;

SELECT * FROM [dbo].[SiteSetting]
WHERE name = 'DM.Logging.TransactionLoggingConfig'

-- Enable Logging

-- Non-Vanity client
BEGIN TRAN
update SiteSetting
set [value] = 
'{"NamespacesAllowedToLog":"cityofcolumbus","RefreshIntervalInMinutes": 1, "IsEmptyNamespaceLogsAllowed": false, "IsTranDbProcessInfoLoggingEnabled": true, "IsDataManagerLoggingEnabled":true, "IsTransactionStatsLoggingEnabled": true,"IsTransactionOperationLoggingEnabled": true,"IsStackTraceNeededForTranLogging": false}'
, LastModifiedTimestamp = CURRENT_TIMESTAMP
where name = 'DM.Logging.TransactionLoggingConfig'

-- Vanity client
BEGIN TRAN
update SiteSetting
set [value] = 
'{"NamespacesAllowedToLog":"all","RefreshIntervalInMinutes": 1, "IsEmptyNamespaceLogsAllowed": false, "IsTranDbProcessInfoLoggingEnabled": true, "IsDataManagerLoggingEnabled":true, "IsTransactionStatsLoggingEnabled": true,"IsTransactionOperationLoggingEnabled": true,"IsStackTraceNeededForTranLogging": false}'
, LastModifiedTimestamp = CURRENT_TIMESTAMP
where name = 'DM.Logging.TransactionLoggingConfig'

-- COMMIT
-- ROLLBACK


-- Disable Logging

-- Non-Vanity client
BEGIN TRAN
 UPDATE SiteSetting
	SET [value] = 
		'{"IsDataManagerLoggingEnabled":false, "NamespacesAllowedToLog":"NAMESPACE","IsEmptyNamespaceLogsAllowed": false,"IsTransactionOperationLoggingEnabled": false, "IsTranDbProcessInfoLoggingEnabled": false, "IsTransactionStatsLoggingEnabled": false,"IsStackTraceNeededForTranLogging": false,"RefreshIntervalInMinutes": 5}'
		, LastModifiedTimestamp = CURRENT_TIMESTAMP
    WHERE name = 'DM.Logging.TransactionLoggingConfig'

-- Vanity client
BEGIN TRAN
 UPDATE SiteSetting
	SET [value] = 
		'{"IsDataManagerLoggingEnabled":false, "NamespacesAllowedToLog":"All","IsEmptyNamespaceLogsAllowed": false,"IsTransactionOperationLoggingEnabled": false, "IsTranDbProcessInfoLoggingEnabled": false, "IsTransactionStatsLoggingEnabled": false,"IsStackTraceNeededForTranLogging": false,"RefreshIntervalInMinutes": 5}'
		, LastModifiedTimestamp = CURRENT_TIMESTAMP
    WHERE name = 'DM.Logging.TransactionLoggingConfig'

-- COMMIT
-- ROLLBACK