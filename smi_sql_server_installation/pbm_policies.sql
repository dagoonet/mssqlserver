
---------------------------------------------------------------------------------------------
-- --- policy name: Identify Databases not backed up in the last 4 hours							 --- --
-- --- description: checks backup intervall, alerts if db is not backed up for 4 hours --- --
---------------------------------------------------------------------------------------------
SET NOCOUNT ON;
use msdb;
go

declare @condition_id int
if not exists (select condition_id from msdb.dbo.syspolicy_conditions where name = N'Databases not backed up in the last 4 hours')
  begin
		execute msdb.dbo.sp_syspolicy_add_condition	@name=N'Databases not backed up in the last 4 hours', 
																								@description=N'', 
																								@facet=N'Database', 
																								@expression=N'<Operator>
																																<TypeClass>Bool</TypeClass>
																																<OpType>OR</OpType>
																																<Count>2</Count>
																																<Operator>
																																	<TypeClass>Bool</TypeClass>
																																	<OpType>AND</OpType>
																																	<Count>2</Count>
																																	<Operator>
																																		<TypeClass>Bool</TypeClass>
																																		<OpType>AND</OpType>
																																		<Count>2</Count>
																																		<Operator>
																																			<TypeClass>Bool</TypeClass>
																																			<OpType>GE</OpType>
																																			<Count>2</Count>
																																			<Attribute>
																																				<TypeClass>DateTime</TypeClass>
																																				<Name>LastBackupDate</Name>
																																			</Attribute>
																																			<Function>
																																				<TypeClass>DateTime</TypeClass>
																																				<FunctionType>DateAdd</FunctionType>
																																				<ReturnType>DateTime</ReturnType>
																																				<Count>3</Count>
																																				<Constant>
																																					<TypeClass>String</TypeClass>
																																					<ObjType>System.String</ObjType>
																																					<Value>HH</Value>
																																				</Constant>
																																				<Constant>
																																					<TypeClass>Numeric</TypeClass>
																																					<ObjType>System.Double</ObjType>
																																					<Value>-168</Value>
																																				</Constant>
																																				<Function>
																																					<TypeClass>DateTime</TypeClass>
																																					<FunctionType>GetDate</FunctionType>
																																					<ReturnType>DateTime</ReturnType>
																																					<Count>0</Count>
																																				</Function>
																																			</Function>
																																		</Operator>
																																		<Operator>
																																			<TypeClass>Bool</TypeClass>
																																			<OpType>GE</OpType>
																																			<Count>2</Count>
																																			<Attribute>
																																				<TypeClass>DateTime</TypeClass>
																																				<Name>LastLogBackupDate</Name>
																																			</Attribute>
																																			<Function>
																																				<TypeClass>DateTime</TypeClass>
																																				<FunctionType>DateAdd</FunctionType>
																																				<ReturnType>DateTime</ReturnType>
																																				<Count>3</Count>
																																				<Constant>
																																					<TypeClass>String</TypeClass>
																																					<ObjType>System.String</ObjType>
																																					<Value>HH</Value>
																																				</Constant>
																																				<Constant>
																																					<TypeClass>Numeric</TypeClass>
																																					<ObjType>System.Double</ObjType>
																																					<Value>-4</Value>
																																				</Constant>
																																				<Function>
																																					<TypeClass>DateTime</TypeClass>
																																					<FunctionType>GetDate</FunctionType>
																																					<ReturnType>DateTime</ReturnType>
																																					<Count>0</Count>
																																				</Function>
																																			</Function>
																																		</Operator>
																																	</Operator>
																																	<Operator>
																																		<TypeClass>Bool</TypeClass>
																																		<OpType>EQ</OpType>
																																		<Count>2</Count>
																																		<Attribute>
																																			<TypeClass>Numeric</TypeClass>
																																			<Name>RecoveryModel</Name>
																																		</Attribute>
																																		<Function>
																																			<TypeClass>Numeric</TypeClass>
																																			<FunctionType>Enum</FunctionType>
																																			<ReturnType>Numeric</ReturnType>
																																			<Count>2</Count>
																																			<Constant>
																																				<TypeClass>String</TypeClass>
																																				<ObjType>System.String</ObjType>
																																				<Value>Microsoft.SqlServer.Management.Smo.RecoveryModel</Value>
																																			</Constant>
																																			<Constant>
																																				<TypeClass>String</TypeClass>
																																				<ObjType>System.String</ObjType>
																																				<Value>Full</Value>
																																			</Constant>
																																		</Function>
																																	</Operator>
																																</Operator>
																																<Operator>
																																	<TypeClass>Bool</TypeClass>
																																	<OpType>EQ</OpType>
																																	<Count>2</Count>
																																	<Attribute>
																																		<TypeClass>Numeric</TypeClass>
																																		<Name>RecoveryModel</Name>
																																	</Attribute>
																																	<Function>
																																		<TypeClass>Numeric</TypeClass>
																																		<FunctionType>Enum</FunctionType>
																																		<ReturnType>Numeric</ReturnType>
																																		<Count>2</Count>
																																		<Constant>
																																			<TypeClass>String</TypeClass>
																																			<ObjType>System.String</ObjType>
																																			<Value>Microsoft.SqlServer.Management.Smo.RecoveryModel</Value>
																																		</Constant>
																																		<Constant>
																																			<TypeClass>String</TypeClass>
																																			<ObjType>System.String</ObjType>
																																			<Value>Simple</Value>
																																		</Constant>
																																	</Function>
																																</Operator>
																															</Operator>', 
																								@is_name_condition=0, 
																								@obj_name=N'', 
																								@condition_id=@condition_id OUTPUT;
		Select @condition_id;
	end

