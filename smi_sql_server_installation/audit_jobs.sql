use [master]
CREATE SERVER AUDIT [SqlAgentObjectAccess_Audit] 
TO APPLICATION_LOG
WITH (QUEUE_DELAY = 1000, ON_FAILURE = CONTINUE, AUDIT_GUID = 'e1f7d882-b26e-4b70-bc03-87af197eb7de')
go


ALTER SERVER AUDIT [SqlAgentObjectAccess_Audit] WITH (STATE = ON)

USE [msdb]
go 

CREATE DATABASE AUDIT SPECIFICATION [SqlAgentObjectAccess_Audit_MSDB]
FOR SERVER AUDIT [SqlAgentObjectAccess_Audit]
ADD (EXECUTE ON OBJECT::[dbo].[sp_delete_job] BY [dbo]),
ADD (EXECUTE ON OBJECT::[dbo].[sp_delete_job] BY   [SQLAgentUserRole]),
ADD (EXECUTE ON OBJECT::[dbo].[sp_add_job] BY [dbo]),
ADD (EXECUTE ON OBJECT::[dbo].[sp_add_job] BY [SQLAgentUserRole]),
ADD (EXECUTE ON OBJECT::[dbo].[sp_start_job] BY [dbo]),
ADD (EXECUTE ON OBJECT::[dbo].[sp_start_job] BY [SQLAgentUserRole]),
ADD (EXECUTE ON OBJECT::[dbo].[sp_stop_job] BY [dbo]),
ADD (EXECUTE ON OBJECT::[dbo].[sp_stop_job] BY [SQLAgentUserRole])
WITH (STATE = ON)
GO

/* ALTER SERVER AUDIT [SqlAgentObjectAccess_Audit] with (STATE = OFF);  
GO  
DROP SERVER AUDIT [SqlAgentObjectAccess_Audit];
GO */ 

ALTER SERVER AUDIT [DatabaseAccess] WITH (STATE = ON)
GO



USE [master]
GO

/****** Object:  Audit [sysadmin_successful_logon] ******/
CREATE SERVER AUDIT [audit_smi_bi_successful_logon]
TO APPLICATION_LOG
WHERE ([server_principal_name]='domain\weingart_v' OR 
       [server_principal_name]='domain\feichtinger_a' OR
       [server_principal_name]='domain\kidan_t' OR
	   [server_principal_name]='domain\e_klaus_w')
ALTER SERVER AUDIT [audit_smi_bi_successful_logon] WITH (STATE = ON)
GO

CREATE SERVER AUDIT SPECIFICATION [spec_smi_bi_successful_logon]
FOR SERVER AUDIT [audit_smi_bi_successful_logon]
ADD (SUCCESSFUL_LOGIN_GROUP)
WITH (STATE = ON)
GO



Select DISTINCT action_id,name,class_desc,parent_class_desc from sys.dm_audit_actions