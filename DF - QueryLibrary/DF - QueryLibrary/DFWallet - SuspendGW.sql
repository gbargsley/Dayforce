/* ********************

	Suspend GW account only

	Need to know user Email to Identify the record to suspend

   ******************* */

--Step 1 - get user GUAccountId, review and verify which record to suspend
declare @GUAccountId bigint 
SELECT @GUAccountId=a.GUAccountId FROM [dbo].[Account] a join EntityContactInfo ec on a.GUEntityId = ec.GUEntityId
	where ec.Email = '<email address>' and BankLinkId = 5 and IsSuspended = 0 -- only to DF banklink;  10/07/2024: Added IsSuspended condition

SELECT ec.GUEntityId, a.GUAccountId, a.BankLinkId, a.ExternalAccountNumber, a.EmployerIdentifier, a.IsSuspended 
	FROM [dbo].[Account] a join EntityContactInfo ec on a.GUEntityId = ec.GUEntityId
	where GUAccountId = @GUAccountId


--Step 2 - Suspend Gateway account
--         Run as set of queried to see before and after
BEGIN TRAN
SELECT ec.GUEntityId, a.GUAccountId, a.BankLinkId, a.ExternalAccountNumber, a.EmployerIdentifier, a.IsSuspended FROM [dbo].[Account] a
	join EntityContactInfo ec on a.GUEntityId = ec.GUEntityId
	where GUAccountId = @GUAccountId


Update Account set IsSuspended = 1 where GUAccountId = @GUAccountId -- has employeridentified and externalaccountnumber not like 'ch_%'

SELECT ec.GUEntityId, a.GUAccountId, a.BankLinkId, a.ExternalAccountNumber, a.EmployerIdentifier, a.IsSuspended FROM [dbo].[Account] a
	join EntityContactInfo ec on a.GUEntityId = ec.GUEntityId
	where GUAccountId = @GUAccountId


--Step 3 - Before should show records, after should not
--         If all is well then COMMIT, if not then ROLLBACK
-- COMMIT
-- ROLLBACK
