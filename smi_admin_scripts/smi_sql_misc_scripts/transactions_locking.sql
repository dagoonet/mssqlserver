SELECT name, log_reuse_wait_desc FROM master.sys.databases;
SELECT * FROM master.sys.databases;
dbcc opentran('Speakingdictat7_test')


select * from sys.sysprocesses where open_tran = 1

select * from sys.dm_tran_active_transactions



select transaction_id, name, transaction_begin_time
 ,case transaction_type 
    when 1 then '1 = Read/write transaction'
    when 2 then '2 = Read-only transaction'
    when 3 then '3 = System transaction'
    when 4 then '4 = Distributed transaction'
end as transaction_type 
,case transaction_state 
    when 0 then '0 = The transaction has not been completely initialized yet'
    when 1 then '1 = The transaction has been initialized but has not started'
    when 2 then '2 = The transaction is active'
    when 3 then '3 = The transaction has ended. This is used for read-only transactions'
    when 4 then '4 = The commit process has been initiated on the distributed transaction'
    when 5 then '5 = The transaction is in a prepared state and waiting resolution'
    when 6 then '6 = The transaction has been committed'
    when 7 then '7 = The transaction is being rolled back'
    when 8 then '8 = The transaction has been rolled back'
end as transaction_state
,case dtc_state 
    when 1 then '1 = ACTIVE'
    when 2 then '2 = PREPARED'
    when 3 then '3 = COMMITTED'
    when 4 then '4 = ABORTED'
    when 5 then '5 = RECOVERED'
end as dtc_state 
,transaction_status, transaction_status2,dtc_status, dtc_isolation_level, filestream_transaction_id
from sys.dm_tran_active_transactions





select	trans.session_id AS [SESSION ID],
				ESes.host_name AS [HOST NAME],
				login_name AS [Login NAME],
				trans.transaction_id AS [TRANSACTION ID],
				tas.name AS [TRANSACTION NAME],
				tas.transaction_state as [transaction state],
				tas.transaction_begin_time AS [TRANSACTION BEGIN TIME],
				tds.database_id AS [DATABASE ID],DBs.name AS [DATABASE NAME]
FROM sys.dm_tran_active_transactions tas
JOIN sys.dm_tran_session_transactions trans
ON (trans.transaction_id=tas.transaction_id)
LEFT OUTER JOIN sys.dm_tran_database_transactions tds
ON (tas.transaction_id = tds.transaction_id )
LEFT OUTER JOIN sys.databases AS DBs
ON tds.database_id = DBs.database_id
LEFT OUTER JOIN sys.dm_exec_sessions AS ESes
ON trans.session_id = ESes.session_id
WHERE ESes.session_id IS NOT NULL

--==============================================================================================================
SELECT  b.session_id,
  			ISNULL(CAST(Db_name(a.database_id) AS VARCHAR(20)), 'N/A'),
				ISNULL(c.command, 'N/A'),
				ISNULL(Substring(st.TEXT, ( c.statement_start_offset / 2 ) + 1, ( (  CASE c.statement_end_offset  WHEN -1 THEN Datalength(st.TEXT) ELSE c.statement_end_offset END - c.statement_start_offset ) / 2 ) + 1), 'N/A'),
				ISNULL(Coalesce(Quotename(Db_name(st.dbid)) + N'.' + Quotename(Object_schema_name(st.objectid, st.dbid)) + N'.' + Quotename(Object_name(st.objectid, st.dbid)), ''), 'N/A'),
				ISNULL(c.wait_type, 'N/A'),
				ISNULL(c.wait_time, 'N/A')
FROM   sys.dm_tran_database_transactions a JOIN sys.dm_tran_session_transactions b
ON a.transaction_id = b.transaction_id JOIN sys.dm_exec_requests c CROSS APPLY sys.dm_exec_sql_text(c.sql_handle) AS st
ON b.session_id = c.session_id

--==============================================================================================================

