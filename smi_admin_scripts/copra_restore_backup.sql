dbcc traceon(3004, 3605, -1)

USE [master]
GO

/****** Object:  Database [zeroing]    Script Date: 25.10.2019 08:50:24 ******/
CREATE DATABASE [zeroing]
 CONTAINMENT = NONE
 ON  PRIMARY 
( NAME = N'zeroing01', FILENAME = N'S:\MSSQL14.MSSQLSERVER\MSSQL\DATA\zeroing01.mdf' , SIZE = 85000000KB , MAXSIZE = UNLIMITED, FILEGROWTH = 65536KB ),
( NAME = N'zeroing02', FILENAME = N'S:\MSSQL14.MSSQLSERVER\MSSQL\DATA\zeroing02.ndf' , SIZE = 85000000KB , MAXSIZE = UNLIMITED, FILEGROWTH = 65536KB ),
( NAME = N'zeroing04', FILENAME = N'S:\MSSQL14.MSSQLSERVER\MSSQL\DATA\zeroing04.ndf' , SIZE = 85000000KB , MAXSIZE = UNLIMITED, FILEGROWTH = 65536KB ),
( NAME = N'zeroring03', FILENAME = N'S:\MSSQL14.MSSQLSERVER\MSSQL\DATA\zeroring03.ndf' , SIZE = 85000000KB , MAXSIZE = UNLIMITED, FILEGROWTH = 65536KB )
 LOG ON 
( NAME = N'zeroing_log', FILENAME = N'L:\MSSQL14.MSSQLSERVER\MSSQL\Data\zeroing_log.ldf' , SIZE = 51200000KB , MAXSIZE = 2048GB , FILEGROWTH = 65536KB )
GO




BACKUP DATABASE [COPRA6Live] TO  
DISK = N'\\clnapvl2\smi_system$\db_backups\CLCOPPDB-NEU\copra6live_20191031_1.bak',  
DISK = N'\\clnapvl2\smi_system$\db_backups\CLCOPPDB-NEU\copra6live_20191031_2.bak',  
DISK = N'\\clnapvl2\smi_system$\db_backups\CLCOPPDB-NEU\copra6live_20191031_3.bak',  
DISK = N'\\clnapvl2\smi_system$\db_backups\CLCOPPDB-NEU\copra6live_20191031_4.bak' 
WITH NOFORMAT, NOINIT,  NAME = N'COPRA6Live-Full Database Backup', SKIP, NOREWIND, NOUNLOAD,  STATS = 10, buffercount = 500, blocksize = 512
GO




dbcc traceon(3004, 3605, -1)
USE [master]
RESTORE DATABASE [COPRA6Live] 
FROM  
DISK = N'\\clnapvl2\smi_system$\db_backups\CLCOPPDB-NEU\copra6live_20191031_1.bak',  
DISK = N'\\clnapvl2\smi_system$\db_backups\CLCOPPDB-NEU\copra6live_20191031_2.bak',  
DISK = N'\\clnapvl2\smi_system$\db_backups\CLCOPPDB-NEU\copra6live_20191031_3.bak',  
DISK = N'\\clnapvl2\smi_system$\db_backups\CLCOPPDB-NEU\copra6live_20191031_4.bak' 
WITH  FILE = 1, replace, NOUNLOAD,  STATS = 10, buffercount = 500, blocksize = 512
--MOVE N'COPRA6Live' TO N'S:\MSSQL14.MSSQLSERVER\MSSQL\DATA\COPRA6Live.mdf',  
--MOVE N'COPRA6Live2' TO N'S:\MSSQL14.MSSQLSERVER\MSSQL\DATA\COPRA6Live2.mdf',  
--MOVE N'COPRA6Live3' TO N'S:\MSSQL14.MSSQLSERVER\MSSQL\DATA\COPRA6Live3.ndf',  
--MOVE N'COPRA6Live4' TO N'S:\MSSQL14.MSSQLSERVER\MSSQL\DATA\COPRA6Live4.ndf',  
--MOVE N'COPRA6Live_Admin_Instances' TO N'S:\MSSQL14.MSSQLSERVER\MSSQL\DATA\COPRA6Live_Admin_Instances.ndf',  
--MOVE N'COPRA6Live_log' TO N'L:\MSSQL14.MSSQLSERVER\MSSQL\Data\COPRA6Live_log.ldf'

GO

		@BufferCount = 500, 
		@NumberOfFiles = 4, 
		@BlockSize = 512, 


exec sp_readerrorlog 0, 1, 'Zero'

exec xp_readerrorlog 0, 1, N'Database Instant File Initialization'