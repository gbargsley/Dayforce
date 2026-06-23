-- Server: AN1PRDDFCMON002
-- Query 1 --
SELECT TOP 10 * 
FROM [admindb]..[clientdbconfiginfo] WITH (NOLOCK)
WHERE [namespace] = 'apjdemocontrol'
-- Get ControlDBServername and controlDBName columns values for next query

SELECT TOP 10 * 
FROM [admindb]..[clientdbconfiginfo] WITH (NOLOCK)
WHERE [controlDBName] = 'apjdemocontrol'

--server azg1dbasql011
use DBAInternalDataAccess
declare @DatabaseName varchar(500) ='%uzsup252%'
select * from [DBAInternalDataAccess].[dbo].[Vw_ClientDBInfo_PreProd]  where ControlDBName like @DatabaseName and cast(CollectedTimeStamp as date) =cast(getdate() as Date)  order by CollectedTimeStamp desc


-- Server from ControlDBServername from query 1
-- Input conrolDBName from query 1
SELECT TOP 10 * 
FROM [PetcoControl].[dbo].[DatabaseConnection] WITH (NOLOCK)
WHERE [name] = 'petco'
