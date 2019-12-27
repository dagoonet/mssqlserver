-- Missing Index Script
-- Original Author: Pinal Dave (C) 2011
-- http://blog.sqlauthority.com
SELECT
dm_mid.database_id AS DatabaseID, 
dm_migs.avg_user_impact*(dm_migs.user_seeks+dm_migs.user_scans) Avg_Estimated_Impact,
dm_migs.last_user_seek AS Last_User_Seek,
object_name(dm_mid.object_id,dm_mid.database_id) AS [TableName],
'CREATE INDEX [IX_' + object_name(dm_mid.object_id,dm_mid.database_id) + '_'
+ REPLACE(REPLACE(REPLACE(ISNULL(dm_mid.equality_columns,''),', ','_'),'[',''),']','') +
CASE
	WHEN dm_mid.equality_columns IS NOT NULL AND dm_mid.inequality_columns IS NOT NULL THEN '_'
	ELSE ''
END
+ REPLACE(REPLACE(REPLACE(ISNULL(dm_mid.inequality_columns,''),', ','_'),'[',''),']','')
+ ']'
+ ' ON ' + dm_mid.statement
+ ' (' + ISNULL (dm_mid.equality_columns,'')
+ CASE WHEN dm_mid.equality_columns IS NOT NULL AND dm_mid.inequality_columns IS NOT NULL THEN ',' ELSE
'' END
+ ISNULL (dm_mid.inequality_columns, '')
+ ')'
+ ISNULL (' INCLUDE (' + dm_mid.included_columns + ')', '') AS Create_Statement
FROM sys.dm_db_missing_index_groups dm_mig
INNER JOIN sys.dm_db_missing_index_group_stats dm_migs
ON dm_migs.group_handle = dm_mig.index_group_handle
INNER JOIN sys.dm_db_missing_index_details dm_mid
ON dm_mig.index_handle = dm_mid.index_handle
WHERE dm_mid.database_ID = DB_ID()
ORDER BY Avg_Estimated_Impact DESC 
GO



SELECT IX.name AS 'Name'
, PS.index_level AS 'Level'
, PS.page_count AS 'Pages'
, PS.avg_fragmentation_in_percent AS 'External Fragmentation (%)'
, PS.fragment_count AS 'Fragments'
, PS.avg_fragment_size_in_pages AS 'Avg Fragment Size'
FROM sys.dm_db_index_physical_stats(
DB_ID(),
OBJECT_ID('dbo.DWCatalog'),
DEFAULT, DEFAULT, 'LIMITED') PS
JOIN sys.indexes IX
ON IX.OBJECT_ID = PS.OBJECT_ID AND IX.index_id = PS.index_id
WHERE IX.name = 'DWCatalog_ExtID_Project';
GO


SELECT IX.name AS 'Name'
     , PS.index_level AS 'Level'
     , PS.page_count AS 'Pages'
     , PS.avg_page_space_used_in_percent AS 'Page Fullness (%)'
  FROM sys.dm_db_index_physical_stats( 
           DB_ID(), 
           OBJECT_ID('dbo.DWCatalog'), 
           DEFAULT, DEFAULT, 'DETAILED') PS
  JOIN sys.indexes IX
    ON IX.OBJECT_ID = PS.OBJECT_ID AND IX.index_id = PS.index_id 
  WHERE IX.name = 'DWCatalog_ExtID_Project';
GO