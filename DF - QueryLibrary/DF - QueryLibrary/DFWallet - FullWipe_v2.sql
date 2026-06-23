/* *************************
   Full Wipe GW accounts   
   
   Remove DFID record -- Mongo (No SQL Booster) -- mongodb://HostingDBA:96cy19N913650@app105-dfid-prod-web-wallet-cosmo.mongo.cosmos.azure.com:10255/wallet?ssl=true&retryWrites=false&maxIdleTimeMS=120000&authMechanism=SCRAM-SHA-256&appName=%40app105-dfid-prod-web-wallet-cosmo%40&replicaSet=globaldb
   Remove Paycard  - Client DB
   Remove Dayforce EmployeePaymentGatewayIdentity records -- Azure SQL DB
*/
--Step 1 - Remove DFID Record
db.resource.find({"_id":"lindalligoncalves@gmail.com"})
db.resource.deleteOne({"_id":"lindalligoncalves@gmail.com"})

--Step 2 - Remove Dayforce linked records
USE sephora;
select * from employee with (nolock)
where lastname LIKE '%Frazier%'
and firstname LIKE '%Latoya%'

select * from employeepaymentgatewayidentity where employeeid = '210134'

--Remove GlobalId link in 
DECLARE @GatewayId UNIQUEIDENTIFIER = '95C30D6F-6119-4C94-A8A6-A92FF8A38DB1'

SELECT *
FROM EmployeePaymentGatewayIdentity ep
WHERE ep.GatewayGlobalId = @GatewayId

SELECT *
FROM EmployeePaycard
WHERE EmployeeId = (SELECT EmployeeId FROM EmployeePaymentGatewayIdentity WHERE GatewayGlobalId = @GatewayId)
	and ComdataAccountId = (select comdataaccountid from comdataaccount (nolock) where xrefcode = 'GATEWAY_ACCOUNT')

BEGIN TRAN
DELETE EmployeePaycard
WHERE EmployeeId = (SELECT EmployeeId FROM EmployeePaymentGatewayIdentity WHERE GatewayGlobalId = @GatewayId)
	and ComdataAccountId = (select comdataaccountid from comdataaccount (nolock) where xrefcode = 'GATEWAY_ACCOUNT')

DELETE EmployeePaymentGatewayIdentity WHERE GatewayGlobalId = @GatewayId

SELECT *
FROM EmployeePaymentGatewayIdentity ep
WHERE ep.GatewayGlobalId = @GatewayId

SELECT *
FROM EmployeePaycard
WHERE EmployeeId = (SELECT EmployeeId FROM EmployeePaymentGatewayIdentity WHERE GatewayGlobalId = @GatewayId)
	and ComdataAccountId = (select comdataaccountid from comdataaccount (nolock) where xrefcode = 'GATEWAY_ACCOUNT')

--If all is well then COMMIT, if not then ROLLBACK
--COMMIT
--ROLLBACK


--Step 3 - Remove all Gateway records
DECLARE @globalId as nvarchar(68) = '95c30d6f-6119-4c94-a8a6-a92ff8a38db1'
DECLARE @entityId as bigint = (select GUEntityId from entity where globalId = @globalId)

select * from entity where GUEntityId = @entityId;

select * from RegisteredPrograms  WHERE AccountId in (
    SELECT GUAccountId FROM Account WHERE GUEntityId = @entityId
)

select * from EFTAccount WHERE GUAccountId in (
    SELECT GUAccountId FROM Account WHERE GUEntityId = @entityId
)

select * FROM BankNicknames WHERE AccountId in (
    SELECT GUAccountId FROM Account WHERE GUEntityId = @entityId
)

select * FROM EmployerInformation WHERE AccountId in (
    SELECT GUAccountId FROM Account WHERE GUEntityId = @entityId )

select * FROM PRNInfo WHERE GUAccountId in (
    SELECT GUAccountId FROM Account WHERE GUEntityId = @entityId
)

