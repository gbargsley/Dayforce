/* *************************
   Dayforce account linked but nothing in Gateway
   Need to know DF Server and Namespace
   Remove Dayforce EmployeePaymentGatewayIdentity records
*/
--Step 1 - used to verify correct user and get EmployeeID from DF Database
select * from employee with (nolock)
where lastname = '<lastname>'
and firstname = '<firstname>'

--Step 2 - used to verify linked record in employeepaymentgatewayidentity table and get GatewayGlobalId for employeeid from above
select * from employeepaymentgatewayidentity where employeeid = <employeeid from above>

--Step 3 - run as complete set to be able to compare before and after values
--         if the wipe worked then after values should show no records
--Remove GlobalId link in 
DECLARE @GatewayId UNIQUEIDENTIFIER = '<gatewayglobalid from above>'

SELECT *
FROM EmployeePaymentGatewayIdentity ep
WHERE ep.GatewayGlobalId = @GatewayId

SELECT *
FROM EmployeePaycard
WHERE EmployeeId = (SELECT EmployeeId FROM EmployeePaymentGatewayIdentity WHERE GatewayGlobalId = @GatewayId)
	--and ComdataAccountId = 2
	and ComdataAccountId = (select comdataaccountid from comdataaccount (nolock) where xrefcode = 'GATEWAY_ACCOUNT')
	and (EffectiveEnd is null or EffectiveEnd> GetDate()) -- only end-date the current valid card

BEGIN TRAN
UPDATE EmployeePaycard
SET EffectiveEnd = CURRENT_TIMESTAMP
WHERE EmployeeId = (SELECT EmployeeId FROM EmployeePaymentGatewayIdentity WHERE GatewayGlobalId = @GatewayId)
	--and ComdataAccountId = 2
	and ComdataAccountId = (select comdataaccountid from comdataaccount (nolock) where xrefcode = 'GATEWAY_ACCOUNT')
	and (EffectiveEnd is null or EffectiveEnd> GetDate()) -- only end-date the current valid card

DELETE EmployeePaymentGatewayIdentity WHERE GatewayGlobalId = @GatewayId

SELECT *
FROM EmployeePaymentGatewayIdentity ep
WHERE ep.GatewayGlobalId = @GatewayId

SELECT *
FROM EmployeePaycard
WHERE EmployeeId = (SELECT EmployeeId FROM EmployeePaymentGatewayIdentity WHERE GatewayGlobalId = @GatewayId)

--Step 4 - If all is well then COMMIT.  If there are issues then ROLLBACK
--COMMIT
--ROLLBACK
