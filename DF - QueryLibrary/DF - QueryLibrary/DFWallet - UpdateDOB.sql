DECLARE @EntityId as bigint = (select GUEntityId from FTRegistry..EntityContactInfo where Email = 'k.holmes89@yahoo.com');

select * from FTRegistry..Entity where GUEntityId = @EntityId;

BEGIN TRAN

update FTRegistry..Entity set DateOfBirth = '1955-10-04 00:00:00.000' where GUEntityId = @EntityID

select * from FTRegistry..Entity where GUEntityId = @EntityId;

-- ROLLBACK
-- COMMIT