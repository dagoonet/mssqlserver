USE [msdb]
GO


------------------------------------------
-- Template für die Anlage eines Alerts --
------------------------------------------
/*
if not exists (select id from msdb.dbo.sysalerts where name = N'dba - 3928_trn_failed_deadlock')
  begin
		begin transaction
			declare @returncode int
			select @returncode = 0

			if (@@ERROR <> 0 OR @ReturnCode <> 0) 
			   goto QuitWithRollback

		commit transaction
    goto endsave
    quitwithrollback:
    if (@@trancount > 0) 
		  rollback transaction
    endsave:
  end
*/


truncate table msdb.dbo.sysalerts;
truncate table msdb.dbo.sysnotifications;

if not exists (select id from msdb.dbo.sysalerts where name = N'dba - 1101_low_disk_space')
  begin
		begin transaction
			declare @returncode int
			select @returncode = 0

			/****** Object:  Alert [Error_1101_Filegroup_full]    Script Date: 21.08.2015 07:10:17 ******/
			exec @returncode = msdb.dbo.sp_add_alert  @name=N'dba - 1101_low_disk_space', 
																								@message_id=1101, 
																								@severity=0, 
																								@enabled=1, 
																								@delay_between_responses=0, 
																								@include_event_description_in=1, 
																								@category_name=N'[Uncategorized]', 
																								@job_id=N'00000000-0000-0000-0000-000000000000'
			if (@@ERROR <> 0 OR @ReturnCode <> 0) 
			   goto QuitWithRollback

		commit transaction
    goto endsave
    quitwithrollback:
    if (@@trancount > 0) 
		  rollback transaction
    endsave:
  end

USE [msdb]
GO
if not exists (select id from msdb.dbo.sysalerts where name = N'dba - 1105_no_more_space_in_filegroup')
  begin
		begin transaction
			declare @returncode int
			select @returncode = 0

  		/****** Object:  Alert [Error_1105_Filegroup_full]    Script Date: 21.08.2015 07:10:23 ******/
			exec @returncode = msdb.dbo.sp_add_alert	@name=N'dba - 1105_no_more_space_in_filegroup', 
																								@message_id=1105, 
																								@severity=0, 
																								@enabled=1, 
																								@delay_between_responses=0, 
																								@include_event_description_in=1, 
																								@category_name=N'[Uncategorized]', 
																								@job_id=N'00000000-0000-0000-0000-000000000000'

			if (@@ERROR <> 0 OR @ReturnCode <> 0) 
			   goto QuitWithRollback

		commit transaction
    goto endsave
    quitwithrollback:
    if (@@trancount > 0) 
		  rollback transaction
    endsave:

  end


USE [msdb]
GO
if not exists (select id from msdb.dbo.sysalerts where name = N'dba - 1205_lk_victim')
  begin
		begin transaction
			declare @returncode int
			select @returncode = 0

			/****** Object:  Alert [Error_1205_Deadlock_detected]    Script Date: 21.08.2015 07:10:31 ******/
			exec @returncode = msdb.dbo.sp_add_alert  @name=N'dba - 1205_lk_victim', 
																								@message_id=1205, 
																								@severity=0, 
																								@enabled=1, 
																								@delay_between_responses=0, 
																								@include_event_description_in=1, 
																								@category_name=N'[Uncategorized]', 
																								@job_id=N'00000000-0000-0000-0000-000000000000'

			if (@@ERROR <> 0 OR @ReturnCode <> 0) 
			   goto QuitWithRollback

		commit transaction
    goto endsave
    quitwithrollback:
    if (@@trancount > 0) 
		  rollback transaction
    endsave:
  end

USE [msdb]
GO
if not exists (select id from msdb.dbo.sysalerts where name = N'dba - 17053_os_error')
  begin
		begin transaction
			declare @returncode int
			select @returncode = 0

			/****** Object:  Alert [Error_17053_log_flush]    Script Date: 21.08.2015 07:10:39 ******/
			exec @returncode = msdb.dbo.sp_add_alert  @name=N'dba - 17053_os_error', 
																								@message_id=17053, 
																								@severity=0, 
																								@enabled=1, 
																								@delay_between_responses=300, 
																								@include_event_description_in=1, 
																								@category_name=N'[Uncategorized]', 
																								@job_id=N'00000000-0000-0000-0000-000000000000' 

			if (@@ERROR <> 0 OR @ReturnCode <> 0) 
			   goto QuitWithRollback

		commit transaction
    goto endsave
    quitwithrollback:
    if (@@trancount > 0) 
		  rollback transaction
    endsave:
  end

