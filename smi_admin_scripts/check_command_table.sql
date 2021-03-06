declare @current datetime;
declare @lsubject nvarchar(200);
declare @servername nvarchar(200);
declare @reboottime datetime;
declare @rcpto nvarchar(200);

--set @servername = @@SERVERNAME;
--set @reboottime = CONVERT(nvarchar(24), GETDATE(), 120);

set @current = convert(date, current_timestamp);

set @rcpto = 'deubel_m@ukw.de';

declare @xml nvarchar(max) = N'';
declare @table nvarchar(max);
declare @header nvarchar(max);

set @header = N'<html>' +
							N'<head>' +
							N'<style>' +
							N'table { border: 1px solid black;	border-collapse: separate; }' +
							N'th, td { border: 1px solid black; padding: 0.2em 0.5em; }' +
							N'body { font-family: Helvetica, Arial, Geneva, sans-serif; }' +
							N'</style>' +
							N'</head>' +
							N'<body>' +
							N'<H3>Command Output</H3>' +  
							N'<table border="1" frame = "void">' +  
							N'<tr>' + 
							N'<th>Database Name</th>' + 
							N'<th>Command</th>' +
							N'<th>Error Number</th>' +
							N'<th>Error Message</th>' +
							N'<th>Date</th>' +
							-- N'<th>Result</th>' +
							N'</tr>';

set @xml = cast ((select td = DatabaseName, '',
												 td = CommandType, '',
												 td = ErrorNumber, '',
												 td = ISNULL(ErrorMessage, 'N/A'), '',
												 td = convert(nvarchar(24), getdate(), 120), ''
									from master.dbo.commandlog
									where (CommandType = 'DBCC_CHECKDB' or CommandType like 'BACKUP%') and (@current = convert(date, EndTime))
									group by DatabaseName, CommandType, ErrorNumber, ErrorMessage, EndTime
									order by EndTime desc
									FOR XML PATH('tr'), TYPE) AS NVARCHAR(MAX));

set @table = @header + @xml + N'</table></body></html>'

-- print @table;
			
set @lsubject = @servername + N': Command Output' + N' - ' + convert(nvarchar(24), getdate(), 120);

exec msdb.dbo.sp_send_dbmail  @profile_name = 'Default Public Profile',  
															@recipients = @rcpto,  
															@subject = @lsubject,  
															@body = @table,  
															@body_format = 'HTML' ;  