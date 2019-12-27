
select OBJECT_NAME(S.[OBJECT_ID]) AS [objectname], 
       I.[NAME] AS [indexname], 
       USER_SEEKS, 
       USER_SCANS, 
       USER_LOOKUPS, 
       USER_UPDATES 
-- into #index_usage 
FROM SYS.DM_DB_INDEX_USAGE_STATS AS S INNER JOIN SYS.INDEXES AS I 
ON I.[OBJECT_ID] = S.[OBJECT_ID] AND I.INDEX_ID = S.INDEX_ID 
WHERE OBJECTPROPERTY(S.[OBJECT_ID],'IsUserTable') = 1 -- and user_updates = 0
-- and OBJECT_NAME(S.[OBJECT_ID]) = 'DWInfo'
order by objectname desc

----------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------

SELECT OBJECT_NAME(A.[OBJECT_ID]) AS [objectname], 
       I.[NAME] AS [indexname], 
       A.LEAF_INSERT_COUNT, 
       A.LEAF_UPDATE_COUNT, 
       A.LEAF_DELETE_COUNT 
into #index_operational
FROM SYS.DM_DB_INDEX_OPERATIONAL_STATS (NULL,NULL,NULL,NULL ) as A INNER JOIN SYS.INDEXES AS I 
ON I.[OBJECT_ID] = A.[OBJECT_ID] AND I.INDEX_ID = A.INDEX_ID 
WHERE OBJECTPROPERTY(A.[OBJECT_ID],'IsUserTable') = 1 
-- and OBJECT_NAME(A.[OBJECT_ID]) = 'DWInfo'
--order by objectname desc

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


use tempdb;
go
select i.user_seeks, 
	     -- i.user_scans, 
	     i.user_lookups,
	     i.user_updates
from #index_usage as i
union
select p.leaf_insert_count,
	     p.leaf_update_count,
	     p.leaf_delete_count 
from #index_operational as p -- order by objectname

use tempdb;
go
select i.objectname, 
       i.indexname, 
			 p.objectname as oper_obj_name,
	     p.indexname as oper_idx_name,
	     i.user_seeks, 
	     i.user_scans, 
	     i.user_lookups,
	     i.user_updates,
	     p.leaf_insert_count,
	     p.leaf_update_count,
	     p.leaf_delete_count
from #index_usage as i inner join #index_operational as p
on i.objectname = p.objectname and i.indexname = p.indexname
group by	i.objectname,
					p.objectname,
					i.indexname,
					p.indexname,
					i.user_seeks, 
					i.user_scans, 
					i.user_lookups,
					i.user_updates,
					p.leaf_insert_count,
					p.leaf_update_count,
					p.leaf_delete_count
-- order by objectname

drop table #index_usage;
drop table #index_operational;

















----------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------
select	ips.index_id,
				object_name(ips.object_id) as tablename,
				i.name as indexname,
				index_type_desc,
				stats_date(ips.object_id,i.index_id) as stats_last_updated_time,
				page_count,
				round(avg_fragmentation_in_percent, 2) as avg_fragmentation_in_percent, 
				round(avg_page_space_used_in_percent, 2) as avg_page_space_used_in_percent
from sys.dm_db_index_physical_stats(db_id(), null, null, null, 'sampled') ips
		 inner join sys.indexes i 
on (ips.object_id = i.object_id) and (ips.index_id = i.index_id)
		 -- inner join sys.dm_db_index_usage_stats as s on (s.index_id = ips.index_id) and (ips.object_id = s.object_id)
order by avg_fragmentation_in_percent desc



select * 
from sys.dm_db_index_usage_stats as s
		 inner join sys.dm_db_index_physical_stats(db_id(), null, null, null, 'sampled') as p 
on	 s.database_id = p.database_id
select * from sys.dm_db_index_physical_stats(db_id(), null, null, null, 'sampled')


-- select * from sys.dm_db_index_operational_stats(NULL,NULL,NULL,NULL)
-- Quickly get row counts.

SELECT OBJECT_SCHEMA_NAME(p.object_id) AS [Schema]

    , OBJECT_NAME(p.object_id) AS [Table]

    , i.name AS [Index]

    , p.partition_number

    , p.rows AS [Row Count]

    , i.type_desc AS [Index Type]

FROM sys.partitions p

INNER JOIN sys.indexes i ON p.object_id = i.object_id

                         AND p.index_id = i.index_id

WHERE OBJECT_SCHEMA_NAME(p.object_id) != 'sys'

ORDER BY [Schema], [Table], [Index]

------------------------------------------------------------------------------
select STATS_DATE(so.object_id, index_id) StatsDate
, si.name IndexName
, schema_name(so.schema_id) + N'.' + so.Name TableName
, so.object_id, si.index_id
from sys.indexes si
inner join sys.tables so on so.object_id = si.object_id
order by 1 desc

------------------------------------------------------------------------------

use tempdb;
go
select * from #index_usage

use tempdb;
go
select * from #index_operational

use tempdb;
go
select i.objectname, 
       i.indexname, 
	   p.objectname as oper_obj_name,
	   p.indexname as oper_idx_name,
	   i.user_seeks, 
	   i.user_scans, 
	   i.user_lookups,
	   i.user_updates,
	   p.leaf_insert_count,
	   p.leaf_update_count,
	   p.leaf_delete_count
from #index_usage as i inner join #index_operational as p
on i.objectname = p.objectname and i.indexname = p.indexname


------------------------------------------------------------------------------------------------------------------

SELECT OBJECT_NAME(ips.OBJECT_ID) as tableName
 ,i.NAME as indexName
 ,ips.index_id
 ,index_type_desc
 ,avg_fragmentation_in_percent
 ,avg_page_space_used_in_percent
 ,page_count
 ,stats_date (ips.object_id,i.index_id) as stats_last_updated_time 
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'SAMPLED') ips
INNER JOIN sys.indexes i ON (ips.object_id = i.object_id)
 AND (ips.index_id = i.index_id)
ORDER BY avg_fragmentation_in_percent DESC



select a.id as 'ObjectID', isnull(a.name,'Heap') as 'IndexName', b.name as 'TableName', stats_date (id,indid) as stats_last_updated_time 
from sys.sysindexes as a 
inner join sys.objects as b on a.id = b.object_id where b.type = 'U' 

SELECT OBJECT_NAME(object_id) AS [ObjectName]
      ,[name] AS [StatisticName]
      ,STATS_DATE([object_id], [stats_id]) AS [StatisticUpdateDate]
FROM sys.stats