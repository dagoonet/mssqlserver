USE [msdb]
GO

/****** Object:  Job [DatabaseBackup - USER_DATABASES - FULL]    Script Date: 21.08.2019 09:37:56 ******/
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
EXEC @ReturnCode = msdb.dbo.sp_add_schedule @schedule_name=N'full_database_backup_daily_20h', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20190821, 
		@active_end_date=99991231, 
		@active_start_time=200000, 
		@active_end_time=235959
		-- @schedule_uid=N'8d00db2d-e4ef-41f7-8097-0860f3ab6a8a'

EXEC @ReturnCode = msdb.dbo.sp_add_schedule @schedule_name=N'dbcc_database_daily_21h', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20190821, 
		@active_end_date=99991231, 
		@active_start_time=210000, 
		@active_end_time=235959
		-- @schedule_uid=N'8d00db2d-e4ef-41f7-8097-0860f3ab6a8a'

EXEC @ReturnCode = msdb.dbo.sp_add_schedule @schedule_name=N'index_maintenance_daily', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20190821, 
		@active_end_date=99991231, 
		@active_start_time=064500, 
		@active_end_time=235959
		-- @schedule_uid=N'8d00db2d-e4ef-41f7-8097-0860f3ab6a8a'

EXEC @ReturnCode = msdb.dbo.sp_add_schedule @schedule_name=N'index_maintenance_daily', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20190821, 
		@active_end_date=99991231, 
		@active_start_time=064500, 
		@active_end_time=235959
		-- @schedule_uid=N'8d00db2d-e4ef-41f7-8097-0860f3ab6a8a'

EXEC @ReturnCode = msdb.dbo.sp_add_schedule @schedule_name=N'transactionlog_backup_every_5min', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=5, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20190821, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959
GO 