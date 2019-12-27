use [msdb]
go

declare @returncode int

/****** object:  job [dba - get long running queries]    script date: 12.04.2019 11:12:15 ******/
if exists (select job_id from msdb.dbo.sysjobs_view where name = N'dba - policy_violation_notification')  
  begin
		begin transaction
			select @returncode = 0
			exec @returncode =  msdb.dbo.sp_delete_job @job_name = N'dba - policy_violation_notification'
		  if (@@error <> 0 or @returncode <> 0) goto quitwithrollback
		commit transaction
			goto endsave
	end

if not exists (select job_id from msdb.dbo.sysjobs_view where name = N'dba - policy_violation_notification')
  begin
		/****** object:  job [dba - policy_violation_notification]    script date: 12.04.2019 11:14:50 ******/
		begin transaction
			select @returncode = 0
			/****** object:  jobcategory [database maintenance]    script date: 12.04.2019 11:14:50 ******/
			if not exists (select name from msdb.dbo.syscategories where name = N'database maintenance' and category_class = 1)
			begin
			  exec @returncode = msdb.dbo.sp_add_category @class = N'job', 
																										@type = N'local', 
																										@name = N'database maintenance'
			  if (@@error <> 0 or @returncode <> 0) goto quitwithrollback
			end

			declare @jobid binary(16)
			exec @returncode = msdb.dbo.sp_add_job  @job_name = N'dba - policy_violation_notification', 
																							@enabled = 1, 
																							@notify_level_eventlog = 0, 
																							@notify_level_email = 0, 
																							@notify_level_netsend = 0, 
																							@notify_level_page = 0, 
																							@delete_level = 0, 
																							@description = N'no description available.', 
																							@category_name = N'database maintenance', 
																							@owner_login_name = N'sa', 
																							@job_id  =  @jobid output
			if (@@error <> 0 or @returncode <> 0) goto quitwithrollback
			
			/****** object:  step [34052_email_notification]    script date: 12.04.2019 11:14:50 ******/
			exec @returncode = msdb.dbo.sp_add_jobstep  @job_id = @jobid, 
																									@step_name = N'34052_email_notification', 
																									@step_id = 1, 
																									@cmdexec_success_code = 0, 
																									@on_success_action = 1, 
																									@on_success_step_id = 0, 
																									@on_fail_action = 2, 
																									@on_fail_step_id = 0, 
																									@retry_attempts = 0, 
																									@retry_interval = 0, 
																									@os_run_priority = 0, @subsystem = N'tsql', 
																									@command = N'exec msdb.dbo.smi_sp_policy_violation @rcpto  =  n''smi_dbalerts@ukw.de'', @check  =  0', 
																									@database_name = N'msdb', 
																									@flags = 0
			if (@@error <> 0 or @returncode <> 0) goto quitwithrollback

			exec @returncode = msdb.dbo.sp_update_job @job_id = @jobid, 
																								@start_step_id = 1
			if (@@error <> 0 or @returncode <> 0) goto quitwithrollback
			
			exec @returncode = msdb.dbo.sp_add_jobserver @job_id = @jobid, 
																									 @server_name = N'(local)'
			if (@@error <> 0 or @returncode <> 0) goto quitwithrollback
		commit transaction
		goto endsave
	end

quitwithrollback:
	if (@@trancount > 0) rollback transaction
endsave:
go


