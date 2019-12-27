USE [COPRA6Live]
GO
CREATE NONCLUSTERED INDEX [IX_Timestamp]
ON [dbo].[CO6_Data_Decimal_6_3] ([Timestamp])
INCLUDE ([ID],[VarID],[PreviousVersion],[EntryUser],[EntryTime],[deleted],[Parent_ID],[Parent_VarID],[DateTimeTo],[validated],[val],[FlagCurrent])
GO