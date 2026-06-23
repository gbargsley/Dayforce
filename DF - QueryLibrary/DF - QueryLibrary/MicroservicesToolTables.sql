-- AZG1DBASQL011
-- MicroServicesTool

Select * from MicroServices where abbreviation='dapdl'

Select * from MicroServicesLogin where IsServiceLogin=0 and MicroServicesId in (32)

Select * from MicroServicespod where MicroServicesLoginid in (404,405)

Select * from MicroServicesLoginSchemaRoles where MicroServicesLoginid in (404,405)


--delete from MicroServicespod where microservicespodid in (714, 715)


INSERT INTO MicroServices (MicroService, SchemaName, Released, Module, Abbreviation, LastModifiedTimestamp, LastModifiedUser)
VALUES
(
	'dapdatalakeapi'
	, 'dapdl'
	, 1
	, 'DataPlatform'
	, 'dapdl'
	, getdate()
	, 'CUSTADDS\PV2C7B6'
)