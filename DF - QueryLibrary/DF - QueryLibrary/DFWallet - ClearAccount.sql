select * from RegisteredPrograms where AccountId = 5290946057052237094
select * from Account where GUAccountId = 5290946057052237094


BEGIN TRAN
Delete from RegisteredPrograms where AccountId = 5290946057052237094
Delete from Account where GUAccountId = 5290946057052237094


select * from RegisteredPrograms where AccountId = 5290946057052237094
select * from Account where GUAccountId = 5290946057052237094

-- ROLLBACK
-- COMMIT