select * from accountHistory WHERE GUEntityId = @entityId
select * FROM Account WHERE GUEntityId = @entityId
select * FROM KYCReview WHERE GUEntityId = @entityId
select * FROM EntityGovId where GUEntityId = @entityId
select * FROM EntityContactInfo where GUEntityId = @entityId
select * FROM WalletLink where GlobalId = @globalId
select * FROM ExternalErrors where GlobalId = @globalId
select * from EntityEmployerIdentityNumber where EntityId = @entityId
select * from EntityDeviceIds where GUEntityId=@entityId
select * from EntityLockedStatus where GUEntityId = @entityId
select * from WODEntityValidationStatus where GUEntityId = @entityId
select * FROM Entity where GUEntityId = @entityId


BEGIN TRANSACTION
select * from entity where GUEntityId = @entityId;

DELETE FROM RegisteredPrograms WHERE AccountId in (
    SELECT GUAccountId FROM Account WHERE GUEntityId = @entityId )

DELETE FROM EFTAccount WHERE GUAccountId in (
    SELECT GUAccountId FROM Account WHERE GUEntityId = @entityId )

DELETE FROM BankNicknames WHERE AccountId in (
    SELECT GUAccountId FROM Account WHERE GUEntityId = @entityId )

DELETE FROM EmployerInformation WHERE AccountId in (
    SELECT GUAccountId FROM Account WHERE GUEntityId = @entityId )

DELETE FROM PRNInfo WHERE GUAccountId in (
    SELECT GUAccountId FROM Account WHERE GUEntityId = @entityId )

DELETE FROM accountHistory WHERE GUEntityId = @entityId
Delete from dbo.EntityParentalConsent where GUEntityId = @entityId
DELETE FROM Account WHERE GUEntityId = @entityId
DELETE FROM KYCReview WHERE GUEntityId = @entityId
DELETE FROM EntityGovId where GUEntityId = @entityId
DELETE FROM EntityContactInfo where GUEntityId = @entityId 
DELETE FROM WalletLink where GlobalId = @globalId 
DELETE FROM ExternalErrors where GlobalId = @globalId
DELETE FROM AcceptedTermsAndConditions where EntityId=@entityId
DELETE FROM AcceptedLegal where EntityId = @entityId
DELETE FROM EntityDeviceVersion where EntityId=@entityId
Delete from EntityEmployerIdentityNumber where EntityId = @entityId
Delete from EntityDeviceIds where GUEntityId=@entityId
DELETE FROM EntityLockedStatus where GUEntityId = @entityId
DELETE from WODEntityValidationStatus where GUEntityId = @entityId
DELETE FROM Entity where GUEntityId = @entityId


select * from entity where GUEntityId = @entityId;

select * from RegisteredPrograms  WHERE AccountId in (
    SELECT GUAccountId FROM Account WHERE GUEntityId = @entityId
)

select * from EFTAccount WHERE GUAccountId in (
    SELECT GUAccountId FROM Account WHERE GUEntityId = @entityId
)

select * FROM BankNicknames WHERE AccountId in (
    SELECT GUAccountId FROM Account WHERE GUEntityId = @entityId
)

select * FROM PRNInfo WHERE GUAccountId in (
    SELECT GUAccountId FROM Account WHERE GUEntityId = @entityId
)

select * FROM Account WHERE GUEntityId = @entityId
select * FROM KYCReview WHERE GUEntityId = @entityId
select * FROM EntityGovId where GUEntityId = @entityId
select * FROM EntityContactInfo where GUEntityId = @entityId
select * FROM WalletLink where GlobalId = @globalId
select * FROM ExternalErrors where GlobalId = @globalId
select * from EntityEmployerIdentityNumber where EntityId = @entityId
select * from EntityDeviceIds where GUEntityId=@entityId
select * from EntityLockedStatus where GUEntityId = @entityId
select * from WODEntityValidationStatus where GUEntityId = @entityId
select * FROM Entity where GUEntityId = @entityId

--If all is well then COMMIT, if not then ROLLBACK
--COMMIT
--ROLLBACK

