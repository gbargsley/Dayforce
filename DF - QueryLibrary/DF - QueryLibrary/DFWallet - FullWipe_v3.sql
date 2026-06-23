/* *************************
   Full Wipe GW accounts   
   
   Remove DFID record -- Mongo (No SQL Booster) -- mongodb://HostingDBA:96cy19N913650@app105-dfid-prod-web-wallet-cosmo.mongo.cosmos.azure.com:10255/wallet?ssl=true&retryWrites=false&maxIdleTimeMS=120000&authMechanism=SCRAM-SHA-256&appName=%40app105-dfid-prod-web-wallet-cosmo%40&replicaSet=globaldb
   Remove Paycard  - Client DB
   Remove Dayforce EmployeePaymentGatewayIdentity records -- Azure SQL DB
*/
--Step 1 - Remove DFID Record
db.resource.find({"_id":"bradw1982@hotmail.co.uk"})
db.resource.deleteOne({"_id":"bradw1982@hotmail.co.uk"})

--Step 2 - Remove Dayforce linked records
USE elioruk;
select * from employee with (nolock)
where 
    lastname LIKE '%Williams%'
    and firstname LIKE '%Bradley%'
    --employeeid = '147778'

select * from employeepaymentgatewayidentity where employeeid = '143490'

--Remove GlobalId link in 
DECLARE @GatewayId UNIQUEIDENTIFIER = '2DEE08AF-6251-47D7-9CF7-47F20F1CDEAD'

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
DECLARE @globalId as nvarchar(68) = '2dee08af-6251-47d7-9cf7-47f20f1cdead'
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
select * from KYCAuditLog where KYCReviewId in (select KYCReviewId FROM KYCReview WHERE GUEntityId = @entityId)
select * FROM KYCReview WHERE GUEntityId = @entityId
select * FROM EntityGovId where GUEntityId = @entityId
select * FROM EntityContactInfo where GUEntityId = @entityId
select * FROM WalletLink where GlobalId = @globalId
select * FROM ExternalErrors where GlobalId = @globalId
select * from EntityEmployerIdentityNumber where EntityId = @entityId
select * from EntityDeviceIds where GUEntityId=@entityId
select * from EntityLockedStatus where GUEntityId = @entityId
select * from WODEntityValidationStatus where GUEntityId = @entityId
select * from DTBAcceptedLegal where EntityId=@entityId
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
DELETE from KYCAuditLog where KYCReviewId in (select KYCReviewId FROM KYCReview WHERE GUEntityId = @entityId)
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
DELETE FROM DTBAcceptedLegal where EntityId=@entityId
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
select * from KYCAuditLog where KYCReviewId in (select KYCReviewId FROM KYCReview WHERE GUEntityId = @entityId)
select * FROM KYCReview WHERE GUEntityId = @entityId
select * FROM EntityGovId where GUEntityId = @entityId
select * FROM EntityContactInfo where GUEntityId = @entityId
select * FROM WalletLink where GlobalId = @globalId
select * FROM ExternalErrors where GlobalId = @globalId
select * from EntityEmployerIdentityNumber where EntityId = @entityId
select * from EntityDeviceIds where GUEntityId=@entityId
select * from EntityLockedStatus where GUEntityId = @entityId
select * from WODEntityValidationStatus where GUEntityId = @entityId
select * from DTBAcceptedLegal where EntityId=@entityId
select * FROM Entity where GUEntityId = @entityId

--If all is well then COMMIT, if not then ROLLBACK
--COMMIT
--ROLLBACK
