declare @loopcounter int;
declare @maxid int;
declare @dynamicsql nvarchar(max);
declare @database_name nvarchar(max);

-- user databases --
select identity(int, 1, 1) as id, name, database_id, user_access, user_access_desc, state, state_desc
into #user_databases
from [master].[sys].[databases] where database_id > 4; 

set @loopcounter = 1;
select @maxid = max(id) from #user_databases;
while(@loopcounter <= @maxid)
	begin
	  print @loopcounter;
		print @maxid;
    select @database_name = name
	  from #user_databases where id = @loopcounter;

		set @dynamicsql = N'use ' + quotename(@database_name) + ';
												SELECT ''' + @database_name + ''' as database_name,
														 schemaname = OBJECT_SCHEMA_NAME(o.object_id),
														 tablename = o.NAME
												FROM sys.objects o
												INNER JOIN sys.indexes i ON i.OBJECT_ID = o.OBJECT_ID
												-- tables that are heaps without any nonclustered indexes
												WHERE (
																o.type = ''U''
																AND o.OBJECT_ID NOT IN 
																		(
																			SELECT OBJECT_ID
																			FROM sys.indexes
																			WHERE index_id > 0
																		)
																)';
		print 'Database Name: ' + @database_name;
		print @dynamicsql;
    exec sp_executesql @dynamicsql;
	  set @loopcounter = @loopcounter  + 1;    
	end
select * from #user_databases;
drop table #user_databases;
