/* **********************************
   Create Account Bank record in Gateway
   Need to make sure BankLinkId is correct for US or CAN
   Need to randomly create BIGINT GUAccountId and make sure is it not being used
   ********************************** */
--Step 1 - verify user has Dayforce 3001 account and no active bank account record with known GlobalId
select * from account a with (nolock)
join Entity e with (nolock) on e.GUEntityId = a.GUEntityId
join EntityContactInfo ec with (nolock) on e.GUEntityId = ec.GUEntityId
where globalId = 'a8ecfc1e-cb3b-42ce-a30e-0622a7bf3fc2'

--Step 2 - verify bigint is not in use
select * from account where GUAccountId = (select max(GUAccountid)+1 from account (nolock))
select * from registeredprograms where registeredprogramsId = (select max(registeredprogramsId)+1 from registeredprograms (nolock))

------------start transaction block-------------------------

--Step 3 - insert record and verify it was inserted correctly
BEGIN TRAN 

DECLARE @EntityId as bigint = (select GUEntityId from entity where globalId = 'a8ecfc1e-cb3b-42ce-a30e-0622a7bf3fc2');
DECLARE @GUAccountid as bigint = (select max(GUAccountid)+1 from account (nolock)) 


--IMPORTANT NOTE : PLEASE REPLACE '<KNOWN BANK LINK ID>' WITH 2 FOR CBKC BANK ACCOUNT, 6 FOR CANADA BANK ACCOUNT, 8 FOR GREEN DOT BANK ACCOUNT.
INSERT INTO Account values (@GUAccountid, @EntityId, '8', 1001, 'b55942a5-2a6c-464d-88a3-ae7f0e4bfec1', 0, NULL, '', NULL, NULL, '2020-01-01', NULL, 0, getdate(), NULL,NULL) 

IF NOT EXISTS (select 1 from KYCReview ky
inner join Entity e on e.GUEntityId = ky.GUEntityId
where GlobalId = 'a8ecfc1e-cb3b-42ce-a30e-0622a7bf3fc2' ) 

BEGIN 
--IF KYCREVIEWSTATUS IS NULL OR EMPTY PLEASE UPDATE COLUMN TO INCLUDE THE KYC STATUS OF THE USER. (ExternalEntityId = 1011 for Green Dot, 1006 CAN, 1010 UK[different DB])
INSERT INTO [dbo].[KYCReview] ([KYCReviewId],[KYCTransactionId] ,[FailureReason],[CreatedTime] ,[UpdatedTime] ,[KYCReviewStatus],[GUEntityId] ,[ExternalEntityId])     
VALUES  (newID(),''  ,''  ,getdate() ,getdate()  ,'Success' ,'120247', '1011')
 
END 


IF NOT EXISTS (select 1 from registeredprograms
inner join account on GUAccountID = AccountID
where GUEntityID = @EntityId and externalentityprogramname = 'gpr') 

BEGIN

delete from registeredprograms where AccountID = @GUAccountid and externalentityprogramname = '51711'

--PROGRAM NAME WILL BE PROVIDED AND WILL BE ONE OF THREE OPTIONS: 'dda', 'gpr', or 'InstantIssue'
insert into registeredprograms
select (select max(registeredprogramsid)+1 from registeredprograms (nolock)),@GUAccountid,'gpr',getdate()

END

--Step 4 - if all is well then COMMIT, if not then ROLLBACK

--verify record was inserted correctly
select * from Account where GUAccountId = (select max(GUAccountid) from account (nolock)) 
select * from [dbo].[KYCReview] (nolock) WHERE GUEntityID = '120247'
select * from registeredprograms where AccountId = (select max(GUAccountid) from account (nolock))
--COMMIT TRAN
--ROLLBACK TRAN