select * from master.dbo.syslockinfo
SELECT 
    HostName,
    "OS UserName",
    Login, 
    spid, 
    "Database", 
    TableID,
    "Table Name_________", 
    IndID, 
--  [Index Name],
    "Lock Type", 
    "Lock Mode", 
    Status, 
--  Resource,
    Count(*) AS "Lock Count"
FROM (
    SELECT
        Convert(VarChar(30), RTRIM(P.HostName)) AS HostName,
        Convert(VarChar(30), RTRIM(P.nt_UserName)) AS "OS UserName",
        Convert(VarChar(30), Suser_SName(p.sid)) AS Login, 
        Convert(SmallInt, req_spid) AS spid,
        Convert(VarChar(30), DB_Name(rsc_dbid)) AS "Database",
        rsc_objid AS TableID,
    Convert(VarChar(30), Object_Name(rsc_objid, rsc_dbid))
        AS [Table Name_________],
        rsc_indid AS IndID, 
        CASE SubString (lock_type.name, 1, 4) 
            When '' Then 'None'
            When 'DB' Then 'Database'
            When 'FIL' Then 'File'
            When 'IDX' Then 'Index'
            When 'TAB' Then 'Table'
            When 'PAG' Then 'Page'
            When 'KEY' Then 'Key'
            When 'EXT' Then 'Extent'
            When 'RID' Then 'Row ID'
            When 'APP' Then 'Application'
            Else SubString (lock_type.name, 1, 4)
        END AS "Lock Type",
        Case SubString (lock_mode.name, 1, 12)
            When NULL Then 'N/A'
            When 'Sch-S' Then 'SCHEMA (Stability)'--'SCHEMA stability lock'
            When 'Sch-M' Then 'SCHEMA (Modification)'--'SCHEMA modification lock'
            When 'S' Then 'SHARED'--'SHARED Lock acquisition'
            When 'U' Then 'UPDATE'--'UPDATE lock acquisition'
            When 'X' Then 'EXCLUSIVE'--'EXCLUSIVE lock granted'
            When 'IS' Then 'SHARED (Intent)'--'INTENT for SHARED lock'
            When 'IU' Then 'UPDATE (Intent)'--'INTENT for UPDATE lock'
            When 'IX' Then 'EXCLUSIVE (Intent)'--'INTENT for EXCLUSIVE lock'
            When 'SIU' Then 'SHARED (Intent UPDATE)'--'SHARED lock with INTENT for UPDATE'
            When 'SIX' Then 'SHARED (Intent EXCLUSIVE)'--'SHARED lock with INTENT for EXCLUSIVE'
            When 'UIX' Then 'UPDATE'--'UPDATE lock with INTENT for EXCLUSIVE'
            When 'BU' Then 'UPDATE (BULK)'--'BULK UPDATE lock'
            Else SubString (lock_mode.name, 1, 12)
        END AS "Lock Mode", 
        SubString(lock_status.name, 1, 5) AS Status,
        SubString (rsc_text, 1, 16) AS Resource
    FROM 
        Master..SysLockInfo S
        JOIN Master..spt_values lock_type on S.rsc_type = lock_type.number
        JOIN Master..spt_values lock_status on S.req_status = lock_status.number
        JOIN Master..spt_values lock_mode on S.req_mode = lock_mode.number -1
        JOIN Master..SysProcesses P on S.req_spid = P.spid
    WHERE
            lock_type.type = 'LR'
        AND lock_status.type = 'LS'
        AND lock_mode.type = 'L'
        AND DB_Name(rsc_dbid) NOT IN ('master', 'msdb', 'model')
    ) AS X
WHERE TableID > 0
GROUP BY 
    HostName,
    "OS UserName",
    Login, 
    spid, 
    "Database", 
    TableID,
    "Table Name_________", 
    IndID, 
    "Lock Type", 
    "Lock Mode", 
    Status
ORDER BY
    spid, "Database", "Table Name_________", "Lock Type", Login