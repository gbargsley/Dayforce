DECLARE @EntityId as bigint = (select GUEntityId from EntityContactInfo (nolock) where Email ='lege.rousseau@greatexpressions.com');

select * from Entity where GUEntityId = @EntityId
begin tran

--update entity set middlename = 'Angea', FirstName = 'Rickea' where GUEntityId = @EntityId
update entity set middlename = 'R', FirstName = 'Rickea' where GUEntityId = @EntityId


select * from Entity where GUEntityId = @EntityId

-- Commit
-- Rollback
select top 10 * from EntityContactInfo where email like '%jaeu%'

select top 10 * from entity where middlename = 'R.' and LastName = 'Rousseau' 