USE [msdb]
GO

/****** Object:  Job [dba - arm_easyconnect_permissions]    Script Date: 07.08.2019 08:20:24 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Database Maintenance]    Script Date: 07.08.2019 08:20:24 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Database Maintenance' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Database Maintenance'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'dba - arm_easyconnect_permissions', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'Database Maintenance', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [create_permissions_table]    Script Date: 07.08.2019 08:20:24 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'create_permissions_table', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'declare @maxid int; 
declare @loopcounter int; 
declare @database_id int;
declare @user_access nchar(10);
declare @user_access_desc nchar(50);
declare @state tinyint;
declare @state_desc nchar(255);
declare @database_name varchar(255); 
declare @collation varchar(100);
declare @dynamicsql nvarchar(4000);
declare @exec_sp nvarchar(4000);
declare @debug int;
declare @skip_sysdbs int;
declare @skip_userdbs int;
declare @result_output int;
declare @skip_sysdb_table_permissions int;
declare @skip_userdb_table_permissions int;


-------------------------------------
-- --- debugging einschalten	 --- --
-------------------------------------

set @debug = 0; -- debug on = 1
set @skip_sysdbs = 0; -- skip_sysdbs on = 1
set @skip_userdbs = 0; -- skip_userdbs on = 1
set @skip_sysdb_table_permissions = 0; -- skip sysdbs table permissions = 1
set @skip_userdb_table_permissions = 0;-- skip userdbs table permissions = 1

-------------------------------------------------
-- --- legt fest, ob als Scan oder als Job --- --
-- --- @result_output = 0 - Job						 --- --
-- --- @result_output = 1 - Scan (ARM)		 --- --
-------------------------------------------------
set @result_output = 0;

set nocount on;

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

create table #dbrolemembers
						(
							databaserolename nvarchar(128),
							members int
						);

if object_id(N''dbo.tblPermissions'', N''U'') is not null
  drop table dbo.tblPermissions;

create table  tblPermissions
							(
								id int identity(1,1) primary key nonclustered,
								name				nvarchar(4000),
								parent_uri	nvarchar(4000),
								uri					nvarchar(4000),
								type_id			int null,
								permission_name	nvarchar(256),
								ace_type		int	 null,
								accountidname		nvarchar(400),
								accountidtype		int null,	
								accountidprovider	nvarchar(256)
							);

if exists (select * from sysobjects where id = object_id(N''sidtostring'') and xtype in (N''fn'', N''if'', N''tf''))
  drop function sidtostring;

set @dynamicsql = N''CREATE FUNCTION sidToString(@varBinarySID VARBINARY(85))
										RETURNS NVARCHAR(200)
										WITH EXECUTE AS CALLER  
										AS  
										BEGIN
											DECLARE @StringSID NVARCHAR(200)
											DECLARE @len AS INT
											SET @len = LEN(@varBinarySID)
											DECLARE @loop AS INT
											SELECT @StringSID = ''''S-''''
											SELECT @StringSID = @StringSID + CONVERT(VARCHAR, CONVERT(INT, CONVERT(VARBINARY, SUBSTRING(@varBinarySID, 1, 1))))
											SELECT @StringSID = @StringSID + ''''-''''
											SELECT @StringSID = @StringSID + CONVERT(VARCHAR, CONVERT(INT, CONVERT(VARBINARY, SUBSTRING(@varBinarySID, 3, 6))))
											SET @loop = 9
											WHILE @loop < @len
											BEGIN
													DECLARE @temp_var BINARY (4)
													SELECT @temp_var = SUBSTRING(@varBinarySID, @loop, 4)
													SELECT @StringSID = @StringSID + ''''-'''' + CONVERT(VARCHAR, CONVERT(BIGINT, CONVERT(VARBINARY, REVERSE(CONVERT(VARBINARY, @temp_var)))))
													SET @loop = @loop + 4
											END
											RETURN (@StringSID)
										END;
									'';
execute sp_executesql @dynamicsql;


set @loopcounter = 1;


----------------------------------------------------------------
-- --- databases on this server: name, state, user access --- --
----------------------------------------------------------------

-- system databases --
select identity(int, 1, 1) as id, name, database_id, user_access, user_access_desc, state, state_desc
into #system_databases
from [master].[sys].[databases] where name = ''master'' or name = ''msdb'' or name = ''model'';

-- user databases --
select identity(int, 1, 1) as id, name, database_id, user_access, user_access_desc, state, state_desc
into #user_databases
from [master].[sys].[databases] where database_id > 4; 

----------------------------------------------------------------
-- --- select all resource permissions from ms sql server --- --
----------------------------------------------------------------

-- principal types S = SQL_LOGIN, R = SERVER_ROLE, C = CERTIFICATE_MAPPED_LOGIN, U = WINDOWS_LOGIN, G = WINDOWS_GROUP
-- Calculate current account id''s
-- set statistics io off
select  [principal_id],
				case when [type] = ''S'' then name										
						 when [type] = ''R'' then name
						 when [type] = ''C'' then name
						 when [type] = ''K'' then name
						 when [type] = ''U'' then dbo.sidtostring([sid])
						 when [type] = ''G'' then dbo.sidtostring([sid])
						 -- when [type] = ''U'' then suser_sname([sid])
						 -- when [type] = ''G'' then suser_sname([sid])
						 else ''''
				end as accountidname,
				case when [type] = ''S'' then 1
						 when [type] = ''R'' then 1
						 when [type] = ''C'' then 1
						 when [type] = ''K'' then 1
						 when [type] = ''U'' then 3
						 when [type] = ''G'' then 3
						 else 0
				end as accountidtype,
				case when [type] = ''S'' then ''@@self''
						 when [type] = ''R'' then ''@@self''
						 when [type] = ''C'' then ''@@self''			 
						 when [type] = ''K'' then ''@@self''
						 when [type] = ''U'' then upper(substring(suser_sname([sid]), 0, charindex(''\'', suser_sname([sid]))))
						 when [type] = ''G'' then upper(substring(suser_sname([sid]), 0, charindex(''\'', suser_sname([sid]))))
						 else ''''
				end as accountidprovider
			into #serveraccountids
			from [master].[sys].[server_principals]
			where [type] in (''S'', ''R'', ''C'', ''U'', ''G'', ''K'')
			-- where not ([name] like ''##%'') and [type] in (''S'', ''R'', ''U'', ''G'')

-- Calculate current account permissions
select [class_desc],
       [grantee_principal_id],
       [permission_name],
       [state_desc]
  into #accountpermissions
  from [master].[sys].[server_permissions]

--select * from #accountPermissions as a
--join #serveraccountids as s on a.grantee_principal_id = s.principal_id

-- Add "buildin" account permissions (see https://technet.microsoft.com/en-us/library/ms175892(v=sql.105).aspx)

INSERT INTO #accountPermissions
SELECT P.[class_desc],
       R.[principal_id] AS grantee_prinicipal_id,
	   P.[permission_name],
	   ''GRANT'' AS state_desc
FROM [sys].fn_builtin_permissions(DEFAULT) AS P
INNER JOIN [sys].[server_principals] AS R
ON R.[name] LIKE ''bulkadmin'' AND ''ADMINISTER BULK OPERATIONS'' IN (P.[permission_name], P.[covering_permission_name], P.[parent_covering_permission_name])

INSERT INTO #accountPermissions
SELECT P.[class_desc],
       R.[principal_id] AS grantee_prinicipal_id,
	   P.[permission_name],
	   ''GRANT'' AS state_desc
FROM [sys].fn_builtin_permissions(DEFAULT) AS P
INNER JOIN [sys].[server_principals] AS R
ON R.[name] LIKE ''dbcreator'' AND ''CREATE ANY DATABASE'' IN (P.[permission_name], P.[covering_permission_name], P.[parent_covering_permission_name])

INSERT INTO #accountPermissions
SELECT P.[class_desc],
       R.[principal_id] AS grantee_prinicipal_id,
	   P.[permission_name],
	   ''GRANT'' AS state_desc
FROM [sys].fn_builtin_permissions(DEFAULT) AS P
INNER JOIN [sys].[server_principals] AS R
ON R.[name] LIKE ''diskadmin'' AND ''ALTER RESOURCES'' IN (P.[permission_name], P.[covering_permission_name], P.[parent_covering_permission_name])

INSERT INTO #accountPermissions
SELECT P.[class_desc],
       R.[principal_id] AS grantee_prinicipal_id,
	   P.[permission_name],
	   ''GRANT'' AS state_desc
FROM [sys].fn_builtin_permissions(DEFAULT) AS P
INNER JOIN [sys].[server_principals] AS R
ON R.[name] LIKE ''processadmin'' AND ''ALTER ANY CONNECTION'' IN (P.[permission_name], P.[covering_permission_name], P.[parent_covering_permission_name])

INSERT INTO #accountPermissions
SELECT P.[class_desc],
       R.[principal_id] AS grantee_prinicipal_id,
	     P.[permission_name],
	     ''GRANT'' AS state_desc
FROM [sys].fn_builtin_permissions(DEFAULT) AS P
INNER JOIN [sys].[server_principals] AS R
ON R.name LIKE ''processadmin'' AND ''ALTER SERVER STATE'' IN (P.[permission_name], P.[covering_permission_name], P.[parent_covering_permission_name])

INSERT INTO #accountPermissions
SELECT P.[class_desc],
       R.[principal_id] AS grantee_prinicipal_id,
	   P.[permission_name],
	   ''GRANT'' AS state_desc
FROM [sys].fn_builtin_permissions(DEFAULT) AS P
INNER JOIN [sys].[server_principals] AS R
ON R.name LIKE ''serveradmin'' AND
   (''ALTER ANY ENDPOINT'' IN (P.[permission_name], P.[covering_permission_name], P.[parent_covering_permission_name]) OR
    ''ALTER RESOURCES'' IN (P.[permission_name], P.[covering_permission_name], P.[parent_covering_permission_name]) OR
    ''ALTER SERVER STATE'' IN (P.[permission_name], P.[covering_permission_name], P.[parent_covering_permission_name]) OR
    ''ALTER SETTINGS'' IN (P.[permission_name], P.[covering_permission_name], P.[parent_covering_permission_name]) OR
    ''SHUTDOWN'' IN (P.[permission_name], P.[covering_permission_name], P.[parent_covering_permission_name]) OR
    ''VIEW SERVER STATE'' IN (P.[permission_name], P.[covering_permission_name], P.[parent_covering_permission_name]))

INSERT INTO #accountPermissions
SELECT P.[class_desc],
       R.[principal_id] AS grantee_prinicipal_id,
	     P.[permission_name],
	    ''GRANT'' AS state_desc
FROM [sys].fn_builtin_permissions(DEFAULT) AS P
INNER JOIN [sys].[server_principals] AS R
ON R.name LIKE ''setupadmin'' AND ''ALTER ANY LINKED SERVER'' IN (P.[permission_name], P.[covering_permission_name], P.[parent_covering_permission_name])

--INSERT INTO #accountPermissions
--SELECT P.[class_desc],
--       R.[principal_id] AS grantee_prinicipal_id,
--	     P.[permission_name],
--	     ''GRANT'' AS state_desc
--FROM [sys].fn_builtin_permissions(DEFAULT) AS P
--INNER JOIN [sys].[server_principals] AS R
--ON R.name LIKE ''sysadmin'' AND ''CONTROL SERVER'' IN (P.[permission_name], P.[covering_permission_name], P.[parent_covering_permission_name])


INSERT INTO #accountPermissions
SELECT distinct(P.[class_desc]),
       R.[principal_id] AS grantee_prinicipal_id,
	     -- P.[permission_name],
		   ''SYSADMIN'' as permission_name,
	     ''GRANT'' AS state_desc
FROM [sys].fn_builtin_permissions(DEFAULT) AS P
INNER JOIN [sys].[server_principals] AS R
ON R.name LIKE ''sysadmin'' AND ''CONTROL SERVER'' IN (P.[permission_name], P.[covering_permission_name], P.[parent_covering_permission_name])


-- Add server (root) node to result
insert into tblPermissions
SELECT R.*,
       [permission_name], 
			 CASE WHEN [state_desc] LIKE ''GRANT%'' THEN 0
						WHEN [state_desc] LIKE ''DENY%'' THEN 1
						ELSE 2
			 END AS ace_type,
			 accountIdName,
			 accountIdType,
			 accountIdProvider
-- INTO #result
FROM (SELECT CAST(''@@self'' AS NVARCHAR(MAX)) AS name,
             CAST('''' AS NVARCHAR(MAX)) AS parent_uri,
             CAST(''@@self'' AS NVARCHAR(MAX)) AS uri,
						 133 AS type_id) AS R
INNER JOIN #accountPermissions AS P
ON P.[class_desc] = ''SERVER''
INNER JOIN #serverAccountIds A
ON P.[grantee_principal_id] = A.[principal_id]


-- Add ''Databases'' node to result
insert into tblPermissions
SELECT ''Databases'' AS name,
       ''@@self'' AS parent_uri,
       ''@@self''+''/Databases'' AS uri,
			 53 AS type_id,
			 null AS permission_name,
			 0 AS ace_type,
			 null AS accountIdName,
			 0 AS accountIdType,
			 null AS accountIdProvider


-- Add ''System Databases'' node to result
insert into tblPermissions
SELECT ''System Databases'' AS name,
       ''@@self''+''/Databases'' AS parent_uri,
       ''@@self''+''/Databases/System Databases'' AS uri,
			 53 AS type_id,
			 null AS permission_name,
			 0 AS ace_type,
			 null AS accountIdName,
			 0 AS accountIdType,
			 null AS accountIdProvider


--INSERT INTO #result
--SELECT ''User Databases'' AS name,
--       ''@@self''+''/Databases'' AS parent_uri,
--       ''@@self''+''/Databases/User Databases'' AS uri,
--	   53 AS type_id,
--	   null AS permission_name,
--	   0 AS ace_type,
--	   null AS accountIdName,
--	   0 AS accountIdType,
--	   null AS accountIdProvider	   	   
	   

--------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------

-----------------------------------------------------
-- --- Add all system database nodes to result --- --
-----------------------------------------------------

-- system databases 
-- maxid zuweisen
select @maxid = max(id) from #system_databases;

if @debug = 1 and @skip_sysdbs = 0
  print ''START SYSTEM DATABASES'';	  

if @skip_sysdbs = 1
  goto skip_sysdbs

while(@loopcounter <= @maxid)
	begin
    select @database_name = name
	  from #system_databases where id = @loopcounter;

		if @debug = 1	and @skip_sysdbs = 0
		  print ''START SYSTEM DATABASE: '' + @database_name;

		set @dynamicsql = N'''';
		set @dynamicsql = N''insert into tblPermissions
												SELECT	'''''' + @database_name + '''''' AS name,
																''''@@self''''+''''/Databases/System Databases'''' AS parent_uri,
																''''@@self''''+''''/Databases/System Databases/'' + @database_name + '''''' AS uri,
																22 AS type_id,
																P.[permission_name],
																CASE WHEN [state_desc] LIKE ''''GRANT%'''' THEN 0
																		 ELSE 1
																END AS ace_type,
																A.accountIdName,
																A.accountIdType,
																A.accountIdProvider
												FROM #accountPermissions AS P
												INNER JOIN #serverAccountIds AS A
												ON P.[class_desc] = ''''DATABASE'''' AND P.[grantee_principal_id] = A.[principal_id]'';
		execute sp_executesql @dynamicsql;


		-------------------------------
		-- --- insert users node --- --
		-------------------------------
		set @dynamicsql = N'''';
		set @dynamicsql = N''insert into tblPermissions
												select ''''Users'''' as name,
															 ''''@@self''''+''''/Databases/System Databases/'' + @database_name + '''''' as parent_uri,
															 ''''@@self''''+''''/Databases/System Databases/'' + @database_name + '''' + ''/Users'''' AS uri,
															 52 as type_id,
															 null AS permission_name,
															 0 AS ace_type,
															 null AS accountIdName,
															 0 AS accountIdType,
															 null AS accountIdProvider'';
		-- execute sp_executesql @dynamicsql;

		---------------------------------------
		-- --- insert database role node --- --
		---------------------------------------
		set @dynamicsql = N'''';
		set @dynamicsql = N''insert into tblPermissions
												select ''''Database Roles'''' as name,
															 ''''@@self''''+''''/Databases/System Databases/'' + @database_name + '''''' as parent_uri,
															 ''''@@self''''+''''/Databases/System Databases/'' + @database_name + '''' + ''/Database Roles'''' AS uri,
															 52 as type_id,
															 null AS permission_name,
															 0 AS ace_type,
															 null AS accountIdName,
															 0 AS accountIdType,
															 null AS accountIdProvider'';
		execute sp_executesql @dynamicsql;

		-------------------------------
		-- --- insert table node --- --
		-------------------------------
		set @dynamicsql = N'''';
		set @dynamicsql = N''insert into tblPermissions
												select ''''Tables'''' as name,
															 ''''@@self''''+''''/Databases/System Databases/'' + @database_name + '''''' as parent_uri,
															 ''''@@self''''+''''/Databases/System Databases/'' + @database_name + '''' + ''/Tables'''' AS uri,
															 52 as type_id,
															 null AS permission_name,
															 0 AS ace_type,
															 null AS accountIdName,
															 0 AS accountIdType,
															 null AS accountIdProvider'';
		execute sp_executesql @dynamicsql;

		-------------------------------
		-- --- insert views node --- --
		-------------------------------
		set @dynamicsql = N'''';
		set @dynamicsql = N''insert into tblPermissions
												select ''''Views'''' as name,
															 ''''@@self''''+''''/Databases/System Databases/'' + @database_name + '''''' as parent_uri,
															 ''''@@self''''+''''/Databases/System Databases/'' + @database_name + '''' + ''/Views'''' AS uri,
															 52 as type_id,
															 null AS permission_name,
															 0 AS ace_type,
															 null AS accountIdName,
															 0 AS accountIdType,
															 null AS accountIdProvider'';
		execute sp_executesql @dynamicsql;

		------------------------------------------
		-- --- insert stored procedure node --- --
		------------------------------------------
		set @dynamicsql = N'''';
		set @dynamicsql = N''insert into tblPermissions
												select ''''Stored Procedures'''' as name,
															 ''''@@self''''+''''/Databases/System Databases/'' + @database_name + '''''' as parent_uri,
															 ''''@@self''''+''''/Databases/System Databases/'' + @database_name + '''' + ''/Stored Procedures'''' AS uri,
															 52 as type_id,
															 null AS permission_name,
															 0 AS ace_type,
															 null AS accountIdName,
															 0 AS accountIdType,
															 null AS accountIdProvider'';
		execute sp_executesql @dynamicsql;
		

		----------------------------------------
		-- --- insert schema node					---	--
		----------------------------------------
		set @dynamicsql = N'''';
		set @dynamicsql = N''insert into tblPermissions
												select ''''Schemas'''' as name,
															 ''''@@self''''+''''/Databases/System Databases/'' + @database_name + '''''' as parent_uri,
															 ''''@@self''''+''''/Databases/System Databases/'' + @database_name + ''/Schemas'''' AS uri,
															 52 as type_id,
															 null AS permission_name,
															 0 AS ace_type,
															 null AS accountIdName,
															 0 AS accountIdType,
															 null AS accountIdProvider'';
		execute sp_executesql @dynamicsql;


		-----------------------------------------
		-- --- insert database permissions --- --
		-----------------------------------------
		exec(	N''insert into tblPermissions
						SELECT '''''' + @database_name + '''''' AS name,
										''''@@self''''+''''/Databases/System Databases'''' AS parent_uri,
										''''@@self''''+''''/Databases/System Databases/'' + @database_name + '''''' AS uri,
										22 AS type_id,
										P.[permission_name],
										CASE WHEN [state_desc] LIKE ''''GRANT%'''' THEN 0
												WHEN [state_desc] LIKE ''''DENY%'''' THEN 1
												ELSE 2
										END AS ace_type,
										A.accountIdName,
										A.accountIdType,
										A.accountIdProvider
						FROM
								( SELECT [class_desc], [grantee_principal_id], [permission_name], [state_desc]
									FROM ['' + @database_name + ''].[sys].[database_permissions]

									-- See https://technet.microsoft.com/en-us/library/ms189612(v=sql.105).aspx
									UNION
									SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''ALTER ANY USER'''', ''''GRANT''''
									FROM ['' + @database_name + ''].[sys].[database_principals]
									WHERE name LIKE ''''db_accessadmin''''
									UNION
									SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''CREATE SCHEMA'''', ''''GRANT''''
									FROM ['' + @database_name + ''].[sys].[database_principals]
									WHERE name LIKE ''''db_accessadmin''''
									UNION
									SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''BACKUP DATABASE'''', ''''GRANT''''
									FROM ['' + @database_name + ''].[sys].[database_principals]
									WHERE name LIKE ''''db_backupoperator''''
									UNION
									SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''BACKUP LOG'''', ''''GRANT''''
									FROM ['' + @database_name + ''].[sys].[database_principals]
									WHERE name LIKE ''''db_backupoperator''''
									UNION
									SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''CHECKPOINT'''', ''''GRANT''''
									FROM ['' + @database_name + ''].[sys].[database_principals]
									WHERE name LIKE ''''db_backupoperator''''
									UNION
									SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''SELECT'''', ''''GRANT''''
									FROM ['' + @database_name + ''].[sys].[database_principals]
									WHERE name LIKE ''''db_datareader''''
									UNION
									SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''SELECT'''', ''''DENY''''
									FROM ['' + @database_name + ''].[sys].[database_principals]
									WHERE name LIKE ''''db_denydatareader''''
									UNION
									--------------------------------------------------------------------------------------------------------------
									--------------------------------------------------------------------------------------------------------------													
									SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''DELETE'''', ''''DENY''''
									FROM ['' + @database_name + ''].[sys].[database_principals]
									WHERE name LIKE ''''db_denydatawriter''''
									UNION
									SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''INSERT'''', ''''DENY''''
									FROM ['' + @database_name + ''].[sys].[database_principals]
									WHERE name LIKE ''''db_denydatawriter''''
									UNION
									SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''UPDATE'''', ''''DENY''''
									FROM ['' + @database_name + ''].[sys].[database_principals]
									WHERE name LIKE ''''db_denydatawriter''''
									UNION
									SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''DELETE'''', ''''GRANT''''
									FROM ['' + @database_name + ''].[sys].[database_principals]
									WHERE name LIKE ''''db_datawriter''''
									UNION
									SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''INSERT'''', ''''GRANT''''
									FROM ['' + @database_name + ''].[sys].[database_principals]
									WHERE name LIKE ''''db_datawriter''''
									UNION
									SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''UPDATE'''', ''''GRANT''''
									FROM ['' + @database_name + ''].[sys].[database_principals]
									WHERE name LIKE ''''db_datawriter''''
									UNION
									SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''ALTER ANY ASSEMBLY'''', ''''GRANT''''
									FROM ['' + @database_name + ''].[sys].[database_principals]
									WHERE name LIKE ''''db_ddladmin''''
									UNION
									SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''ALTER ANY ASYMMETRIC KEY'''', ''''GRANT''''
									FROM ['' + @database_name + ''].[sys].[database_principals]
									WHERE name LIKE ''''db_ddladmin''''
									UNION
									SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''ALTER ANY CERTIFICATE'''', ''''GRANT''''
									FROM ['' + @database_name + ''].[sys].[database_principals]
									WHERE name LIKE ''''db_ddladmin''''
									UNION
									SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''ALTER ANY CONTRACT'''', ''''GRANT''''
									FROM ['' + @database_name + ''].[sys].[database_principals]
									WHERE name LIKE ''''db_ddladmin''''
									UNION
									SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''ALTER ANY DATABASE DDL TRIGGER'''', ''''GRANT''''
									FROM ['' + @database_name + ''].[sys].[database_principals]
									WHERE name LIKE ''''db_ddladmin''''
									UNION
									SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''ALTER ANY DATABASE EVENT'''', ''''GRANT''''
									FROM ['' + @database_name + ''].[sys].[database_principals]
									WHERE name LIKE ''''db_ddladmin''''
									UNION
									SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''NOTIFICATION'''', ''''GRANT''''
									FROM ['' + @database_name + ''].[sys].[database_principals]
									WHERE name LIKE ''''db_ddladmin''''
									UNION
									SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''ALTER ANY DATASPACE'''', ''''GRANT''''
									FROM ['' + @database_name + ''].[sys].[database_principals]
									WHERE name LIKE ''''db_ddladmin''''
									UNION
									SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''ALTER ANY FULLTEXT CATALOG'''', ''''GRANT''''
									FROM ['' + @database_name + ''].[sys].[database_principals]
									WHERE name LIKE ''''db_ddladmin''''
									UNION
									SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''ALTER ANY MESSAGE TYPE'''', ''''GRANT''''
									FROM ['' + @database_name + ''].[sys].[database_principals]
									WHERE name LIKE ''''db_ddladmin''''
									UNION
									SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''ALTER ANY REMOTE SERVICE BINDING'''', ''''GRANT''''
									FROM ['' + @database_name + ''].[sys].[database_principals]
									WHERE name LIKE ''''db_ddladmin''''
									UNION
									SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''ALTER ANY ROUTE'''', ''''GRANT''''
									FROM ['' + @database_name + ''].[sys].[database_principals]
									WHERE name LIKE ''''db_ddladmin''''
									UNION
									SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''ALTER ANY SCHEMA'''', ''''GRANT''''
									FROM ['' + @database_name + ''].[sys].[database_principals]
									WHERE name LIKE ''''db_ddladmin''''
									UNION
									SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''ALTER ANY SERVICE'''', ''''GRANT''''
									FROM ['' + @database_name + ''].[sys].[database_principals]
									WHERE name LIKE ''''db_ddladmin''''
									UNION
									SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''ALTER ANY SYMMETRIC KEY'''', ''''GRANT''''
									FROM ['' + @database_name + ''].[sys].[database_principals]
									WHERE name LIKE ''''db_ddladmin''''
									UNION
									SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''CHECKPOINT'''', ''''GRANT''''
									FROM ['' + @database_name + ''].[sys].[database_principals]
									WHERE name LIKE ''''db_ddladmin''''
									UNION
									SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''CREATE AGGREGATE'''', ''''GRANT''''
									FROM ['' + @database_name + ''].[sys].[database_principals]
									WHERE name LIKE ''''db_ddladmin''''
									UNION
									SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''CREATE DEFAULT'''', ''''GRANT''''
									FROM ['' + @database_name + ''].[sys].[database_principals]
									WHERE name LIKE ''''db_ddladmin''''
									UNION
									SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''CREATE FUNCTION'''', ''''GRANT''''
									FROM ['' + @database_name + ''].[sys].[database_principals]
									WHERE name LIKE ''''db_ddladmin''''
									UNION
									SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''CREATE PROCEDURE'''', ''''GRANT''''
									FROM ['' + @database_name + ''].[sys].[database_principals]
									WHERE name LIKE ''''db_ddladmin''''
									UNION
									SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''CREATE QUEUE'''', ''''GRANT''''
									FROM ['' + @database_name + ''].[sys].[database_principals]
									WHERE name LIKE ''''db_ddladmin''''
									UNION
									SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''CREATE RULE'''', ''''GRANT''''
									FROM ['' + @database_name + ''].[sys].[database_principals]
									WHERE name LIKE ''''db_ddladmin''''
									UNION
									SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''CREATE SYNONYM'''', ''''GRANT''''
									FROM ['' + @database_name + ''].[sys].[database_principals]
									WHERE name LIKE ''''db_ddladmin''''
									UNION
									SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''CREATE TABLE'''', ''''GRANT''''
									FROM ['' + @database_name + ''].[sys].[database_principals]
									WHERE name LIKE ''''db_ddladmin''''
									UNION
									SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''CREATE TYPE'''', ''''GRANT''''
									FROM ['' + @database_name + ''].[sys].[database_principals]
									WHERE name LIKE ''''db_ddladmin''''
									UNION
									SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''CREATE VIEW'''', ''''GRANT''''
									FROM ['' + @database_name + ''].[sys].[database_principals]
									WHERE name LIKE ''''db_ddladmin''''
									UNION
									SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''CREATE XML SCHEMA COLLECTION'''', ''''GRANT''''
									FROM ['' + @database_name + ''].[sys].[database_principals]
									WHERE name LIKE ''''db_ddladmin''''
									UNION
									SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''REFERENCES'''', ''''GRANT''''
									FROM ['' + @database_name + ''].[sys].[database_principals]
									WHERE name LIKE ''''db_ddladmin''''
									UNION
									SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''CONTROL'''', ''''GRANT''''
									FROM ['' + @database_name + ''].[sys].[database_principals]
									WHERE name LIKE ''''db_owner''''
									UNION
									SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''ALTER ANY APPLICATION ROLE,'''', ''''GRANT''''
									FROM ['' + @database_name + ''].[sys].[database_principals]
									WHERE name LIKE ''''db_securityadmin''''
									UNION
									SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''ALTER ANY ROLE,'''', ''''GRANT''''
									FROM ['' + @database_name + ''].[sys].[database_principals]
									WHERE name LIKE ''''db_securityadmin''''
									UNION
									SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''CREATE SCHEMA,'''', ''''GRANT''''
									FROM ['' + @database_name + ''].[sys].[database_principals]
									WHERE name LIKE ''''db_securityadmin''''
									UNION
									SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''VIEW DEFINITION,'''', ''''GRANT''''
									FROM ['' + @database_name + ''].[sys].[database_principals]
									WHERE name LIKE ''''db_securityadmin''''
									UNION
									SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''VIEW,'''', ''''GRANT''''
									FROM ['' + @database_name + ''].[sys].[database_principals]
									WHERE name LIKE ''''dbm_monitor''''
									) AS P
									INNER JOIN 
									(
										SELECT
											[principal_id],
											CASE  WHEN [type] = ''''S'''' THEN [name] + ''''@'' + @database_name + ''''''
														WHEN [type] = ''''R'''' THEN [name] + ''''@'' + @database_name + ''''''
														WHEN [type] = ''''C'''' THEN [name] + ''''@'' + @database_name + ''''''
														WHEN [type] = ''''K'''' THEN [name] + ''''@'' + @database_name + ''''''
														WHEN [type] = ''''U'''' THEN dbo.sidToString([sid])
														WHEN [type] = ''''G'''' THEN dbo.sidToString([sid])
														-- when [type] = ''''U'''' then suser_sname([sid])
														-- when [type] = ''''G'''' then suser_sname([sid])
														ELSE ''''''''
											END AS accountIdName,
											CASE  WHEN [type] = ''''S'''' THEN 1
														WHEN [type] = ''''R'''' THEN 1
														WHEN [type] = ''''C'''' THEN 1
														WHEN [type] = ''''K'''' THEN 1
														WHEN [type] = ''''U'''' THEN 3
														WHEN [type] = ''''G'''' THEN 3
														ELSE 0
											END AS accountIdType,
											CASE  WHEN [type] = ''''S'''' THEN ''''@@self''''
														WHEN [type] = ''''R'''' THEN ''''@@self''''
														WHEN [type] = ''''C'''' THEN ''''@@self''''
														WHEN [type] = ''''K'''' THEN ''''@@self''''
														WHEN [type] = ''''U'''' THEN SUBSTRING(SUSER_SNAME([sid]), 0, CHARINDEX(''''\'''', SUSER_SNAME([sid])))
														WHEN [type] = ''''G'''' THEN SUBSTRING(SUSER_SNAME([sid]), 0, CHARINDEX(''''\'''', SUSER_SNAME([sid])))
														ELSE ''''''''
											END AS accountIdProvider
										FROM ['' + @database_name + ''].[sys].[database_principals]
										WHERE [type] IN (''''S'''', ''''R'''', ''''C'''', ''''K'''', ''''U'''', ''''G'''')
										--WHERE NOT ([name] LIKE ''''##%'''') AND [type] IN (''''S'''', ''''R'''', ''''U'''', ''''G'''')

								) AS A
									ON P.[class_desc] = ''''DATABASE'''' AND P.[grantee_principal_id] = A.[principal_id]
							'');

		--------------------------------------------------------------------------------------------------------------------------
		--------------------------------------------------------------------------------------------------------------------------
		--------------------------------------------------------------------------------------------------------------------------
		set @collation = (select convert(varchar, databasepropertyex(@database_name, ''collation'')));
		set @dynamicsql = N''alter table #tbl_privileges alter column table_name sysname collate '' + @collation + '''';
    execute sp_executesql @dynamicsql;

		
		set @exec_sp = quotename(@database_name) + N''.sys.sp_table_privileges @table_name = ''''%%'''''';
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
 

    --------------------------------------
		-- --- insert users permissions --- --
		--------------------------------------
		set @dynamicsql = N''insert into tblPermissions
												select	p.grantee as name, 
																''''@@self'''' + ''''/Databases/System Databases/'' + @database_name + ''/Users'''' as parent_uri, 
																''''@@self'''' + ''''/Databases/System Databases/'' + @database_name + ''/Users/'''' + p.grantee as uri,
																22 as type_id,				
																p.privilege as permission_name,
																0 as ace_type,
																-- p.grantee as accountIdName,
																case when p.acctype = ''''S'''' then p.grantee + ''''@'' + @database_name + ''''''
																		 when p.acctype = ''''R'''' then p.grantee + ''''@'' + @database_name + ''''''
																		 when p.acctype = ''''C'''' then p.grantee + ''''@'' + @database_name + ''''''
																		 when p.acctype = ''''K'''' then p.grantee + ''''@'' + @database_name + ''''''
																		 when p.acctype = ''''U'''' then dbo.sidtostring(p.sid)
																		 when p.acctype = ''''G'''' then dbo.sidtostring(p.sid)
																		 else ''''''''
																end as accountIdName,
																case	when p.acctype = ''''S'''' then 1
																			when p.acctype = ''''R'''' then 1
																			when p.acctype = ''''C'''' then 1
																			when p.acctype = ''''K'''' then 1
																			when p.acctype = ''''U'''' then 3
																			when p.acctype = ''''G'''' then 3
																			else 0
																end as accountIdType,
																case	when p.acctype = ''''S'''' then ''''@@self''''
																			when p.acctype = ''''R'''' then ''''@@self''''
																			when p.acctype = ''''C'''' then ''''@@self''''
																			when p.acctype = ''''K'''' then ''''@@self''''
																			when p.acctype = ''''U'''' then substring(suser_sname(p.sid), 0, charindex(''''\'''', suser_sname(p.sid)))
																			when p.acctype = ''''G'''' then substring(suser_sname(p.sid), 0, charindex(''''\'''', suser_sname(p.sid)))
																			else ''''''''
																end as accountIdProvider								
																-- select p.*										
												from 	( 
																select  '''' + @database_name + '''' as db_name,
																				perm.permission_name as privilege,
																				princ.name as grantee,
																				princ.type as accType,
																				princ.sid as sid,
																				princ.type_desc,
																				perm.state_desc
																from '' + @database_name + ''.sys.database_principals as princ
																left join '' + @database_name + ''.sys.database_permissions as perm on perm.grantee_principal_id = princ.principal_id
																where princ.type <> ''''R''''
															) p;''

		-- print @dynamicsql;
		-- exec sp_executesql @dynamicsql;


		---------------------------------------
		-- --- insert tables permissions --- --
		---------------------------------------

		if @skip_sysdb_table_permissions = 1
		  goto skip_sysdb_table_permissions;

		set @dynamicsql = N'''';
		set @dynamicsql = N''insert into tblPermissions
												select	p.table_name as name, 
																''''@@self'''' + ''''/Databases/System Databases/'' + @database_name + ''/Tables'''' as parent_uri, 
																''''@@self'''' + ''''/Databases/System Databases/'' + @database_name + ''/Tables/'''' + p.table_name as uri,
																-- 23 as type_id,				
																22 as type_id,
																p.privilege as permission_name,
																0 as ace_type,
																-- p.grantee as accountIdName,
																case when p.acctype = ''''S'''' then p.grantee + ''''@'' + @database_name + ''''''
																		 when p.acctype = ''''R'''' then p.grantee + ''''@'' + @database_name + ''''''
																		 when p.acctype = ''''C'''' then p.grantee + ''''@'' + @database_name + ''''''
																		 when p.acctype = ''''K'''' then p.grantee + ''''@'' + @database_name + ''''''
																		 when p.acctype = ''''U'''' then dbo.sidtostring(p.sid)
																		 when p.acctype = ''''G'''' then dbo.sidtostring(p.sid)
																		 else ''''''''
																end as accountIdName,
																case	when p.acctype = ''''S'''' then 1
																			when p.acctype = ''''R'''' then 1
																			when p.acctype = ''''C'''' then 1
																			when p.acctype = ''''K'''' then 1
																			when p.acctype = ''''U'''' then 3
																			when p.acctype = ''''G'''' then 3
																			else 0
																end as accountIdType,
																case	when p.acctype = ''''S'''' then ''''@@self''''
																			when p.acctype = ''''R'''' then ''''@@self''''
																			when p.acctype = ''''C'''' then ''''@@self''''
																			when p.acctype = ''''K'''' then ''''@@self''''
																			when p.acctype = ''''U'''' then substring(suser_sname(p.sid), 0, charindex(''''\'''', suser_sname(p.sid)))
																			when p.acctype = ''''G'''' then substring(suser_sname(p.sid), 0, charindex(''''\'''', suser_sname(p.sid)))
																			else ''''''''
																end as accountIdProvider				
																-- select p.*										
												from 	( 
																--select tblp.table_qualifier, tblp.privilege, tblp.table_name, tblp.grantee, dp.principal_id, dp.name, dp.type as accType, dp.sid as sid, t.type, t.schema_id from #tbl_privileges tblp
																--	join '' + @database_name + ''.sys.tables as t on t.name collate Latin1_General_CI_AS = tblp.table_name
																--	left join '' + @database_name + ''.sys.database_principals as dp on dp.name collate Latin1_General_CI_AS = tblp.grantee
																--where tblp.grantee <> ''''dbo''''
																select  '''' + @database_name + '''' as table_qualifier,
																				perm.permission_name as privilege,
																				princ.name as grantee,
																				princ.type as accType,
																				princ.sid as sid,
																				princ.type_desc,
																				perm.state_desc,
																				object_name(perm.major_id) as objectname,
																				concat(s.name collate '' + @collation + '', ''''.'''', t.name collate '' + @collation + '') as table_name,
																				t.type,
																				t.schema_id
																from '' + @database_name + ''.sys.database_principals princ
																left join '' + @database_name + ''.sys.database_permissions perm on perm.grantee_principal_id = princ.principal_id
																inner join '' + @database_name + ''.sys.tables t on perm.major_id = t.object_id
																inner join '' + @database_name + ''.sys.schemas as s on s.schema_id = t.schema_id

															) p;''

		-- print @dynamicsql;
		exec sp_executesql @dynamicsql;

		skip_sysdb_table_permissions:

		--------------------------------------
		-- --- insert views permissions --- --
		--------------------------------------
		set @dynamicsql = N'''';
		set @dynamicsql = N''insert into tblPermissions
												select	p.view_name as name, 
																''''@@self'''' + ''''/Databases/System Databases/'' + @database_name + ''/Views'''' as parent_uri, 
																''''@@self'''' + ''''/Databases/System Databases/'' + @database_name + ''/Views/'''' + p.view_name as uri,
																22 as type_id,				
																p.privilege as permission_name,
																0 as ace_type,
																-- p.grantee as accountIdName,
																case when p.acctype = ''''S'''' then p.grantee + ''''@'' + @database_name + ''''''
																		 when p.acctype = ''''R'''' then p.grantee + ''''@'' + @database_name + ''''''
																		 when p.acctype = ''''C'''' then p.grantee + ''''@'' + @database_name + ''''''
																		 when p.acctype = ''''K'''' then p.grantee + ''''@'' + @database_name + ''''''
																		 when p.acctype = ''''U'''' then dbo.sidtostring(p.sid)
																		 when p.acctype = ''''G'''' then dbo.sidtostring(p.sid)
																		 else ''''''''
																end as accountIdName,
																case	when p.acctype = ''''S'''' then 1
																			when p.acctype = ''''R'''' then 1
																			when p.acctype = ''''C'''' then 1
																			when p.acctype = ''''K'''' then 1
																			when p.acctype = ''''U'''' then 3
																			when p.acctype = ''''G'''' then 3
																			else 0
																end as accountIdType,
																case	when p.acctype = ''''S'''' then ''''@@self''''
																			when p.acctype = ''''R'''' then ''''@@self''''
																			when p.acctype = ''''C'''' then ''''@@self''''
																			when p.acctype = ''''K'''' then ''''@@self''''
																			when p.acctype = ''''U'''' then substring(suser_sname(p.sid), 0, charindex(''''\'''', suser_sname(p.sid)))
																			when p.acctype = ''''G'''' then substring(suser_sname(p.sid), 0, charindex(''''\'''', suser_sname(p.sid)))
																			else ''''''''
																end as accountIdProvider				
																-- select p.*										
												from 	( 
																--select tblp.table_qualifier, tblp.privilege, tblp.table_name, tblp.grantee, dp.type as accType, v.type, v.schema_id, dp.sid as sid from #tbl_privileges tblp
																--	join '' + @database_name + ''.sys.views as v on v.name collate Latin1_General_CI_AS = tblp.table_name
																--	left join '' + @database_name + ''.sys.database_principals as dp on dp.name collate Latin1_General_CI_AS = tblp.grantee 
																--where tblp.grantee <> ''''dbo''''
																select  '''' + @database_name + '''' as table_qualifier,
																				perm.permission_name as privilege,
																				princ.name as grantee,
																				princ.type as accType,
																				princ.sid as sid,
																				princ.type_desc,
																				perm.state_desc,
																				object_name(perm.major_id) as objectname,
																				concat(s.name collate '' + @collation + '', ''''.'''', v.name collate '' + @collation + '') as view_name,
																				v.type,
																				v.schema_id
																from '' + @database_name + ''.sys.database_principals princ
																left join '' + @database_name + ''.sys.database_permissions perm on perm.grantee_principal_id = princ.principal_id
																inner join '' + @database_name + ''.sys.views v on perm.major_id = v.object_id
																inner join '' + @database_name + ''.sys.schemas as s on s.schema_id = v.schema_id
															) p;''
		--print @dynamicsql;
		exec sp_executesql @dynamicsql;


		--------------------------------------------------
		-- --- insert stored procedures permissions --- --
		--------------------------------------------------
		set @dynamicsql = N'''';
		set @dynamicsql = N''insert into tblPermissions
												select	p.sp_name as name, 
																''''@@self'''' + ''''/Databases/System Databases/'' + @database_name + ''/Stored Procedures'''' as parent_uri, 
																''''@@self'''' + ''''/Databases/System Databases/'' + @database_name + ''/Stored Procedures/'''' + p.sp_name as uri,
																22 as type_id,				
																p.privilege as permission_name,
																0 as ace_type,
																-- p.grantee as accountIdName,
																case when p.acctype = ''''S'''' then p.grantee + ''''@'' + @database_name + ''''''
																		 when p.acctype = ''''R'''' then p.grantee + ''''@'' + @database_name + ''''''
																		 when p.acctype = ''''C'''' then p.grantee + ''''@'' + @database_name + ''''''
																		 when p.acctype = ''''K'''' then p.grantee + ''''@'' + @database_name + ''''''
																		 when p.acctype = ''''U'''' then dbo.sidtostring(p.sid)
																		 when p.acctype = ''''G'''' then dbo.sidtostring(p.sid)
																		 else ''''''''
																end as accountIdName,
																case	when p.acctype = ''''S'''' then 1
																			when p.acctype = ''''R'''' then 1
																			when p.acctype = ''''C'''' then 1
																			when p.acctype = ''''K'''' then 1
																			when p.acctype = ''''U'''' then 3
																			when p.acctype = ''''G'''' then 3
																			else 0
																end as accountIdType,
																case	when p.acctype = ''''S'''' then ''''@@self''''
																			when p.acctype = ''''R'''' then ''''@@self''''
																			when p.acctype = ''''C'''' then ''''@@self''''
																			when p.acctype = ''''K'''' then ''''@@self''''
																			when p.acctype = ''''U'''' then substring(suser_sname(p.sid), 0, charindex(''''\'''', suser_sname(p.sid)))
																			when p.acctype = ''''G'''' then substring(suser_sname(p.sid), 0, charindex(''''\'''', suser_sname(p.sid)))
																			else ''''''''
																end as accountIdProvider				
																-- select p.*										
												from 	( 
																--select procs.name as sp_name, dpe.permission_name as privilege, dpr.name as grantee, dpr.type as accType, dpr.sid as sid from '' + @database_name + ''.sys.database_permissions as dpe
																--  join '' + @database_name + ''.sys.procedures as procs on procs.object_id = dpe.major_id
																--  join '' + @database_name + ''.sys.database_principals as dpr on dpr.principal_id = dpe.grantee_principal_id
																--where procs.object_id not in(select major_id from '' + @database_name + ''.sys.extended_properties)
																select  '''' + @database_name + '''' as table_qualifier,
																				perm.permission_name as privilege,
																				princ.name as grantee,
																				princ.type as accType,
																				princ.sid as sid,
																				princ.type_desc,
																				perm.state_desc,
																				object_name(perm.major_id) as objectname,
																				concat(s.name collate '' + @collation + '', ''''.'''', p.name collate '' + @collation + '') collate '' + @collation + '' as sp_name,
																				p.type,
																				p.schema_id
																from '' + @database_name + ''.sys.database_principals princ
																left join '' + @database_name + ''.sys.database_permissions perm on perm.grantee_principal_id = princ.principal_id
																inner join '' + @database_name + ''.sys.procedures p on perm.major_id = p.object_id
																inner join '' + @database_name + ''.sys.schemas as s on s.schema_id = p.schema_id
															) p'';


		-- print @dynamicsql;
		exec sp_executesql @dynamicsql;

		
		---------------------------------------
		-- --- insert schema permissions --- --
		---------------------------------------
		set @dynamicsql = N''insert into tblPermissions
												select	p.schema_names as name, 
																''''@@self'''' + ''''/Databases/System Databases/'' + @database_name + ''/Schemas'''' as parent_uri, 
																''''@@self'''' + ''''/Databases/System Databases/'' + @database_name + ''/Schemas/'''' + p.schema_names as uri,
																22 as type_id,				
																p.privilege as permission_name,
																0 as ace_type,
																-- p.grantee as accountIdName,
																case when p.acctype = ''''S'''' then p.grantee + ''''@'' + @database_name + ''''''
																		 when p.acctype = ''''R'''' then p.grantee + ''''@'' + @database_name + ''''''
																		 when p.acctype = ''''C'''' then p.grantee + ''''@'' + @database_name + ''''''
																		 when p.acctype = ''''K'''' then p.grantee + ''''@'' + @database_name + ''''''
																		 when p.acctype = ''''U'''' then dbo.sidtostring(p.sid)
																		 when p.acctype = ''''G'''' then dbo.sidtostring(p.sid)
																		 else ''''''''
																end as accountIdName,
																case	when p.acctype = ''''S'''' then 1
																			when p.acctype = ''''R'''' then 1
																			when p.acctype = ''''C'''' then 1
																			when p.acctype = ''''K'''' then 1
																			when p.acctype = ''''U'''' then 3
																			when p.acctype = ''''G'''' then 3
																			else 0
																end as accountIdType,
																case	when p.acctype = ''''S'''' then ''''@@self''''
																			when p.acctype = ''''R'''' then ''''@@self''''
																			when p.acctype = ''''C'''' then ''''@@self''''
																			when p.acctype = ''''K'''' then ''''@@self''''
																			when p.acctype = ''''U'''' then substring(suser_sname(p.sid), 0, charindex(''''\'''', suser_sname(p.sid)))
																			when p.acctype = ''''G'''' then substring(suser_sname(p.sid), 0, charindex(''''\'''', suser_sname(p.sid)))
																			else ''''''''
																end as accountIdProvider				
																-- select p.*										
												from 	( 
																select s.name as schema_names, perm.permission_name as privilege, prin.name as grantee, prin.type as accType,  prin.sid as sid from '' + @database_name + ''.sys.database_permissions as perm 
																  join '' + @database_name + ''.sys.schemas as s	on perm.major_id = s.schema_id
																  join '' + @database_name + ''.sys.database_principals as prin on prin.principal_id = perm.grantee_principal_id
																where perm.class_desc = ''''SCHEMA''''
															) p'';
		-- print @dynamicsql;
		exec sp_executesql @dynamicsql;

		--------------------------------------------
		-- --- insert system database roles	  --- --
		--------------------------------------------
		set @dynamicsql = N''insert into tblPermissions
												select	distinct p.grantee as name, 
																''''@@self'''' + ''''/Databases/System Databases/'' + @database_name + ''/Database Roles'''' as parent_uri, 
																''''@@self'''' + ''''/Databases/System Databases/'' + @database_name + ''/Database Roles/'''' + p.grantee as uri,
																22 as type_id,				
																-- p.privilege as permission_name,
																-- NULL as permission_name,
																tp.permission_name as permission_name,
																0 as ace_type,
																-- p.grantee as accountIdName,
																case when p.acctype = ''''R'''' then p.grantee + ''''@'' + @database_name + ''''''
																		 else ''''''''
																end as accountIdName,
																case	when p.acctype = ''''R'''' then 1
																			else 0
																end as accountIdType,
																case	when p.acctype = ''''R'''' then ''''@@self''''
																			else ''''''''
																end as accountIdProvider								
												-- select p.*
												from 	( select  '''' + @database_name + '''' as db_name,
																				perm.permission_name as privilege,
																				princ.name as grantee,
																				princ.type as accType,
																				princ.sid as sid,
																				princ.type_desc,
																				perm.state_desc
																from '' + @database_name + ''.sys.database_principals as princ
																left join '' + @database_name + ''.sys.database_permissions as perm 
																on perm.grantee_principal_id = princ.principal_id
																where princ.type = ''''R''''
															) as p
												left outer join msdb.dbo.tblPermissions as tp 
												on p.grantee + ''''@'' + @database_name + '''''' = tp.accountidname
												where tp.permission_name is not null;''
		-- print @dynamicsql;
		exec sp_executesql @dynamicsql;

	  --print @dbname;  
	  set @loopcounter  = @loopcounter  + 1;     
		truncate table #tbl_privileges;
		if @debug = 1 and @skip_sysdbs = 0
			print ''END SYSTEM DATABASE: '' + @database_name;
	end;
if @debug = 1 and @skip_sysdbs = 0
  print ''END SYSTEM DATABASES'';	  

skip_sysdbs: -- skip system databases

truncate table #tbl_privileges; -- cleanup

--------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------

----------------------------------------------------
-- --- add all user databases nodes to result --- --
----------------------------------------------------

if @debug = 1 and @skip_userdbs = 0
  print ''START USER DATABASES'';	  

if @skip_userdbs = 1
  goto skip_userdbs;

set @loopcounter = 1;
-- @maxid zuweisen
select @maxid = max(id) from #user_databases;

while(@loopcounter <= @maxid)
	begin

	  select	@database_name = name, 
						@state = state, 
						@state_desc = state_desc
	  from #user_databases where id = @loopcounter;
		set @state_desc = ltrim(rtrim(@state_desc));

		if @debug = 1	and @skip_userdbs = 0
		  print ''START USER DATABASE: '' + @database_name;

		
		if @state > 0
		  goto skip_db_rolemembers;

		set @dynamicsql = N''insert into #dbrolemembers
												select distinct(dp1.name) as databaserolename,   
															 case dp2.name
																		when isnull(dp2.name, 0)  then 1
																		else 0
															 end as members												
												from '' + @database_name + ''.sys.database_role_members as drm  
														 right outer join '' + @database_name + ''.sys.database_principals as dp1  
												on drm.role_principal_id = dp1.principal_id  
														 left outer join '' + @database_name + ''.sys.database_principals as dp2  
												on drm.member_principal_id = dp2.principal_id  
												where dp1.type = ''''R''''
												order by dp1.name'';
		execute sp_executesql @dynamicsql;
		skip_db_rolemembers:
		-- select @database_name as databasename, databaserolename, members from #dbrolemembers;

		-- select  '''''' + @database_name + '' - '' + trim(@state_desc) + '''''' as name,

		set @dynamicsql = N'''';
		set @dynamicsql = N''insert into tblPermissions
												SELECT	'''''' + @database_name + '''''' AS name,												
																''''@@self''''+''''/Databases'''' AS parent_uri,
																''''@@self''''+''''/Databases/'' + @database_name + ''''''  AS uri,
																case when 0 = '' + cast(@state as char) + '' then 22
																     else 23
																end as type_id,
																P.[permission_name],
																CASE WHEN [state_desc] LIKE ''''GRANT%'''' THEN 0
																		ELSE 1
																END AS ace_type,
																A.accountIdName,
																A.accountIdType,
																A.accountIdProvider
												FROM #accountPermissions AS P
												INNER JOIN #serverAccountIds AS A
												ON P.[class_desc] = ''''DATABASE'''' AND P.[grantee_principal_id] = A.[principal_id]'';
    if @debug = 1
			print @dynamicsql;				
		execute sp_executesql @dynamicsql;

		if @state > 0
		  goto db_not_online;

		-------------------------------
		-- --- insert users node --- --
		-------------------------------
		set @dynamicsql = N'''';
		set @dynamicsql = N''insert into tblPermissions
												select ''''Users'''' as name,
															 ''''@@self''''+''''/Databases/'' + @database_name + '''''' as parent_uri,
															 ''''@@self''''+''''/Databases/'' + @database_name + '''' + ''/Users'''' AS uri,
															 52 as type_id,
															 null AS permission_name,
															 0 AS ace_type,
															 null AS accountIdName,
															 0 AS accountIdType,
															 null AS accountIdProvider'';
		--execute sp_executesql @dynamicsql;

		---------------------------------------
		-- --- insert database role node --- --
		---------------------------------------
		set @dynamicsql = N'''';
		set @dynamicsql = N''insert into tblPermissions
												select ''''Database Roles'''' as name,
															 ''''@@self''''+''''/Databases/'' + @database_name + '''''' as parent_uri,
															 ''''@@self''''+''''/Databases/'' + @database_name + '''' + ''/Database Roles'''' AS uri,
															 52 as type_id,
															 null AS permission_name,
															 0 AS ace_type,
															 null AS accountIdName,
															 0 AS accountIdType,
															 null AS accountIdProvider'';
		execute sp_executesql @dynamicsql;

		-------------------------------
		-- --- insert table node --- --
		-------------------------------
		set @dynamicsql = N'''';
		set @dynamicsql = N''insert into tblPermissions
												select ''''Tables'''' as name,
															 ''''@@self''''+''''/Databases/'' + @database_name + '''''' as parent_uri,
															 ''''@@self''''+''''/Databases/'' + @database_name + '''' + ''/Tables'''' AS uri,
															 52 as type_id,
															 null AS permission_name,
															 0 AS ace_type,
															 null AS accountIdName,
															 0 AS accountIdType,
															 null AS accountIdProvider'';
		execute sp_executesql @dynamicsql;

		-------------------------------
		-- --- insert views node --- --
		-------------------------------
		set @dynamicsql = N'''';
		set @dynamicsql = N''insert into tblPermissions
												select ''''Views'''' as name,
															 ''''@@self''''+''''/Databases/'' + @database_name + '''''' as parent_uri,
															 ''''@@self''''+''''/Databases/'' + @database_name + '''' + ''/Views'''' AS uri,
															 52 as type_id,
															 null AS permission_name,
															 0 AS ace_type,
															 null AS accountIdName,
															 0 AS accountIdType,
															 null AS accountIdProvider'';
		execute sp_executesql @dynamicsql;

		------------------------------------------
		-- --- insert stored procedure node --- --
		------------------------------------------
		set @dynamicsql = N'''';
		set @dynamicsql = N''insert into tblPermissions
												select ''''Stored Procedures'''' as name,
															 ''''@@self''''+''''/Databases/'' + @database_name + '''''' as parent_uri,
															 ''''@@self''''+''''/Databases/'' + @database_name + '''' + ''/Stored Procedures'''' AS uri,
															 52 as type_id,
															 null AS permission_name,
															 0 AS ace_type,
															 null AS accountIdName,
															 0 AS accountIdType,
															 null AS accountIdProvider'';
		execute sp_executesql @dynamicsql;

		
		----------------------------------------
		-- --- insert schema node					---	--
		----------------------------------------
		set @dynamicsql = N'''';
		set @dynamicsql = N''insert into tblPermissions
												select ''''Schemas'''' as name,
															 ''''@@self''''+''''/Databases/'' + @database_name + '''''' as parent_uri,
															 ''''@@self''''+''''/Databases/'' + @database_name + ''/Schemas'''' AS uri,
															 52 as type_id,
															 null AS permission_name,
															 0 AS ace_type,
															 null AS accountIdName,
															 0 AS accountIdType,
															 null AS accountIdProvider'';
		execute sp_executesql @dynamicsql;
		
		-----------------------------------------
		-- --- insert database permissions --- --
		-----------------------------------------

		--SELECT	'''''' + @database_name + '' - '' + trim(@state_desc) + '''''' AS name,	
		-- SELECT '''''' + @database_name + '''''' AS name,	
		--print @state_desc;

		-- set @dynamicsql = N''insert into tblPermissions

		exec(''insert into tblPermissions
				  SELECT	 '''''' + @database_name + '' - '' + @state_desc + '''''' AS name,	
									 ''''@@self''''+''''/Databases'''' AS parent_uri,
									 ''''@@self''''+''''/Databases/'' + @database_name + '''''' AS uri,
									 22 AS type_id,
									 P.[permission_name],
									 CASE WHEN [state_desc] LIKE ''''GRANT%'''' THEN 0
												WHEN [state_desc] LIKE ''''DENY%'''' THEN 1
												ELSE 2
									 END AS ace_type,
									 A.accountIdName,
									 A.accountIdType,
									 A.accountIdProvider
		FROM
			(-- See https://technet.microsoft.com/en-us/library/ms189612(v=sql.105).aspx
			 SELECT [class_desc], [grantee_principal_id], [permission_name], [state_desc]
			 FROM ['' + @database_name + ''].[sys].[database_permissions]			 
			 UNION
			 SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''ALTER ANY USER'''', ''''GRANT''''
			 FROM ['' + @database_name + ''].[sys].[database_principals]
			 WHERE name LIKE ''''db_accessadmin'''' and (select members from #dbrolemembers where DatabaseRoleName = ''''db_accessadmin'''') = 1
			 UNION
			 SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''CREATE SCHEMA'''', ''''GRANT''''
			 FROM ['' + @database_name + ''].[sys].[database_principals]
			 WHERE name LIKE ''''db_accessadmin'''' and (select members from #dbrolemembers where DatabaseRoleName = ''''db_accessadmin'''') = 1
			 UNION
			 
			 SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''BACKUP DATABASE'''', ''''GRANT''''
			 FROM ['' + @database_name + ''].[sys].[database_principals]
			 WHERE name LIKE ''''db_backupoperator'''' and (select members from #dbrolemembers where DatabaseRoleName = ''''db_backupoperator'''') = 1
			 UNION
			 SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''BACKUP LOG'''', ''''GRANT''''
			 FROM ['' + @database_name + ''].[sys].[database_principals]
			 WHERE name LIKE ''''db_backupoperator'''' and (select members from #dbrolemembers where DatabaseRoleName = ''''db_backupoperator'''') = 1
			 UNION
			 SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''CHECKPOINT'''', ''''GRANT''''
			 FROM ['' + @database_name + ''].[sys].[database_principals]
			 WHERE name LIKE ''''db_backupoperator'''' and (select members from #dbrolemembers where DatabaseRoleName = ''''db_backupoperator'''') = 1
			 UNION
			 
			 SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''SELECT'''', ''''GRANT''''
			 FROM ['' + @database_name + ''].[sys].[database_principals]
			 WHERE name LIKE ''''db_datareader'''' and (select members from #dbrolemembers where DatabaseRoleName = ''''db_datareader'''') = 1
			 UNION
			 SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''SELECT'''', ''''DENY''''
			 FROM ['' + @database_name + ''].[sys].[database_principals]
			 WHERE name LIKE ''''db_denydatareader'''' and (select members from #dbrolemembers where DatabaseRoleName = ''''db_denydatareader'''') = 1
			 UNION
			 --------------------------------------------------------------------------------------------------------------
			 --------------------------------------------------------------------------------------------------------------			 
			 SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''DELETE'''', ''''DENY''''
			 FROM ['' + @database_name + ''].[sys].[database_principals]
			 WHERE name LIKE ''''db_denydatareader'''' and (select members from #dbrolemembers where DatabaseRoleName = ''''db_denydatawriter'''') = 1
			 UNION
			 SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''INSERT'''', ''''DENY''''
			 FROM ['' + @database_name + ''].[sys].[database_principals]
			 WHERE name LIKE ''''db_denydatawriter'''' and (select members from #dbrolemembers where DatabaseRoleName = ''''db_denydatawriter'''') = 1
			 UNION
			 SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''UPDATE'''', ''''DENY''''
			 FROM ['' + @database_name + ''].[sys].[database_principals]
			 WHERE name LIKE ''''db_denydatawriter'''' and (select members from #dbrolemembers where DatabaseRoleName = ''''db_denydatawriter'''') = 1
			 UNION
			 --------------------------------------------------------------------------------------------------------------
			 --------------------------------------------------------------------------------------------------------------			 
			 SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''DELETE'''', ''''GRANT''''
			 FROM ['' + @database_name + ''].[sys].[database_principals]
			 WHERE name LIKE ''''db_datawriter'''' and (select members from #dbrolemembers where DatabaseRoleName = ''''db_datawriter'''') = 1
			 UNION
			 SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''INSERT'''', ''''GRANT''''
			 FROM ['' + @database_name + ''].[sys].[database_principals]
			 WHERE name LIKE ''''db_datawriter'''' and (select members from #dbrolemembers where DatabaseRoleName = ''''db_datawriter'''') = 1
			 UNION
			 SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''UPDATE'''', ''''GRANT''''
			 FROM ['' + @database_name + ''].[sys].[database_principals]
			 WHERE name LIKE ''''db_datawriter'''' and (select members from #dbrolemembers where DatabaseRoleName = ''''db_datawriter'''') = 1
			 UNION
			 --------------------------------------------------------------------------------------------------------------
			 --------------------------------------------------------------------------------------------------------------

			 SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''ALTER ANY ASSEMBLY'''', ''''GRANT''''
			 FROM ['' + @database_name + ''].[sys].[database_principals]
			 WHERE name LIKE ''''db_ddladmin'''' and (select members from #dbrolemembers where DatabaseRoleName = ''''db_ddladmin'''') = 1
			 UNION
			 SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''ALTER ANY ASYMMETRIC KEY'''', ''''GRANT''''
			 FROM ['' + @database_name + ''].[sys].[database_principals]
			 WHERE name LIKE ''''db_ddladmin'''' and (select members from #dbrolemembers where DatabaseRoleName = ''''db_ddladmin'''') = 1
			 UNION
			 SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''ALTER ANY CERTIFICATE'''', ''''GRANT''''
			 FROM ['' + @database_name + ''].[sys].[database_principals]
			 WHERE name LIKE ''''db_ddladmin'''' and (select members from #dbrolemembers where DatabaseRoleName = ''''db_ddladmin'''') = 1
			 UNION
			 SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''ALTER ANY CONTRACT'''', ''''GRANT''''
			 FROM ['' + @database_name + ''].[sys].[database_principals]
			 WHERE name LIKE ''''db_ddladmin'''' and (select members from #dbrolemembers where DatabaseRoleName = ''''db_ddladmin'''') = 1
			 UNION
			 SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''ALTER ANY DATABASE DDL TRIGGER'''', ''''GRANT''''
			 FROM ['' + @database_name + ''].[sys].[database_principals]
			 WHERE name LIKE ''''db_ddladmin'''' and (select members from #dbrolemembers where DatabaseRoleName = ''''db_ddladmin'''') = 1
			 UNION
			 SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''ALTER ANY DATABASE EVENT'''', ''''GRANT''''
			 FROM ['' + @database_name + ''].[sys].[database_principals]
			 WHERE name LIKE ''''db_ddladmin'''' and (select members from #dbrolemembers where DatabaseRoleName = ''''db_ddladmin'''') = 1
			 UNION
			 SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''NOTIFICATION'''', ''''GRANT''''
			 FROM ['' + @database_name + ''].[sys].[database_principals]
			 WHERE name LIKE ''''db_ddladmin'''' and (select members from #dbrolemembers where DatabaseRoleName = ''''db_ddladmin'''') = 1
			 UNION
			 SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''ALTER ANY DATASPACE'''', ''''GRANT''''
			 FROM ['' + @database_name + ''].[sys].[database_principals]
			 WHERE name LIKE ''''db_ddladmin'''' and (select members from #dbrolemembers where DatabaseRoleName = ''''db_ddladmin'''') = 1
			 UNION
			 SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''ALTER ANY FULLTEXT CATALOG'''', ''''GRANT''''
			 FROM ['' + @database_name + ''].[sys].[database_principals]
			 WHERE name LIKE ''''db_ddladmin'''' and (select members from #dbrolemembers where DatabaseRoleName = ''''db_ddladmin'''') = 1
			 UNION
			 SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''ALTER ANY MESSAGE TYPE'''', ''''GRANT''''
			 FROM ['' + @database_name + ''].[sys].[database_principals]
			 WHERE name LIKE ''''db_ddladmin'''' and (select members from #dbrolemembers where DatabaseRoleName = ''''db_ddladmin'''') = 1
			 UNION
			 SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''ALTER ANY REMOTE SERVICE BINDING'''', ''''GRANT''''
			 FROM ['' + @database_name + ''].[sys].[database_principals]
			 WHERE name LIKE ''''db_ddladmin'''' and (select members from #dbrolemembers where DatabaseRoleName = ''''db_ddladmin'''') = 1
			 UNION
			 SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''ALTER ANY ROUTE'''', ''''GRANT''''
			 FROM ['' + @database_name + ''].[sys].[database_principals]
			 WHERE name LIKE ''''db_ddladmin'''' and (select members from #dbrolemembers where DatabaseRoleName = ''''db_ddladmin'''') = 1
			 UNION
			 SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''ALTER ANY SCHEMA'''', ''''GRANT''''
			 FROM ['' + @database_name + ''].[sys].[database_principals]
			 WHERE name LIKE ''''db_ddladmin'''' and (select members from #dbrolemembers where DatabaseRoleName = ''''db_ddladmin'''') = 1
			 UNION
			 SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''ALTER ANY SERVICE'''', ''''GRANT''''
			 FROM ['' + @database_name + ''].[sys].[database_principals]
			 WHERE name LIKE ''''db_ddladmin'''' and (select members from #dbrolemembers where DatabaseRoleName = ''''db_ddladmin'''') = 1
			 UNION
			 SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''ALTER ANY SYMMETRIC KEY'''', ''''GRANT''''
			 FROM ['' + @database_name + ''].[sys].[database_principals]
			 WHERE name LIKE ''''db_ddladmin'''' and (select members from #dbrolemembers where DatabaseRoleName = ''''db_ddladmin'''') = 1
			 UNION
			 SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''CHECKPOINT'''', ''''GRANT''''
			 FROM ['' + @database_name + ''].[sys].[database_principals]
			 WHERE name LIKE ''''db_ddladmin'''' and (select members from #dbrolemembers where DatabaseRoleName = ''''db_ddladmin'''') = 1
			 UNION
			 SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''CREATE AGGREGATE'''', ''''GRANT''''
			 FROM ['' + @database_name + ''].[sys].[database_principals]
			 WHERE name LIKE ''''db_ddladmin'''' and (select members from #dbrolemembers where DatabaseRoleName = ''''db_ddladmin'''') = 1
			 UNION
			 SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''CREATE DEFAULT'''', ''''GRANT''''
			 FROM ['' + @database_name + ''].[sys].[database_principals]
			 WHERE name LIKE ''''db_ddladmin'''' and (select members from #dbrolemembers where DatabaseRoleName = ''''db_ddladmin'''') = 1
			 UNION
			 SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''CREATE FUNCTION'''', ''''GRANT''''
			 FROM ['' + @database_name + ''].[sys].[database_principals]
			 WHERE name LIKE ''''db_ddladmin'''' and (select members from #dbrolemembers where DatabaseRoleName = ''''db_ddladmin'''') = 1
			 UNION
			 SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''CREATE PROCEDURE'''', ''''GRANT''''
			 FROM ['' + @database_name + ''].[sys].[database_principals]
			 WHERE name LIKE ''''db_ddladmin'''' and (select members from #dbrolemembers where DatabaseRoleName = ''''db_ddladmin'''') = 1
			 UNION
			 SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''CREATE QUEUE'''', ''''GRANT''''
			 FROM ['' + @database_name + ''].[sys].[database_principals]
			 WHERE name LIKE ''''db_ddladmin'''' and (select members from #dbrolemembers where DatabaseRoleName = ''''db_ddladmin'''') = 1
			 UNION
			 SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''CREATE RULE'''', ''''GRANT''''
			 FROM ['' + @database_name + ''].[sys].[database_principals]
			 WHERE name LIKE ''''db_ddladmin'''' and (select members from #dbrolemembers where DatabaseRoleName = ''''db_ddladmin'''') = 1
			 UNION
			 SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''CREATE SYNONYM'''', ''''GRANT''''
			 FROM ['' + @database_name + ''].[sys].[database_principals]
			 WHERE name LIKE ''''db_ddladmin'''' and (select members from #dbrolemembers where DatabaseRoleName = ''''db_ddladmin'''') = 1
			 UNION
			 SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''CREATE TABLE'''', ''''GRANT''''
			 FROM ['' + @database_name + ''].[sys].[database_principals]
			 WHERE name LIKE ''''db_ddladmin'''' and (select members from #dbrolemembers where DatabaseRoleName = ''''db_ddladmin'''') = 1
			 UNION
			 SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''CREATE TYPE'''', ''''GRANT''''
			 FROM ['' + @database_name + ''].[sys].[database_principals]
			 WHERE name LIKE ''''db_ddladmin'''' and (select members from #dbrolemembers where DatabaseRoleName = ''''db_ddladmin'''') = 1
			 UNION
			 SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''CREATE VIEW'''', ''''GRANT''''
			 FROM ['' + @database_name + ''].[sys].[database_principals]
			 WHERE name LIKE ''''db_ddladmin'''' and (select members from #dbrolemembers where DatabaseRoleName = ''''db_ddladmin'''') = 1
			 UNION
			 SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''CREATE XML SCHEMA COLLECTION'''', ''''GRANT''''
			 FROM ['' + @database_name + ''].[sys].[database_principals]
			 WHERE name LIKE ''''db_ddladmin'''' and (select members from #dbrolemembers where DatabaseRoleName = ''''db_ddladmin'''') = 1
			 UNION
			 SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''REFERENCES'''', ''''GRANT''''
			 FROM ['' + @database_name + ''].[sys].[database_principals]
			 WHERE name LIKE ''''db_ddladmin'''' and (select members from #dbrolemembers where DatabaseRoleName = ''''db_ddladmin'''') = 1
			 UNION
			 --------------------------------------------------------------------------------------------------------------
			 --------------------------------------------------------------------------------------------------------------
			 SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''CONTROL'''', ''''GRANT''''
			 FROM ['' + @database_name + ''].[sys].[database_principals]
			 WHERE name LIKE ''''db_owner'''' and (select members from #dbrolemembers where DatabaseRoleName = ''''db_owner'''') = 1
			 UNION
			 --------------------------------------------------------------------------------------------------------------
			 --------------------------------------------------------------------------------------------------------------
			 SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''ALTER ANY APPLICATION ROLE,'''', ''''GRANT''''
			 FROM ['' + @database_name + ''].[sys].[database_principals]
			 WHERE name LIKE ''''db_securityadmin'''' and (select members from #dbrolemembers where DatabaseRoleName = ''''db_securityadmin'''') = 1
			 UNION
			 SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''ALTER ANY ROLE,'''', ''''GRANT''''
			 FROM ['' + @database_name + ''].[sys].[database_principals]
			 WHERE name LIKE ''''db_securityadmin'''' and (select members from #dbrolemembers where DatabaseRoleName = ''''db_securityadmin'''') = 1
			 UNION
			 SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''CREATE SCHEMA,'''', ''''GRANT''''
			 FROM ['' + @database_name + ''].[sys].[database_principals]
			 WHERE name LIKE ''''db_securityadmin'''' and (select members from #dbrolemembers where DatabaseRoleName = ''''db_securityadmin'''') = 1
			 UNION
			 SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''VIEW DEFINITION,'''', ''''GRANT''''
			 FROM ['' + @database_name + ''].[sys].[database_principals]
			 WHERE name LIKE ''''db_securityadmin'''' and (select members from #dbrolemembers where DatabaseRoleName = ''''db_securityadmin'''') = 1
			 UNION
			 --------------------------------------------------------------------------------------------------------------
			 --------------------------------------------------------------------------------------------------------------
			 SELECT ''''DATABASE'''', [principal_id] AS [grantee_principal_id], ''''VIEW,'''', ''''GRANT''''
			 FROM ['' + @database_name + ''].[sys].[database_principals]
			 WHERE name LIKE ''''dbm_monitor'''' and (select members from #dbrolemembers where DatabaseRoleName = ''''dbm_monitor'''') = 1
			) AS P
			INNER JOIN (
				SELECT
					[principal_id],
					CASE WHEN [type] = ''''S'''' THEN [name] + ''''@'' + @database_name + ''''''
							 WHEN [type] = ''''R'''' THEN [name] + ''''@'' + @database_name + ''''''
							 WHEN [type] = ''''C'''' THEN [name] + ''''@'' + @database_name + ''''''
							 WHEN [type] = ''''U'''' THEN dbo.sidToString(sid)
							 WHEN [type] = ''''G'''' THEN dbo.sidToString(sid)
							 ELSE ''''''''
					END AS accountIdName,
					CASE WHEN [type] = ''''S'''' THEN 1
							 WHEN [type] = ''''R'''' THEN 1
							 WHEN [type] = ''''C'''' THEN 1
							 WHEN [type] = ''''U'''' THEN 3
							 WHEN [type] = ''''G'''' THEN 3
							 ELSE 0
					END AS accountIdType,
					CASE WHEN [type] = ''''S'''' THEN ''''@@self''''
							 WHEN [type] = ''''R'''' THEN ''''@@self''''
							 WHEN [type] = ''''C'''' THEN ''''@@self''''
							 WHEN [type] = ''''U'''' THEN SUBSTRING(SUSER_SNAME(sid), 0, CHARINDEX(''''\'''', SUSER_SNAME(sid)))
							 WHEN [type] = ''''G'''' THEN SUBSTRING(SUSER_SNAME(sid), 0, CHARINDEX(''''\'''', SUSER_SNAME(sid)))
							 ELSE ''''''''
					END AS accountIdProvider
				FROM ['' + @database_name + ''].[sys].[database_principals]
				WHERE [type] IN (''''S'''', ''''R'''', ''''C'''', ''''U'''', ''''G'''')
				-- WHERE NOT ([name] LIKE ''''##%'''') AND [type] IN (''''S'''', ''''R'''', ''''U'''', ''''G'''')

		) AS A
			ON P.[class_desc] = ''''DATABASE'''' AND P.[grantee_principal_id] = A.[principal_id]
		'');
		--print len(@dynamicsql);
		--print @dynamicsql;
		--execute sp_executesql @dynamicsql;
		-- truncate table #dbrolemembers;


		-------------------------------------------------------------------------------------------------------------------
		-- --- hier wird die Collation der Datenbank abgefragt und im nächsten Schritt der Spalte										 --- --
		-- --- table_name in der temporären Tabelle #tbl_privileges auf die Collation der Datenbank gesetzt.				 --- --
		-- --- Dies ist notwendig damit auch die Tabellennamen in die #tbl_privileges eingetragen werden können.     --- --
		-------------------------------------------------------------------------------------------------------------------
		set @collation = (select convert(varchar, databasepropertyex(@database_name, ''collation'')));
		-- print @database_name + '' - '' + @collation;


		set @dynamicsql = N''alter table #tbl_privileges alter column table_name sysname collate '' + @collation + '''';
		-- print @dynamicsql;
    execute sp_executesql @dynamicsql;
		--------------------------------------------------------------------------------------------------------------------------
		--------------------------------------------------------------------------------------------------------------------------
		
		set @exec_sp = quotename(@database_name) + N''.sys.sp_table_privileges @table_name = ''''%%'''''';
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

    --------------------------------------
		-- --- insert users permissions --- --
		--------------------------------------
		set @dynamicsql = N''insert into tblPermissions
												select	p.grantee as name, 
																''''@@self'''' + ''''/Databases/'' + @database_name + ''/Users'''' as parent_uri, 
																''''@@self'''' + ''''/Databases/'' + @database_name + ''/Users/'''' + p.grantee as uri,
																22 as type_id,				
																p.privilege as permission_name,
																0 as ace_type,
																-- p.grantee as accountIdName,
																case when p.acctype = ''''S'''' then p.grantee + ''''@'' + @database_name + ''''''
																		 when p.acctype = ''''R'''' then p.grantee + ''''@'' + @database_name + ''''''
																		 when p.acctype = ''''C'''' then p.grantee + ''''@'' + @database_name + ''''''
																		 when p.acctype = ''''K'''' then p.grantee + ''''@'' + @database_name + ''''''
																		 when p.acctype = ''''U'''' then dbo.sidtostring(p.sid)
																		 when p.acctype = ''''G'''' then dbo.sidtostring(p.sid)
																		 else ''''''''
																end as accountIdName,
																case	when p.acctype = ''''S'''' then 1
																			when p.acctype = ''''R'''' then 1
																			when p.acctype = ''''C'''' then 1
																			when p.acctype = ''''K'''' then 1
																			when p.acctype = ''''U'''' then 3
																			when p.acctype = ''''G'''' then 3
																			else 0
																end as accountIdType,
																case	when p.acctype = ''''S'''' then ''''@@self''''
																			when p.acctype = ''''R'''' then ''''@@self''''
																			when p.acctype = ''''C'''' then ''''@@self''''
																			when p.acctype = ''''K'''' then ''''@@self''''
																			when p.acctype = ''''U'''' then substring(suser_sname(p.sid), 0, charindex(''''\'''', suser_sname(p.sid)))
																			when p.acctype = ''''G'''' then substring(suser_sname(p.sid), 0, charindex(''''\'''', suser_sname(p.sid)))
																			else ''''''''
																end as accountIdProvider								
																-- select p.*										
												from 	( 
																select  '''''' + @database_name + '''''' as db_name,
																				perm.permission_name as privilege,
																				princ.name as grantee,
																				princ.type as accType,
																				princ.sid as sid,
																				princ.type_desc,
																				perm.state_desc
																from '' + @database_name + ''.sys.database_principals as princ
																left join '' + @database_name + ''.sys.database_permissions as perm on perm.grantee_principal_id = princ.principal_id
																where princ.type <> ''''R''''
															) p;''

		-- print @dynamicsql;
		-- exec sp_executesql @dynamicsql;

    --------------------------------------
		-- --- insert table permissions --- --
		--------------------------------------
		if @skip_userdb_table_permissions = 1
		  goto skip_userdb_table_permissions;
		set @dynamicsql = N''insert into tblPermissions
												select	p.table_name as name, 
																''''@@self'''' + ''''/Databases/'' + @database_name + ''/Tables'''' as parent_uri, 
																''''@@self'''' + ''''/Databases/'' + @database_name + ''/Tables/'''' + p.table_name as uri,
																22 as type_id,				
																p.privilege as permission_name,
																0 as ace_type,
																-- p.grantee as accountIdName,
																case when p.acctype = ''''S'''' then p.grantee + ''''@'' + @database_name + ''''''
																		 when p.acctype = ''''R'''' then p.grantee + ''''@'' + @database_name + ''''''
																		 when p.acctype = ''''C'''' then p.grantee + ''''@'' + @database_name + ''''''
																		 when p.acctype = ''''K'''' then p.grantee + ''''@'' + @database_name + ''''''
																		 when p.acctype = ''''U'''' then dbo.sidtostring(p.sid)
																		 when p.acctype = ''''G'''' then dbo.sidtostring(p.sid)
																		 else ''''''''
																end as accountIdName,
																case	when p.acctype = ''''S'''' then 1
																			when p.acctype = ''''R'''' then 1
																			when p.acctype = ''''C'''' then 1
																			when p.acctype = ''''K'''' then 1
																			when p.acctype = ''''U'''' then 3
																			when p.acctype = ''''G'''' then 3
																			else 0
																end as accountIdType,
																case	when p.acctype = ''''S'''' then ''''@@self''''
																			when p.acctype = ''''R'''' then ''''@@self''''
																			when p.acctype = ''''C'''' then ''''@@self''''
																			when p.acctype = ''''K'''' then ''''@@self''''
																			when p.acctype = ''''U'''' then substring(suser_sname(p.sid), 0, charindex(''''\'''', suser_sname(p.sid)))
																			when p.acctype = ''''G'''' then substring(suser_sname(p.sid), 0, charindex(''''\'''', suser_sname(p.sid)))
																			else ''''''''
																end as accountIdProvider								
																-- select p.*										
												from 	( 
																--select tblp.table_qualifier, tblp.privilege, tblp.table_name, tblp.grantee, dp.type as accType, dp.sid as sid, t.type, t.schema_id from #tbl_privileges tblp
																--	join '' + @database_name + ''.sys.tables as t on t.name collate Latin1_General_CI_AS = tblp.table_name
																--	left join '' + @database_name + ''.sys.database_principals as dp on dp.name collate Latin1_General_CI_AS = tblp.grantee
																--where tblp.grantee <> ''''dbo''''
																select  '''''' + @database_name + '''''' as table_qualifier,
																				perm.permission_name as privilege,
																				princ.name as grantee,
																				princ.type as accType,
																				princ.sid as sid,
																				princ.type_desc,
																				perm.state_desc,
																				object_name(perm.major_id) as objectname,
																				-- concat(s.name, ''''.'''', t.name) as table_name,
																				s.name + ''''.'''' + t.name as table_name,
																				t.type,
																				t.schema_id
																from '' + @database_name + ''.sys.database_principals princ
																left join '' + @database_name + ''.sys.database_permissions perm on perm.grantee_principal_id = princ.principal_id
																inner join '' + @database_name + ''.sys.tables t on perm.major_id = t.object_id
																inner join '' + @database_name + ''.sys.schemas as s on s.schema_id = t.schema_id
															) p;''

		-- print @dynamicsql;
		exec sp_executesql @dynamicsql;
		skip_userdb_table_permissions:

    --------------------------------------
		-- --- insert view permissions --- --
		--------------------------------------
		set @dynamicsql = N''insert into tblPermissions
												select	p.view_name as name, 
																''''@@self'''' + ''''/Databases/'' + @database_name + ''/Views'''' as parent_uri, 
																''''@@self'''' + ''''/Databases/'' + @database_name + ''/Views/'''' + p.view_name as uri,
																22 as type_id,				
																p.privilege as permission_name,
																0 as ace_type,
																-- p.grantee as accountIdName,
																case when p.acctype = ''''S'''' then p.grantee + ''''@'' + @database_name + ''''''
																		 when p.acctype = ''''R'''' then p.grantee + ''''@'' + @database_name + ''''''
																		 when p.acctype = ''''C'''' then p.grantee + ''''@'' + @database_name + ''''''
																		 when p.acctype = ''''K'''' then p.grantee + ''''@'' + @database_name + ''''''
																		 when p.acctype = ''''U'''' then dbo.sidtostring(p.sid)
																		 when p.acctype = ''''G'''' then dbo.sidtostring(p.sid)
																		 else ''''''''
																end as accountIdName,
																case	when p.acctype = ''''S'''' then 1
																			when p.acctype = ''''R'''' then 1
																			when p.acctype = ''''C'''' then 1
																			when p.acctype = ''''K'''' then 1
																			when p.acctype = ''''U'''' then 3
																			when p.acctype = ''''G'''' then 3
																			else 0
																end as accountIdType,
																case	when p.acctype = ''''S'''' then ''''@@self''''
																			when p.acctype = ''''R'''' then ''''@@self''''
																			when p.acctype = ''''C'''' then ''''@@self''''
																			when p.acctype = ''''K'''' then ''''@@self''''
																			when p.acctype = ''''U'''' then substring(suser_sname(p.sid), 0, charindex(''''\'''', suser_sname(p.sid)))
																			when p.acctype = ''''G'''' then substring(suser_sname(p.sid), 0, charindex(''''\'''', suser_sname(p.sid)))
																			else ''''''''
																end as accountIdProvider				

												-- select p.*										
												from 	( 
																--select tblp.table_qualifier, tblp.privilege, tblp.table_name, tblp.grantee, dp.type as accType, dp.sid as sid, v.type, v.schema_id from #tbl_privileges tblp
																--	join '' + @database_name + ''.sys.views as v on v.name collate Latin1_General_CI_AS = tblp.table_name
																--	left join '' + @database_name + ''.sys.database_principals as dp on dp.name collate Latin1_General_CI_AS = tblp.grantee 
																--where tblp.grantee <> ''''dbo''''
																select  '''''' + @database_name + '''''' as table_qualifier,
																				perm.permission_name as privilege,
																				princ.name as grantee,
																				princ.type as accType,
																				princ.sid as sid,
																				princ.type_desc,
																				perm.state_desc,
																				object_name(perm.major_id) as objectname,
																				-- concat(s.name collate '' + @collation + '', ''''.'''', v.name collate '' + @collation + '') as view_name,
																				s.name + ''''.'''' + v.name as view_name,
																				v.type,
																				v.schema_id
																from '' + @database_name + ''.sys.database_principals princ
																left join '' + @database_name + ''.sys.database_permissions perm on perm.grantee_principal_id = princ.principal_id
																inner join '' + @database_name + ''.sys.views v on perm.major_id = v.object_id
																inner join '' + @database_name + ''.sys.schemas as s on s.schema_id = v.schema_id
															) p;''
		-- print @dynamicsql;
		exec sp_executesql @dynamicsql;


		--------------------------------------------------
		-- --- insert stored procedures permissions --- --
		--------------------------------------------------
		set @dynamicsql = N''insert into tblPermissions
												select	p.sp_name as name, 
																''''@@self'''' + ''''/Databases/'' + @database_name + ''/Stored Procedures'''' as parent_uri, 
																''''@@self'''' + ''''/Databases/'' + @database_name + ''/Stored Procedures/'''' + p.sp_name as uri,
																22 as type_id,				
																p.privilege as permission_name,
																0 as ace_type,
																-- p.grantee as accountIdName,
																case when p.acctype = ''''S'''' then p.grantee + ''''@'' + @database_name + ''''''
																		 when p.acctype = ''''R'''' then p.grantee + ''''@'' + @database_name + ''''''
																		 when p.acctype = ''''C'''' then p.grantee + ''''@'' + @database_name + ''''''
																		 when p.acctype = ''''K'''' then p.grantee + ''''@'' + @database_name + ''''''
																		 when p.acctype = ''''U'''' then dbo.sidtostring(p.sid)
																		 when p.acctype = ''''G'''' then dbo.sidtostring(p.sid)
																		 else ''''''''
																end as accountIdName,
																case	when p.acctype = ''''S'''' then 1
																			when p.acctype = ''''R'''' then 1
																			when p.acctype = ''''C'''' then 1
																			when p.acctype = ''''K'''' then 1
																			when p.acctype = ''''U'''' then 3
																			when p.acctype = ''''G'''' then 3
																			else 0
																end as accountIdType,
																case	when p.acctype = ''''S'''' then ''''@@self''''
																			when p.acctype = ''''R'''' then ''''@@self''''
																			when p.acctype = ''''C'''' then ''''@@self''''
																			when p.acctype = ''''K'''' then ''''@@self''''
																			when p.acctype = ''''U'''' then substring(suser_sname(p.sid), 0, charindex(''''\'''', suser_sname(p.sid)))
																			when p.acctype = ''''G'''' then substring(suser_sname(p.sid), 0, charindex(''''\'''', suser_sname(p.sid)))
																			else ''''''''
																end as accountIdProvider				
																-- select p.*										
												from 	( 
																--select procs.name as sp_name, dpe.permission_name as privilege, dpr.name as grantee, dpr.type as accType, dpr.sid as sid from '' + @database_name + ''.sys.database_permissions as dpe
																--join '' + @database_name + ''.sys.procedures as procs on procs.object_id = dpe.major_id
																--join '' + @database_name + ''.sys.database_principals as dpr on dpr.principal_id = dpe.grantee_principal_id
																--where procs.object_id not in(select major_id from '' + @database_name + ''.sys.extended_properties)
																select  '''''' + @database_name + '''''' as table_qualifier,
																				perm.permission_name as privilege,
																				princ.name as grantee,
																				princ.type as accType,
																				princ.sid as sid,
																				princ.type_desc,
																				perm.state_desc,
																				object_name(perm.major_id) as objectname,
																				-- concat(s.name collate '' + @collation + '', ''''.'''', p.name collate '' + @collation + '') collate '' + @collation + '' as sp_name,
																				s.name + ''''.'''' + p.name as sp_name,
																				p.type,
																				p.schema_id
																from '' + @database_name + ''.sys.database_principals princ
																left join '' + @database_name + ''.sys.database_permissions perm on perm.grantee_principal_id = princ.principal_id
																inner join '' + @database_name + ''.sys.procedures p on perm.major_id = p.object_id
																inner join '' + @database_name + ''.sys.schemas as s on s.schema_id = p.schema_id
															) p'';


		-- print @dynamicsql;
		exec sp_executesql @dynamicsql;

		---------------------------------------
		-- --- insert schema permissions --- --
		---------------------------------------
		set @dynamicsql = N''insert into tblPermissions
												select	p.schema_names as name, 
																''''@@self'''' + ''''/Databases/'' + @database_name + ''/Schemas'''' as parent_uri, 
																''''@@self'''' + ''''/Databases/'' + @database_name + ''/Schemas/'''' + p.schema_names as uri,
																22 as type_id,				
																p.privilege as permission_name,
																0 as ace_type,
																-- p.grantee as accountIdName,
																case when p.acctype = ''''S'''' then p.grantee + ''''@'' + @database_name + ''''''
																		 when p.acctype = ''''R'''' then p.grantee + ''''@'' + @database_name + ''''''
																		 when p.acctype = ''''C'''' then p.grantee + ''''@'' + @database_name + ''''''
																		 when p.acctype = ''''K'''' then p.grantee + ''''@'' + @database_name + ''''''
																		 when p.acctype = ''''U'''' then dbo.sidtostring(p.sid)
																		 when p.acctype = ''''G'''' then dbo.sidtostring(p.sid)
																		 else ''''''''
																end as accountIdName,
																case	when p.acctype = ''''S'''' then 1
																			when p.acctype = ''''R'''' then 1
																			when p.acctype = ''''C'''' then 1
																			when p.acctype = ''''K'''' then 1
																			when p.acctype = ''''U'''' then 3
																			when p.acctype = ''''G'''' then 3
																			else 0
																end as accountIdType,
																case	when p.acctype = ''''S'''' then ''''@@self''''
																			when p.acctype = ''''R'''' then ''''@@self''''
																			when p.acctype = ''''C'''' then ''''@@self''''
																			when p.acctype = ''''K'''' then ''''@@self''''
																			when p.acctype = ''''U'''' then substring(suser_sname(p.sid), 0, charindex(''''\'''', suser_sname(p.sid)))
																			when p.acctype = ''''G'''' then substring(suser_sname(p.sid), 0, charindex(''''\'''', suser_sname(p.sid)))
																			else ''''''''
																end as accountIdProvider				
																-- select p.*										
												from 	( 
																select s.name as schema_names, perm.permission_name as privilege, prin.name as grantee, prin.type as accType, prin.sid as sid 
																from '' + @database_name + ''.sys.database_permissions as perm 
																join '' + @database_name + ''.sys.schemas as s	on perm.major_id = s.schema_id
																join '' + @database_name + ''.sys.database_principals as prin on prin.principal_id = perm.grantee_principal_id
																where perm.class_desc = ''''SCHEMA''''
															) p'';

  
		-- print @dynamicsql;
		exec sp_executesql @dynamicsql;


		--------------------------------------------
		-- --- insert user database roles			--- --
		--------------------------------------------
		set @dynamicsql = N''insert into tblPermissions
												select	distinct p.grantee as name, 
																''''@@self'''' + ''''/Databases/'' + @database_name + ''/Database Roles'''' as parent_uri, 
																''''@@self'''' + ''''/Databases/'' + @database_name + ''/Database Roles/'''' + p.grantee as uri,
																22 as type_id,				
																-- p.privilege as permission_name,
																-- NULL as permission_name,
																tp.permission_name as permission_name,
																0 as ace_type,
																-- p.grantee as accountIdName,
																case when p.acctype = ''''R'''' then p.grantee + ''''@'' + @database_name + ''''''
																		 else ''''''''
																end as accountIdName,
																case	when p.acctype = ''''R'''' then 1
																			else 0
																end as accountIdType,
																case	when p.acctype = ''''R'''' then ''''@@self''''
																			else ''''''''
																end as accountIdProvider								
												-- select p.*
												from 	( select  '''''' + @database_name + '''''' as db_name,
																				perm.permission_name as privilege,
																				princ.name as grantee,
																				princ.type as accType,
																				princ.sid as sid,
																				princ.type_desc,
																				perm.state_desc
																from '' + @database_name + ''.sys.database_principals as princ
																left join '' + @database_name + ''.sys.database_permissions as perm 
																on perm.grantee_principal_id = princ.principal_id
																where princ.type = ''''R''''
															) as p
												left outer join msdb.dbo.tblPermissions as tp 
												on p.grantee + ''''@'' + @database_name + '''''' collate '' + @collation + '' = tp.accountidname collate '' + @collation + ''
												where tp.permission_name is not null;''
		-- SQL_Latin1_General_CP1_CI_AS
		-- print @dynamicsql;
		exec sp_executesql @dynamicsql;

	  --print @dbname;  
		db_not_online:
		set @loopcounter  = @loopcounter  + 1;		
		truncate table #dbrolemembers;
		truncate table #tbl_privileges;
		if @debug = 1	and @skip_userdbs = 0
		  print ''END USER DATABASE: '' + @database_name;
	end;
if @debug = 1	and @skip_userdbs = 0
  print ''END USER DATABASES'';
skip_userdbs:

--------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------

----------------------------------
--			Security subtree				--
----------------------------------

-- Add ''Security'' node to result
insert into tblPermissions
SELECT ''Security'' AS name,
       ''@@self'' AS parent_uri,
       ''@@self''+''/Security'' AS uri,
			 53 AS type_id,
			 null AS permission_name,
			 0 AS ace_type,
			 null AS accountIdName,
			 0 AS accountIdType,
			 null AS accountIdProvider

-- Add ''Logins'' node to result
insert into tblPermissions
SELECT ''Logins'' AS name,
       ''@@self''+''/Security'' AS parent_uri,
       ''@@self''+''/Security/Logins'' AS uri,
			 53 AS type_id,
			 null AS permission_name,
			 0 AS ace_type,
			 null AS accountIdName,
			 0 AS accountIdType,
			 null AS accountIdProvider

-- Add logins to result
insert into tblPermissions
SELECT A.[name],
       ''@@self'' + ''/Security/Logins'',
			 ''@@self'' + ''/Security/Logins/'' + A.[name],
			 -- 83, 
			 case when a.is_disabled = 1 then 80
						ELSE 83
			 end, 				
			 P.[permission_name],
			 CASE WHEN P.[state_desc] LIKE ''GRANT%'' THEN 0
						ELSE 1
			 END AS ace_type,
			 S.accountIdName,
			 S.accountIdType,
			 S.accountIdProvider
FROM (SELECT CAST(''@@self'' AS NVARCHAR(MAX)) AS name,
             CAST('''' AS NVARCHAR(MAX)) AS parent_uri,
             CAST(''@@self'' AS NVARCHAR(MAX)) AS uri,
	         10 AS type_id) AS R
INNER JOIN #accountPermissions AS P ON P.[class_desc] = ''LOGIN''
INNER JOIN [master].[sys].[server_principals] A ON A.[type] IN (''S'', ''C'', ''K'', ''U'', ''G'')
INNER JOIN #serverAccountIds AS S ON P.[grantee_principal_id] = S.[principal_id]


-- Add ''Server Roles'' node to result
insert into tblPermissions
SELECT ''Server Roles'' AS name,
       ''@@self''+''/Security'' AS parent_uri,
       ''@@self''+''/Security/Server Roles'' AS uri,
			 53 AS type_id,
			 null AS permission_name,
			 0 AS ace_type,
			 null AS accountIdName,
			 0 AS accountIdType,
			 null AS accountIdProvider

-- Add server roles to result
insert into tblPermissions
SELECT A.[name],
       ''@@self'' + ''/Security/Server Roles'',
			 ''@@self'' + ''/Security/Server Roles/'' + A.[name],
			 123, 
			 P.[permission_name],
			 CASE WHEN P.state_desc LIKE ''GRANT%'' THEN 0
						ELSE 1
			 END AS ace_type,
			 S.accountIdName,
			 S.accountIdType,
			 S.accountIdProvider
FROM (SELECT CAST(''@@self'' AS NVARCHAR(MAX)) AS name,
             CAST('''' AS NVARCHAR(MAX)) AS parent_uri,
             CAST(''@@self'' AS NVARCHAR(MAX)) AS uri,
	           10 AS type_id) AS R
INNER JOIN #accountPermissions AS P ON P.[class_desc] = ''SERVER ROLE''
INNER JOIN [master].[sys].[server_principals] A ON A.[type] IN (''R'')
INNER JOIN #serverAccountIds AS S ON P.[grantee_principal_id] = S.[principal_id]


-- SELECT RESULT

-- SELECT * FROM #result
if @result_output = 1
  begin
		select [name],
					 [parent_uri],
					 [uri],
					 [type_id],
					 [permission_name],
					 [ace_type],
					 [accountidname],
					 [accountidtype],
					 [accountidprovider]
			from [msdb].[dbo].[tblPermissions] 
			-- where accountidname = ''sysadmin'';
		drop table msdb.dbo.tblPermissions;	
	end


-- CLEANUP
--truncate table tblPermissions;
drop table #tbl_privileges;
--drop table #result;
drop table #dbrolemembers;
drop table #serverAccountIds;
drop table #accountPermissions;
drop table #user_databases;
drop table #system_databases;

set statistics io off


-- SELECT name,type_desc,is_disabled,modify_date,default_database_name from sys.server_principals order by type_desc', 
		@database_name=N'msdb', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'dba - arm_easyconnect_permissions', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20190614, 
		@active_end_date=99991231, 
		@active_start_time=5500, 
		@active_end_time=235959, 
		@schedule_uid=N'ba160b73-dc87-4756-8f75-6abb84725549'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


