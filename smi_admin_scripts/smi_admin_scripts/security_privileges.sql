declare @maxid int;
declare @debug int = 0; -- 1 = debug on
declare @loopcounter int; 
declare @database_id int;
declare @user_access nchar(10);
declare @user_access_desc nchar(50);
declare @state nchar(10);
declare @state_desc nchar(50);
declare @collation varchar(100);
declare @dynamicsql nvarchar(4000);
declare @database_name varchar(255); 
declare @exec_sp nvarchar(max);
declare @skip_user_dbs int = 0; -- 1 = skip
declare @skip_system_dbs int = 1; -- 1 = skip

set nocount on;
-- set statistics io on;

if exists (select * from sysobjects where id = object_id(N'sidtostring') and xtype in (N'fn', N'if', N'tf'))
  drop function sidtostring;

EXEC('
  CREATE FUNCTION sidToString(@varBinarySID VARBINARY(85))
  RETURNS NVARCHAR(200)
  WITH EXECUTE AS CALLER  
  AS  
  BEGIN
    DECLARE @StringSID NVARCHAR(200)
    DECLARE @len AS INT
    SET @len = LEN(@varBinarySID)
    DECLARE @loop AS INT
    SELECT @StringSID = ''S-''
    SELECT @StringSID = @StringSID + CONVERT(VARCHAR, CONVERT(INT, CONVERT(VARBINARY, SUBSTRING(@varBinarySID, 1, 1))))
    SELECT @StringSID = @StringSID + ''-''
    SELECT @StringSID = @StringSID + CONVERT(VARCHAR, CONVERT(INT, CONVERT(VARBINARY, SUBSTRING(@varBinarySID, 3, 6))))
    SET @loop = 9
    WHILE @loop < @len
    BEGIN
        DECLARE @temp_var BINARY (4)
        SELECT @temp_var = SUBSTRING(@varBinarySID, @loop, 4)
        SELECT @StringSID = @StringSID + ''-'' + CONVERT(VARCHAR, CONVERT(BIGINT, CONVERT(VARBINARY, REVERSE(CONVERT(VARBINARY, @temp_var)))))
        SET @loop = @loop + 4
    END
    RETURN (@StringSID)
  END;
');


set @loopcounter = 1;

-- databases on this server, name, state, user access
-- system databases
select identity(int, 1, 1) as id, name, database_id, user_access, user_access_desc, state, state_desc
into #system_databases
from [master].[sys].[databases] where database_id < 5;

-- user databases
select identity(int, 1, 1) as id, name, database_id, user_access, user_access_desc, state, state_desc
into #user_databases
from [master].[sys].[databases] where database_id > 4; 
-- select * from #user_databases;

create table #tbl_privileges
						 (
							 table_qualifier sysname,
							 table_owner sysname,
							 table_name  sysname,
							 grantor sysname,
							 grantee sysname,
							 privilege sysname,
							 is_grantable sysname
						 );

create table #result
						(
						  id int identity(1,1) primary key nonclustered,
							name				nvarchar(1500),
							parent_uri	nvarchar(1500),
							uri					nvarchar(1500),
							type_id			int null,
							permission_name	nvarchar(256),
							ace_type		int	 null,
							accountidname		nvarchar(400),
							accountidtype		int null,	
							accountidprovider	nvarchar(256)
						);


--------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------
select
	[principal_id],
	case	when [type] = 'S' then name										
				when [type] = 'R' then name
				when [type] = 'U' then dbo.sidtostring([sid])
				when [type] = 'G' then dbo.sidtostring([sid])
				else ''
	end as accountidname,
	case	when [type] = 'S' then 1
				when [type] = 'R' then 1
				when [type] = 'U' then 3
				when [type] = 'G' then 3
				else 0
	end as accountidtype,
	case	when [type] = 'S' then '@@self'
				when [type] = 'R' then '@@self'
				when [type] = 'U' then substring(suser_sname([sid]), 0, charindex('\', suser_sname([sid])))
				when [type] = 'G' then substring(suser_sname([sid]), 0, charindex('\', suser_sname([sid])))
				else ''
	end as accountidprovider
into #serveraccountids
from [master].[sys].[server_principals]
where not ([name] like '##%') and [type] in ('S', 'R', 'U', 'G')

select	[class_desc],
				[grantee_principal_id],
				[permission_name],
				[state_desc]
	into #accountpermissions
	from [master].[sys].[server_permissions]

insert into #result
select	r.*,
				[permission_name], 
				case when [state_desc] like 'GRANT%' then 0
						else 1
				end as ace_type,
				accountidname,
				accountidtype,
				accountidprovider
-- into #result
from (select	cast('@@self' as nvarchar(max)) as name,
							cast('' as nvarchar(max)) as parent_uri,
							cast('@@self' as nvarchar(max)) as uri,
							133 as type_id) as r
			inner join #accountpermissions as p
			on p.[class_desc] = 'SERVER'
			inner join #serveraccountids a
			on p.[grantee_principal_id] = a.[principal_id]

-- Add 'Databases' node to #result

insert into #result
select 'Databases' as name,
       '@@self' as parent_uri,
       '@@self'+'/Databases' as uri,
			 53 as type_id,
			 null as permission_name,
			 0 as ace_type,
			 null as accountidname,
			 0 as accountidtype,
	   null as accountidprovider

-- Add 'System Databases' node to #result

insert into #result
select 'System Databases' as name,
       '@@self'+'/Databases' as parent_uri,
       '@@self'+'/Databases/System Databases' as uri,
			 53 as type_id,
			 null as permission_name,
			 0 as ace_type,
			 null as accountidname,
			 0 as accountidtype,
			 null as accountidprovider

--select * from #result
--drop table #result
--drop table #accountpermissions
--drop table #serveraccountids
--------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------
-- system databases 
if @skip_system_dbs = 1
  goto skip_system_dbs

-- maxid zuweisen
select @maxid = max(id) from #system_databases;

if @debug = 1
	print 'START SYSTEM DATABASES';	  

while(@loopcounter <= @maxid)
	begin
    select @database_name = name
	  from #system_databases where id = @loopcounter;
		
		if @debug = 1
		  print 'START SYSTEM DATABASE: ' + @database_name;

		set @dynamicsql = N'';
		set @dynamicsql = N'INSERT	INTO #result
												SELECT	''' + @database_name + ''' AS name,
																''@@self''+''/Databases/System Databases'' AS parent_uri,
																''@@self''+''/Databases/System Databases/' + @database_name + ''' AS uri,
																23 AS type_id,
																P.[permission_name],
																CASE WHEN [state_desc] LIKE ''GRANT%'' THEN 0
																		ELSE 1
																END AS ace_type,
																A.accountIdName,
																convert(int, A.accountIdType),
																A.accountIdProvider
												FROM #accountPermissions AS P
												INNER JOIN #serverAccountIds AS A
												ON P.[class_desc] = ''DATABASE'' AND P.[grantee_principal_id] = A.[principal_id]';
		execute sp_executesql @dynamicsql;

		-----------------------
		-- insert table node --
		-----------------------
		set @dynamicsql = N'';
		set @dynamicsql = N'insert into #result
												select ''Tables'' as name,
															 ''@@self''+''/Databases/System Databases/' + @database_name + ''' as parent_uri,
															 ''@@self''+''/Databases/System Databases/' + @database_name + '' + '/Tables'' AS uri,
															 53 as type_id,
															 null AS permission_name,
															 0 AS ace_type,
															 null AS accountIdName,
															 0 AS accountIdType,
															 null AS accountIdProvider';
		execute sp_executesql @dynamicsql;

		-----------------------
		-- insert views node --
		-----------------------
		set @dynamicsql = N'';
		set @dynamicsql = N'insert into #result
												select ''Views'' as name,
															 ''@@self''+''/Databases/System Databases/' + @database_name + ''' as parent_uri,
															 ''@@self''+''/Databases/System Databases/' + @database_name + '' + '/Views'' AS uri,
															 53 as type_id,
															 null AS permission_name,
															 0 AS ace_type,
															 null AS accountIdName,
															 0 AS accountIdType,
															 null AS accountIdProvider';
		execute sp_executesql @dynamicsql;

		----------------------------------
		-- insert stored procedure node --
		----------------------------------
		set @dynamicsql = N'';
		set @dynamicsql = N'insert into #result
												select ''Stored Procedures'' as name,
															 ''@@self''+''/Databases/System Databases/' + @database_name + ''' as parent_uri,
															 ''@@self''+''/Databases/System Databases/' + @database_name + '' + '/Stored Procedures'' AS uri,
															 53 as type_id,
															 null AS permission_name,
															 0 AS ace_type,
															 null AS accountIdName,
															 0 AS accountIdType,
															 null AS accountIdProvider';
		execute sp_executesql @dynamicsql;
		
		---------------------------------
		-- INSERT DATABASE PERMISSIONS --
		---------------------------------
		EXEC('
			INSERT INTO #result
			SELECT ''' + @database_name + ''' AS name,
						 ''@@self''+''/Databases/System Databases'' AS parent_uri,
						 ''@@self''+''/Databases/System Databases/' + @database_name + ''' AS uri,
						 23 AS type_id,
						 P.[permission_name],
						 CASE WHEN [state_desc] LIKE ''GRANT%'' THEN 0
									ELSE 1
						 END AS ace_type,
						 A.accountIdName,
						 A.accountIdType,
						 A.accountIdProvider
		FROM
			(SELECT [class_desc], [grantee_principal_id], [permission_name], [state_desc]
			 FROM [' + @database_name + '].[sys].[database_permissions]

			 -- See https://technet.microsoft.com/en-us/library/ms189612(v=sql.105).aspx
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''ALTER ANY USER'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_accessadmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''CREATE SCHEMA'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_accessadmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''BACKUP DATABASE'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_backupoperator''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''BACKUP LOG'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_backupoperator''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''CHECKPOINT'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_backupoperator''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''SELECT'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_datareader''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''DELETE'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_datawriter''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''INSERT'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_datawriter''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''UPDATE'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_datawriter''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''ALTER ANY ASSEMBLY'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''ALTER ANY ASYMMETRIC KEY'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''ALTER ANY CERTIFICATE'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''ALTER ANY CONTRACT'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''ALTER ANY DATABASE DDL TRIGGER'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''ALTER ANY DATABASE EVENT'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''NOTIFICATION'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''ALTER ANY DATASPACE'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''ALTER ANY FULLTEXT CATALOG'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''ALTER ANY MESSAGE TYPE'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''ALTER ANY REMOTE SERVICE BINDING'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''ALTER ANY ROUTE'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''ALTER ANY SCHEMA'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''ALTER ANY SERVICE'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''ALTER ANY SYMMETRIC KEY'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''CHECKPOINT'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''CREATE AGGREGATE'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''CREATE DEFAULT'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''CREATE FUNCTION'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''CREATE PROCEDURE'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''CREATE QUEUE'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''CREATE RULE'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''CREATE SYNONYM'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''CREATE TABLE'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''CREATE TYPE'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''CREATE VIEW'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''CREATE XML SCHEMA COLLECTION'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''REFERENCES'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''CONTROL'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_owner''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''ALTER ANY APPLICATION ROLE,'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_securityadmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''ALTER ANY ROLE,'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_securityadmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''CREATE SCHEMA,'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_securityadmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''VIEW DEFINITION,'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_securityadmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''VIEW,'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''dbm_monitor''
			) AS P
			INNER JOIN (
				SELECT
					[principal_id],
					CASE WHEN [type] = ''S'' THEN [name] + ''@' + @database_name + '''
							 WHEN [type] = ''R'' THEN [name] + ''@' + @database_name + '''
							 WHEN [type] = ''U'' THEN dbo.sidToString([sid])
							 WHEN [type] = ''G'' THEN dbo.sidToString([sid])
							 ELSE ''''
					END AS accountIdName,
					CASE WHEN [type] = ''S'' THEN 1
							 WHEN [type] = ''R'' THEN 1
							 WHEN [type] = ''U'' THEN 3
							 WHEN [type] = ''G'' THEN 3
							 ELSE 0
					END AS accountIdType,
					CASE WHEN [type] = ''S'' THEN ''@@self''
							 WHEN [type] = ''R'' THEN ''@@self''
							 WHEN [type] = ''U'' THEN SUBSTRING(SUSER_SNAME([sid]), 0, CHARINDEX(''\'', SUSER_SNAME([sid])))
							 WHEN [type] = ''G'' THEN SUBSTRING(SUSER_SNAME([sid]), 0, CHARINDEX(''\'', SUSER_SNAME([sid])))
							 ELSE ''''
					END AS accountIdProvider
				FROM [' + @database_name + '].[sys].[database_principals]
				WHERE NOT ([name] LIKE ''##%'') AND [type] IN (''S'', ''R'', ''U'', ''G'')

		) AS A
			ON P.[class_desc] = ''DATABASE'' AND P.[grantee_principal_id] = A.[principal_id]
		');


		--------------------------------------------------------------------------------------------------------------------------
		--------------------------------------------------------------------------------------------------------------------------
		--------------------------------------------------------------------------------------------------------------------------
		set @collation = (select convert(varchar, databasepropertyex(@database_name, 'collation')));
		set @dynamicsql = N'alter table #tbl_privileges alter column table_name sysname collate ' + @collation + '';
    execute sp_executesql @dynamicsql;

		
		set @exec_sp = quotename(@database_name) + N'.sys.sp_table_privileges @table_name = ''%%''';
		insert into #tbl_privileges
		(  
			table_qualifier,
			table_owner,
			table_name,
			grantor,
			grantee,
			privilege,
			is_grantable
		) 
		exec sp_executesql @exec_sp;
 
		-- TABLES
		set @dynamicsql = N'';
		set @dynamicsql = N'insert into #result
												select	p.table_name as name, 
																convert(nvarchar(1500), ''@@self'' + ''/Databases/System Databases/' + @database_name + '/Tables'') as parent_uri, 
																convert(nvarchar(1500), ''@@self'' + ''/Databases/System Databases/' + @database_name + '/Tables/'' + p.table_name) as uri,
																23 as type_id,				
																p.privilege as permission_name,
																0 as ace_type,
																p.grantee as accountIdName,
																--p.principal_id,
																--case when [type] = ''S'' then [name] + ''@' + @database_name + '''
																--		 when [type] = ''R'' then [name] + ''@' + @database_name + '''
																--		 when [type] = ''U'' then dbo.sidtostring([p.sid])
																--		 when [type] = ''G'' then dbo.sidtostring([p.sid])
																--		 else ''''
																--end as accountIdName,
																case	when p.acctype = ''S'' then 1
																			when p.acctype = ''R'' then 1
																			when p.acctype = ''U'' then 3
																			when p.acctype = ''G'' then 3
																			else 0
																end as accountIdType,
																case	when p.acctype = ''S'' then ''@@self''
																			when p.acctype = ''R'' then ''@@self''
																			-- when p.acctype = ''U'' then substring(suser_sname([p.sid]), 0, charindex(''\'', suser_sname([p.sid])))
																			-- when p.acctype = ''G'' then substring(suser_sname([p.sid]), 0, charindex(''\'', suser_sname([p.sid])))
																			else ''''
																end as accountIdProvider				
																-- select p.*										
												from 	( 
																select tblp.table_qualifier, tblp.privilege, tblp.table_name, tblp.grantee, dp.principal_id, dp.name, dp.sid, dp.type as accType, t.type, t.schema_id from #tbl_privileges tblp
																	join ' + @database_name + '.sys.tables as t on t.name collate Latin1_General_CI_AS = tblp.table_name
																	left join ' + @database_name + '.sys.database_principals as dp on dp.name collate Latin1_General_CI_AS = tblp.grantee
																where tblp.grantee <> ''dbo''
															) p;'

		--print @dynamicsql;
		exec sp_executesql @dynamicsql;

		-- VIEWS
		set @dynamicsql = N'';
		set @dynamicsql = N'insert into #result
												select	p.table_name as name, 
																convert(nvarchar(1500), ''@@self'' + ''/Databases/System Databases/' + @database_name + '/Views'') as parent_uri, 
																convert(nvarchar(1500), ''@@self'' + ''/Databases/System Databases/' + @database_name + '/Views/'' + p.table_name) as uri,
																23 as type_id,				
																p.privilege as permission_name,
																0 as ace_type,
																p.grantee as accountIdName,
																case	when p.acctype = ''S'' then 1
																			when p.acctype = ''R'' then 1
																			when p.acctype = ''U'' then 3
																			when p.acctype = ''G'' then 3
																			else 0
																end as accountIdType,
																case	when p.acctype = ''S'' then ''@@self''
																			when p.acctype = ''R'' then ''@@self''
																			--when p.acctype = ''U'' then substring(suser_sname([sid]), 0, charindex(''\'', suser_sname([sid])))
																			--when p.acctype = ''G'' then substring(suser_sname([sid]), 0, charindex(''\'', suser_sname([sid])))
																			else ''''
																end as accountIdProvider				
																-- select p.*										
												from 	( 
																select tblp.table_qualifier, tblp.privilege, tblp.table_name, tblp.grantee, dp.type as accType, v.type, v.schema_id from #tbl_privileges tblp
																	join ' + @database_name + '.sys.views as v on v.name collate Latin1_General_CI_AS = tblp.table_name
																	left join ' + @database_name + '.sys.database_principals as dp on dp.name collate Latin1_General_CI_AS = tblp.grantee 
																where tblp.grantee <> ''dbo''
															) p;'
		--print @dynamicsql;
		exec sp_executesql @dynamicsql;


		-- STORED PROCEDURES
		set @dynamicsql = N'';
		set @dynamicsql = N'insert into #result
												select	p.sp_name as name, 
																convert(nvarchar(1500), ''@@self'' + ''/Databases/System Databases/' + @database_name + '/Stored Procedures'') as parent_uri, 
																convert(nvarchar(1500), ''@@self'' + ''/Databases/System Databases/' + @database_name + '/Stored Procedures/'' + p.sp_name) as uri,
																23 as type_id,				
																p.privilege as permission_name,
																0 as ace_type,
																p.grantee as accountIdName,
																case	when p.acctype = ''S'' then 1
																			when p.acctype = ''R'' then 1
																			when p.acctype = ''U'' then 3
																			when p.acctype = ''G'' then 3
																			else 0
																end as accountIdType,
																case	when p.acctype = ''S'' then ''@@self''
																			when p.acctype = ''R'' then ''@@self''
																			--when p.acctype = ''U'' then substring(suser_sname([sid]), 0, charindex(''\'', suser_sname([sid])))
																			--when p.acctype = ''G'' then substring(suser_sname([sid]), 0, charindex(''\'', suser_sname([sid])))
																			else ''''
																end as accountIdProvider				
																-- select p.*										
												from 	( 
																select procs.name as sp_name, dpe.permission_name as privilege, dpr.name as grantee, dpr.type as accType from ' + @database_name + '.sys.database_permissions as dpe
																join ' + @database_name + '.sys.procedures as procs on procs.object_id = dpe.major_id
																join ' + @database_name + '.sys.database_principals as dpr on dpr.principal_id = dpe.grantee_principal_id
																where procs.object_id not in(select major_id from ' + @database_name + '.sys.extended_properties)
															) p';


		-- print @dynamicsql;
		exec sp_executesql @dynamicsql;




	  --print @dbname;  
	  set @loopcounter  = @loopcounter  + 1;     
		truncate table #tbl_privileges;
		if @debug = 1
		  print 'END SYSTEM DATABASE: ' + @database_name;
	end
skip_system_dbs:
if @debug = 1
  print 'END SYSTEM DATABASES';


-- truncate table #tbl_privileges; -- cleanup
--------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------
-- user databases 
if @skip_user_dbs = 1
  goto skip_user_dbs
-- @maxid zuweisen
select @maxid = max(id) from #user_databases;
set @loopcounter = 1;

-- print 'START USER DATABASES';
while(@loopcounter <= @maxid)
	begin	  
	  select @database_name = name
	  from #user_databases where id = @loopcounter;
		-- print 'START USER DATABASE: ' + @database_name;
		set @dynamicsql = N'';
		set @dynamicsql = N'INSERT	INTO #result
												SELECT	''' + @database_name + ''' AS name,
																''@@self''+''/Databases'' AS parent_uri,
																''@@self''+''/Databases/' + @database_name + ''' AS uri,
																23 AS type_id,
																P.[permission_name],
																CASE WHEN [state_desc] LIKE ''GRANT%'' THEN 0
																		ELSE 1
																END AS ace_type,
																A.accountIdName,
																A.accountIdType,
																A.accountIdProvider
												FROM #accountPermissions AS P
												INNER JOIN #serverAccountIds AS A
												ON P.[class_desc] = ''DATABASE'' AND P.[grantee_principal_id] = A.[principal_id]';
		execute sp_executesql @dynamicsql;

		-----------------------
		-- insert table node --
		-----------------------
		set @dynamicsql = N'';
		set @dynamicsql = N'insert into #result
												select ''Tables'' as name,
															 ''@@self''+''/Databases/' + @database_name + ''' as parent_uri,
															 ''@@self''+''/Databases/' + @database_name + '' + '/Tables'' AS uri,
															 53 as type_id,
															 null AS permission_name,
															 0 AS ace_type,
															 null AS accountIdName,
															 0 AS accountIdType,
															 null AS accountIdProvider';
		execute sp_executesql @dynamicsql;

		-----------------------
		-- insert views node --
		-----------------------
		set @dynamicsql = N'';
		set @dynamicsql = N'insert into #result
												select ''Views'' as name,
															 ''@@self''+''/Databases/' + @database_name + ''' as parent_uri,
															 ''@@self''+''/Databases/' + @database_name + '' + '/Views'' AS uri,
															 53 as type_id,
															 null AS permission_name,
															 0 AS ace_type,
															 null AS accountIdName,
															 0 AS accountIdType,
															 null AS accountIdProvider';
		execute sp_executesql @dynamicsql;

		----------------------------------
		-- insert stored procedure node --
		----------------------------------
		set @dynamicsql = N'';
		set @dynamicsql = N'insert into #result
												select ''Stored Procedures'' as name,
															 ''@@self''+''/Databases/' + @database_name + ''' as parent_uri,
															 ''@@self''+''/Databases/' + @database_name + '' + '/Stored Procedures'' AS uri,
															 53 as type_id,
															 null AS permission_name,
															 0 AS ace_type,
															 null AS accountIdName,
															 0 AS accountIdType,
															 null AS accountIdProvider';
		execute sp_executesql @dynamicsql;
		------------------------------------
		---- insert Security node					--
		------------------------------------
		--set @dynamicsql = N'';
		--set @dynamicsql = N'insert into #result
		--										select ''Security'' as name,
		--													 ''@@self''+''/Databases/' + @database_name + ''' as parent_uri,
		--													 ''@@self''+''/Databases/' + @database_name + '' + '/Security'' AS uri,
		--													 53 as type_id,
		--													 null AS permission_name,
		--													 0 AS ace_type,
		--													 null AS accountIdName,
		--													 0 AS accountIdType,
		--													 null AS accountIdProvider';
		--execute sp_executesql @dynamicsql;

		------------------------------------
		---- insert users node						--
		------------------------------------
		--set @dynamicsql = N'';
		--set @dynamicsql = N'insert into #result
		--										select ''Database Users'' as name,
		--													 ''@@self''+''/Databases/' + @database_name + '/Security'' as parent_uri,
		--													 ''@@self''+''/Databases/' + @database_name + '' + '/Security/Users'' AS uri,
		--													 53 as type_id,
		--													 null AS permission_name,
		--													 0 AS ace_type,
		--													 null AS accountIdName,
		--													 0 AS accountIdType,
		--													 null AS accountIdProvider';
		--execute sp_executesql @dynamicsql;

		------------------------------------
		---- insert roles node						--
		------------------------------------
		--set @dynamicsql = N'';
		--set @dynamicsql = N'insert into #result
		--										select ''Database Roles'' as name,
		--													 ''@@self''+''/Databases/' + @database_name + '/Security'' as parent_uri,
		--													 ''@@self''+''/Databases/' + @database_name + '' + '/Security/Roles'' AS uri,
		--													 53 as type_id,
		--													 null AS permission_name,
		--													 0 AS ace_type,
		--													 null AS accountIdName,
		--													 0 AS accountIdType,
		--													 null AS accountIdProvider';
		--execute sp_executesql @dynamicsql;

		----------------------------------
		-- insert schema node						--
		----------------------------------
		set @dynamicsql = N'';
		set @dynamicsql = N'insert into #result
												select ''Stored Procedures'' as name,
															 ''@@self''+''/Databases/' + @database_name + ''' as parent_uri,
															 ''@@self''+''/Databases/' + @database_name + '' + '/Schemas'' AS uri,
															 53 as type_id,
															 null AS permission_name,
															 0 AS ace_type,
															 null AS accountIdName,
															 0 AS accountIdType,
															 null AS accountIdProvider';
		execute sp_executesql @dynamicsql;

		
		---------------------------------
		-- INSERT DATABASE PERMISSIONS --
		---------------------------------
		EXEC('
			INSERT INTO #result
			SELECT ''' + @database_name + ''' AS name,
						 ''@@self''+''/Databases'' AS parent_uri,
						 ''@@self''+''/Databases/' + @database_name + ''' AS uri,
						 23 AS type_id,
						 P.[permission_name],
						 CASE WHEN [state_desc] LIKE ''GRANT%'' THEN 0
									ELSE 1
						 END AS ace_type,
						 A.accountIdName,
						 A.accountIdType,
						 A.accountIdProvider
		FROM
			(SELECT [class_desc], [grantee_principal_id], [permission_name], [state_desc]
			 FROM [' + @database_name + '].[sys].[database_permissions]

			 -- See https://technet.microsoft.com/en-us/library/ms189612(v=sql.105).aspx
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''ALTER ANY USER'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_accessadmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''CREATE SCHEMA'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_accessadmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''BACKUP DATABASE'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_backupoperator''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''BACKUP LOG'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_backupoperator''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''CHECKPOINT'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_backupoperator''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''SELECT'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_datareader''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''DELETE'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_datawriter''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''INSERT'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_datawriter''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''UPDATE'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_datawriter''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''ALTER ANY ASSEMBLY'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''ALTER ANY ASYMMETRIC KEY'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''ALTER ANY CERTIFICATE'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''ALTER ANY CONTRACT'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''ALTER ANY DATABASE DDL TRIGGER'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''ALTER ANY DATABASE EVENT'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''NOTIFICATION'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''ALTER ANY DATASPACE'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''ALTER ANY FULLTEXT CATALOG'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''ALTER ANY MESSAGE TYPE'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''ALTER ANY REMOTE SERVICE BINDING'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''ALTER ANY ROUTE'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''ALTER ANY SCHEMA'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''ALTER ANY SERVICE'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''ALTER ANY SYMMETRIC KEY'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''CHECKPOINT'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''CREATE AGGREGATE'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''CREATE DEFAULT'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''CREATE FUNCTION'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''CREATE PROCEDURE'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''CREATE QUEUE'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''CREATE RULE'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''CREATE SYNONYM'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''CREATE TABLE'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''CREATE TYPE'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''CREATE VIEW'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''CREATE XML SCHEMA COLLECTION'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''REFERENCES'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_ddladmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''CONTROL'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_owner''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''ALTER ANY APPLICATION ROLE,'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_securityadmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''ALTER ANY ROLE,'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_securityadmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''CREATE SCHEMA,'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_securityadmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''VIEW DEFINITION,'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''db_securityadmin''
			 UNION
			 SELECT ''DATABASE'', [principal_id] AS [grantee_principal_id], ''VIEW,'', ''GRANT''
			 FROM [' + @database_name + '].[sys].[database_principals]
			 WHERE name LIKE ''dbm_monitor''
			) AS P
			INNER JOIN (
				SELECT
					[principal_id],
					CASE WHEN [type] = ''S'' THEN [name] + ''@' + @database_name + '''
							 WHEN [type] = ''R'' THEN [name] + ''@' + @database_name + '''
							 WHEN [type] = ''U'' THEN dbo.sidToString([sid])
							 WHEN [type] = ''G'' THEN dbo.sidToString([sid])
							 ELSE ''''
					END AS accountIdName,
					CASE WHEN [type] = ''S'' THEN 1
							 WHEN [type] = ''R'' THEN 1
							 WHEN [type] = ''U'' THEN 3
							 WHEN [type] = ''G'' THEN 3
							 ELSE 0
					END AS accountIdType,
					CASE WHEN [type] = ''S'' THEN ''@@self''
							 WHEN [type] = ''R'' THEN ''@@self''
							 WHEN [type] = ''U'' THEN SUBSTRING(SUSER_SNAME([sid]), 0, CHARINDEX(''\'', SUSER_SNAME([sid])))
							 WHEN [type] = ''G'' THEN SUBSTRING(SUSER_SNAME([sid]), 0, CHARINDEX(''\'', SUSER_SNAME([sid])))
							 ELSE ''''
					END AS accountIdProvider
				FROM [' + @database_name + '].[sys].[database_principals]
				WHERE NOT ([name] LIKE ''##%'') AND [type] IN (''S'', ''R'', ''U'', ''G'')

		) AS A
			ON P.[class_desc] = ''DATABASE'' AND P.[grantee_principal_id] = A.[principal_id]
		');


		--------------------------------------------------------------------------------------------------------------------------
		--------------------------------------------------------------------------------------------------------------------------
		--------------------------------------------------------------------------------------------------------------------------
		set @collation = (select convert(varchar, databasepropertyex(@database_name, 'collation')));
		set @dynamicsql = N'alter table #tbl_privileges alter column table_name sysname collate ' + @collation + '';
    execute sp_executesql @dynamicsql;

		
		set @exec_sp = quotename(@database_name) + N'.sys.sp_table_privileges @table_name = ''%%''';
		insert into #tbl_privileges
		(  
			table_qualifier,
			table_owner,
			table_name,
			grantor,
			grantee,
			privilege,
			is_grantable
		) 
		exec sp_executesql @exec_sp;
 
		-- TABLES

		set @dynamicsql = N'insert into #result
												select	p.table_name as name, 
																''@@self'' + ''/Databases/' + @database_name + '/Tables'' as parent_uri, 
																''@@self'' + ''/Databases/' + @database_name + '/Tables/'' + p.table_name as uri,
																23 as type_id,				
																p.privilege as permission_name,
																0 as ace_type,
																p.grantee as accountIdName,
																case	when p.acctype = ''S'' then 1
																			when p.acctype = ''R'' then 1
																			when p.acctype = ''U'' then 3
																			when p.acctype = ''G'' then 3
																			else 0
																end as accountIdType,
																case	when p.acctype = ''S'' then ''@@self''
																			when p.acctype = ''R'' then ''@@self''
																			--when p.acctype = ''U'' then substring(suser_sname([sid]), 0, charindex(''\'', suser_sname([sid])))
																			--when p.acctype = ''G'' then substring(suser_sname([sid]), 0, charindex(''\'', suser_sname([sid])))
																			else ''''
																end as accountIdProvider				
																-- select p.*										
												from 	( 
																select tblp.table_qualifier, tblp.privilege, tblp.table_name, tblp.grantee, dp.type as accType, t.type, t.schema_id from #tbl_privileges tblp
																	join ' + @database_name + '.sys.tables as t on t.name collate Latin1_General_CI_AS = tblp.table_name
																	left join ' + @database_name + '.sys.database_principals as dp on dp.name collate Latin1_General_CI_AS = tblp.grantee
																where tblp.grantee <> ''dbo''
															) p;'

		--print @dynamicsql;
		exec sp_executesql @dynamicsql;

		-- VIEWS
		set @dynamicsql = N'insert into #result
												select	p.table_name as name, 
																''@@self'' + ''/Databases/' + @database_name + '/Views'' as parent_uri, 
																''@@self'' + ''/Databases/' + @database_name + '/Views/'' + p.table_name as uri,
																23 as type_id,				
																p.privilege as permission_name,
																0 as ace_type,
																p.grantee as accountIdName,
																case	when p.acctype = ''S'' then 1
																			when p.acctype = ''R'' then 1
																			when p.acctype = ''U'' then 3
																			when p.acctype = ''G'' then 3
																			else 0
																end as accountIdType,
																case	when p.acctype = ''S'' then ''@@self''
																			when p.acctype = ''R'' then ''@@self''
																			--when p.acctype = ''U'' then substring(suser_sname([sid]), 0, charindex(''\'', suser_sname([sid])))
																			--when p.acctype = ''G'' then substring(suser_sname([sid]), 0, charindex(''\'', suser_sname([sid])))
																			else ''''
																end as accountIdProvider				
																-- select p.*										
												from 	( 
																select tblp.table_qualifier, tblp.privilege, tblp.table_name, tblp.grantee, dp.type as accType, v.type, v.schema_id from #tbl_privileges tblp
																	join ' + @database_name + '.sys.views as v on v.name collate Latin1_General_CI_AS = tblp.table_name
																	left join ' + @database_name + '.sys.database_principals as dp on dp.name collate Latin1_General_CI_AS = tblp.grantee 
																where tblp.grantee <> ''dbo''
															) p;'
		--print @dynamicsql;
		exec sp_executesql @dynamicsql;


		-- STORED PROCEDURES
		set @dynamicsql = N'insert into #result
												select	p.sp_name as name, 
																convert(nvarchar(1500), ''@@self'' + ''/Databases/' + @database_name + '/Stored Procedures'') as parent_uri, 
																convert(nvarchar(1500), ''@@self'' + ''/Databases/' + @database_name + '/Stored Procedures/'' + p.sp_name) as uri,
																23 as type_id,				
																p.privilege as permission_name,
																0 as ace_type,
																p.grantee as accountIdName,
																case	when p.acctype = ''S'' then 1
																			when p.acctype = ''R'' then 1
																			when p.acctype = ''U'' then 3
																			when p.acctype = ''G'' then 3
																			else 0
																end as accountIdType,
																case	when p.acctype = ''S'' then ''@@self''
																			when p.acctype = ''R'' then ''@@self''
																			--when p.acctype = ''U'' then substring(suser_sname([sid]), 0, charindex(''\'', suser_sname([sid])))
																			--when p.acctype = ''G'' then substring(suser_sname([sid]), 0, charindex(''\'', suser_sname([sid])))
																			else ''''
																end as accountIdProvider				
																-- select p.*										
												from 	( 
																select procs.name as sp_name, dpe.permission_name as privilege, dpr.name as grantee, dpr.type as accType from ' + @database_name + '.sys.database_permissions as dpe
																join ' + @database_name + '.sys.procedures as procs on procs.object_id = dpe.major_id
																join ' + @database_name + '.sys.database_principals as dpr on dpr.principal_id = dpe.grantee_principal_id
																where procs.object_id not in(select major_id from ' + @database_name + '.sys.extended_properties)
															) p';


		-- print @dynamicsql;
		exec sp_executesql @dynamicsql;


		-- schema permissions
		set @dynamicsql = N'insert into #result
												select	p.schema_names as name, 
																convert(nvarchar(1500), ''@@self'' + ''/Databases/' + @database_name + '/Security/Schemas'') as parent_uri, 
																convert(nvarchar(1500), ''@@self'' + ''/Databases/' + @database_name + '/Security/Schemas/'' + p.schema_names) as uri,
																23 as type_id,				
																p.privilege as permission_name,
																0 as ace_type,
																p.grantee as accountIdName,
																case	when p.acctype = ''S'' then 1
																			when p.acctype = ''R'' then 1
																			when p.acctype = ''U'' then 3
																			when p.acctype = ''G'' then 3
																			else 0
																end as accountIdType,
																case	when p.acctype = ''S'' then ''@@self''
																			when p.acctype = ''R'' then ''@@self''
																			--when p.acctype = ''U'' then substring(suser_sname([sid]), 0, charindex(''\'', suser_sname([sid])))
																			--when p.acctype = ''G'' then substring(suser_sname([sid]), 0, charindex(''\'', suser_sname([sid])))
																			else ''''
																end as accountIdProvider				
																-- select p.*										
												from 	( 
																select schema_name(perm.major_id) as schema_names, perm.permission_name as privilege, prin.name as grantee, prin.type as accType
																from ' + @database_name + '.sys.database_permissions as perm 
																join ' + @database_name + '.sys.database_principals as prin 
																on perm.grantee_principal_id = prin.principal_id
																where class_desc = ''SCHEMA''
															) p';


		-- print @dynamicsql;
		exec sp_executesql @dynamicsql;


		--select schema_name(perm.major_id) as schema_names, perm.permission_name as privilege, prin.name as grantee, prin.type
		--from sys.database_permissions as perm 
		--join sys.database_principals as prin 
		--on perm.grantee_principal_id = prin.principal_id
		--where class_desc = 'SCHEMA'

		--select object_name(dpe.major_id) as sname, dpe.permission_name as privilege, dpr.name as grantee, dpr.type as accType
		--from _8manDB.sys.database_permissions as dpe join _8ManDB.sys.database_principals as dpr on dpe.grantee_principal_id = dpr.principal_id
		--where class_desc = 'SCHEMA'

		--select * from _8mandb.sys.schemas

		--select object_name(major_id) as oname, class_desc ,type from _8manDB.sys.database_permissions order by oname asc



		--------------------------------------------------------------------------------------------------------------------------
		--------------------------------------------------------------------------------------------------------------------------
		--------------------------------------------------------------------------------------------------------------------------

	  --print @dbname;  
	  set @loopcounter  = @loopcounter  + 1;     
		truncate table #tbl_privileges;
		--print 'END USER DATABASE:' + @database_name;
	end;
skip_user_dbs:
--print 'END USER DATABASES';
--select * from sys.database_principals

-- set statistics io on;
-- EXEC tempdb.dbo.sp_help @objname = N'#result';
-- select * from #result order by uri asc;
select * from #result where uri like '%Schema%' or parent_uri like '%Schema%' -- order by parent_uri;
-- select * from #table_privs
-- select * from #view_privs
-- set statistics io off
drop table #tbl_privileges;
drop table #result;
drop table #serverAccountIds;
drop table #accountPermissions;
drop table #user_databases;
drop table #system_databases;

-- select * from COPRA6Live.sys.database_principals
-- select * from copra6live.sys.database_permissions
-- select * from sys.tables
-- select * from sys.views



