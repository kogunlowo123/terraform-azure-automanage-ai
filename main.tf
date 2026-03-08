###############################################################################
# Data Sources
###############################################################################

data "azurerm_subscription" "current" {}
data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

###############################################################################
# Log Analytics Workspace
###############################################################################

resource "azurerm_log_analytics_workspace" "this" {
  name                = "${var.name_prefix}-log-analytics"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days

  tags = var.tags
}

resource "azurerm_log_analytics_solution" "updates" {
  solution_name         = "Updates"
  location              = var.location
  resource_group_name   = var.resource_group_name
  workspace_resource_id = azurerm_log_analytics_workspace.this.id
  workspace_name        = azurerm_log_analytics_workspace.this.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/Updates"
  }

  tags = var.tags
}

resource "azurerm_log_analytics_solution" "security" {
  solution_name         = "Security"
  location              = var.location
  resource_group_name   = var.resource_group_name
  workspace_resource_id = azurerm_log_analytics_workspace.this.id
  workspace_name        = azurerm_log_analytics_workspace.this.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/Security"
  }

  tags = var.tags
}

###############################################################################
# Automanage Configuration
###############################################################################

resource "azurerm_automanage_configuration" "this" {
  name                = "${var.name_prefix}-automanage-config"
  resource_group_name = var.resource_group_name
  location            = var.location

  antimalware {
    exclusions {
      extensions = ".log;.ldf"
      paths      = "C:\\Windows\\Temp"
      processes  = "svchost.exe"
    }
    real_time_protection_enabled   = var.enable_antimalware
    scheduled_scan_enabled         = var.enable_antimalware
    scheduled_scan_type            = 1
    scheduled_scan_day             = 1
    scheduled_scan_time_in_minutes = 120
  }

  automation_account_enabled = true

  backup {
    policy_name                                 = "${var.name_prefix}-backup-policy"
    time_zone                                   = "UTC"
    instant_rp_retention_range_in_days          = 5
    schedule_policy {
      schedule_run_frequency = var.backup_frequency
      schedule_run_times     = ["12:00"]
      schedule_run_days      = var.backup_frequency == "Weekly" ? ["Sunday"] : null
    }
    retention_policy {
      retention_policy_type = "LongTermRetentionPolicy"
      daily_schedule {
        retention_times = ["12:00"]
        retention_duration {
          count         = var.backup_retention_days
          duration_type = "Days"
        }
      }
      weekly_schedule {
        retention_times = ["12:00"]
        retention_duration {
          count         = 4
          duration_type = "Weeks"
        }
      }
    }
  }

  log_analytics_enabled = true
  status_change_alert_enabled = true

  tags = var.tags
}

###############################################################################
# Maintenance Configuration
###############################################################################

resource "azurerm_maintenance_configuration" "this" {
  name                = "${var.name_prefix}-maintenance-config"
  resource_group_name = var.resource_group_name
  location            = var.location
  scope               = "InGuestPatch"

  in_guest_user_patch_mode = var.enable_auto_patching ? "User" : null

  window {
    start_date_time = "2024-01-01 ${var.maintenance_window.start_time}"
    time_zone       = "UTC"
    duration        = var.maintenance_window.duration
    recur_every     = "1Week ${var.maintenance_window.day}"
  }

  install_patches {
    linux {
      classifications_to_include = ["Critical", "Security"]
    }
    windows {
      classifications_to_include = ["Critical", "Security", "UpdateRollup"]
    }
    reboot = "IfRequired"
  }

  tags = var.tags
}

resource "azurerm_maintenance_assignment_virtual_machine" "this" {
  for_each = toset(var.vm_ids)

  location                     = var.location
  maintenance_configuration_id = azurerm_maintenance_configuration.this.id
  virtual_machine_id           = each.value
}

###############################################################################
# Recovery Services Vault & Backup
###############################################################################

resource "azurerm_recovery_services_vault" "this" {
  name                = "${var.name_prefix}-recovery-vault"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"
  soft_delete_enabled = true
  storage_mode_type   = "GeoRedundant"

  tags = var.tags
}

resource "azurerm_backup_policy_vm" "this" {
  name                = "${var.name_prefix}-vm-backup-policy"
  resource_group_name = var.resource_group_name
  recovery_vault_name = azurerm_recovery_services_vault.this.name

  timezone = "UTC"

  backup {
    frequency = var.backup_frequency
    time      = "23:00"
    weekdays  = var.backup_frequency == "Weekly" ? ["Sunday"] : null
  }

  retention_daily {
    count = var.backup_retention_days
  }

  retention_weekly {
    count    = 4
    weekdays = ["Sunday"]
  }

  retention_monthly {
    count    = 6
    weekdays = ["Sunday"]
    weeks    = ["First"]
  }

  retention_yearly {
    count    = 1
    weekdays = ["Sunday"]
    weeks    = ["First"]
    months   = ["January"]
  }

  instant_restore_retention_days = 5
}

resource "azurerm_backup_protected_vm" "this" {
  for_each = toset(var.vm_ids)

  resource_group_name = var.resource_group_name
  recovery_vault_name = azurerm_recovery_services_vault.this.name
  source_vm_id        = each.value
  backup_policy_id    = azurerm_backup_policy_vm.this.id

  depends_on = [azurerm_backup_policy_vm.this]
}

###############################################################################
# Diagnostic Settings
###############################################################################

