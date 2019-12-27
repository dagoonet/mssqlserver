USE [msdb]
GO

/****** Object:  Job [DBA - 34052_Scheduled_Policy_Violation]    Script Date: 21.03.2019 06:22:29 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Database Maintenance]    Script Date: 21.03.2019 06:22:29 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Database Maintenance' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Database Maintenance'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA - 34052_Scheduled_Policy_Violation', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'Database Maintenance', 
		@owner_login_name=N'KLINIK\ServiceSSA', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [34052_email_notification]    Script Date: 21.03.2019 06:22:30 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'34052_email_notification', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'declare @pname varchar(50);
declare @hresult int;
declare @hdate datetime;
declare @pid int;
declare @result bit;
declare @check_free_space_trn varchar(50);
declare @databases_not_backed_up varchar(50);

set @check_free_space_trn = ''check_free_space_trn'';
set @databases_not_backed_up = ''Identify Databases not backed up in the last 24 hours'';
set @result = 0; -- 0 = failure, 1 = success

select top 1 @pid = p.policy_id, @pname = p.name, @hresult = h.result, @hdate = h.end_date 
-- top 1 p.policy_id, p.name, h.result, h.start_date 
from msdb.dbo.syspolicy_policies p join msdb.dbo.syspolicy_policy_execution_history h 
on p.policy_id = h.policy_id
order by h.start_date desc


--select top 1 @pname as policy_name, h.policy_id, h.history_id, d.target_query_expression, d.execution_date, d.result
-- from  msdb.dbo.syspolicy_policy_execution_history h join msdb.dbo.syspolicy_policy_execution_history_details d 
-- on h.history_id = d.history_id where d.result = ''0''
--  -- and execution_date >= @hdate
--  and h.policy_id = @pid
-- order by execution_date desc




-- if @check_free_space_trn = (select @pname) and @result = (select @hresult)
if @result = (select @hresult)
  begin
	------------------------------------------------------------------------------
	---- verschickt eine Mail an @recipients mit der Info über Langläufer --------
	---- beim Implentieren muß die Variable @recipients angepasst werden  --------
	---- eventuell auch die Variable @profile_name						  --------
	------------------------------------------------------------------------------
	DECLARE @xml NVARCHAR(MAX) = N'''';
	DECLARE @table NVARCHAR(MAX);
	declare @header nvarchar(max);

	set @header =  N''<html><body>'' +
				   N''<H3>'' + @pname + ''</H3>'' +  
				   N''<table border="1">'' +  
				   N''<tr>'' + 
				   N''<th>Policy Name</th>'' + 
				   N''<th>policy_id</th>'' +
				   N''<th>history_id</th>'' +
				   N''<th>Database</th>'' +
				   N''<th>Execution Date</th>'' +
				   N''<th>Result</th>'' +
				   N''</tr>'';

	set @xml = cast ((select td = @pname, '''',
							 td = h.policy_id, '''',
							 td = h.history_id, '''',
							 td = d.target_query_expression, '''',
							 td = d.execution_date, '''',
							 td = d.result, ''''
					  from  msdb.dbo.syspolicy_policy_execution_history h join msdb.dbo.syspolicy_policy_execution_history_details d 
					  on h.history_id = d.history_id where d.result = ''0'' and h.policy_id = @pid order by execution_date desc
					   -- ORDER  BY log_bytes_used DESC
					  FOR XML PATH(''tr''), TYPE) AS NVARCHAR(MAX));

	set @table = @header + @xml + N''</table></body></html>''

	-- print @table;

	exec msdb.dbo.sp_send_dbmail  
		@profile_name = ''Default Public Profile'',  
		@recipients = ''deubel_m@ukw.de'',  
		@subject = ''Policy Violation'',  
		@body = @table,  
		@body_format = ''HTML'' ;  
  end', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO

