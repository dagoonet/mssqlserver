USE [msdb]
GO
/****** Object:  StoredProcedure [dbo].[get_long_running_queries]    Script Date: 11.04.2019 15:54:25 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- author:		<author,,name>
-- create date: <create date,,>
-- description:	<description,,>
-- =============================================
ALTER procedure [dbo].[get_long_running_queries] @rcpto nvarchar(200)
as
begin
	-- set nocount on added to prevent extra result sets from
	-- interfering with select statements.
	set nocount on;
  ------------------------------------------------------------------------------
	---- verschickt eine Mail an @recipients mit der Info über Langläufer --------
	---- beim Implentieren muß die Variable @recipients angepasst werden  --------
	---- eventuell auch die Variable @profile_name						  --------
	------------------------------------------------------------------------------
	declare @xml nvarchar(max) = N'';
	declare @table nvarchar(max);
	declare @header nvarchar(max);

	declare @lsubject nvarchar(100);
	declare @servername nvarchar(100);
	declare @reboottime datetime;
	set @servername = @@SERVERNAME;
	set @reboottime = CONVERT(nvarchar(24), GETDATE(), 120);
	

	set @header = N'<html><body>' +
								N'<H3>Long Running Queries</H3>' +  
								N'<table border="1">' +  
								N'<tr>' + 
								N'<th>Session ID</th><th>Database Name</th><th>command</th><th>statement_text</th><th>command_text</th><th>wait_type</th><th>wait_time</th>' +
								N'<th>MB used</th><th>MB used system</th><th>MB reserved</th><th>MB reserved system</th><th>Record count</th>' +
								N'</tr>';

	set @xml = cast ((SELECT td = b.session_id, '',
								td = CAST(Db_name(a.database_id) AS VARCHAR(20)), '',
								td = c.command, '',
								Substring(st.TEXT, ( c.statement_start_offset / 2 ) + 1, ( (  CASE c.statement_end_offset  WHEN -1 THEN Datalength(st.TEXT) ELSE c.statement_end_offset END - c.statement_start_offset ) / 2 ) + 1) as td, '',
								Coalesce(Quotename(Db_name(st.dbid)) + N'.' + Quotename(Object_schema_name(st.objectid, st.dbid)) + N'.' + Quotename(Object_name(st.objectid, st.dbid)), '') as td, '',
								td = c.wait_type, '',
								td = c.wait_time, '',
								td = a.database_transaction_log_bytes_used / 1024.0 / 1024.0, '',
								td = a.database_transaction_log_bytes_used_system / 1024.0 / 1024.0, '',
								td = a.database_transaction_log_bytes_reserved / 1024.0 / 1024.0, '',
								td = a.database_transaction_log_bytes_reserved_system / 1024.0 / 1024.0, '',
								td = a.database_transaction_log_record_count, ''            
						FROM   sys.dm_tran_database_transactions a JOIN sys.dm_tran_session_transactions b
						ON a.transaction_id = b.transaction_id JOIN sys.dm_exec_requests c CROSS APPLY sys.Dm_exec_sql_text(c.sql_handle) AS st
						ON b.session_id = c.session_id
						-- ORDER  BY log_bytes_used DESC
						FOR XML PATH('tr'), TYPE) AS NVARCHAR(MAX));

	set @table = @header + @xml + N'</table></body></html>'

	set @lsubject = @servername + ': ' + N'long running queries' + ' - ' + CONVERT(nvarchar(24), GETDATE(), 120);

	EXEC msdb.dbo.sp_send_dbmail @profile_name = 'Default Public Profile',  
															 @recipients = @rcpto,  
															 @subject = @lsubject,  
															 @body = @table,  
															 @body_format = 'HTML' ;  

						
end
