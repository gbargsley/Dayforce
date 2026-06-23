


SELECT
    CodeName,
    ShortName,
    Enabled,
    ClientValue,
    ClientValueInDays
FROM DataManagementPolicy WITH(NOLOCK)
WHERE IsReadOnly = 0
AND CodeName IN ('PurgeHRExportStageData')

SELECT MIN(CallStartTimestampUTC), MAX(CallStartTimestampUTC), DATEDIFF(dd, MIN(CallStartTimestampUTC), MAX(CallStartTimestampUTC)) AS DaysOfData
FROM HCMAnywhereUsageMetrics WITH(NOLOCK)

SELECT MIN(LastModifiedTimestamp) AS OldestRecord, MAX(LastModifiedTimeStamp) AS NewestRecord, DATEDIFF(dd, MIN(LastModifiedTimestamp), MAX(LastModifiedTimeStamp)) AS DaysOfData
FROM HRPagingData WITH(NOLOCK)

SELECT TOP 10 
                        dmp.CodeName,
                        dml.ExecStartTimeUTC,
                        dml.ExecEndTimeUTC,
                        dml.[Log],
                        dml.ExecStartTimeUTC
FROM DataManagementLog dml WITH(NOLOCK)
INNER JOIN DataManagementPolicy dmp WITH(NOLOCK) ON dml.PolicyId = dmp.DataManagementPolicyId
WHERE dmp.CodeName IN ('PurgeHRExportStageData')
ORDER BY 2 DESC
