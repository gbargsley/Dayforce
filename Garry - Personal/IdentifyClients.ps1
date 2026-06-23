#Author: Alok Jesudasen 
#Revised Date: 2016-01-06

$ScriptMode="Update";

$TempFileLocation="C:\Users\khuynh\biometric"+$(get-date -f yyyyMMddTHHmmssffff)+".csv"


$DashboardServer = "ncdb60.dayforce.com";
$DashboardDatabase = "DashboardDatabase";
$DashboardUser = "dashboard";
$DashboardPassword = "sql@tfs2008";




$ControlQuery =   "
				select databaseserver Servername,databasename ClientDbName from dashboardadmin.AdminInfo (nolock)
				 where DatabaseServer not like '%an1prdfcsql04cl%'
				 and DatabaseServer not like '%prvctlsql%'
				 and DatabaseServer not like '%corsql01%'
				 and DatabaseServer not like '%an1prvmydsql01%'
				 and databaseserver not like '%error%'


			
                 ";

$DatabaseConnectionQuery =@"

-- Non-terminated employees, most recent status
SELECT EmployeeId, EffectiveStart INTO #temp_EmployeePayPolicy FROM 
(
	SELECT e.EmployeeId, ees.EffectiveStart, g.XRefCode Status, RANK() OVER (PARTITION BY e.EmployeeId ORDER BY EffectiveStart DESC) StatusIndex FROM Employee e WITH(NOLOCK)
	JOIN EmployeeEmploymentStatus ees WITH(NOLOCK) ON ees.EmployeeId=e.EmployeeId
	JOIN EmploymentStatus s WITH(NOLOCK) ON s.EmploymentStatusId=ees.EmploymentStatusId
	JOIN EmploymentStatusGroup g WITH(NOLOCK) ON g.EmploymentStatusGroupId=s.EmploymentStatusGroupId
) Employees WHERE StatusIndex=1 AND Status<>'TERMINATED'

-- Collect home addresses
SELECT EmployeeId, StateCode INTO #temp_EmployeeHomeAddress FROM
(
	SELECT e.EmployeeId, COALESCE(StateCode,'Unknown-Location') StateCode, RANK() OVER (PARTITION BY e.EmployeeId ORDER BY p.EffectiveStart DESC) AddressIndex FROM #temp_EmployeePayPolicy e WITH(NOLOCK)
	LEFT JOIN PersonAddress p WITH(NOLOCK) ON p.PersonId=e.EmployeeId
) HomeAddresses WHERE AddressIndex=1

-- Collect work addresses
SELECT EmployeeId, StateCode INTO #temp_EmployeeWorkAddress FROM 
(
	SELECT ewa.EmployeeId, COALESCE(org.StateCode,'Unknown-Location') StateCode, IsPrimary, RANK() OVER (PARTITION BY ewa.EmployeeId ORDER BY ewa.EffectiveStart DESC) AddressIndex FROM EmployeeWorkAssignment ewa WITH(NOLOCK)
	JOIN HierarchyOrgView hov WITH(NOLOCK) ON hov.ParentOrgUnitId=ewa.OrgUnitId 
	LEFT JOIN OrgUnit org WITH(NOLOCK) ON org.orgUnitId=hov.ChildClosestAddressOrgUnitId
) WorkAddresses WHERE AddressIndex=1 AND IsPrimary=1

-- Affected employees will match joining on policy, use unknown for missing state
SELECT StateCode, COUNT(*) Employees INTO #temp_AffectedHomeStates
FROM 
(
	SELECT distinct e.employeeid, COALESCE(h.StateCode,'Unknown-Location') StateCode from #temp_EmployeePayPolicy e WITH(NOLOCK)
	JOIN EmployeeBioTemplate p WITH(NOLOCK) ON e.EmployeeID=p.EmployeeID
	LEFT JOIN #temp_EmployeeHomeAddress h WITH(NOLOCK) ON e.EmployeeId=h.EmployeeId
) t GROUP BY StateCode

-- Affected employees will match joining on policy, use unknown for missing state
SELECT StateCode, COUNT(*) Employees INTO #temp_AffectedWorkStates
FROM 
(
	SELECT distinct e.employeeid, COALESCE(h.StateCode,'Unknown-Location') StateCode from #temp_EmployeePayPolicy e WITH(NOLOCK)
	JOIN EmployeeBioTemplate p WITH(NOLOCK) ON e.EmployeeID=p.EmployeeID
	LEFT JOIN #temp_EmployeeWorkAddress h WITH(NOLOCK) ON e.EmployeeId=h.EmployeeId
) t GROUP BY StateCode

DECLARE @namespace NVARCHAR(MAX) = (SELECT TOP 1 Namespace FROM Client WHERE ClientId=(SELECT TOP 1 ClientId FROM AppUser WITH(NOLOCK) WHERE ClientId>0))

-- Use 'Unknown-ALL' to indicate customers that had all affected employees with unknown work state or all affected employees with unknown home state

select BioNameSpace, GetDate() AddedDate from (
SELECT distinct @namespace BioNameSpace,  StateCode FROM #temp_AffectedHomeStates
where statecode like 'il'
UNION
SELECT distinct @namespace,  StateCode  FROM #temp_AffectedWorkStates
where statecode like 'il'
) as x
DROP TABLE #temp_EmployeePayPolicy
DROP TABLE #temp_EmployeeHomeAddress
DROP TABLE #temp_EmployeeWorkAddress
DROP TABLE #temp_AffectedHomeStates
DROP TABLE #temp_AffectedWorkStates


"@;



#Write-Output 'The Following Control databases will be updated' | Out-File -append C:\Users\ajesudasen\RecUpdate.csv
                      





$Results = Invoke-Sqlcmd -ServerInstance $DashboardServer -Database $DashboardDatabase -Username $DashboardUser -Password $DashboardPassword -Query $ControlQuery #| Out-GridView



$Results | FOREACH-OBJECT{
       #Write-Host 'ClientDBName:'$_.ClientDBName 'ServerName:'$_.ServerName
        #Write-Host 'ServerName:'$_.ServerName
        $Global:ClientDBName=$_.ClientDBName
        $Global:ServerName=$_.ServerName
        
Write-Host 'ServerName:'$Global:ServerName 'ClientName:'$Global:ClientDBName
        
        $DatabaseConnections = Invoke-Sqlcmd -ServerInstance $Global:ServerName -Database $Global:ClientDBName -Query $DatabaseConnectionQuery 
        $DatabaseConnections | FOREACH-OBJECT {
            


			 
			$Global:BioNameSpace=$_.BioNameSpace;
			$Global:AddedDate=$_.AddedDate;
			$InsertQuery = 
			'   
			if '''+$Global:BioNameSpace+ ''' not in (select namespace from dbo.BioMetricDataClient )
			begin
				insert into dbo.BioMetricDataClient values ('''+$Global:BioNameSpace+ ''','''+ $Global:AddedDate +''')
			end
			 
			 ';

			 $INS = Invoke-Sqlcmd -ServerInstance $DashboardServer -Database $DashboardDatabase -Username $DashboardUser -Password $DashboardPassword -Query $InsertQuery 
			 
            Write-Host 'ClientDBName:'$Global:ClientDBName 'ServerName:'$Global:ServerName 'Namespace:'$_.Namespace
            #Write-Output 'ClientDbName:'$Global:ClientDBName 'AccountName:'$_.AccountName  'Username:'$_.UserName 'Password:'$_.Password | Add-Content -Path C:\Users\ajesudasen\RecUpdate.csv -

         }

      }
               
             

