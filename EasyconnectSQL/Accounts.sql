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
-- select * from #databases;

------------------------------------------------------
-- ---- SELECT ALL ACCOUNTS FROM MS SQL SERVER ---- --
------------------------------------------------------
-- SELECT ALL SERVER ACCOUNTS
set nocount on;

select
  [name] as accountname,
  [is_disabled] as accountstatus,
	type,
  case when [type] = 'S' then
			 case when is_disabled = 0 then 12
			      else 10
			 end
	   when [type] = 'C' then
			 case when is_disabled = 0 then 12
			      else 10
			 end	    
	     when [type] = 'R' then 32
       else 0
  end as accounttype,
  [name] as accountidname,
  1 as accountidtyp,
  '@@self' as accountidprovider,
  is_fixed_role,
  default_database_name,
  default_language_name
into #temp_result
from [master].[sys].[server_principals] 
where [type] in ('R', 'S', 'C') -- and name not like  '##%';

-- select * from master.sys.server_principals
-- select * from #temp_result

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
		if @state > 0 
		  goto skip_db;

		set @dynamicsql = N'INSERT INTO #temp_result
												SELECT
												[name] + ''@' + @database_name + ''' AS accountName,
												0 AS accountStatus,
												type,
												CASE WHEN [type] = ''S'' THEN 12
														 WHEN [type] = ''C'' THEN 12
														 WHEN [type] = ''R'' THEN 32
														 ELSE 0
												END AS accountType,
												[name] + ''@' + @database_name + ''' AS accountIdName,
												1 AS accountIdTyp,
												''@@self'' AS accountIdProvider,
												is_fixed_role,
												''' + @database_name + ''',
												default_language_name
											FROM [' + @database_name + '].[sys].[database_principals]
											WHERE [type] in (''R'',  ''S'', ''C''); -- AND [name] NOT LIKE  ''##%'';
										';
		execute sp_executesql @dynamicsql;
		skip_db:
		set @loopcounter  = @loopcounter  + 1;	
	end;

-- select * from smi_sysdba.sys.database_principals

SELECT
	accountName,
	accountStatus,
	case when type = 'S' then
				 case when accountStatus = 0 then 12
						else 10
				 end				
		   when type = 'C' then
				 case when accountStatus = 0 then 12
						else 10
				 end										
			 when type = 'R' then 32
	     else 0
	END as accountType,
	accountIdName,
	accountIdTyp,
	accountIdProvider,
	is_fixed_role,
	default_database_name,
	default_language_name
into #result
FROM #temp_result;


-- SELECT RESULT

select * from #result;
--select * from #result;


-- CLEANUP

drop table #databases;
drop table #result;
drop table #temp_result;
