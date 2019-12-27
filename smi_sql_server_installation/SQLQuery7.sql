SELECT spid, kpid, dbid, cpu, memusage FROM sysprocesses WHERE kpid=6684
SELECT spid, kpid, status, cpu, memusage, open_tran, dbid, cmd FROM sysprocesses WHERE spid=13

select * from sysprocesses 
where cmd = 'RESOURCE MONITOR'

dbcc inputbuffer(13)

dbcc memorystatus