declare @maxid int; 
declare @loopcounter int; 
declare @database_id int;
declare @user_access nchar(10);
declare @user_access_desc nchar(50);
declare @state tinyint;
declare @state_desc nchar(50);
declare @dynamicsql nvarchar(4000);
declare @database_name varchar(255); 

declare @debug int;
declare @result_output int;


---------------------------------------------------
-- ---  put all databases info in #databases --- --
---------------------------------------------------
-- databases --
select identity(int, 1, 1) as id, name, database_id, user_access, user_access_desc, state, state_desc
into #databases
from [master].[sys].[databases] where name = 'master' or name = 'msdb' or name = 'model' or database_id > 4;

---------------------------------------------------------------
-- ---- SELECT ALL ACCOUNT RELATIONS FROM MS SQL SERVER ---- --
---------------------------------------------------------------

EXEC('
  if exists
  (
    select * from sysobjects where id = object_id(N''sidtostring'') 
    and xtype in (N''fn'', N''if'', N''tf'')
  )
    drop function sidtostring
');

EXEC('
  create function sidtostring(@varbinarysid varbinary(85))
  returns nvarchar(200)
  with execute as caller  
  as  
  begin
    declare @stringsid nvarchar(200)
    declare @len as int
    set @len = len(@varbinarysid)
    declare @loop as int
    select @stringsid = ''S-''
    select @stringsid = @stringsid + convert(varchar, convert(int, convert(varbinary, substring(@varbinarysid, 1, 1))))
    select @stringsid = @stringsid + ''-''
    select @stringsid = @stringsid + convert(varchar, convert(int, convert(varbinary, substring(@varbinarysid, 3, 6))))
    set @loop = 9
    while @loop < @len
    begin
        declare @temp_var binary (4)
        select @temp_var = substring(@varbinarysid, @loop, 4)
        select @stringsid = @stringsid + ''-'' + convert(varchar, convert(bigint, convert(varbinary, reverse(convert(varbinary, @temp_var)))))
        set @loop = @loop + 4
    end
    return (@stringsid)
  end;
');


select
  case when pm.type = 'S' then pm.name
       when pm.type = 'R' then pm.name
			 when pm.type = 'C' then pm.name
       when pm.type = 'U' then dbo.sidtostring(pm.sid)
       when pm.type = 'G' then dbo.sidtostring(pm.sid)
       else ''
  end as memberaccountidname,
  case when pm.[type] = 'S' then 1
       when pm.[type] = 'R' then 1
			 when pm.[type] = 'C' then 1
       when pm.[type] = 'U' then 3
       when pm.[type] = 'G' then 3
       else 0
  end as memberaccountidtype,
  case when pm.[type] = 'S' then '@@self'
       when pm.[type] = 'R' then '@@self'
			 when pm.[type] = 'C' then '@@self'
       when pm.[type] = 'U' then substring(suser_sname(pm.sid), 0, charindex('\', suser_sname(pm.sid)))
       when pm.[type] = 'G' then substring(suser_sname(pm.sid), 0, charindex('\', suser_sname(pm.sid)))
       else ''
  end as memberaccountidprovider,
  pr.name as groupaccountidname,
  1 as groupaccountidtype,
  '@@self' as groupaccountidprovider
into #result
from [master].[sys].[server_role_members] as m
inner join [master].[sys].[server_principals] as pr
on m.role_principal_id = pr.principal_id --and pr.name not like  '##%'
inner join [master].[sys].[server_principals] as pm
on m.member_principal_id = pm.principal_id and pm.[type] in ('S', 'R', 'C', 'U', 'G') --and pm.name not like  '##%'

insert into #result
select 
    case when [type] = 'S' then name
         when [type] = 'U' then dbo.sidtostring(sid)
         when [type] = 'G' then dbo.sidtostring(sid)
         else ''
    end as memberaccountidname,
    case when [type] = 'S' then 1
         when [type] = 'U' then 3
         when [type] = 'G' then 3
         else 0
    end as memberaccountidtype,
    case when [type] = 'S' then '@@self'
         when [type] = 'U' then substring(suser_sname(sid), 0, charindex('\', suser_sname(sid)))
         when [type] = 'G' then substring(suser_sname(sid), 0, charindex('\', suser_sname(sid)))
         else ''
    end as memberaccountidprovider,
    'public' as groupaccountidname,
    1 as groupaccountidtype,
    '@@self' as groupaccountidprovider
  from [master].[sys].[server_principals]
  where [type] in ('S', 'U', 'G') -- and name not like  '##%'



set @loopcounter = 1;
-- @maxid zuweisen
select @maxid = max(id) from #databases;
------------------------------------------
-- --- select all database accounts --- --
------------------------------------------
while(@loopcounter <= @maxid)
	begin
		select	@database_name = name, 
						@state = state, 
						@state_desc = state_desc
	  from #databases where id = @loopcounter;
		print @database_name;
		if @state > 0 
		  goto skip_db;
			
		set @dynamicsql = N'INSERT INTO #result
												SELECT
													CASE WHEN PM.[type] = ''S'' THEN PM.name + ''@'' + ''' + @database_name + '''
															 WHEN PM.[type] = ''R'' THEN PM.name + ''@'' + ''' + @database_name + '''
															 WHEN PM.[type] = ''U'' THEN dbo.sidToString(PM.sid)
															 WHEN PM.[type] = ''G'' THEN dbo.sidToString(PM.sid)
															 ELSE ''''
													END AS memberAccountIdName,
													CASE WHEN PM.[type] = ''S'' THEN 1
															 WHEN PM.[type] = ''R'' THEN 1
															 WHEN PM.[type] = ''U'' THEN 3
															 WHEN PM.[type] = ''G'' THEN 3
															 ELSE 0
													END AS memberAccountIdType,
													CASE WHEN PM.[type] = ''S'' THEN ''@@self''
															 WHEN PM.[type] = ''R'' THEN ''@@self''
															 WHEN PM.[type] = ''U'' THEN SUBSTRING(SUSER_SNAME(PM.sid), 0, CHARINDEX(''\'', SUSER_SNAME(PM.sid)))
															 WHEN PM.[type] = ''G'' THEN SUBSTRING(SUSER_SNAME(PM.sid), 0, CHARINDEX(''\'', SUSER_SNAME(PM.sid)))
															 ELSE ''''
													END AS memberAccountIdProvider,
    
													PR.name + ''@'' + ''' + @database_name + ''' AS groupAccountIdName,
													1 AS groupAccountIdType,
													''@@self'' AS groupAccountIdProvider
												FROM [' + @database_name + '].[sys].[database_role_members] AS M
													INNER JOIN [' + @database_name + '].[sys].[database_principals] AS PR
												ON M.role_principal_id = PR.principal_id AND PR.name NOT LIKE  ''##%''
													INNER JOIN [' + @database_name + '].[sys].[database_principals] AS PM
												ON M.member_principal_id = PM.principal_id AND PM.[type] IN (''S'', ''R'', ''U'', ''G''); -- AND PM.name NOT LIKE  ''##%''
											';
		execute sp_executesql @dynamicsql;
		skip_db:
		set @loopcounter  = @loopcounter  + 1;	
	end;


-- DECLARE @database_name NVARCHAR(200), @database_id INT;
--DECLARE database_cursor CURSOR FOR
--SELECT name, database_id FROM [master].[sys].[databases];

--OPEN database_cursor

--FETCH NEXT FROM database_cursor INTO @database_name, @database_id

--WHILE @@FETCH_STATUS = 0 BEGIN
--  print @database_name;
--  set @dynamicsql = N'INSERT INTO #result
--											SELECT
--												CASE WHEN PM.[type] = ''S'' THEN PM.name + ''@'' + ''' + @database_name + '''
--														 WHEN PM.[type] = ''R'' THEN PM.name + ''@'' + ''' + @database_name + '''
--														 WHEN PM.[type] = ''U'' THEN dbo.sidToString(PM.sid)
--														 WHEN PM.[type] = ''G'' THEN dbo.sidToString(PM.sid)
--														 ELSE ''''
--												END AS memberAccountIdName,
--												CASE WHEN PM.[type] = ''S'' THEN 1
--														 WHEN PM.[type] = ''R'' THEN 1
--														 WHEN PM.[type] = ''U'' THEN 3
--														 WHEN PM.[type] = ''G'' THEN 3
--														 ELSE 0
--												END AS memberAccountIdType,
--												CASE WHEN PM.[type] = ''S'' THEN ''@@self''
--														 WHEN PM.[type] = ''R'' THEN ''@@self''
--														 WHEN PM.[type] = ''U'' THEN SUBSTRING(SUSER_SNAME(PM.sid), 0, CHARINDEX(''\'', SUSER_SNAME(PM.sid)))
--														 WHEN PM.[type] = ''G'' THEN SUBSTRING(SUSER_SNAME(PM.sid), 0, CHARINDEX(''\'', SUSER_SNAME(PM.sid)))
--														 ELSE ''''
--												END AS memberAccountIdProvider,
    
--												PR.name + ''@'' + ''' + @database_name + ''' AS groupAccountIdName,
--												1 AS groupAccountIdType,
--												''@@self'' AS groupAccountIdProvider
--											FROM [' + @database_name + '].[sys].[database_role_members] AS M
--												INNER JOIN [' + @database_name + '].[sys].[database_principals] AS PR
--											ON M.role_principal_id = PR.principal_id -- AND PR.name NOT LIKE  ''##%''
--												INNER JOIN [' + @database_name + '].[sys].[database_principals] AS PM
--											ON M.member_principal_id = PM.principal_id AND PM.[type] IN (''S'', ''R'', ''U'', ''G''); -- AND PM.name NOT LIKE  ''##%''
--										';
--  FETCH NEXT FROM database_cursor INTO @database_name, @database_id
--END

--CLOSE database_cursor;

--DEALLOCATE database_cursor;

-- SELECT RESULT

SELECT * FROM #result
ORDER BY memberAccountIdName;

-- CLEANUP

drop table #databases;
drop table #result;
drop function sidtostring;
