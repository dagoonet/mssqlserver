USE [msdb]
GO
/****** Object:  StoredProcedure [dbo].[sp_smi_get_long_running_queries]    Script Date: 11.04.2019 15:54:25 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

if object_id('smi_sp_get_long_running_queries', 'p') is not null
  drop procedure dbo.smi_sp_get_long_running_queries
go
create procedure [dbo].[smi_sp_get_long_running_queries] @rcpto nvarchar(200), @check int = 0, @skipdbs varchar(50) = ''
-- alter procedure [dbo].[sp_smi_get_long_running_queries] @rcpto nvarchar(200)
as
begin
	-- set nocount on added to prevent extra result sets from
	-- interfering with select statements.
	set nocount on;
	--------------------------------------------------------------------
	-- --- author: Marcus Deubel																	--- --
	-- --- copyright: (c) 2019 Marcus Deubel											---	--		
	-- --- license: BSD License																		--- --
	-- --- description:	sending e-mail about long running queries --- --
	-- --- @skipdbs must always contain dbid 32767								--- --
	--------------------------------------------------------------------
	declare @xml nvarchar(max) = N'';
	declare @table nvarchar(max);
	declare @header nvarchar(max);

	declare @lsubject nvarchar(200);
	declare @servername nvarchar(200);
	declare @reboottime datetime;

	set @servername = @@SERVERNAME;
	set @reboottime = CONVERT(nvarchar(24), GETDATE(), 120);

	-- set @skipdbs = '1,2,3,4,7,32767'; -- database ids
	
	-- alternative for the string_split, SQL Server < 2016
	-- declare @skipdbs table (did int);
  -- insert into @skipdbs
	-- select did from (values (1),(2),(3),(4),(9),(19),(20),(21),(22),(25)) AS tbl(did)
	
	
	----------------------------
	-- original T-SQL Abfrage --
	----------------------------
	--select b.session_id,
  -- 			 isnull(cast(db_name(a.database_id) as varchar(20)), 'n/a') as database_id,
	--			 isnull(c.command, 'n/a') as command,
	--			 isnull(substring(st.text, ( c.statement_start_offset / 2 ) + 1, ( (  case c.statement_end_offset  when -1 then datalength(st.text) else c.statement_end_offset end - c.statement_start_offset ) / 2 ) + 1), 'n/a') statement_text,
	--			 isnull(coalesce(quotename(db_name(st.dbid)) + '.' + quotename(object_schema_name(st.objectid, st.dbid)) + '.' + quotename(object_name(st.objectid, st.dbid)), ''), 'n/a') command_text,
	--			 isnull(c.wait_type, 'n/a') wait_type,
	--			 isnull(c.wait_time, 'n/a') wait_time,
	--			 a.database_transaction_log_bytes_used / 1024.0 / 1024.0 as 'MB used',
	--			 a.database_transaction_log_bytes_used_system / 1024.0 / 1024.0 as 'MB used system',
	--			 a.database_transaction_log_bytes_reserved / 1024.0 / 1024.0 as 'MB reserved',
	--			 a.database_transaction_log_bytes_reserved_system / 1024.0 / 1024.0 as 'MB reserved system',
	--			 a.database_transaction_log_record_count as 'Record count'
	--into #long_running_queries
	--from sys.dm_tran_database_transactions as a join sys.dm_tran_session_transactions as b
	--on a.transaction_id = b.transaction_id join sys.dm_exec_requests as c cross apply sys.dm_exec_sql_text(c.sql_handle) as st
	--on b.session_id = c.session_id
	--where (a.database_id > 4) and (c.command = 'UPDATE' or c.command = 'INSERT' or c.command = 'DELETE')


	set @header = N'<html>' +
								N'<style>' +
								N'table, th, td { border: 1px solid black; }' +
								N'</style>' +
								N'</head>' + 
								N'<body>' +
								N'<H3>Long Running Queries</H3>' +  
								N'<table border="1">' +  
								N'<tr>' + 
								N'<th>Session ID</th><th>Database Name</th><th>command</th><th>statement_text</th><th>command_text</th><th>wait_type</th><th>wait_time</th>' +
								N'<th>MB used</th><th>MB used system</th><th>MB reserved</th><th>MB reserved system</th><th>Record count</th>' +
								N'</tr>';

	set @xml = cast ((select  td = b.session_id, '',
														td = isnull(cast(db_name(a.database_id) as varchar(20)), 'n/a'), '',
														td = isnull(c.command, 'n/a'), '',
														td = isnull(substring(st.text, ( c.statement_start_offset / 2 ) + 1, ( (  case c.statement_end_offset  when -1 then datalength(st.text) else c.statement_end_offset end - c.statement_start_offset ) / 2 ) + 1), 'n/a'), '',
														td = isnull(coalesce(quotename(db_name(st.dbid)) + '.' + quotename(object_schema_name(st.objectid, st.dbid)) + '.' + quotename(object_name(st.objectid, st.dbid)), ''), 'n/a'), '',
														td = isnull(c.wait_type, 'n/a'), '',
														td = isnull(c.wait_time, 'n/a'), '',
														td = a.database_transaction_log_bytes_used / 1024.0 / 1024.0, '',
														td = a.database_transaction_log_bytes_used_system / 1024.0 / 1024.0, '',
														td = a.database_transaction_log_bytes_reserved / 1024.0 / 1024.0, '',
														td = a.database_transaction_log_bytes_reserved_system / 1024.0 / 1024.0, '',
														td = a.database_transaction_log_record_count, ''            
										from   sys.dm_tran_database_transactions a join sys.dm_tran_session_transactions b
										on a.transaction_id = b.transaction_id join sys.dm_exec_requests c cross apply sys.dm_exec_sql_text(c.sql_handle) as st
										on b.session_id = c.session_id
										where (a.database_id not in (select cast(ltrim(rtrim(value)) as int) from string_split(@skipdbs, ','))) and (c.command = 'UPDATE' or c.command = 'INSERT' or c.command = 'DELETE')
										-- SQL Server 2016
										-- where (a.database_id not in (select cast(ltrim(rtrim(value)) as int) from string_split(@skipdbs, ','))) and (c.command = 'UPDATE' or c.command = 'INSERT' or c.command = 'DELETE')
										-- SQL Server < 2016
										-- where ((a.database_id not in (select did from @skipdbs)) and ((c.command = 'UPDATE' or c.command = 'INSERT' or c.command = 'DELETE')))
										-- ORDER  BY log_bytes_used DESC
										FOR XML PATH('tr'), TYPE) AS NVARCHAR(MAX));

	set @table = @header + @xml + N'</table></body></html>'

	set @lsubject = @servername + N': long running queries' + N' - ' + CONVERT(nvarchar(24), GETDATE(), 120);

	if len(@xml) > 0 or @check = 1
	  begin
			exec msdb.dbo.sp_send_dbmail @profile_name = 'Default Public Profile',  
																	 @recipients = @rcpto,  
																	 @subject = @lsubject,  
																	 @body = @table,  
																	 @body_format = 'HTML' ;  
	  end					
end

						 
					     