declare @object_set_id int
if not exists (select policy_id from msdb.dbo.syspolicy_policies where name = N'Identify Databases not backed up in the last 4 hours')
	begin
	  if not exists (select object_set_id from msdb.dbo.syspolicy_object_sets_internal where object_set_name = N'Identify Databases not backed up in the last 4 hours_ObjectSet')
			begin
				execute msdb.dbo.sp_syspolicy_add_object_set	@object_set_name=N'Identify Databases not backed up in the last 4 hours_ObjectSet', 
																											@facet=N'Database', 
																											@object_set_id=@object_set_id OUTPUT;
				select @object_set_id;
				declare @target_set_id int;
				execute msdb.dbo.sp_syspolicy_add_target_set	@object_set_name=N'Identify Databases not backed up in the last 4 hours_ObjectSet', 
																											@type_skeleton=N'Server/Database', 
																											@type=N'DATABASE', 
																											@enabled=True, 
																											@target_set_id=@target_set_id OUTPUT;
				select @target_set_id;

				execute msdb.dbo.sp_syspolicy_add_target_set_level	@target_set_id=@target_set_id, 
																														@type_skeleton=N'Server/Database', 
																														@level_name=N'Database', 
																														@condition_name=N'', 
																														@target_set_level_id=0

			end;

		declare @policy_id int;
		execute msdb.dbo.sp_syspolicy_add_policy	@name=N'Identify Databases not backed up in the last 4 hours', 
																							@condition_name=N'Databases not backed up in the last 4 hours', 
																							@policy_category=N'', 
																							@description=N'', 
																							@help_text=N'', 
																							@help_link=N'', 
																							@schedule_uid=N'00000000-0000-0000-0000-000000000000', 
																							@execution_mode=0, 
																							@is_enabled=false, 
																							@policy_id=@policy_id OUTPUT, 
																							@root_condition_name=N'', 
																							@object_set=N'Identify Databases not backed up in the last 4 hours_ObjectSet';
		select @policy_id;
	end;
GO