USE [msdb]
GO
if not exists (select id from msdb.dbo.sysalerts where name = N'dba - 3041_backup_failed')
  begin
		begin transaction
			declare @returncode int
			select @returncode = 0

			/****** Object:  Alert [Error_3041_Backup_failed]    Script Date: 21.08.2015 07:10:46 ******/
			exec @returncode = msdb.dbo.sp_add_alert  @name=N'dba - 3041_backup_failed', 
																								@message_id=3041, 
																								@severity=0, 
																								@enabled=1, 
																								@delay_between_responses=0, 
																								@include_event_description_in=1, 
																								@category_name=N'[Uncategorized]', 
																								@job_id=N'00000000-0000-0000-0000-000000000000'

			if (@@ERROR <> 0 OR @ReturnCode <> 0) 
			   goto QuitWithRollback

		commit transaction
    goto endsave
    quitwithrollback:
    if (@@trancount > 0) 
		  rollback transaction
    endsave:

  end

USE [msdb]
GO
if not exists (select id from msdb.dbo.sysalerts where name = N'dba - 3043_backup_page_error')
  begin
		begin transaction
			declare @returncode int
			select @returncode = 0

			/****** Object:  Alert [Error_3043_Backup_page_error]    Script Date: 21.08.2015 07:10:55 ******/
			exec @returncode = msdb.dbo.sp_add_alert  @name=N'dba - 3043_backup_page_error', 
																								@message_id=3043, 
																								@severity=0, 
																								@enabled=1, 
																								@delay_between_responses=0, 
																								@include_event_description_in=1, 
																								@category_name=N'[Uncategorized]', 
																								@job_id=N'00000000-0000-0000-0000-000000000000'

			if (@@ERROR <> 0 OR @ReturnCode <> 0) 
			   goto QuitWithRollback

		commit transaction
    goto endsave
    quitwithrollback:
    if (@@trancount > 0) 
		  rollback transaction
    endsave:

  end

USE [msdb]
GO
if not exists (select id from msdb.dbo.sysalerts where name = N'dba - 3049_backup_trn_corrupt')
  begin
		begin transaction
			declare @returncode int
			select @returncode = 0

			/****** Object:  Alert [Error_3049_Backup_trn_corrupt]    Script Date: 21.08.2015 07:11:04 ******/
			exec @returncode = msdb.dbo.sp_add_alert  @name=N'dba - 3049_backup_trn_corrupt', 
																								@message_id=3049, 
																								@severity=0, 
																								@enabled=1, 
																								@delay_between_responses=0, 
																								@include_event_description_in=1, 
																								@category_name=N'[Uncategorized]', 
																								@job_id=N'00000000-0000-0000-0000-000000000000'

			if (@@ERROR <> 0 OR @ReturnCode <> 0) 
			   goto QuitWithRollback

		commit transaction
    goto endsave
    quitwithrollback:
    if (@@trancount > 0) 
		  rollback transaction
    endsave:

  end

USE [msdb]
GO
if not exists (select id from msdb.dbo.sysalerts where name = N'dba - 9001_log_not_avail')
  begin
		begin transaction
			declare @returncode int
			select @returncode = 0

			/****** Object:  Alert [Error_9001_no_transaction_log]    Script Date: 21.08.2015 07:11:14 ******/
			exec @returncode = msdb.dbo.sp_add_alert  @name=N'dba - 9001_log_not_avail', 
																								@message_id=9001, 
																								@severity=0, 
																								@enabled=1, 
																								@delay_between_responses=300, 
																								@include_event_description_in=1, 
																								@category_name=N'[Uncategorized]', 
																								@job_id=N'00000000-0000-0000-0000-000000000000'

			if (@@ERROR <> 0 OR @ReturnCode <> 0) 
			   goto QuitWithRollback

		commit transaction
    goto endsave
    quitwithrollback:
    if (@@trancount > 0) 
		  rollback transaction
    endsave:

  end

USE [msdb]
GO
if not exists (select id from msdb.dbo.sysalerts where name = N'dba - 9002_log_is_full')
  begin
		begin transaction
			declare @returncode int
			select @returncode = 0

			/****** Object:  Alert [Error_9002_transaction_log_full]    Script Date: 21.08.2015 07:11:37 ******/
			exec @returncode = msdb.dbo.sp_add_alert  @name=N'dba - 9002_log_is_full', 
																								@message_id=9002, 
																								@severity=0, 
																								@enabled=1, 
																								@delay_between_responses=300, 
																								@include_event_description_in=1, 
																								@category_name=N'[Uncategorized]', 
																								@job_id=N'00000000-0000-0000-0000-000000000000'

			if (@@ERROR <> 0 OR @ReturnCode <> 0) 
			   goto QuitWithRollback

		commit transaction
    goto endsave
    quitwithrollback:
    if (@@trancount > 0) 
		  rollback transaction
    endsave:

  end

