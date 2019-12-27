use ContosoRetailDW;
go
execute as login = 'smi_exec_views'
-- select * from ContosoRetailDW.smi_views.V_Customer;
SELECT * FROM fn_my_permissions('smi_eb_execute_views', 'OBJECT');  

revert
go