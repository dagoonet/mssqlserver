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
-- --- description:	sending e-mail about restored databases   --- --
--------------------------------------------------------------------
if object_id('smi_sp_restored_databases', 'p') is not null
  drop procedure dbo.smi_sp_restored_databases
go
create or alter procedure [dbo].[smi_sp_restored_databases] @rcpto nvarchar(200), @check int = 0
-- alter procedure [dbo].[sp_smi_get_long_running_queries] @rcpto nvarchar(200)
as
begin
	-- set nocount on added to prevent extra result sets from
	-- interfering with select statements.
	set nocount on;
  --------------------------------------------------------------------------
	-- --- verschickt eine Mail an @recipients mit der Info über				--- --
	-- --- wiederhergestellte Datenbanken																--- -- 
	-- --- beim Implentieren muß die Variable @recipients								--- --
	-- --- angepasst werden.																					  --- --
	-- --- eventuell auch die Variable @profile_name										--- --
	--------------------------------------------------------------------------
	
	declare @xml nvarchar(max) = N'';
	declare @table nvarchar(max);
	declare @header nvarchar(max);

	declare @lsubject nvarchar(200);
	declare @servername nvarchar(200);
	declare @reboottime datetime;
	declare @datum nvarchar(50);

	set @servername = @@SERVERNAME;
	set @reboottime = CONVERT(nvarchar(24), GETDATE(), 120);
	set @datum = format(getdate(), 'yyyy-MM-dd');

	
	------------------------------------
	-- --- original T-SQL Abfrage --- --
	------------------------------------
	--select servername, databasename, restorepoint, iscorrupted, restored, LastRestored
	--from msdb.dbo.VeeamRestoredDBs
	--where trim(LastRestored) = trim(@datum);

	set @header = N'<html>' +
								N'<style>' +
								N'table, th, td { border: 1px solid black; }' +
								N'</style>' +
								N'</head>' + 
								N'<body>' +
								N'<H3>Restored Databases</H3>' +  
								N'<table border="1">' +  
								N'<tr>' + 
								N'<th>ServerName</th><th>Database Name</th><th>Restorepoint</th><th>Iscorrupted</th><th>Restored</th><th>LastRestored</th>' +
								N'</tr>';

	set @xml = cast ((select  td = servername, '',
														td = databasename, '',
														td = restorepoint, '',
														td = iscorrupted, '',
														td = restored, '',
														td = LastRestored, ''
									  from msdb.dbo.VeeamRestoredDBs
									  where trim(LastRestored) = trim(@datum)
										FOR XML PATH('tr'), TYPE) AS NVARCHAR(MAX));

	set @table = @header + @xml + N'</table></body></html>'

	set @lsubject = @servername + N': Restored Databases' + N' - ' + CONVERT(nvarchar(24), GETDATE(), 120);

	if len(@xml) > 0 or @check = 1
	  begin
			exec msdb.dbo.sp_send_dbmail @profile_name = 'Default Public Profile',  
																	 @recipients = @rcpto,  
																	 @subject = @lsubject,  
																	 @body = @table,  
																	 @body_format = 'HTML' ;  
	  end					
end

						 
					     