USE [msdb]
GO
if not exists (select id from msdb.dbo.sysalerts where name = N'dba - 9003_log_invalid_lsn')
  begin
		begin transaction
			declare @returncode int
			select @returncode = 0

			-- Object:  Alert [Error_9003_transaction_log_corrupt]  
			-- Script Date: 21.08.2015 07:11:44
			-- TRN does not match full backup 
			exec @returncode = msdb.dbo.sp_add_alert  @name=N'dba - 9003_log_invalid_lsn', 
																								@message_id=9003, 
																								@severity=0, 
																								@enabled=1, 
																								@delay_between_responses=0, 
																								@include_event_description_in=1, 
																								@category_name=N'[Uncategorized]', 
																								@job_id=N'00000000-0000-0000-0000-000000000000'

			if (@@ERROR <> 0 OR @ReturnCode <> 0) 
			   goto QuitWithRollback

		commit transaction
    goto endsave
    quitwithrollback:
    if (@@trancount > 0) 
		  rollback transaction
    endsave:

  end

USE [msdb]
GO
if not exists (select id from msdb.dbo.sysalerts where name = N'dba - 9004_log_corrupt')
  begin
		begin transaction
			declare @returncode int
			select @returncode = 0

			/****** Object:  Alert [Error_9003_transaction_log_corrupt]    Script Date: 21.08.2015 07:11:44 ******/
			exec @returncode = msdb.dbo.sp_add_alert  @name=N'dba - 9004_log_corrupt', 
																								@message_id=9004, 
																								@severity=0, 
																								@enabled=1, 
																								@delay_between_responses=0, 
																								@include_event_description_in=1, 
																								@category_name=N'[Uncategorized]', 
																								@job_id=N'00000000-0000-0000-0000-000000000000'

			if (@@ERROR <> 0 OR @ReturnCode <> 0) 
			   goto QuitWithRollback

		commit transaction
    goto endsave
    quitwithrollback:
    if (@@trancount > 0) 
		  rollback transaction
    endsave:

  end

USE [msdb]
GO
if not exists (select id from msdb.dbo.sysalerts where name = N'dba - 34052_scheduled_policy_violation')
  begin
    /****** Object:  Job [dba - Policy_Violation_Notification]    Script Date: 11.04.2019 11:29:12 ******/
		begin transaction
			declare @returncode int
			select @returncode = 0
			/****** Object:  JobCategory [Database Maintenance]    Script Date: 11.04.2019 11:29:12 ******/
			IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Database Maintenance' AND category_class=1)
				BEGIN
					EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Database Maintenance'
					IF (@@ERROR <> 0 OR @ReturnCode <> 0) 
					  GOTO QuitWithRollback
				END

			DECLARE @jobId BINARY(16)
			if not exists (select name from msdb.dbo.sysjobs where name = N'dba - Policy_Violation_Notification')
			  begin
					exec @ReturnCode = msdb.dbo.sp_add_job	@job_name=N'dba - Policy_Violation_Notification', 
																							    @enabled=1, 
																									@notify_level_eventlog=0, 
																									@notify_level_email=0, 
																									@notify_level_netsend=0, 
																									@notify_level_page=0, 
																									@delete_level=0, 
																									@description=N'No description available.', 
																									@category_name=N'Database Maintenance', 
																									@owner_login_name=N'sa', 
																									@job_id = @jobId OUTPUT
				  if (@@ERROR <> 0 OR @ReturnCode <> 0) 
			      goto QuitWithRollback

					/****** Object:  Step [34052_email_notification]    Script Date: 11.04.2019 11:29:12 ******/
					exec @ReturnCode = msdb.dbo.sp_add_jobstep  @job_id=@jobId,		
																											@step_name=N'34052_email_notification', 
																											@step_id=1, 
																											@cmdexec_success_code=0, 
																											@on_success_action=1, 
																											@on_success_step_id=0, 
																											@on_fail_action=2, 
																											@on_fail_step_id=0, 
																											@retry_attempts=0, 
																											@retry_interval=0, 
																											@os_run_priority=0, 
																											@subsystem=N'TSQL', 
																											@command=N'EXEC msdb.dbo.sp_smi_policy_violation @rcpto = N''smi_dbalerts@ukw.de'', @check = 0', 
																											@database_name=N'master', 
																											@flags=0
				  if (@@ERROR <> 0 OR @ReturnCode <> 0) 
			      goto QuitWithRollback

			    exec @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
				  if (@@ERROR <> 0 OR @ReturnCode <> 0) 
			      goto QuitWithRollback

 			    exec @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
				  if (@@ERROR <> 0 OR @ReturnCode <> 0) 
			      goto QuitWithRollback

					/****** Object:  Alert [dba - 34052_Scheduled_Policy_Violation]    Script Date: 11.04.2019 11:26:46 ******/
					exec @ReturnCode = msdb.dbo.sp_add_alert	@name=N'dba - 34052_scheduled_policy_violation', 
																										@message_id=34052, 
																										@severity=0, 
																										@enabled=1, 
																										@delay_between_responses=0, 
																										@include_event_description_in=1, 
																										@category_name=N'[Uncategorized]', 
																										@job_name='dba - Policy_Violation_Notification'

					if (@@ERROR <> 0 OR @ReturnCode <> 0) goto QuitWithRollback
			  end

		commit transaction
    GOTO EndSave
    QuitWithRollback:
    IF (@@TRANCOUNT > 0) 
		  ROLLBACK TRANSACTION
    EndSave:
  end

