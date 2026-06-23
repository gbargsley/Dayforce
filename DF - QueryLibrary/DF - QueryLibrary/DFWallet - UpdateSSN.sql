DECLARE @EntityId as bigint = (select GUEntityId from EntityContactInfo where Email = 'rlauer0702@gmail.com');

select * from Entity where GUEntityId = @EntityId;

BEGIN TRAN

Update Entity set GovernmentIdentifier = '542637698' where GUEntityId = @EntityId 
Update EntityGovId set GovernmentIdValue = '542637698' where GUEntityId = @EntityId

select * from Entity where GUEntityId = @EntityId;

-- ROLLBACK
-- COMMIT