-- select * from smi_sysdba.dbo.tblPermissions
select [name]
      ,[parent_uri]
      ,[uri]
      ,[type_id]
      ,[permission_name]
      ,[ace_type]
      ,[accountidname]
      ,[accountidtype]
      ,[accountidprovider]
  from [msdb].[dbo].[tblPermissions]
drop table msdb.dbo.tblPermissions;
--exec('drop function sidtostring;');


-- SELECT name,type_desc,is_disabled,modify_date,default_database_name from sys.server_principals order by type_desc