use [msdb]
go
if not exists (select id from msdb.dbo.sysalerts where name = N'dba - 18204_backup_device_failed')
  begin
		begin transaction
			declare @returncode int
			select @returncode = 0

			/****** Object:  Alert [Error_18204_backup_device_failed]    Script Date: 10.07.2018 06:43:47 ******/
			exec @returncode = msdb.dbo.sp_add_alert  @name=N'dba - 18204_backup_device_failed', 
																								@message_id=18204, 
																								@severity=0, 
																								@enabled=1, 
																								@delay_between_responses=0, 
																								@include_event_description_in=0, 
																								@category_name=N'[Uncategorized]', 
																								@job_id=N'00000000-0000-0000-0000-000000000000'

		  if (@@ERROR <> 0 OR @ReturnCode <> 0) 
 	      goto QuitWithRollback

		commit transaction
    goto endsave
    quitwithrollback:
    if (@@trancount > 0) 
		  rollback transaction
    endsave:
  end


USE [msdb]
GO
if not exists (select id from msdb.dbo.sysalerts where name = N'dba - 18210_failure_on_backup_device')
  begin
		begin transaction
			declare @returncode int
			select @returncode = 0

			/****** Object:  Alert [Error_18210_backup_device_failed]    Script Date: 10.07.2018 06:43:57 ******/
			exec @returncode = msdb.dbo.sp_add_alert  @name=N'dba - 18210_failure_on_backup_device', 
																								@message_id=18210, 
																								@severity=0, 
																								@enabled=1, 
																								@delay_between_responses=0, 
																								@include_event_description_in=0, 
																								@category_name=N'[Uncategorized]', 
																								@job_id=N'00000000-0000-0000-0000-000000000000'

		  if (@@ERROR <> 0 OR @ReturnCode <> 0) 
 	      goto QuitWithRollback

		commit transaction
    goto endsave
    quitwithrollback:
    if (@@trancount > 0) 
		  rollback transaction
    endsave:
  end

USE [msdb]
GO
if not exists (select id from msdb.dbo.sysalerts where name = N'dba - 823_b_harderr')
  begin
		begin transaction
			declare @returncode int
			select @returncode = 0

			-- Object:  Alert [Error_823_OS_error]    
			-- Script Date: 21.08.2018 07:09:58
			-- possible Hardware Error
			exec @returncode = msdb.dbo.sp_add_alert  @name=N'dba - 823_b_harderr', 
																								@message_id=823, 
																								@severity=0, 
																								@enabled=1, 
																								@delay_between_responses=0, 
																								@include_event_description_in=1, 
																								@category_name=N'[Uncategorized]', 
																								@job_id=N'00000000-0000-0000-0000-000000000000'
		  if (@@ERROR <> 0 OR @ReturnCode <> 0) 
 	      goto QuitWithRollback

		commit transaction
    goto endsave
    quitwithrollback:
    if (@@trancount > 0) 
		  rollback transaction
    endsave:
  end

USE [msdb]
GO
if not exists (select id from msdb.dbo.sysalerts where name = N'dba - 824_b_hardsserr')
  begin
		begin transaction
			declare @returncode int
			select @returncode = 0

			-- Object:  Alert [Error_824_logical_io_error]    
			-- Script Date: 21.08.2018 07:10:35
			-- possible logical error
			exec @returncode = msdb.dbo.sp_add_alert	@name=N'dba - 824_b_hardsserr', 
																								@message_id=824, 
																								@severity=0, 
																								@enabled=1, 
																								@delay_between_responses=0, 
																								@include_event_description_in=1, 
																								@category_name=N'[Uncategorized]', 
																								@job_id=N'00000000-0000-0000-0000-000000000000'
		  if (@@ERROR <> 0 OR @ReturnCode <> 0) 
 	      goto QuitWithRollback

		commit transaction
    goto endsave
    quitwithrollback:
    if (@@trancount > 0) 
		  rollback transaction
    endsave:
  end

