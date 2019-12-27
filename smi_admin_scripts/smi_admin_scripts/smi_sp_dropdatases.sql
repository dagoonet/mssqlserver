USE [msdb]
GO
/****** Object:  StoredProcedure [dbo].[sp_smi_get_long_running_queries]    Script Date: 11.04.2019 15:54:25 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--------------------------------------------------------------------
-- --- author:		Marcus Deubel																---	--				
-- --- create date: 14.11.2019																---	--
-- --- description:	drop databases except @skipdbs						--- --
--------------------------------------------------------------------
if object_id('smi_sp_drop_database', 'p') is not null
  drop procedure dbo.smi_sp_drop_database
go
create or alter procedure [dbo].[smi_sp_drop_database] @rcpto nvarchar(200), @check int = 0 --, @skipdbs varchar(50) = ''
as
begin
	-- set nocount on added to prevent extra result sets from
	-- interfering with select statements.
	set nocount on;

	declare @xml nvarchar(max) = N'';
	declare @table nvarchar(max);
	declare @header nvarchar(max);

	declare @loopcounter int;
	declare @maxid int;
	declare @dynamicsql nvarchar(max);
	declare @database_name nvarchar(max);

	declare @skipdbs nvarchar(max) = N'';
	set @skipdbs = '_8ManDB,one_TB_database,system_mdw,StackOverflow'; -- database ids
	
	-- user databases --
  select identity(int, 1, 1) as id, name as dbname
	into #user_databases
	from sys.sysdatabases as sysdbs 
	where sysdbs.name not in (select trim(value) from string_split(@skipdbs, ',')) and sysdbs.dbid > 4

	set @loopcounter = 1;
	select @maxid = max(id) from #user_databases;
	print @maxid;
	while(@loopcounter <= @maxid)
		begin
			print @loopcounter;
			print @maxid;
			select @database_name = dbname
			from #user_databases where id = @loopcounter;

			set @dynamicsql = N'use master; drop database if exists ' + @database_name + ';';
			print @dynamicsql;
			exec sp_executesql @dynamicsql;
			set @loopcounter = @loopcounter  + 1;    
		end
	select * from #user_databases;
	drop table #user_databases;
end