-----------------------------------------------------------------------------------
-- --- policy name: check_free_space_trn																		 --- --
-- --- description: checks free space in transcation log, alerts 20% or less --- --
-----------------------------------------------------------------------------------
use msdb;
go
declare @condition_id int
if not exists (select condition_id from msdb.dbo.syspolicy_conditions where name = N'free space trn')
  begin
		execute msdb.dbo.sp_syspolicy_add_condition	@name=N'free space trn', 
																								@description=N'', 
																								@facet=N'LogFile', 
																								@expression=N'<Operator>
																																<TypeClass>Bool</TypeClass>
																																<OpType>OR</OpType>
																																<Count>2</Count>
																																<Operator>
																																	<TypeClass>Bool</TypeClass>
																																	<OpType>GE</OpType>
																																	<Count>2</Count>
																																	<Function>
																																		<TypeClass>Numeric</TypeClass>
																																		<FunctionType>Multiply</FunctionType>
																																		<ReturnType>Numeric</ReturnType>
																																		<Count>2</Count>
																																		<Function>
																																			<TypeClass>Numeric</TypeClass>
																																			<FunctionType>Divide</FunctionType>
																																			<ReturnType>Numeric</ReturnType>
																																			<Count>2</Count>
																																			<Function>
																																				<TypeClass>Numeric</TypeClass>
																																				<FunctionType>Subtract</FunctionType>
																																				<ReturnType>Numeric</ReturnType>
																																				<Count>2</Count>
																																				<Attribute>
																																					<TypeClass>Numeric</TypeClass>
																																					<Name>Size</Name>
																																				</Attribute>
																																				<Attribute>
																																					<TypeClass>Numeric</TypeClass>
																																					<Name>UsedSpace</Name>
																																				</Attribute>
																																			</Function>
																																			<Attribute>
																																				<TypeClass>Numeric</TypeClass>
																																				<Name>Size</Name>
																																			</Attribute>
																																		</Function>
																																		<Constant>
																																			<TypeClass>Numeric</TypeClass>
																																			<ObjType>System.Double</ObjType>
																																			<Value>100</Value>
																																		</Constant>
																																	</Function>
																																	<Constant>
																																		<TypeClass>Numeric</TypeClass>
																																		<ObjType>System.Double</ObjType>
																																		<Value>20</Value>
																																	</Constant>
																																</Operator>
																																<Operator>
																																	<TypeClass>Bool</TypeClass>
																																	<OpType>NE</OpType>
																																	<Count>2</Count>
																																	<Attribute>
																																		<TypeClass>Numeric</TypeClass>
																																		<Name>GrowthType</Name>
																																	</Attribute>
																																	<Function>
																																		<TypeClass>Numeric</TypeClass>
																																		<FunctionType>Enum</FunctionType>
																																		<ReturnType>Numeric</ReturnType>
																																		<Count>2</Count>
																																		<Constant>
																																			<TypeClass>String</TypeClass>
																																			<ObjType>System.String</ObjType>
																																			<Value>Microsoft.SqlServer.Management.Smo.FileGrowthType</Value>
																																		</Constant>
																																		<Constant>
																																			<TypeClass>String</TypeClass>
																																			<ObjType>System.String</ObjType>
																																			<Value>None</Value>
																																		</Constant>
																																	</Function>
																																</Operator>
																															</Operator>', 
																							@is_name_condition=0, 
																							@obj_name=N'', 
																							@condition_id=@condition_id OUTPUT;
		select @condition_id;
	end