USE [msdb]
GO
if not exists (select id from msdb.dbo.sysalerts where name = N'dba - 825_b_retryworked')
  begin
		begin transaction
			declare @returncode int
			select @returncode = 0

			-- Object:  Alert [Error_825_read_failed_error]    
			-- Script Date: 21.08.2018 07:16:15
			-- indicats disk problems
			exec @returncode = msdb.dbo.sp_add_alert  @name=N'dba - 825_b_retryworked', 
																								@message_id=825, 
																								@severity=0, 
																								@enabled=1, 
																								@delay_between_responses=0, 
																								@include_event_description_in=1, 
																								@category_name=N'[Uncategorized]', 
																								@job_id=N'00000000-0000-0000-0000-000000000000'

		  if (@@ERROR <> 0 OR @ReturnCode <> 0) 
 	      goto QuitWithRollback

		commit transaction
    goto endsave
    quitwithrollback:
    if (@@trancount > 0) 
		  rollback transaction
    endsave:
  end

--Severity Level	Meaning
--17	Insufficient Resources
--18	Nonfatal Internal Error Detected
--19	SQL Server Error in Resource
--20	SQL Server Fatal Error in Current Process
--21	SQL Server Fatal Error in Database (dbid) Process
--22	SQL Server Fatal Error Table Integrity Suspect
--23	SQL Server Fatal Error: Database Integrity Suspect
--24	Hardware Error
--25	Fatal Error

USE [msdb]
GO
if not exists (select id from msdb.dbo.sysalerts where name = N'dba - 014_insufficient_permissions')
  begin
		begin transaction
			declare @returncode int
			select @returncode = 0

			/****** Object:  Alert [dba - 017_INSUFFICIENT_RESOURCES]    Script Date: 11.04.2019 10:23:15 ******/
			exec @returncode = msdb.dbo.sp_add_alert  @name=N'dba - 014_insufficient_permissions', 
																								@message_id=0, 
																								@severity=14, 
																								@enabled=1, 
																								@delay_between_responses=0, 
																								@include_event_description_in=1, 
																								@category_name=N'[Uncategorized]', 
																								@job_id=N'00000000-0000-0000-0000-000000000000'

		  if (@@ERROR <> 0 OR @ReturnCode <> 0) 
 	      goto QuitWithRollback

		commit transaction
    goto endsave
    quitwithrollback:
    if (@@trancount > 0) 
		  rollback transaction
    endsave:
  end

USE [msdb]
GO
if not exists (select id from msdb.dbo.sysalerts where name = N'dba - 017_insufficient_resources')
  begin
		begin transaction
			declare @returncode int
			select @returncode = 0

			/****** Object:  Alert [dba - 017_INSUFFICIENT_RESOURCES]    Script Date: 11.04.2019 10:23:15 ******/
			exec @returncode = msdb.dbo.sp_add_alert  @name=N'dba - 017_insufficient_resources', 
																								@message_id=0, 
																								@severity=17, 
																								@enabled=1, 
																								@delay_between_responses=0, 
																								@include_event_description_in=1, 
																								@category_name=N'[Uncategorized]', 
																								@job_id=N'00000000-0000-0000-0000-000000000000'

		  if (@@ERROR <> 0 OR @ReturnCode <> 0) 
 	      goto QuitWithRollback

		commit transaction
    goto endsave
    quitwithrollback:
    if (@@trancount > 0) 
		  rollback transaction
    endsave:
  end

USE [msdb]
GO
if not exists (select id from msdb.dbo.sysalerts where name = N'dba - 018_nonfatal_internal_error')
  begin
		begin transaction
			declare @returncode int
			select @returncode = 0
			/****** Object:  Alert [dba - 018_NONFATAL_INTERNAL_ERROR]    Script Date: 11.04.2019 10:42:14 ******/
			exec @returncode = msdb.dbo.sp_add_alert  @name=N'dba - 018_nonfatal_internal_error', 
																								@message_id=0, 
																								@severity=18, 
																								@enabled=1, 
																								@delay_between_responses=0, 
																								@include_event_description_in=1, 
																								@category_name=N'[Uncategorized]', 
																								@job_id=N'00000000-0000-0000-0000-000000000000'

		  if (@@ERROR <> 0 OR @ReturnCode <> 0) 
 	      goto QuitWithRollback

		commit transaction
    goto endsave
    quitwithrollback:
    if (@@trancount > 0) 
		  rollback transaction
    endsave:
  end

USE [msdb]
GO
if not exists (select id from msdb.dbo.sysalerts where name = N'dba - 019_error_in_resource')
  begin
		begin transaction
			declare @returncode int
			select @returncode = 0

			/****** Object:  Alert [dba - 018_NONFATAL_INTERNAL_ERROR]    Script Date: 11.04.2019 10:42:14 ******/
			exec @returncode = msdb.dbo.sp_add_alert  @name=N'dba - 019_error_in_resource', 
																								@message_id=0, 
																								@severity=19, 
																								@enabled=1, 
																								@delay_between_responses=0, 
																								@include_event_description_in=1, 
																								@category_name=N'[Uncategorized]', 
																								@job_id=N'00000000-0000-0000-0000-000000000000'

		  if (@@ERROR <> 0 OR @ReturnCode <> 0) 
 	      goto QuitWithRollback

		commit transaction
    goto endsave
    quitwithrollback:
    if (@@trancount > 0) 
		  rollback transaction
    endsave:
  end

