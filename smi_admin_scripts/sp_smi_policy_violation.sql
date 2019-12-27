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
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
alter PROCEDURE sp_smi_policy_violation @rcpto nvarchar(200), @check int = 0
AS
BEGIN
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


	set @check_free_space_trn = 'check_free_space_trn';
	set @databases_not_backed_up = 'Identify Databases not backed up in the last 24 hours';
	set @result = 0; -- 0 = failure, 1 = success

	select top 1 @pid = p.policy_id, @pname = p.name, @hresult = h.result, @hdate = h.end_date 
	-- top 1 p.policy_id, p.name, h.result, h.start_date 
	from msdb.dbo.syspolicy_policies p join msdb.dbo.syspolicy_policy_execution_history h 
	on p.policy_id = h.policy_id
	order by h.start_date desc


	--select top 1 @pname as policy_name, h.policy_id, h.history_id, d.target_query_expression, d.execution_date, d.result
	-- from  msdb.dbo.syspolicy_policy_execution_history h join msdb.dbo.syspolicy_policy_execution_history_details d 
	-- on h.history_id = d.history_id where d.result = '0'
	--  -- and execution_date >= @hdate
	--  and h.policy_id = @pid
	-- order by execution_date desc




	-- if @check_free_space_trn = (select @pname) and @result = (select @hresult)
	if @result = (select @hresult) or @check = 1
		begin
			------------------------------------------------------------------------------
			---- verschickt eine Mail an @recipients mit der Info über Langläufer --------
			---- beim Implentieren muß die Variable @recipients angepasst werden  --------
			---- eventuell auch die Variable @profile_name						  --------
			------------------------------------------------------------------------------
			DECLARE @xml NVARCHAR(MAX) = N'';
			DECLARE @table NVARCHAR(MAX);
			declare @header nvarchar(max);

			set @header = N'<html><body>' +
										N'<H3>' + @pname + '</H3>' +  
										N'<table border="1">' +  
										N'<tr>' + 
										N'<th>Policy Name</th>' + 
										N'<th>policy_id</th>' +
										N'<th>history_id</th>' +
										N'<th>Database</th>' +
										N'<th>Execution Date</th>' +
										N'<th>Result</th>' +
										N'</tr>';

			set @xml = cast ((select td = @pname, '',
															 td = h.policy_id, '',
															 td = h.history_id, '',
															 td = d.target_query_expression, '',
															 td = d.execution_date, '',
															 td = d.result, ''
												from  msdb.dbo.syspolicy_policy_execution_history h join msdb.dbo.syspolicy_policy_execution_history_details d 
												on h.history_id = d.history_id where d.result = '0' and h.policy_id = @pid order by execution_date desc
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
END
GO
