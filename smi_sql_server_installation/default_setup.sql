----------------------------------------
----  SMI SQL Server default Setup  ----
----------------------------------------
-- =====================================================
-- Author:		Marcus Deubel
-- Copyright: (c) Marcus Deubel
-- Create date: -----------
-- Modify date: 5.5.2019
-- Description:	default setup script for SMI SQL Server
-- =====================================================


-- create default database owner
USE [master]
GO

declare @SqlStatement nvarchar(4000)
declare @loginName varchar (100)

select @loginName = N'smi_db_owner'
/* For security reasons the login is created disabled and with a random password. */
/****** Object:  Login [smi_db_owner]    Script Date: 06.12.2018 15:01:07 ******/
If not Exists (select loginname from master.dbo.syslogins where name = @loginName)
  begin
    set @SqlStatement = N'CREATE LOGIN [' + @loginName + '] WITH PASSWORD=''hr1rqJWb70fIBLEuz7AWFyRTaDhrdhOl7YAaxaqUkIU='', DEFAULT_DATABASE=[tempdb], DEFAULT_LANGUAGE=[us_english], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF';
		exec sp_executesql @SqlStatement;
		set @SqlStatement = N'ALTER LOGIN [' + @loginName + '] DISABLE';
		exec sp_executesql @SqLStatement;
		set @SqlStatement = N'DENY CONNECT SQL TO [' + @loginName + ']';
		exec sp_executesql @SqlStatement;
  end;

-------------------------------------
-- create SQL Server Agent Account --
-------------------------------------
--Select @loginName = N'klinik\ServiceSSA';
--If not Exists (select loginname from master.dbo.syslogins where name = @loginName)
--  begin 
--    Set @SqlStatement = 'CREATE LOGIN [' + @loginName + '] FROM WINDOWS WITH DEFAULT_DATABASE=[tempdb], DEFAULT_LANGUAGE=[us_english]';
--    EXEC sp_executesql @SqlStatement;
--    set @SqlStatement = N'ALTER SERVER ROLE [sysadmin] ADD MEMBER [' + @loginName + ']';
--    EXEC sp_executesql @SqlStatement;
--  end

---------------------------
-- Readonly Server Rolle --
---------------------------
if not exists (select principal_id from master.sys.server_principals where name = 'smi_srv_ReadonlyAccess' and type = 'R')
  begin
    create server role smi_srv_ReadonlyAccess authorization sa;
    grant view server state to smi_srv_ReadonlyAccess;
    grant view any database to smi_srv_ReadonlyAccess;
    grant connect any database to smi_srv_ReadonlyAccess;
    grant select all user securables to smi_srv_ReadonlyAccess;
		grant view any definition to smi_srv_ReadonlyAccess;
  end

if exists (select principal_id from master.sys.server_principals where name = 'smi_srv_ReadonlyAccess' and type = 'R')
  begin
		grant view any definition to smi_srv_ReadonlyAccess;
  end

--------------------------------------
-- create SQL Server Auditors login --
--------------------------------------
Select @loginName = N'klinik\SQL Server Auditors';
If not Exists (select loginname from master.dbo.syslogins where name = @loginName)
  begin 
    Set @SqlStatement = 'CREATE LOGIN [' + @loginName + '] FROM WINDOWS WITH DEFAULT_DATABASE=[tempdb], DEFAULT_LANGUAGE=[us_english]';
    EXEC sp_executesql @SqlStatement;
    set @SqlStatement = N'ALTER SERVER ROLE [smi_srv_ReadonlyAccess] ADD MEMBER [' + @loginName + ']';
    EXEC sp_executesql @SqlStatement;
  end


-----------------------------
-- Remote Admin connection --
-----------------------------
execute sp_configure 'remote admin connections', 1 
GO
reconfigure
GO