USE [msdb]
GO
if not exists (select id from msdb.dbo.sysalerts where name = N'dba - 020_fatal_error_in_current_process')
  begin
		begin transaction
			declare @returncode int
			select @returncode = 0

			/****** Object:  Alert [dba - 018_NONFATAL_INTERNAL_ERROR]    Script Date: 11.04.2019 10:42:14 ******/
			exec @returncode = msdb.dbo.sp_add_alert  @name=N'dba - 020_fatal_error_in_current_process', 
																								@message_id=0, 
																								@severity=20, 
																								@enabled=1, 
																								@delay_between_responses=0, 
																								@include_event_description_in=1, 
																								@category_name=N'[Uncategorized]', 
																								@job_id=N'00000000-0000-0000-0000-000000000000'

		  if (@@ERROR <> 0 OR @ReturnCode <> 0) 
 	      goto QuitWithRollback

		commit transaction
    goto endsave
    quitwithrollback:
    if (@@trancount > 0) 
		  rollback transaction
    endsave:
  end

USE [msdb]
GO
if not exists (select id from msdb.dbo.sysalerts where name = N'dba - 021_fatal_error_database')
  begin
		begin transaction
			declare @returncode int
			select @returncode = 0

			/****** Object:  Alert [dba - 018_NONFATAL_INTERNAL_ERROR]    Script Date: 11.04.2019 10:42:14 ******/
			exec @returncode = msdb.dbo.sp_add_alert  @name=N'dba - 021_fatal_error_database', 
																								@message_id=0, 
																								@severity=21, 
																								@enabled=1, 
																								@delay_between_responses=0, 
																								@include_event_description_in=1, 
																								@category_name=N'[Uncategorized]', 
																								@job_id=N'00000000-0000-0000-0000-000000000000'

		  if (@@ERROR <> 0 OR @ReturnCode <> 0) 
 	      goto QuitWithRollback

		commit transaction
    goto endsave
    quitwithrollback:
    if (@@trancount > 0) 
		  rollback transaction
    endsave:
  end

USE [msdb]
GO
if not exists (select id from msdb.dbo.sysalerts where name = N'dba - 022_fatal_error_table_integrity_suspect')
  begin
		begin transaction
			declare @returncode int
			select @returncode = 0

			/****** Object:  Alert [dba - 018_NONFATAL_INTERNAL_ERROR]    Script Date: 11.04.2019 10:42:14 ******/
			exec @returncode = msdb.dbo.sp_add_alert  @name=N'dba - 022_fatal_error_table_integrity_suspect', 
																								@message_id=0, 
																								@severity=22, 
																								@enabled=1, 
																								@delay_between_responses=0, 
																								@include_event_description_in=1, 
																								@category_name=N'[Uncategorized]', 
																								@job_id=N'00000000-0000-0000-0000-000000000000'

		  if (@@ERROR <> 0 OR @ReturnCode <> 0) 
 	      goto QuitWithRollback

		commit transaction
    goto endsave
    quitwithrollback:
    if (@@trancount > 0) 
		  rollback transaction
    endsave:
  end

USE [msdb]
GO
if not exists (select id from msdb.dbo.sysalerts where name = N'dba - 023_fatal_error_database_integrity_suspect')
  begin
		begin transaction
			declare @returncode int
			select @returncode = 0

			/****** Object:  Alert [dba - 018_NONFATAL_INTERNAL_ERROR]    Script Date: 11.04.2019 10:42:14 ******/
			exec @returncode = msdb.dbo.sp_add_alert  @name=N'dba - 023_fatal_error_database_integrity_suspect', 
	 																							@message_id=0, 
																								@severity=23, 
																								@enabled=1, 
																								@delay_between_responses=0, 
																								@include_event_description_in=1, 
																								@category_name=N'[Uncategorized]', 
																								@job_id=N'00000000-0000-0000-0000-000000000000'

		  if (@@ERROR <> 0 OR @ReturnCode <> 0) 
 	      goto QuitWithRollback

		commit transaction
    goto endsave
    quitwithrollback:
    if (@@trancount > 0) 
		  rollback transaction
    endsave:
  end

