go
 
--validate 
drop table if exists #sanEetable 
CREATE TABLE #sanEetable(
	servername varchar(100) NULL, 
	DBName varchar(1000) NULL,
	PRPayrollTaxFormDefFieldExportTypeId int
	)
exec sp_msforeachdb 
'use [?]
 
IF   (select count(1) from sys.tables where name in (''PRPayrollTaxFormDefField'',''dfdatabaseidentification''))=2
begin
if (select cast(substring(databaseversion,1,2)as int)  from dfdatabaseidentification(nolock))  >= 71
begin
DECLARE @W2DefId int = 
(
    SELECT def.PRPayrollTaxFormDefId
    FROM PRPayrollTaxFormDef def (nolock)
    inner join PRPayrollTaxForm t (nolock) on t.PRPayrollTaxFormId = def.PRPayrollTaxFormId
    where def.EffectiveStart = ''2025-01-01''
    and t.CodeName = ''W2'')
DECLARE @PAGE_PRPayrollTaxFormDefFieldExportTypeId int = (select PRPayrollTaxFormDefFieldExportTypeId from PRPayrollTaxFormDefFieldExportType (nolock) where CodeName=''PAGE'')
insert #sanEetable
select  @@Servername, DB_Name(db_id()),PRPayrollTaxFormDefFieldExportTypeId
from PRPayrollTaxFormDefField (nolock)
WHERE PRPayrollTaxFormDefId = @W2DefId
AND CodeName IN (''Box_14_CTPL'',''Box_14_CO_FAMLI'', ''Box_14_Qual_Tips'', ''Box_14_Qual_OT'',''Box_12_II'')
and PRPayrollTaxFormDefFieldExportTypeId =1end
end'
select * from #sanEetable