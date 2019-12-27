-- ================================================
-- Template generated from Template Explorer using:
-- Create Procedure (New Menu).SQL
--
-- Use the Specify Values for Template Parameters 
-- command (Ctrl-Shift-M) to fill in the parameter 
-- values below.
--
-- This block of comments will not be included in
-- the definition of the procedure.
-- ================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- ===============================================================
-- Author:		Marcus Deubel
-- Create date: 03.03.2019
-- Description:	Sends automatic email on SQL Server Instance start
-- ===============================================================
CREATE PROCEDURE server_restart
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	------------------------------------------------------------------------------
	---- verschickt eine Mail an @recipients mit der Info über SQL Server --------
	---- Instanz Restart												  --------
	---- eventuell auch die Variable @profile_name						  --------
	------------------------------------------------------------------------------
	declare @xml nvarchar(MAX) = N'';
	declare @table nvarchar(MAX);
	declare @lbody nvarchar(max);
	declare @servername nvarchar(100);
	declare @lsubject nvarchar(100);
	declare @reboottime datetime;
	set @servername = @@SERVERNAME;
	set @reboottime = CONVERT(nvarchar(24), GETDATE(), 120);
	-- select @reboottime;

	set @lbody =  N'<html><body>' +
				  N'<H3>SQL Server RESTARTED: ' + @servername + ' - ' + CONVERT(nvarchar(24), GETDATE(), 120) + '</H3>';
				   
	set @table = @lbody + N'</table></body></html>';


	set @lsubject = N'SQL Server RESTARTED: ' + @servername + ' - ' + CONVERT(nvarchar(24), GETDATE(), 120);

    EXEC msdb.dbo.sp_send_dbmail  
		@profile_name = N'Default Public Profile',  
		@recipients = N'deubel_m@ukw.de',  
		@subject = @lsubject,
		@body = @lbody,
		@body_format = N'HTML' ; 

END
GO
--exec sp_procoption @ProcName = ['stored procedure name'], 
--@OptionName = 'STARTUP', 
--@OptionValue = [on|off]
exec sp_procoption @ProcName = server_restart, 
@OptionName = 'STARTUP', 
@OptionValue = 'on'


--USE MASTER
--GO
--SELECT VALUE, VALUE_IN_USE, DESCRIPTION 
--FROM SYS.CONFIGURATIONS 
--WHERE NAME = 'scan for startup procs'
--GO

--SELECT ROUTINE_NAME
--FROM MASTER.INFORMATION_SCHEMA.ROUTINES
--WHERE OBJECTPROPERTY(OBJECT_ID(ROUTINE_NAME),'ExecIsStartup') = 1