USE [msdb]
GO
if not exists (select id from msdb.dbo.sysalerts where name = N'dba - 024_hardware_error')
  begin
		begin transaction
			declare @returncode int
			select @returncode = 0

			/****** Object:  Alert [dba - 018_NONFATAL_INTERNAL_ERROR]    Script Date: 11.04.2019 10:42:14 ******/
			exec @returncode = msdb.dbo.sp_add_alert  @name=N'dba - 024_hardware_error', 
	 																							@message_id=0, 
																								@severity=24, 
																								@enabled=1, 
																								@delay_between_responses=0, 
																								@include_event_description_in=1, 
																								@category_name=N'[Uncategorized]', 
																								@job_id=N'00000000-0000-0000-0000-000000000000'

		  if (@@ERROR <> 0 OR @ReturnCode <> 0) 
 	      goto QuitWithRollback

		commit transaction
    goto endsave
    quitwithrollback:
    if (@@trancount > 0) 
		  rollback transaction
    endsave:
  end

USE [msdb]
GO
if not exists (select id from msdb.dbo.sysalerts where name = N'dba - 025_fatal_error')
  begin
		begin transaction
			declare @returncode int
			select @returncode = 0

			/****** Object:  Alert [dba - 018_NONFATAL_INTERNAL_ERROR]    Script Date: 11.04.2019 10:42:14 ******/
			exec @returncode = msdb.dbo.sp_add_alert  @name=N'dba - 025_fatal_error', 
	 																							@message_id=0, 
																								@severity=25, 
																								@enabled=1, 
																								@delay_between_responses=0, 
																								@include_event_description_in=1, 
																								@category_name=N'[Uncategorized]', 
																								@job_id=N'00000000-0000-0000-0000-000000000000'

		  if (@@ERROR <> 0 OR @ReturnCode <> 0) 
 	      goto QuitWithRollback

		commit transaction
    goto endsave
    quitwithrollback:
    if (@@trancount > 0) 
		  rollback transaction
    endsave:
  end


USE [msdb]
GO
if not exists (select id from msdb.dbo.sysalerts where name = 'dba - Monitor LONG RUNNING TRANSACTION')
  begin
	/****** Object:  Job [dba - get long running queries]    Script Date: 10.12.2018 11:24:16 ******/
	  BEGIN TRANSACTION
	    DECLARE @ReturnCode INT
	    SELECT @ReturnCode = 0
	    /****** Object:  JobCategory [[Uncategorized (Local)]]    Script Date: 10.12.2018 11:24:16 ******/
	    IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
	      BEGIN
	        EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
	        IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
        END

			DECLARE @jobId BINARY(16)
			if not exists (select name from msdb.dbo.sysjobs where name = N'dba - get_long_running_queries')
			  begin
					exec @ReturnCode = msdb.dbo.sp_add_job  @job_name=N'dba - get_long_running_queries', 
																									@enabled=1, 
																									@notify_level_eventlog=0, 
																									@notify_level_email=2, 
																									@notify_level_netsend=0, 
																									@notify_level_page=0, 
																									@delete_level=0, 
																									@description=N'No description available.', 
																									@category_name=N'[Uncategorized (Local)]', 
																									@owner_login_name=N'sa', 
																									@notify_email_operator_name=N'Marcus Deubel', 
																									@job_id = @jobId OUTPUT

					if (@@ERROR <> 0 OR @ReturnCode <> 0) goto QuitWithRollback

					/****** Object:  Step [get_longrunnig_queries]    Script Date: 10.12.2018 11:24:17 ******/
					EXEC @ReturnCode = msdb.dbo.sp_add_jobstep  @job_id=@jobId, 
																											@step_name=N'get_longrunnig_queries', 
																											@step_id=1, 
																											@cmdexec_success_code=0, 
																											@on_success_action=1, 
																											@on_success_step_id=0, 
																											@on_fail_action=2, 
																											@on_fail_step_id=0, 
																											@retry_attempts=0, 
																											@retry_interval=0, 
																											@os_run_priority=0, 
																											@subsystem=N'TSQL', 
																											@command=N'EXEC msdb.dbo.sp_smi_get_long_running_queries @rcpto = N''smi_dbalerts@ukw.de''', 
																											@database_name=N'msdb', 
																											@flags=0

					IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

					EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
					IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
	
					exec @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
					IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback


			  end
			/****** Object:  Alert [dba - Monitor LONG RUNNING TRANSACTION]    Script Date: 10.12.2018 11:22:34 ******/
			exec @returncode = msdb.dbo.sp_add_alert  @name=N'dba - Monitor LONG RUNNING TRANSACTION', 
																								@message_id=0, 
																								@severity=0, 
																								@enabled=1, 
																								@delay_between_responses=60, 
																								@include_event_description_in=1, 
																								@notification_message=N'Langläufer entdeckt. Macht was!', 
																								@category_name=N'[Uncategorized]', 
																								@performance_condition=N'Transactions|Longest Transaction Running Time||>|15', 
																								@job_name=N'dba - get_long_running_queries'
			if (@@ERROR <> 0 OR @ReturnCode <> 0) goto QuitWithRollback
		COMMIT TRANSACTION
		GOTO EndSave
		QuitWithRollback:
			IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
		EndSave:
  end


use [msdb]
go

declare @returncode int
select @returncode = 0

exec @returncode = msdb.dbo.sp_update_operator  @name=N'dbalerts', 
																								@enabled=1, 
																								@pager_days=0, 
																								@email_address=N'smi_dbalerts@ukw.de', 
																								@pager_address=N''

exec @returncode = msdb.dbo.sp_add_notification @alert_name=N'dba - 1101_low_disk_space', @operator_name=N'dbalerts', @notification_method = 1
exec @returncode = msdb.dbo.sp_add_notification @alert_name=N'dba - 1105_no_more_space_in_filegroup', @operator_name=N'dbalerts', @notification_method = 1
exec @returncode = msdb.dbo.sp_add_notification @alert_name=N'dba - 17053_os_error', @operator_name=N'dbalerts', @notification_method = 1
exec @returncode = msdb.dbo.sp_add_notification @alert_name=N'dba - 18204_backup_device_failed', @operator_name=N'dbalerts', @notification_method = 1
exec @returncode = msdb.dbo.sp_add_notification @alert_name=N'dba - 18210_failure_on_backup_device', @operator_name=N'dbalerts', @notification_method = 1
exec @returncode = msdb.dbo.sp_add_notification @alert_name=N'dba - 3041_backup_failed', @operator_name=N'dbalerts', @notification_method = 1
exec @returncode = msdb.dbo.sp_add_notification @alert_name=N'dba - 3043_backup_page_error', @operator_name=N'dbalerts', @notification_method = 1
exec @returncode = msdb.dbo.sp_add_notification @alert_name=N'dba - 3049_backup_trn_corrupt', @operator_name=N'dbalerts', @notification_method = 1
exec @returncode = msdb.dbo.sp_add_notification @alert_name=N'dba - 9001_log_not_avail', @operator_name=N'dbalerts', @notification_method = 1
exec @returncode = msdb.dbo.sp_add_notification @alert_name=N'dba - 9002_log_is_full', @operator_name=N'dbalerts', @notification_method = 1
exec @returncode = msdb.dbo.sp_add_notification @alert_name=N'dba - 9003_log_invalid_lsn', @operator_name=N'dbalerts', @notification_method = 1
exec @returncode = msdb.dbo.sp_add_notification @alert_name=N'dba - 9004_log_corrupt', @operator_name=N'dbalerts', @notification_method = 1
exec @returncode = msdb.dbo.sp_add_notification @alert_name=N'dba - 823_b_harderr', @operator_name=N'dbalerts', @notification_method = 1
exec @returncode = msdb.dbo.sp_add_notification @alert_name=N'dba - 824_b_hardsserr', @operator_name=N'dbalerts', @notification_method = 1
exec @returncode = msdb.dbo.sp_add_notification @alert_name=N'dba - 825_b_retryworked', @operator_name=N'dbalerts', @notification_method = 1
exec @returncode = msdb.dbo.sp_add_notification @alert_name=N'dba - Monitor LONG RUNNING TRANSACTION', @operator_name=N'dbalerts', @notification_method = 1
exec @returncode = msdb.dbo.sp_add_notification @alert_name=N'dba - 017_insufficient_resources', @operator_name=N'dbalerts', @notification_method = 1
exec @returncode = msdb.dbo.sp_add_notification @alert_name=N'dba - 018_nonfatal_internal_error', @operator_name=N'dbalerts', @notification_method = 1
exec @returncode = msdb.dbo.sp_add_notification @alert_name=N'dba - 019_error_in_resource', @operator_name=N'dbalerts', @notification_method = 1
exec @returncode = msdb.dbo.sp_add_notification @alert_name=N'dba - 020_FATAL_error_in_current_process', @operator_name=N'dbalerts', @notification_method = 1
exec @returncode = msdb.dbo.sp_add_notification @alert_name=N'dba - 021_fatal_error_database', @operator_name=N'dbalerts', @notification_method = 1
exec @returncode = msdb.dbo.sp_add_notification @alert_name=N'dba - 022_fatal_error_table_integrity_suspect', @operator_name=N'dbalerts', @notification_method = 1
exec @returncode = msdb.dbo.sp_add_notification @alert_name=N'dba - 023_fatal_error_database_integrity_suspect', @operator_name=N'dbalerts', @notification_method = 1
exec @returncode = msdb.dbo.sp_add_notification @alert_name=N'dba - 024_hardware_error', @operator_name=N'dbalerts', @notification_method = 1
exec @returncode = msdb.dbo.sp_add_notification @alert_name=N'dba - 025_fatal_error', @operator_name=N'dbalerts', @notification_method = 1
GO

