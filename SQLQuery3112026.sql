/*
petco - AZG2VANSQL012.custadds.com
ehi - AZG2EHISQL003.custadds.com
tmn - AZG2TMNSQL004.custadds.com
costa - AZM2DFCSQL009.custadds.com
builders - AZG2BLDSQL003.custadds.com
*/

SELECT ChangeStartTime, PopulateEndTime, UpdateResult, ResultDescription
FROM OrgUpdateHistory WITH (NOLOCK)
WHERE UpdateResult <> 1
    AND ChangeStartTime > '2026-03-01'

UNION ALL

SELECT 
    NULL AS ChangeStartTime,
    NULL AS PopulateEndTime,
    NULL AS UpdateResult,
    'No records found' AS ResultDescription
WHERE NOT EXISTS (
    SELECT 1
    FROM OrgUpdateHistory WITH (NOLOCK)
    WHERE UpdateResult <> 1
        AND ChangeStartTime > '2026-03-01'
);