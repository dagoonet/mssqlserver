USE [master]
GO

declare @len int;
declare @temp nvarchar(max);
declare @logfilepath nvarchar(max);

select @temp = convert(nvarchar(max), SERVERPROPERTY('ErrorLogFileName'));
select @logfilepath = left(@temp, charindex('ERRORLOG', @temp) - 1);


declare @dynamicsql nvarchar(1000);

select @dynamicsql = N'CREATE SERVER AUDIT [SQLServerService_State_Changed]
TO FILE 
(	FILEPATH = N''' + @logfilepath + ''',
	MAXSIZE = 512 MB,
	MAX_FILES = 10,
	RESERVE_DISK_SPACE = ON
)
WITH
(	QUEUE_DELAY = 1000
	,ON_FAILURE = CONTINUE
	,AUDIT_GUID = ''e495d898-7d06-41e1-b05b-3c610a90f9af''
)
ALTER SERVER AUDIT [SQLServerService_State_Changed] WITH (STATE = ON)';

exec sp_executesql @dynamicSql


use [master]
go

create server audit specification [spec_sqlserverservice_state_changed]
for server audit [SQLServerService_State_Changed]
add (server_state_change_group)
with (state = on)
go

