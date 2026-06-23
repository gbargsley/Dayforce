DECLARE @EntityId as bigint = (select GUEntityId from EntityContactInfo where Email ='letitbe3127@hotmail.com');
select * from Entity where GUEntityId = @EntityId;
--select * from Entity where GUEntityId = 1309063

begin tran

Update Entity set LastName = 'Sikes Jr' where GUEntityId = @EntityId

select * from Entity where GUEntityId = @EntityId

-- Commit
-- Rollback
