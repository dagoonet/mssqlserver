-- Script - Find Details for Statistics of Whole Database
-- (c) Pinal Dave
-- Download Script from - https://blog.sqlauthority.com/contact-me/sign-up/
select	distinct	object_name(s.[object_id]) as tablename,
				c.name as columnname,
				s.name as statname,
				stats_date(s.[object_id], s.stats_id) as lastupdated,
				datediff(d,stats_date(s.[object_id], s.stats_id),getdate()) daysold,
				dsp.modification_counter,
				s.auto_created,
				s.user_created,
				s.no_recompute,
				s.[object_id],
				s.stats_id,
				sc.stats_column_id,
				sc.column_id
from	sys.stats s
			join sys.stats_columns sc
on	sc.[object_id] = s.[object_id] and sc.stats_id = s.stats_id
		join sys.columns c on c.[object_id] = sc.[object_id] and c.column_id = sc.column_id
		join sys.partitions par on par.[object_id] = s.[object_id]
		join sys.objects obj on par.[object_id] = obj.[object_id]
		cross apply sys.dm_db_stats_properties(sc.[object_id], s.stats_id) as dsp
where objectproperty(s.object_id,'isusertable') = 1
			and (s.auto_created = 1 or s.user_created = 1)
order by daysold;
