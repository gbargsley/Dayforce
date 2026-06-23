-- FTRegistry
select * from deviceidblacklist where DeviceId = '9990d3b1f296c0e5b9cf7b4ab2b9f91c7e185948e0acf7bf3fe7d988ce6b1677'

BEGIN TRAN

Update DeviceIdBlacklist set IsValidDevice = 1 where DeviceId = '9990d3b1f296c0e5b9cf7b4ab2b9f91c7e185948e0acf7bf3fe7d988ce6b1677'


select * from deviceidblacklist where DeviceId = '9990d3b1f296c0e5b9cf7b4ab2b9f91c7e185948e0acf7bf3fe7d988ce6b1677'

-- COMMIT