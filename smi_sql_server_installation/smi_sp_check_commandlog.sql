USE [msdb]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

if object_id('smi_sp_check_commandlog', 'p') is not null
  drop procedure dbo.smi_sp_check_commandlog
go
create procedure dbo.smi_sp_check_commandlog @rcpto nvarchar(200), @debug int = 0
AS
BEGIN

	------------------------------------------------------------------------
	-- --- author: Marcus Deubel																			--- --
	-- --- copyright: (c) 2019 Marcus Deubel													---	--		
	-- --- license: BSD License																				--- --
	-- --- description: stored procedure to check commandlog table    --- --
	-- ---            : and send emails on error messages             --- --
	------------------------------------------------------------------------

	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	set nocount on;
	declare @xml nvarchar(max) = N'';
	declare @table nvarchar(max);
	declare @header nvarchar(max);
	declare @errNo int;
	declare @database nvarchar(10);
	declare @sqlstmt nvarchar(512);

	declare @lsubject nvarchar(200);
	declare @servername nvarchar(200);
	declare @reboottime datetime;

	-- set @debug = 1;
	--set @rcpto = 'deubel_m@ukw.de';
	set @servername = @@SERVERNAME;
	set @reboottime = CONVERT(nvarchar(24), GETDATE(), 120);
	


	----------------------------
	-- original T-SQL Abfrage --
	----------------------------
	--select	ID, '',
	--				DatabaseName, '',
	--				isnull(SchemaName, 'n/a'),
	--				isnull(ObjectName, 'n/a'),
	--				isnull(ObjectType, 'n/a'),
	--				isnull(IndexName, 'n/a'),
	--				isnull(convert(nvarchar,IndexType), 'n/a'),
	--				isnull(StatisticsName, 'n/a'),
	--				isnull(convert(nvarchar,PartitionNumber), 'n/a'),
	--				isnull(ExtendedInfo, 'n/a'), 
	--				isnull(Command, 'n/a'),
	--				isnull(CommandType, 'n/a'),
	--				isnull(convert(nvarchar,StartTime), 'n/a'),
	--				isnull(convert(nvarchar,EndTime), 'n/a'),
	--				isnull(convert(nvarchar,ErrorNumber), 'n/a'),
	--				isnull(ErrorMessage, 'no Error')
	--FROM [msdb].[dbo].[CommandLog] where CommandType = 'DBCC_CHECKDB' and convert(date,StartTime) = convert(date, getdate());

	set @errNo = (select errorNumber from msdb.dbo.CommandLog where CommandType = 'DBCC_CHECKDB' and convert(date,StartTime) = convert(date, getdate()) and ErrorNumber > 0);

	set @header = N'<html>' +
								N'<style>' +
								N'table, th, td { border: 1px solid black; }' +
								N'</style>' +
								N'</head>' + 
								N'<body>' +
								N'<H3>CommandLog</H3>' +  
								N'<table border="1">' +  
								N'<tr>' + 
								N'<th>DB ID</th><th>Database Name</th><th>SchemaName</th><th>ObjectName</th><th>ObjectType</th><th>IndexName</th><th>IndexType</th><th>StatisticsName</th>' +
								N'<th>PartitionNumber</th><th>ExtendedInfo</th><th>Command</th><th>CommandType</th><th>StartTime</th><th>EndTime</th><th>ErrorNumber</th><th>ErrorMessage</th>' +
								N'</tr>';

	set @xml = cast ((select	td = ID, '',
														td = DatabaseName, '',
														td = isnull(SchemaName, 'n/a'), '',
														td = isnull(ObjectName, 'n/a'), '',
														td = isnull(ObjectType, 'n/a'), '',
														td = isnull(IndexName, 'n/a'), '',
														td = isnull(convert(nvarchar,IndexType), 'n/a'), '',
														td = isnull(StatisticsName, 'n/a'), '',
														td = isnull(convert(nvarchar,PartitionNumber), 'n/a'), '',
														td = isnull(ExtendedInfo, 'n/a'), '',
														td = isnull(Command, 'n/a'), '',
														td = isnull(CommandType, 'n/a'), '',
														td = isnull(convert(nvarchar,StartTime), 'n/a'), '',
														td = isnull(convert(nvarchar,EndTime), 'n/a'), '',
														td = isnull(convert(nvarchar,ErrorNumber), 'n/a'), '',
														td = isnull(ErrorMessage, 'no Error Message'), ''
									  FROM [msdb].[dbo].[CommandLog] where CommandType = 'DBCC_CHECKDB' and convert(date,StartTime) = convert(date, getdate())
										FOR XML PATH('tr'), TYPE) AS NVARCHAR(MAX));

	set @table = @header + @xml + N'</table></body></html>'

	if @debug = 1
		begin
			set @errNo = 1;
		end;

	if @errNo > 0
	  begin
			set @lsubject = @servername + N': ERROR in CommandLog. Please check' + N' - ' + CONVERT(nvarchar(24), GETDATE(), 120);
	  end 
	else 
	  begin
			set @lsubject = @servername + N': CommandLog' + N' - ' + CONVERT(nvarchar(24), GETDATE(), 120);
		end

	if len(@xml) > 0 or @debug = 1
	  begin
			exec msdb.dbo.sp_send_dbmail @profile_name = 'Default Public Profile',  
																	 @recipients = @rcpto,
																	 @subject = @lsubject,  
																	 @body = @table,  
																	 @body_format = 'HTML' ;  
	  end						

END
GO

USE [msdb]
GO

/****** Object:  Job [dba - check_commandlog]    Script Date: 08.11.2019 11:55:34 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]    Script Date: 08.11.2019 11:55:34 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'dba - check_commandlog', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [call smi_sp_check_command]    Script Date: 08.11.2019 11:55:35 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'call smi_sp_check_command', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'execute dbo.smi_sp_check_commandlog @rcpto = N''deubel_m@ukw.de'',
				   @debug = 0
', 
		@database_name=N'msdb', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'daily_check_commandlog', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20191107, 
		@active_end_date=99991231, 
		@active_start_time=235800, 
		@active_end_time=235959, 
		@schedule_uid=N'ed020c81-8cf4-4b6d-bc27-343873fce944'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO

