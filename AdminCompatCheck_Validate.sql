SELECT ServerInstance, Error, *
  FROM [ServerInventory].[dbo].[AdminDBCompaCheck]
  --where error is not null
  where batchid = '8A988673-3000-4A8F-91C5-6BC2C3C474FD'
	and error is not null

update [ServerInventory].[dbo].[AdminDBCompaCheck]
set fixmessage = 'Checked by GLB and either offline or still on SQL 2019'
where error is not null