--------------------------------------------
-- Database Mail setup --
-- Enable Database Mail for this instance --
--------------------------------------------
use master;
go
EXECUTE sp_configure 'show advanced', 1;
go
reconfigure
GO
EXECUTE sp_configure 'Database Mail XPs', 1;
go
reconfigure
go
exec sp_configure 'Agent XPs', 1 -- SQL Server Agent Mail Profil aktivieren
GO
RECONFIGURE WITH OVERRIDE
GO

waitfor delay '00:00:20';

-- Create a Database Mail account

use [msdb]
go
DECLARE @SMTPServer VARCHAR(1024)
DECLARE @AdminEmail VARCHAR(1024)
DECLARE @DomainName VARCHAR(1024)
DECLARE @replyToEmail VARCHAR(1024)
   
SET @SMTPServer = 'relay2int1.ukw.de'
SET @AdminEmail = 'smi_dbalerts@ukw.de'
SET @DomainName = '@ukw.de'
SET @replyToEmail = 'smi_dbalerts@ukw.de'

declare @servername varchar(100)
declare @email_address varchar(100)
declare @display_name varchar(100)
declare @testmsg varchar(100)
declare @profile varchar(100)
declare @account varchar(100);
set @account = 'Primary Account';
set @servername = replace(lower(@@servername),'\','_')
set @email_address = @servername + @DomainName;
set @display_name = 'MSSQL - ' + @servername
set @testmsg = 'Test from ' + @servername
set @profile = 'Default Public Profile'

if exists(select * from msdb.dbo.sysmail_profile)
  begin
		execute msdb.dbo.sysmail_delete_profile_sp @profile_name = @profile;			
	end
if exists(select * from msdb.dbo.sysmail_profileaccount)
	begin
		execute msdb.dbo.sysmail_delete_profileaccount_sp @profile_name = @profile;
	end
if exists(select * from msdb.dbo.sysmail_account)
  begin
		execute msdb.dbo.sysmail_delete_account_sp @account_name = @account; 
	end

print '--------------------------------------';
print '-- --- Database Mail einrichten --- --';
print '--------------------------------------';
EXECUTE msdb.dbo.sysmail_add_account_sp	@account_name = 'Primary Account',
																				@description = 'Account used by all mail profiles.',
																				@email_address = @email_address,
																				@replyto_address = @replyToEmail,
																				@display_name = @display_name,
																				@mailserver_name = @SMTPServer;

-- Create a Database Mail profile
execute msdb.dbo.sysmail_add_profile_sp @profile_name = @profile,
																				@description = 'Default public profile for all users';

 

	-- Add the account to the profile
	EXECUTE msdb.dbo.sysmail_add_profileaccount_sp
		@profile_name = @profile,
		@account_name = 'Primary Account',
		@sequence_number = 1;


	-- Grant access to the profile to all msdb database users
	EXECUTE msdb.dbo.sysmail_add_principalprofile_sp
		@profile_name = @profile,
		@principal_name = 'public',
		@is_default = 1;

	EXECUTE msdb.dbo.sysmail_configure_sp 'MaxFileSize', '10000000';

	--send a test email
	EXECUTE msdb.dbo.sp_send_dbmail
		@subject = @testmsg,
		@recipients = 'deubel_m@ukw.de',
		@query = 'SELECT lower(@@SERVERNAME)';
   
  EXECUTE  msdb.dbo.sp_set_sqlagent_properties 
	    @email_save_in_sent_folder=1, 
		  @databasemail_profile=@profile, 
		  @use_databasemail=1

USE [msdb]
GO

if not exists (select id from msdb.dbo.sysoperators where name = 'Marcus Deubel')
  begin
	/****** Object:  Operator [Marcus Deubel]    Script Date: 11/27/2012 07:47:43 ******/
	EXEC msdb.dbo.sp_add_operator @name=N'Marcus Deubel', 
																@enabled=1, 
																@weekday_pager_start_time=90000, 
																@weekday_pager_end_time=180000, 
																@saturday_pager_start_time=90000, 
																@saturday_pager_end_time=180000, 
																@sunday_pager_start_time=90000, 
																@sunday_pager_end_time=180000, 
																@pager_days=0, 
																@email_address=N'deubel_m@ukw.de', 
																@category_name=N'[Uncategorized]'
  end

USE [msdb]
GO

if not exists (select id from msdb.dbo.sysoperators where name = 'smi_dbalerts')
  begin
		/****** Object:  Operator [dbalerts]    Script Date: 11/27/2012 09:39:48 ******/
		EXEC msdb.dbo.sp_add_operator @name=N'smi_dbalerts', 
																	@enabled=1, 
																	@weekday_pager_start_time=90000, 
																	@weekday_pager_end_time=180000, 
																	@saturday_pager_start_time=90000, 
																	@saturday_pager_end_time=180000, 
																	@sunday_pager_start_time=90000, 
																	@sunday_pager_end_time=180000, 
																	@pager_days=0, 
																	@email_address=N'smi_dbalerts@ukw.de', 
																	@category_name=N'[Uncategorized]'
  end


/*** logrotate ***/

USE [msdb]
GO

if not exists (select job_id from msdb.dbo.sysjobs_view where name = N'dba - sql_server_agent_logrotation')
  begin
		/****** object:  job [sql_server_agent_logrotation]    script date: 09/04/2012 10:27:47 ******/
		begin transaction
			declare @returncode int
			select @returncode = 0
			/****** object:  jobcategory [database maintenance]    script date: 09/04/2012 10:27:47 ******/
			if not exists (select name from msdb.dbo.syscategories where name=N'database maintenance' and category_class=1)
				begin
					exec @returncode = msdb.dbo.sp_add_category @class=N'job', @type=N'local', @name=N'database maintenance'
					if (@@error <> 0 or @returncode <> 0) goto quitwithrollback
				END

			declare @jobid binary(16)
			if not exists (select name from msdb.dbo.sysjobs where name = N'dba - sql_server_agent_logrotation')
				begin
					exec @returncode =  msdb.dbo.sp_add_job @job_name=N'dba - sql_server_agent_logrotation', 
																									@enabled=1, 
																									@notify_level_eventlog=0, 
																									@notify_level_email=2, 
																									@notify_level_netsend=0, 
																									@notify_level_page=0, 
																									@delete_level=0, 
																									@description=N'rotiert die logs des agents. md 2012-09-03', 
																									@category_name=N'database maintenance', 
																									@owner_login_name=N'sa', 
																									@job_id = @jobid output
					if (@@error <> 0 or @returncode <> 0) goto quitwithrollback
					/****** object:  step [sp_cycle_agent_errorlog]    script date: 09/04/2012 10:27:47 ******/
					exec @returncode = msdb.dbo.sp_add_jobstep  @job_id=@jobid, @step_name=N'sp_cycle_agent_errorlog', 
																											@step_id=1, 
																											@cmdexec_success_code=0, 
																											@on_success_action=1, 
																											@on_success_step_id=0, 
																											@on_fail_action=2, 
																											@on_fail_step_id=0, 
																											@retry_attempts=0, 
																											@retry_interval=0, 
																											@os_run_priority=0,
																											@subsystem=N'tsql', 
																											@command=N'exec dbo.sp_cycle_agent_errorlog', 
																											@database_name=N'msdb', 
																											@flags=0
					if (@@error <> 0 or @returncode <> 0) goto quitwithrollback
				
					exec @returncode = msdb.dbo.sp_update_job @job_id = @jobid, @start_step_id = 1
					if (@@error <> 0 or @returncode <> 0) goto quitwithrollback
				
					exec @returncode = msdb.dbo.sp_add_jobschedule  @job_id=@jobid, @name=N'daily_logrotation', 
																													@enabled=1, 
																													@freq_type=4, 
																													@freq_interval=1, 
																													@freq_subday_type=1, 
																													@freq_subday_interval=0, 
																													@freq_relative_interval=0, 
																													@freq_recurrence_factor=0, 
																													@active_start_date=20120903, 
																													@active_end_date=99991231, 
																													@active_start_time=30000, 
																													@active_end_time=235959, 
																													@schedule_uid=N'961682b5-b33f-4f7a-a53b-eb3cad755d5d'
					if (@@error <> 0 or @returncode <> 0) goto quitwithrollback
				
					exec @returncode = msdb.dbo.sp_add_jobserver @job_id = @jobid, @server_name = N'(local)'
					if (@@error <> 0 or @returncode <> 0) goto quitwithrollback
				end
		commit transaction
		goto endsave
		quitwithrollback:
			if (@@trancount > 0) rollback transaction
		endsave:
  end
go


use msdb
go
if not exists (select job_id from msdb.dbo.sysjobs_view where name = N'dba - sql_server_logrotate')
  begin
		/****** object:  job [sql_server_logrotate]    script date: 09/04/2012 10:27:47 ******/
		begin transaction
			declare @returncode int
			select @returncode = 0
			/****** object:  jobcategory [database maintenance]    script date: 09/04/2012 10:27:47 ******/
			if not exists (select name from msdb.dbo.syscategories where name = N'database maintenance' and category_class=1)
  			begin
					exec @returncode = msdb.dbo.sp_add_category @class=N'job', @type=N'local', @name=N'database maintenance'
					if (@@error <> 0 or @returncode <> 0) goto quitwithrollback
				end

				declare @jobid binary(16)
				if not exists (select name from msdb.dbo.sysjobs where name = N'dba - sql_server_logrotate')
					begin
						exec @returncode =  msdb.dbo.sp_add_job @job_name=N'dba - sql_server_logrotate', 
																										@enabled=1, 
																										@notify_level_eventlog=0, 
																										@notify_level_email=2, 
																										@notify_level_netsend=0, 
																										@notify_level_page=0, 
																										@delete_level=0, 
																										@description=N'rotiert die logs des sql servers. md 2012-03-09', 
																										@category_name=N'database maintenance', 
																										@owner_login_name=N'sa', 
																										@job_id = @jobid output
						if (@@error <> 0 or @returncode <> 0) goto quitwithrollback

						/****** object:  step [sp_cycle_errorlog]    script date: 09/04/2012 10:27:47 ******/
						exec @returncode = msdb.dbo.sp_add_jobstep  @job_id=@jobid, 
																												@step_name=N'sp_cycle_errorlog', 
																												@step_id=1, 
																												@cmdexec_success_code=0, 
																												@on_success_action=1, 
																												@on_success_step_id=0, 
																												@on_fail_action=2, 
																												@on_fail_step_id=0, 
																												@retry_attempts=0, 
																												@retry_interval=0, 
																												@os_run_priority=0, 
																												@subsystem=N'tsql', 
																												@command=N'exec sp_cycle_errorlog', 
																												@database_name=N'master', 
																												@flags=0
						if (@@error <> 0 or @returncode <> 0) goto quitwithrollback

						exec @returncode = msdb.dbo.sp_update_job @job_id = @jobid, @start_step_id = 1
						if (@@error <> 0 or @returncode <> 0) goto quitwithrollback

						exec @returncode = msdb.dbo.sp_add_jobschedule  @job_id=@jobid, 
																														@name=N'daily_logrotation', 
																														@enabled=1, 
																														@freq_type=4, 
																														@freq_interval=1, 
																														@freq_subday_type=1, 
																														@freq_subday_interval=0, 
																														@freq_relative_interval=0, 
																														@freq_recurrence_factor=0, 
																														@active_start_date=20120903, 
																														@active_end_date=99991231, 
																														@active_start_time=30000, 
																														@active_end_time=235959, 
																														@schedule_uid=N'961682b5-b33f-4f7a-a53b-eb3cad755d5d'
						if (@@error <> 0 or @returncode <> 0) goto quitwithrollback

						exec @returncode = msdb.dbo.sp_add_jobserver @job_id = @jobid, @server_name = N'(local)'
						if (@@error <> 0 or @returncode <> 0) goto quitwithrollback
					end
		commit transaction
		goto endsave
	
		quitwithrollback:
			if (@@trancount > 0) rollback transaction
		endsave:
  end
go

-----------------------------------------------------------------------------------------------------------------------------
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
if not exists (select id from msdb.dbo.sysalerts where name = N'dba - 3928_trn_failed_deadlock')
  begin
		begin transaction
			declare @returncode int
			select @returncode = 0

			/****** Object:  Alert [Error_3928_Deadlock_detected]    Script Date: 23.10.2015 08:02:50 ******/
			exec @ReturnCode = msdb.dbo.sp_add_alert  @name=N'dba - 3928_trn_failed_deadlock', 
																								@message_id=3928, 
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
																											@command=N'EXEC msdb.dbo.smi_sp_policy_violation @rcpto = N''smi_dbalerts@ukw.de'', @check = 0', 
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
			  end

      if not exists (select id from msdb.dbo.sysalerts where name = N'dba - 34052_scheduled_policy_violation')
       begin
				 /****** Object:  Alert [dba - 34052_Scheduled_Policy_Violation]    Script Date: 11.04.2019 11:26:46 ******/
				 exec @ReturnCode = msdb.dbo.sp_add_alert	@name=N'dba - 34052_scheduled_policy_violation', 
																									@message_id=34052, 
																									@severity=0, 
																									@enabled=1, 
																									@delay_between_responses=60, 
																									@include_event_description_in=1, 
																									@category_name=N'[Uncategorized]', 
																									@job_name='dba - Policy_Violation_Notification'
				if (@@ERROR <> 0 OR @ReturnCode <> 0) 
					goto QuitWithRollback
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
--14	Insufficient Permissions
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

			/****** Object:  Alert [dba - 014_insuffcient_permissions]    Script Date: 18.10.2019 09:50:58 ******/
			exec msdb.dbo.sp_add_alert	@name=N'dba - 014_insufficient_permissions', 
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
if not exists (select id from msdb.dbo.sysalerts where name = N'dba - Monitor LONG RUNNING TRANSACTION')
  begin
	  /****** Object:  Job [dba - get long running queries]    Script Date: 10.12.2018 11:24:16 ******/
    begin transaction
		  declare @returncode int
	    select @returncode = 0

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
																											@command=N'exec msdb.dbo.smi_sp_get_long_running_queries @rcpto = N''smi_dbalerts@ukw.de'', @check = 0, @skipdbs = ''1,3''', 
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

exec @returncode = msdb.dbo.sp_update_operator  @name=N'smi_dbalerts', 
																								@enabled=1, 
																								@pager_days=0, 
																								@email_address=N'smi_dbalerts@ukw.de', 
																								@pager_address=N''

exec @returncode = msdb.dbo.sp_add_notification @alert_name=N'dba - 1101_low_disk_space', @operator_name=N'smi_dbalerts', @notification_method = 1
exec @returncode = msdb.dbo.sp_add_notification @alert_name=N'dba - 1105_no_more_space_in_filegroup', @operator_name=N'smi_dbalerts', @notification_method = 1
exec @returncode = msdb.dbo.sp_add_notification @alert_name=N'dba - 17053_os_error', @operator_name=N'smi_dbalerts', @notification_method = 1
exec @returncode = msdb.dbo.sp_add_notification @alert_name=N'dba - 18204_backup_device_failed', @operator_name=N'smi_dbalerts', @notification_method = 1
exec @returncode = msdb.dbo.sp_add_notification @alert_name=N'dba - 18210_failure_on_backup_device', @operator_name=N'smi_dbalerts', @notification_method = 1
exec @returncode = msdb.dbo.sp_add_notification @alert_name=N'dba - 3041_backup_failed', @operator_name=N'smi_dbalerts', @notification_method = 1
exec @returncode = msdb.dbo.sp_add_notification @alert_name=N'dba - 3043_backup_page_error', @operator_name=N'smi_dbalerts', @notification_method = 1
exec @returncode = msdb.dbo.sp_add_notification @alert_name=N'dba - 3049_backup_trn_corrupt', @operator_name=N'smi_dbalerts', @notification_method = 1
exec @returncode = msdb.dbo.sp_add_notification @alert_name=N'dba - 9001_log_not_avail', @operator_name=N'smi_dbalerts', @notification_method = 1
exec @returncode = msdb.dbo.sp_add_notification @alert_name=N'dba - 9002_log_is_full', @operator_name=N'smi_dbalerts', @notification_method = 1
exec @returncode = msdb.dbo.sp_add_notification @alert_name=N'dba - 9003_log_invalid_lsn', @operator_name=N'smi_dbalerts', @notification_method = 1
exec @returncode = msdb.dbo.sp_add_notification @alert_name=N'dba - 9004_log_corrupt', @operator_name=N'smi_dbalerts', @notification_method = 1
exec @returncode = msdb.dbo.sp_add_notification @alert_name=N'dba - 823_b_harderr', @operator_name=N'smi_dbalerts', @notification_method = 1
exec @returncode = msdb.dbo.sp_add_notification @alert_name=N'dba - 824_b_hardsserr', @operator_name=N'smi_dbalerts', @notification_method = 1
exec @returncode = msdb.dbo.sp_add_notification @alert_name=N'dba - 825_b_retryworked', @operator_name=N'smi_dbalerts', @notification_method = 1
exec @returncode = msdb.dbo.sp_add_notification @alert_name=N'dba - Monitor LONG RUNNING TRANSACTION', @operator_name=N'smi_dbalerts', @notification_method = 1
exec @returncode = msdb.dbo.sp_add_notification @alert_name=N'dba - 017_insufficient_resources', @operator_name=N'smi_dbalerts', @notification_method = 1
exec @returncode = msdb.dbo.sp_add_notification @alert_name=N'dba - 018_nonfatal_internal_error', @operator_name=N'smi_dbalerts', @notification_method = 1
exec @returncode = msdb.dbo.sp_add_notification @alert_name=N'dba - 019_error_in_resource', @operator_name=N'smi_dbalerts', @notification_method = 1
exec @returncode = msdb.dbo.sp_add_notification @alert_name=N'dba - 020_FATAL_error_in_current_process', @operator_name=N'smi_dbalerts', @notification_method = 1
exec @returncode = msdb.dbo.sp_add_notification @alert_name=N'dba - 021_fatal_error_database', @operator_name=N'smi_dbalerts', @notification_method = 1
exec @returncode = msdb.dbo.sp_add_notification @alert_name=N'dba - 022_fatal_error_table_integrity_suspect', @operator_name=N'smi_dbalerts', @notification_method = 1
exec @returncode = msdb.dbo.sp_add_notification @alert_name=N'dba - 023_fatal_error_database_integrity_suspect', @operator_name=N'smi_dbalerts', @notification_method = 1
exec @returncode = msdb.dbo.sp_add_notification @alert_name=N'dba - 024_hardware_error', @operator_name=N'smi_dbalerts', @notification_method = 1
exec @returncode = msdb.dbo.sp_add_notification @alert_name=N'dba - 025_fatal_error', @operator_name=N'smi_dbalerts', @notification_method = 1
GO



---------------------------------------------------------------------------------------------------------------------

use [master]
go

/****** object:  storedprocedure [dbo].[server_restart]    script date: 19.03.2019 13:48:19 ******/
set ansi_nulls on
go

set quoted_identifier on
go

-- ===============================================================
-- Author:		Marcus Deubel
-- Create date: 03.03.2019
-- Description:	Sends automatic email on SQL Server Instance start
-- ===============================================================

if object_id('smi_sp_server_restart', 'p') is not null
  drop procedure dbo.smi_sp_server_restart
go
-----------------------------------
-- alte Stored Procedure löschen --
-----------------------------------
if object_id('sp_smi_server_restart', 'p') is not null
  drop procedure dbo.sp_smi_server_restart
go


create procedure [dbo].[smi_sp_server_restart] as
  begin
		-- set nocount on added to prevent extra result sets from
		-- interfering with select statements.
		set nocount on;
		------------------------------------------------------------------------------
		---- verschickt eine Mail an @recipients mit der Info über SQL Server --------
		---- Instanz Restart																									--------
		---- eventuell auch die Variable @profile_name												--------
		------------------------------------------------------------------------------
		declare @xml nvarchar(MAX) = N'';
		declare @table nvarchar(MAX);
		declare @lbody nvarchar(max);
		declare @servername nvarchar(200);
		declare @lsubject nvarchar(200);
		declare @reboottime datetime;
		set @servername = @@SERVERNAME;
		set @reboottime = CONVERT(nvarchar(24), GETDATE(), 120);
		-- select @reboottime;

		set @lbody =  N'<html><body>' + N'<H3>SQL Server RESTARTED: ' + @servername + ' - ' + CONVERT(nvarchar(24), GETDATE(), 120) + '</H3>';
				   
		set @table = @lbody + N'</table></body></html>';


		set @lsubject = N'SQL Server RESTARTED: ' + @servername + ' - ' + CONVERT(nvarchar(24), GETDATE(), 120);

		exec msdb.dbo.sp_send_dbmail  @profile_name = N'Default Public Profile',  
																	@recipients = N'smi_dbalerts@ukw.de',  
																	@subject = @lsubject,
																	@body = @lbody,
																	@body_format = N'HTML' ; 

  end
go

exec sp_procoption N'[dbo].[smi_sp_server_restart]', 'startup', '1' -- execute on server startup 
go


------------------------------------------------------------------------------------------------------------------

use [msdb]
go
/****** object:  storedprocedure [dbo].[sp_smi_policy_violation]    script date: 20.04.2019 08:15:37 ******/
set ansi_nulls on
go
set quoted_identifier on
go
-- =============================================
-- Author:		Marcus Deubel
-- Create date: 5.5.2019
-- Description:	executed on policy violation
-- =============================================
if object_id('smi_sp_policy_violation', 'p') is not null
  drop procedure dbo.smi_sp_policy_violation
go
-----------------------------------
-- alte Stored Procedure löschen --
-----------------------------------
if object_id('sp_smi_policy_violation', 'p') is not null
  drop procedure dbo.sp_smi_policy_violation
go



create procedure [dbo].[smi_sp_policy_violation] @rcpto nvarchar(200), @check int = 0
as
begin
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
  declare @pname varchar(50);
	declare @hresult int;
	declare @hdate datetime;
	declare @pid int;
	declare @result bit;
	declare @check_free_space_trn varchar(50);
	declare @databases_not_backed_up varchar(50);

	declare @lsubject nvarchar(200);
	declare @servername nvarchar(200);
	declare @reboottime datetime;

	set @servername = @@SERVERNAME;
	set @reboottime = CONVERT(nvarchar(24), GETDATE(), 120);
	set @result = 0; 
	-- 0 = failure, 1 = success

	
	-- holt die zu letzt ausgeführte Policy raus
	select top 1 @pid = p.policy_id, @pname = p.name, @hresult = h.result, @hdate = h.end_date 
	from msdb.dbo.syspolicy_policies p join msdb.dbo.syspolicy_policy_execution_history h 
	on p.policy_id = h.policy_id
	order by h.start_date desc

  if @result = (select @hresult) or @check = 1
		begin
			------------------------------------------------------------------------------
			---- verschickt eine Mail an @recipients mit der Info über						--------
			---- fehlgeschlagene Policys																					--------
			---- beim Implentieren muß die Variable @recipients angepasst werden  --------
			---- eventuell auch die Variable @profile_name												--------
			------------------------------------------------------------------------------
			DECLARE @xml NVARCHAR(MAX) = N'';
			DECLARE @table NVARCHAR(MAX);
			declare @header nvarchar(max);

			set @header = N'<html>' + 
										N'<style>' +
										N'table, th, td { border: 1px solid black; }' +
										N'</style>' +
										N'</head>' + 
										N'<body>' +
										N'<H3>' + @pname + '</H3>' +  
										N'<table border="1">' +  
										N'<tr>' + 
										N'<th>Policy Name</th>' + 
										N'<th>policy_id</th>' +
										N'<th>history_id</th>' +
										N'<th>Database</th>' +
										N'<th>Execution Date</th>' +
										N'<th>Result</th>' +
										N'<th>Expected Value</th>' + 
										N'<th>Current Value</th>' + 
										N'</tr>';

			set @xml = cast ((select td = @pname, '',
															 td = h.policy_id, '',
															 td = h.history_id, '',
															 td = d.target_query_expression, '',
															 td = d.execution_date, '',
															 td = d.result, '',
															 td = cast(result_detail as xml).value('(/Operator/Constant/Value)[1]', 'varchar(200)'), '', -- CAST da kein XML Datentyp
															 td = cast(result_detail as xml).value('(/Operator/Attribute/ResultValue)[1]', 'varchar(200)'), ''
												from  msdb.dbo.syspolicy_policy_execution_history h join msdb.dbo.syspolicy_policy_execution_history_details d 
												on h.history_id = d.history_id 
												where d.result = '0' 	  
												      and CAST(d.execution_date AS date) = CAST(GETDATE() AS date)
															and h.policy_id = @pid	 
												order by d.execution_date desc
												FOR XML PATH('tr'), TYPE) AS NVARCHAR(MAX));

			set @table = @header + @xml + N'</table></body></html>'

			-- print @table;
			set @lsubject = @servername + N': policy violation' + N' - ' + @pname + ' - ' + CONVERT(nvarchar(24), GETDATE(), 120);

			exec msdb.dbo.sp_send_dbmail  @profile_name = 'Default Public Profile',  
																		@recipients = @rcpto,  
																		@subject = @lsubject,  
																		@body = @table,  
																		@body_format = 'HTML' ;  
		end
end
go
----------------------------------------------------------------------------------------------------

USE [msdb]
GO
/****** Object:  StoredProcedure [dbo].[sp_smi_get_long_running_queries]    Script Date: 11.04.2019 15:54:25 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--------------------------------------------------------------------
-- --- author:		Marcus Deubel																---	--				
-- --- create date: 13.4.2019																	---	--
-- --- description:	sending e-mail about long running queries --- --
--------------------------------------------------------------------
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
  ------------------------------------------------------------------------------
	---- verschickt eine Mail an @recipients mit der Info über Langläufer --------
	---- beim Implentieren muß die Variable @recipients angepasst werden  --------
	---- eventuell auch die Variable @profile_name												--------
	------------------------------------------------------------------------------
	declare @xml nvarchar(max) = N'';
	declare @table nvarchar(max);
	declare @header nvarchar(max);

	declare @lsubject nvarchar(200);
	declare @servername nvarchar(200);
	declare @reboottime datetime;

	set @servername = @@SERVERNAME;
	set @reboottime = CONVERT(nvarchar(24), GETDATE(), 120);

	-- set @skipdbs = '1,2,3,4,7'; -- database ids

	----------------------------
	-- original T-SQL Abfrage --
	----------------------------
	--select b.session_id,
 --  			 isnull(cast(db_name(a.database_id) as varchar(20)), 'n/a') as database_id,
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
														isnull(substring(st.text, ( c.statement_start_offset / 2 ) + 1, ( (  case c.statement_end_offset  when -1 then datalength(st.text) else c.statement_end_offset end - c.statement_start_offset ) / 2 ) + 1), 'n/a') as td, '',
														isnull(coalesce(quotename(db_name(st.dbid)) + '.' + quotename(object_schema_name(st.objectid, st.dbid)) + '.' + quotename(object_name(st.objectid, st.dbid)), ''), 'n/a') as td, '',
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
go
						 
					     


