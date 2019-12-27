USE [master]
GO

/****** Object:  StoredProcedure [dbo].[server_restart]    Script Date: 19.03.2019 13:48:19 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[smi_sp_server_restart]
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	--------------------------------------------------------------------
	-- --- author: Marcus Deubel																	--- --
	-- --- copyright: (c) 2019 Marcus Deubel											---	--		
	-- --- license: BSD License																		--- --
	-- --- sends mail on sql server start													--- --
	--------------------------------------------------------------------
	declare @xml nvarchar(MAX) = N'';
	declare @table nvarchar(MAX);
	declare @lbody nvarchar(max);
	declare @servername nvarchar(200);
	declare @lsubject nvarchar(200);
	declare @reboottime datetime;
	set @servername = @@SERVERNAME;
	set @reboottime = CONVERT(nvarchar(24), GETDATE(), 120);
	-- select @reboottime;

	SELECT NodeName, status, status_description, is_current_owner   
	FROM sys.dm_os_cluster_nodes;  


	set @lbody =  N'<html><body>' + N'<H3>SQL Server RESTARTED: ' + @servername + ' - ' + CONVERT(nvarchar(24), GETDATE(), 120) + '</H3>';
	set @table = @lbody + N'</table></body></html>';

  set @lsubject = N'SQL Server RESTARTED: ' + @servername + ' - ' + CONVERT(nvarchar(24), GETDATE(), 120);

	exec msdb.dbo.sp_send_dbmail  @profile_name = N'Default Public Profile',  
																@recipients = N'smi_dbalerts@ukw.de',  
																@subject = @lsubject,
																@body = @lbody,
																@body_format = N'HTML' ; 

END
GO

EXEC sp_procoption N'[dbo].[sp_smi_server_restart]', 'startup', '1'
GO


