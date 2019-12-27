declare @pname varchar(50);
declare @hresult int;
declare @hdate datetime;
declare @pid int;
declare @result bit;
declare @check_free_space_trn varchar(50);
declare @databases_not_backed_up varchar(50);

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
if @result = (select @hresult)
  begin
	------------------------------------------------------------------------------
	---- verschickt eine Mail an @recipients mit der Info über Langläufer --------
	---- beim Implentieren muß die Variable @recipients angepasst werden  --------
	---- eventuell auch die Variable @profile_name						  --------
	------------------------------------------------------------------------------
	DECLARE @xml NVARCHAR(MAX) = N'';
	DECLARE @table NVARCHAR(MAX);
	declare @header nvarchar(max);

	set @header =  N'<html><body>' +
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

	set @xml = cast ((select top 1 td = @pname, '',
							 td = h.policy_id, '',
							 td = h.history_id, '',
							 td = d.target_query_expression, '',
							 td = d.execution_date, '',
							 td = d.result, ''
					  from  msdb.dbo.syspolicy_policy_execution_history h join msdb.dbo.syspolicy_policy_execution_history_details d 
					  on h.history_id = d.history_id where d.result = '0' and h.policy_id = @pid order by execution_date desc
					   -- ORDER  BY log_bytes_used DESC
					  FOR XML PATH('tr'), TYPE) AS NVARCHAR(MAX));

	set @table = @header + @xml + N'</table></body></html>'

	-- print @table;

	exec msdb.dbo.sp_send_dbmail  
		@profile_name = 'Default Public Profile',  
		@recipients = 'deubel_m@ukw.de',  
		@subject = 'Policy Violation',  
		@body = @table,  
		@body_format = 'HTML' ;  
  end