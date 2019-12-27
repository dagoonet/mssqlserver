

----------------------------------------------------
-- --- Database Mail setup										--- --
-- --- Enable Database Mail for this instance --- --
----------------------------------------------------
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
declare @smtpserver varchar(1024);
declare @adminemail varchar(1024);
declare @domainname varchar(1024);
declare @replytoemail varchar(1024);
   
SET @SMTPServer = 'relay2int1.ukw.de';
SET @AdminEmail = 'smi_dbalerts@ukw.de';
SET @DomainName = '@ukw.de';
SET @replyToEmail = 'smi_dbalerts@ukw.de';

declare @servername varchar(100);
declare @email_address varchar(100);
declare @display_name varchar(100);
declare @testmsg varchar(100);
declare @profile varchar(100);
declare @account varchar(100);
set @account = 'Primary Account';
set @servername = replace(lower(@@servername),'\','_');
set @email_address = @servername + @DomainName;
set @display_name = 'MSSQL - ' + @servername;
set @testmsg = 'Test from ' + @servername;
set @profile = 'Default Public Profile';

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
execute msdb.dbo.sysmail_add_account_sp	@account_name = 'Primary Account',
																				@description = 'Account used by all mail profiles.',
																				@email_address = @email_address,
																				@replyto_address = @replyToEmail,
																				@display_name = @display_name,
																				@mailserver_name = @SMTPServer;

	-- Create a Database Mail profile
execute msdb.dbo.sysmail_add_profile_sp @profile_name = @profile,
																				@description = 'Default public profile for all users';

 

	-- Add the account to the profile
execute msdb.dbo.sysmail_add_profileaccount_sp @profile_name = @profile,
																							 @account_name = 'Primary Account',
																							 @sequence_number = 1;


	-- Grant access to the profile to all msdb database users
execute msdb.dbo.sysmail_add_principalprofile_sp @profile_name = @profile,
																								 @principal_name = 'public',
																								 @is_default = 1;

EXECUTE msdb.dbo.sysmail_configure_sp 'MaxFileSize', '10000000';

--send a test email
execute msdb.dbo.sp_send_dbmail @subject = @testmsg,
																@recipients = 'deubel_m@ukw.de',
																@query = 'select lower(@@servername)';
   
execute  msdb.dbo.sp_set_sqlagent_properties @email_save_in_sent_folder=1, 
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
