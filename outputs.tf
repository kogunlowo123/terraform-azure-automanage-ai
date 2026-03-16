output "automanage_config_id" {
  description = "The ID of the Automanage configuration profile."
  value       = azurerm_automanage_configuration.this.id
}

output "maintenance_config_id" {
  description = "The ID of the maintenance configuration."
  value       = azurerm_maintenance_configuration.this.id
}

output "recovery_vault_id" {
  description = "The ID of the Recovery Services vault."
  value       = azurerm_recovery_services_vault.this.id
}

output "backup_policy_id" {
  description = "The ID of the VM backup policy."
  value       = azurerm_backup_policy_vm.this.id
}

output "policy_assignment_ids" {
  description = "Map of custom policy assignment names to their IDs."
  value       = { for k, v in azurerm_policy_assignment.custom : k => v.id }
}

output "action_group_id" {
  description = "The ID of the monitor action group."
  value       = azurerm_monitor_action_group.this.id
}

output "automation_account_id" {
  description = "The ID of the automation account."
  value       = azurerm_automation_account.this.id
}

output "log_analytics_workspace_id" {
  description = "The ID of the Log Analytics workspace."
  value       = azurerm_log_analytics_workspace.this.id
}
