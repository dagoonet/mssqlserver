use [one_TB_database]
go

DECLARE @LoopCounter INT;
declare @col1 bigINT;
declare @col2 NVARCHAR(100);

SELECT @LoopCounter = min(c1) , @col1 = max(c1) 
FROM dbo.my_1st_bigtable
 
WHILE(@LoopCounter IS NOT NULL
      AND @LoopCounter <= @col1)
BEGIN
   SELECT @col2 = c2
   FROM dbo.my_1st_bigtable WHERE c1 = @LoopCounter
    
   PRINT cast(@LoopCounter as nvarchar) + ' ' + @col2;
   SET @LoopCounter  = @LoopCounter  + 1        
END


-------------------------------------------------------------------------
--CREATE TABLE [MyBigTable] ([c1] BIGINT IDENTITY, [c2] CHAR (4100) DEFAULT 'a');
--GO
--CREATE CLUSTERED INDEX [MyBigTable_cl] ON [MyBigTable] ([c1]);
--GO


--SET NOCOUNT ON;
--GO
 
--DECLARE @counter BIGINT;
--DECLARE @start   DATETIME;
--DECLARE @end     DATETIME;
--declare @rows    bigint;

--set @rows = 13000000;
 
--SELECT @counter = 0;
--SELECT @start = GETDATE ();
 
--WHILE (@counter < @rows)
--BEGIN
--INSERT INTO [MyBigTable] DEFAULT VALUES;
--SELECT @counter = @counter + 1;
--END;
 
--SELECT @end = GETDATE ();
 
--INSERT INTO [msdb].[dbo].[Results] VALUES (CONVERT (INTEGER, DATEDIFF (second, @start, @end)));
--GO

USE [one_TB_database]
GO

/****** Object:  Table [dbo].[MyBigTable]    Script Date: 29.03.2019 07:00:13 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[My_2nd_BigTable](
	[c1] [bigint] IDENTITY(1,1) NOT NULL,
	[c2] [char](4100) NULL
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[My_2nd_BigTable] ADD  DEFAULT ('a') FOR [c2]
GO

select COUNT(*) from dbo.My_1st_BigTable
