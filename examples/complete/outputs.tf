output "automanage_config_id" {
  description = "The ID of the Automanage configuration profile"
  value       = module.automanage.automanage_config_id
}

output "maintenance_config_id" {
  description = "The ID of the maintenance configuration"
  value       = module.automanage.maintenance_config_id
}

output "recovery_vault_id" {
  description = "The ID of the Recovery Services vault"
  value       = module.automanage.recovery_vault_id
}

output "backup_policy_id" {
  description = "The ID of the VM backup policy"
  value       = module.automanage.backup_policy_id
}

output "action_group_id" {
  description = "The ID of the monitor action group"
  value       = module.automanage.action_group_id
}

output "automation_account_id" {
  description = "The ID of the automation account"
  value       = module.automanage.automation_account_id
}

output "log_analytics_workspace_id" {
  description = "The ID of the Log Analytics workspace"
  value       = module.automanage.log_analytics_workspace_id
}
