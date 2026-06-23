/* ********************

	Suspend closed Green Dot bank account

	Need to know user Email to Identify the record to suspend

   ******************* */

--Step 1 - get user GUAccountId, review and verify which record to suspend

declare @GUAccountId bigint 
SELECT @GUAccountId=a.GUAccountId FROM [dbo].[Account] a join EntityContactInfo ec on a.GUEntityId = ec.GUEntityId
	where ec.Email = 'codyross1000@gmail.com' and BankLinkId = 8 and IsSuspended = 0 -- only to DF banklink



--Step 2 - Suspend Green Dot bank account
--         Run as set of queried to see before and after
BEGIN TRAN
SELECT ec.GUEntityId, a.GUAccountId, a.BankLinkId, a.ExternalAccountNumber, a.EmployerIdentifier, a.IsSuspended FROM [dbo].[Account] a
	join EntityContactInfo ec on a.GUEntityId = ec.GUEntityId
	where GUAccountId = @GUAccountId


Update Account set IsSuspended = 1 where GUAccountId = @GUAccountId

SELECT ec.GUEntityId, a.GUAccountId, a.BankLinkId, a.ExternalAccountNumber, a.EmployerIdentifier, a.IsSuspended FROM [dbo].[Account] a
	join EntityContactInfo ec on a.GUEntityId = ec.GUEntityId
	where GUAccountId = @GUAccountId


--Step 3 - Before should show IsSuspended = 0, after should show IsSuspended = 1
--         If all is well then COMMIT, if not then ROLLBACK
-- COMMIT
-- ROLLBACK