if not exists (select condition_id from msdb.dbo.syspolicy_conditions where name = N'recovery_model_full')
  begin
		execute msdb.dbo.sp_syspolicy_add_condition	@name=N'recovery_model_full', 
																								@description=N'is recovery model full? is the database a system database?', 
																								@facet=N'Database', 
																								@expression=N'<Operator>
																																<TypeClass>Bool</TypeClass>
																																<OpType>AND</OpType>
																																<Count>2</Count>
																																<Operator>
																																	<TypeClass>Bool</TypeClass>
																																	<OpType>EQ</OpType>
																																	<Count>2</Count>
																																	<Attribute>
																																		<TypeClass>Numeric</TypeClass>
																																		<Name>RecoveryModel</Name>
																																	</Attribute>
																																	<Function>
																																		<TypeClass>Numeric</TypeClass>
																																		<FunctionType>Enum</FunctionType>
																																		<ReturnType>Numeric</ReturnType>
																																		<Count>2</Count>
																																		<Constant>
																																			<TypeClass>String</TypeClass>
																																			<ObjType>System.String</ObjType>
																																			<Value>Microsoft.SqlServer.Management.Smo.RecoveryModel</Value>
																																		</Constant>
																																		<Constant>
																																			<TypeClass>String</TypeClass>
																																			<ObjType>System.String</ObjType>
																																			<Value>Full</Value>
																																		</Constant>
																																	</Function>
																																</Operator>
																																<Operator>
																																	<TypeClass>Bool</TypeClass>
																																	<OpType>GT</OpType>
																																	<Count>2</Count>
																																	<Attribute>
																																		<TypeClass>Numeric</TypeClass>
																																		<Name>ID</Name>
																																	</Attribute>
																																	<Constant>
																																		<TypeClass>Numeric</TypeClass>
																																		<ObjType>System.Double</ObjType>
																																		<Value>4</Value>
																																	</Constant>
																																</Operator>
																															</Operator>', 
																								@is_name_condition=0, 
																								@obj_name=N'', 
																								@condition_id=@condition_id OUTPUT
		Select @condition_id
	end

declare @object_set_id int;
if not exists (select policy_id from msdb.dbo.syspolicy_policies where name = N'check_free_space_trn')
	begin
		if not exists (select object_set_id from msdb.dbo.syspolicy_object_sets_internal where object_set_name = N'check_free_space_trn_ObjectSet')
			begin
				execute msdb.dbo.sp_syspolicy_add_object_set	@object_set_name=N'check_free_space_trn_ObjectSet', 
																											@facet=N'LogFile', 
																											@object_set_id=@object_set_id OUTPUT;
				select @object_set_id;

				declare @target_set_id int;
				execute msdb.dbo.sp_syspolicy_add_target_set	@object_set_name=N'check_free_space_trn_ObjectSet', 
																											@type_skeleton=N'Server/Database/LogFile', 
																											@type=N'LOGFILE', 
																											@enabled=True, 
																											@target_set_id=@target_set_id OUTPUT;

				select @target_set_id;
				execute msdb.dbo.sp_syspolicy_add_target_set_level	@target_set_id=@target_set_id, 
																														@type_skeleton=N'Server/Database/LogFile', 
																														@level_name=N'LogFile', 
																														@condition_name=N'', 
																														@target_set_level_id=0;

				execute msdb.dbo.sp_syspolicy_add_target_set_level	@target_set_id=@target_set_id, 
																														@type_skeleton=N'Server/Database', 
																														@level_name=N'Database', 
																														@condition_name=N'recovery_model_full', 
																														@target_set_level_id=0;
			end;

		declare @policy_id int;
		execute msdb.dbo.sp_syspolicy_add_policy	@name=N'check_free_space_trn', 
																							@condition_name=N'free space trn', 
																							@policy_category=N'', 
																							@description=N'Policy ''check_free_space_trn'' has been violated.', 
																							@help_text=N'', 
																							@help_link=N'', 
																							@schedule_uid=N'00000000-0000-0000-0000-000000000000', 
																							@execution_mode=0, 
																							@is_enabled=false, 
																							@policy_id=@policy_id OUTPUT, 
																							@root_condition_name=N'', 
																							@object_set=N'check_free_space_trn_ObjectSet';
		select @policy_id;
	end
GO
