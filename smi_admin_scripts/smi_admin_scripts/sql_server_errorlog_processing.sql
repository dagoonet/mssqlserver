declare @debug int;
declare @currentdate datetime;
declare @starttime datetime;

set @debug = 1; -- 0 = off, 1 = on
set @currentdate = getdate();
set @starttime = dateadd(minute, -5, @currentdate);


create table #tblTmpErrorLog
(
	LogDate			datetime,
	ProcessInfo		nvarchar(20),
	Text			nvarchar(255)
);

if @debug = 1
  begin
		print @starttime;
		print @currentdate;
  end

-- insert into #tblTmpErrorLog
insert into #tblTmpErrorLog
(
  LogDate,
  ProcessInfo,
  Text
)	
execute master.dbo.xp_readerrorlog 0, 1, null, null, @starttime, @currentdate, N'desc';

select * from 
	( 
		select LogDate, 
			   ProcessInfo, 
			   text as MessageText, 
			   lag(text, 1, '') 
			   over 
			   (order by LogDate) as error
		from #tblTmpErrorLog
	) as ErrTable
where error like 'Error%'

select * from #tblTmpErrorLog;
drop table #tblTmpErrorLog;
