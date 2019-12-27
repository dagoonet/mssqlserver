DECLARE @command varchar(1000)
SELECT @command = '
PRINT ''?'';
IF EXISTS(SELECT 1 FROM [?].sys.symmetric_keys)
BEGIN
  USE [?];
  PRINT ''  Key(s) found!'';
  SELECT ''?'' AS db_name, *
  FROM sys.symmetric_keys
END
'

EXEC sp_MSforeachdb @command


USE [MASTER];
GO

SELECT DB.NAME
  , DEK.ENCRYPTION_STATE
  , DEK.SET_DATE
  , DEK.MODIFY_DATE
  , DEK.OPENED_DATE
  , DEK.ENCRYPTOR_THUMBPRINT
FROM SYS.DATABASES AS DB
LEFT JOIN SYS.DM_DATABASE_ENCRYPTION_KEYS AS DEK
  ON DB.DATABASE_ID = DEK.DATABASE_ID
ORDER BY DB.NAME;



select * from sys.dm_database_encryption_keys 


USE master;  
GO  
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Klinik2019_##';  
go  
CREATE CERTIFICATE cert_AdventureWorks2012 WITH SUBJECT = 'cert_AdventureWorks2012';  
go  
USE AdventureWorks2012;  
GO  
CREATE DATABASE ENCRYPTION KEY  
WITH ALGORITHM = AES_128  
ENCRYPTION BY SERVER CERTIFICATE cert_AdventureWorks2012;  
GO  
ALTER DATABASE AdventureWorks2012  
SET ENCRYPTION ON;  
GO 


BACKUP CERTIFICATE cert_AdventureWorks2012 TO FILE ='\\clnapvl2\smi_system$\DB_backups\wtsql205\certificates\cert_AdventureWorks2012.cert'  
      WITH PRIVATE KEY   
      (   
        FILE ='\\clnapvl2\smi_system$\DB_backups\wtsql205\certificates\cert_AdventureWorks2012.key',  
        ENCRYPTION BY PASSWORD ='Klinik2019_##'   
      )
