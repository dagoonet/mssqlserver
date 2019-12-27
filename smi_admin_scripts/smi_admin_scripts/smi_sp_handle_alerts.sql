--------------------------------------------------------------------
-- --- author:		Marcus Deubel																---	--				
-- --- create date: 2019-10-03																---	--
-- --- description:	sending e-mail about long running queries --- --
--------------------------------------------------------------------
if object_id('smi_sp_handle_alerts', 'p') is not null
  drop procedure dbo.smi_sp_handle_alerts
go
create procedure [dbo].[smi_sp_handle_alerts] @severity int, @check int = 0
-- alter procedure [dbo].[sp_smi_get_long_running_queries] @rcpto nvarchar(200)
as
begin
	-- set nocount on added to prevent extra result sets from
	-- interfering with select statements.
	set nocount on;
	declare @debug int;
	declare @currentdate datetime;
	declare @starttime datetime;

	set @debug = 1; -- 0 = off, 1 = on
	set @currentdate = getdate();
	set @starttime = dateadd(minute, -5, @currentdate);


	create table #tblTmpErrorLog
	(
		LogDate			datetime,
		ProcessInfo	nvarchar(20),
		Text				nvarchar(255)
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
end