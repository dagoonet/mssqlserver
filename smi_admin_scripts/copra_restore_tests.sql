BACKUP DATABASE [COPRA6Live] TO  
DISK = N'\\clnapvl2\smi_system$\db_backups\CLCOPPDB-NEU\copra6live_1.bak',  
DISK = N'\\clnapvl2\smi_system$\db_backups\CLCOPPDB-NEU\copra6live_2.bak',  
DISK = N'\\clnapvl2\smi_system$\db_backups\CLCOPPDB-NEU\copra6live_3.bak',  
DISK = N'\\clnapvl2\smi_system$\db_backups\CLCOPPDB-NEU\copra6live_4.bak' 
WITH NOFORMAT, NOINIT,  NAME = N'COPRA6Live-Full Database Backup', SKIP, NOREWIND, NOUNLOAD,  STATS = 10
GO


dbcc traceon(3004, 3605, -1)
USE [master]
RESTORE DATABASE [COPRA6Live] 
FROM  
DISK = N'\\clnapvl2\smi_system$\DB_backups\clcoppdb\COPRA6Live\FULL_COPY_ONLY\CLCOPPDB_COPRA6Live_FULL_COPY_ONLY_20191025_071811_1.bak',  
DISK = N'\\clnapvl2\smi_system$\DB_backups\clcoppdb\COPRA6Live\FULL_COPY_ONLY\CLCOPPDB_COPRA6Live_FULL_COPY_ONLY_20191025_071811_2.bak',  
DISK = N'\\clnapvl2\smi_system$\DB_backups\clcoppdb\COPRA6Live\FULL_COPY_ONLY\CLCOPPDB_COPRA6Live_FULL_COPY_ONLY_20191025_071811_3.bak',  
DISK = N'\\clnapvl2\smi_system$\DB_backups\clcoppdb\COPRA6Live\FULL_COPY_ONLY\CLCOPPDB_COPRA6Live_FULL_COPY_ONLY_20191025_071811_4.bak' 
WITH  FILE = 1,  MOVE N'COPRA6Live' TO N'S:\MSSQL14.MSSQLSERVER\MSSQL\DATA\COPRA6Live.mdf',  
MOVE N'COPRA6Live2' TO N'S:\MSSQL14.MSSQLSERVER\MSSQL\DATA\COPRA6Live2.mdf',  
MOVE N'COPRA6Live3' TO N'S:\MSSQL14.MSSQLSERVER\MSSQL\DATA\COPRA6Live3.ndf',  
MOVE N'COPRA6Live4' TO N'S:\MSSQL14.MSSQLSERVER\MSSQL\DATA\COPRA6Live4.ndf',  
MOVE N'COPRA6Live_Admin_Instances' TO N'S:\MSSQL14.MSSQLSERVER\MSSQL\DATA\COPRA6Live_Admin_Instances.ndf',  
MOVE N'COPRA6Live_log' TO N'L:\MSSQL14.MSSQLSERVER\MSSQL\Data\COPRA6Live_log.ldf', replace, NOUNLOAD,  STATS = 5

GO

exec sp_readerrorlog 0, 1, 'Zero'

exec xp_readerrorlog 0, 1, N'Database Instant File Initialization'