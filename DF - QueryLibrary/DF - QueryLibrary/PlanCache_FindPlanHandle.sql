SELECT
	db_name(st.dbid)
	, st.text
	, cp.plan_handle
	, cp.usecounts
	, cp.size_in_bytes
	, cp.cacheobjtype
	, cp.objtype
	, qp.query_plan
	, 'DBCC FREEPROCCACHE (0x' + CONVERT( VARCHAR(max), cp.plan_handle, 2) + ');'
FROM sys.dm_exec_cached_plans cp
	CROSS APPLY sys.dm_exec_sql_text (cp.plan_handle) st
	CROSS APPLY sys.dm_exec_query_plan (cp.plan_handle) qp
WHERE text LIKE '%select 
                o.OrgUnitId, coalesce(oc.ShortName, o.ShortName) as Name, op.ParentOrgUnitId as ParentOrgId, o.OrgLevelId, o.DepartmentId, o.ZoneId,
                o.ClientId, coalesce(o.StartDOW, c.FirstDayOfWeek) as OrgStartDOW, op.OrgUnitParentLeft, o.XRefCode, 0 as JobId, 0 as DeptJobId, o.PhysicalLocation
            from
            (
	            -- Get hierarchy (may or may not stop at store)
	            select distinct hov.ChildOrgUnitId as OrgUnitId
	            from UserOrgUnitList ol with(nolock), HierarchyOrgView hov with(nolock)
	            where ol.UserId = @UserId
	            and ol.OrgUnitId = hov.ParentOrgUnitId 
	            and @AccessDate between ol.EffectiveStart and coalesce(ol.EffectiveEnd, ''2050-01-01'')
	            and @PeriodStart between hov.ChildEffectiveStart and coalesce(hov.ChildEffectiveEnd, ''2050-01-01'')
				and (hov.ParentOrgLevelId <> 999 or (hov.ParentOrgUnitId = hov.ChildOrgUnitId)) and (hov.ChildOrgLevelId <> 997)
				%'
	AND DB_NAME(st.dbid) = 'tbg'
ORDER BY cp.usecounts DESC




DBCC FREEPROCCACHE (0x06002700B14ADF2BD01C839E2402000001000000000000000000000000000000000000000000000000000000);
DBCC FREEPROCCACHE (0x06002700B14ADF2BD07E01BD1802000001000000000000000000000000000000000000000000000000000000);



DBCC FREEPROCCACHE (0x06000B00468B302680B6C3C9A101000001000000000000000000000000000000000000000000000000000000);