resource "azurerm_monitor_diagnostic_setting" "vault" {
  name                       = "${var.name_prefix}-vault-diagnostics"
  target_resource_id         = azurerm_recovery_services_vault.this.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  enabled_log {
    category = "CoreAzureBackup"
  }

  enabled_log {
    category = "AddonAzureBackupJobs"
  }

  enabled_log {
    category = "AddonAzureBackupAlerts"
  }

  enabled_log {
    category = "AddonAzureBackupPolicy"
  }

  enabled_log {
    category = "AddonAzureBackupStorage"
  }

  enabled_log {
    category = "AddonAzureBackupProtectedInstance"
  }

  metric {
    category = "Health"
    enabled  = true
  }
}

###############################################################################
# Custom Compliance Policies
###############################################################################

resource "azurerm_policy_definition" "custom" {
  for_each = { for p in var.compliance_policies : p.name => p }

  name         = each.value.name
  policy_type  = "Custom"
  mode         = each.value.mode
  display_name = each.value.display_name
  description  = each.value.description

  policy_rule = each.value.policy_rule
}

resource "azurerm_policy_assignment" "custom" {
  for_each = { for p in var.compliance_policies : p.name => p }

  name                 = "${var.name_prefix}-${each.value.name}"
  scope                = data.azurerm_resource_group.this.id
  policy_definition_id = azurerm_policy_definition.custom[each.key].id
  display_name         = each.value.display_name
  description          = each.value.description
  enforce              = true
}

###############################################################################
# Built-in Policy Assignments
###############################################################################

resource "azurerm_policy_assignment" "require_vm_backup" {
  name                 = "${var.name_prefix}-require-vm-backup"
  scope                = data.azurerm_resource_group.this.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/013e242c-8828-4970-87b3-ab247555486d"
  display_name         = "Azure Backup should be enabled for Virtual Machines"
  description          = "Ensure protection of Azure Virtual Machines by enabling Azure Backup"
  enforce              = true
}

resource "azurerm_policy_assignment" "require_monitoring_agent" {
  name                 = "${var.name_prefix}-require-monitoring"
  scope                = data.azurerm_resource_group.this.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/d21f7323-656e-4ab5-8358-9fa7367b82e0"
  display_name         = "Log Analytics agent should be installed on VMs"
  description          = "Audit VMs that do not have the Log Analytics agent installed"
  enforce              = false
}

###############################################################################
# Monitor Action Group
###############################################################################

resource "azurerm_monitor_action_group" "this" {
  name                = "${var.name_prefix}-action-group"
  resource_group_name = var.resource_group_name
  short_name          = substr(var.name_prefix, 0, 12)

  dynamic "email_receiver" {
    for_each = var.alert_email_addresses
    content {
      name                    = "email-${email_receiver.key}"
      email_address           = email_receiver.value
      use_common_alert_schema = true
    }
  }

  tags = var.tags
}

###############################################################################
# Metric Alerts
###############################################################################

resource "azurerm_monitor_metric_alert" "cpu_alert" {
  for_each = toset(var.vm_ids)

  name                = "${var.name_prefix}-cpu-alert-${index(var.vm_ids, each.value)}"
  resource_group_name = var.resource_group_name
  scopes              = [each.value]
  description         = "Alert when CPU usage exceeds 90% for 15 minutes"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 90
  }

  action {
    action_group_id = azurerm_monitor_action_group.this.id
  }

  tags = var.tags
}

resource "azurerm_monitor_metric_alert" "memory_alert" {
  for_each = toset(var.vm_ids)

  name                = "${var.name_prefix}-memory-alert-${index(var.vm_ids, each.value)}"
  resource_group_name = var.resource_group_name
  scopes              = [each.value]
  description         = "Alert when available memory drops below 10%"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Available Memory Bytes"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 1073741824
  }

  action {
    action_group_id = azurerm_monitor_action_group.this.id
  }

  tags = var.tags
}

resource "azurerm_monitor_metric_alert" "disk_alert" {
  for_each = toset(var.vm_ids)

  name                = "${var.name_prefix}-disk-alert-${index(var.vm_ids, each.value)}"
  resource_group_name = var.resource_group_name
  scopes              = [each.value]
  description         = "Alert when OS disk IOPS consumption exceeds 95%"
  severity            = 1
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "OS Disk IOPS Consumed Percentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 95
  }

  action {
    action_group_id = azurerm_monitor_action_group.this.id
  }

  tags = var.tags
}

resource "azurerm_monitor_metric_alert" "vm_availability" {
  for_each = toset(var.vm_ids)

  name                = "${var.name_prefix}-availability-alert-${index(var.vm_ids, each.value)}"
  resource_group_name = var.resource_group_name
  scopes              = [each.value]
  description         = "Alert when VM availability drops below 100%"
  severity            = 0
  frequency           = "PT1M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "VmAvailabilityMetric"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 1
  }

  action {
    action_group_id = azurerm_monitor_action_group.this.id
  }

  tags = var.tags
}

###############################################################################
# Automation Account & Runbooks
###############################################################################

resource "azurerm_automation_account" "this" {
  name                = "${var.name_prefix}-automation"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = "Basic"

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

resource "azurerm_role_assignment" "automation_contributor" {
  scope                = data.azurerm_resource_group.this.id
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = azurerm_automation_account.this.identity[0].principal_id
}

resource "azurerm_automation_runbook" "this" {
  for_each = { for rb in var.automation_runbooks : rb.name => rb }

  name                    = each.value.name
  location                = var.location
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.this.name
  log_verbose             = true
  log_progress            = true
  description             = each.value.description
  runbook_type            = each.value.runbook_type

  content = each.value.content

  tags = var.tags
}

resource "azurerm_monitor_diagnostic_setting" "automation" {
  name                       = "${var.name_prefix}-automation-diagnostics"
  target_resource_id         = azurerm_automation_account.this.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  enabled_log {
    category = "JobLogs"
  }

  enabled_log {
    category = "JobStreams"
  }

  enabled_log {
    category = "DscNodeStatus"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
