
USE [msdb]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create or ALTER procedure [dbo].[smi_sp_drop_database] @rcpto nvarchar(200), @check int = 0, @skipdbs varchar(255) = ''
-- alter procedure [dbo].[sp_smi_get_long_running_queries] @rcpto nvarchar(200)
as
begin
	------------------------------------------------------------------------
	-- --- author: Marcus Deubel																			--- --
	-- --- copyright: (c) 2019 Marcus Deubel													---	--
	-- --- license: BSD License																				--- --
	-- --- description: stored procedure to drop database automaticly --- --
	------------------------------------------------------------------------
	-- set nocount on added to prevent extra result sets from
	-- interfering with select statements.
	set nocount on;

	declare @xml nvarchar(max) = N'';
	declare @table nvarchar(max);
	declare @header nvarchar(max);
	declare @temp nvarchar(255) = N'';

	declare @loopcounter int;
	declare @maxid int;
	declare @dynamicsql nvarchar(max);
	declare @database_name nvarchar(255) = N'';

	--declare @skipdbs nvarchar(max) = N'';
	--set @skipdbs = '_8ManDB,one_TB_database,system_mdw,StackOverflow'; -- database ids
	
	----------------------------------------------------------------
  -- --- holt alle Datenbanken mit bestehenden Verbindungen --- --
	----------------------------------------------------------------
	select identity(int, 1, 1) as id, db.name as dbname, count(ps.dbid) as NumberOfConnections, db.database_id, db.state_desc
	into #skiped_databases
	from master.sys.databases as db 
	left outer join sys.sysprocesses as ps on db.database_id = ps.dbid
	where db_name(db.database_id) not in (select trim(value) from string_split(@skipdbs, ',')) and ps.dbid > 4
	group by name, database_id, state_desc

	-----------------------------------------------------------------
	-- --- fügt die Datenbanken zur aktuellen Skip Liste hinzu --- --
	-----------------------------------------------------------------
	set @temp = (select dbname from #skiped_databases);
	set @temp = concat(',', @temp);
	set @skipdbs = concat(@skipdbs, @temp);


	-----------------------------------------------------------------
	-- --- temporäre Tabelle für die zu löschenden Datenbanken --- --
	-----------------------------------------------------------------
	select identity(int, 1, 1) as id, name as dbname
	into #user_databases
	from sys.sysdatabases as sysdbs 
	where db_name(sysdbs.dbid) not in (select trim(value) from string_split(@skipdbs, ',')) and sysdbs.dbid > 4


	
	set @loopcounter = 1;
	select @maxid = max(id) from #user_databases;
	print @maxid;
	----------------------------------------------------
	-- --- Schleife um die Datenbanken zu löschen --- --
	----------------------------------------------------
	while(@loopcounter <= @maxid)
		begin
			print @loopcounter;
			print @maxid;
			select @database_name = dbname
			from #user_databases where id = @loopcounter;

			set @dynamicsql = N'use master; drop database if exists ' + @database_name + ';';
			-- print @dynamicsql;
			exec sp_executesql @dynamicsql;
			set @loopcounter = @loopcounter  + 1;    
		end
	select * from #user_databases;
	drop table #user_databases;
end
