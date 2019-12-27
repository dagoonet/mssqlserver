-- Enable Database Mail for this instance

EXECUTE sp_configure 'show advanced', 1;

RECONFIGURE;

EXECUTE sp_configure 'Database Mail XPs',1;

RECONFIGURE;

GO

 

-- Create a Database Mail account

EXECUTE msdb.dbo.sysmail_add_account_sp

    @account_name = 'Primary Account',

    @description = 'Account used by all mail profiles.',

    @email_address = 'clsqlbip@ukw.de',

    @replyto_address = 'clsqlbip@ukw.de',

    @display_name = 'clsqlbip@ukw.de',

    @mailserver_name = 'relay2int1.ukw.de';

 

-- Create a Database Mail profile

EXECUTE msdb.dbo.sysmail_add_profile_sp

    @profile_name = 'Default Public Profile',

    @description = 'Default public profile for all users';

 

-- Add the account to the profile

EXECUTE msdb.dbo.sysmail_add_profileaccount_sp

    @profile_name = 'Default Public Profile',

    @account_name = 'Primary Account',

    @sequence_number = 1;

 

-- Grant access to the profile to all msdb database users

EXECUTE msdb.dbo.sysmail_add_principalprofile_sp

    @profile_name = 'Default Public Profile',

    @principal_name = 'public',

    @is_default = 1;

GO

 

--send a test email

EXECUTE msdb.dbo.sp_send_dbmail

    @subject = 'Test Database Mail Message',

    @recipients = 'deubel_m@ukw.de',

    @query = 'SELECT @@SERVERNAME';

GO



USE [msdb]
GO

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
GO

USE [msdb]
GO

/****** Object:  Operator [dbalerts]    Script Date: 11/27/2012 09:39:48 ******/
EXEC msdb.dbo.sp_add_operator @name=N'dbalerts', 
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
GO




