variable "name_prefix" {
  description = "Prefix for all resource names."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}$", var.name_prefix))
    error_message = "Name prefix must start with a lowercase letter, contain only lowercase letters, numbers, and hyphens, and be 2-21 characters."
  }
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the Azure resource group."
  type        = string
}

variable "vm_ids" {
  description = "List of Virtual Machine resource IDs to manage."
  type        = list(string)

  validation {
    condition     = length(var.vm_ids) > 0
    error_message = "At least one VM ID must be provided."
  }
}

variable "maintenance_window" {
  description = "Maintenance window configuration for patching."
  type = object({
    day        = string
    start_time = string
    duration   = string
  })
  default = {
    day        = "Saturday"
    start_time = "02:00"
    duration   = "05:00"
  }

  validation {
    condition     = contains(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], var.maintenance_window.day)
    error_message = "Maintenance window day must be a valid day of the week."
  }
}

variable "backup_frequency" {
  description = "Frequency of VM backups (Daily or Weekly)."
  type        = string
  default     = "Daily"

  validation {
    condition     = contains(["Daily", "Weekly"], var.backup_frequency)
    error_message = "Backup frequency must be Daily or Weekly."
  }
}

variable "backup_retention_days" {
  description = "Number of days to retain VM backups."
  type        = number
  default     = 30

  validation {
    condition     = var.backup_retention_days >= 7 && var.backup_retention_days <= 365
    error_message = "Backup retention must be between 7 and 365 days."
  }
}

variable "enable_antimalware" {
  description = "Enable Microsoft Antimalware extension on VMs."
  type        = bool
  default     = true
}

variable "enable_auto_patching" {
  description = "Enable automatic OS patching during maintenance windows."
  type        = bool
  default     = true
}

variable "compliance_policies" {
  description = "List of custom Azure Policy definitions for compliance."
  type = list(object({
    name         = string
    display_name = string
    description  = string
    policy_rule  = string
    mode         = optional(string, "All")
  }))
  default = []
}

variable "alert_email_addresses" {
  description = "Email addresses for monitoring alert notifications."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for email in var.alert_email_addresses : can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", email))])
    error_message = "All email addresses must be valid."
  }
}

variable "log_retention_days" {
  description = "Number of days to retain logs in Log Analytics workspace."
  type        = number
  default     = 90

  validation {
    condition     = var.log_retention_days >= 30 && var.log_retention_days <= 730
    error_message = "Log retention must be between 30 and 730 days."
  }
}

variable "automation_runbooks" {
  description = "List of automation runbooks for auto-remediation."
  type = list(object({
    name         = string
    description  = string
    runbook_type = optional(string, "PowerShell")
    content      = string
  }))
  default = [
    {
      name         = "Restart-UnhealthyVM"
      description  = "Restarts a VM that has failed health checks"
      runbook_type = "PowerShell"
      content      = <<-POWERSHELL
        param(
            [Parameter(Mandatory=$true)]
            [string]$VMName,
            [Parameter(Mandatory=$true)]
            [string]$ResourceGroupName
        )

        Connect-AzAccount -Identity

        $vm = Get-AzVM -Name $VMName -ResourceGroupName $ResourceGroupName -Status
        $powerState = ($vm.Statuses | Where-Object { $_.Code -like "PowerState/*" }).DisplayStatus

        if ($powerState -ne "VM running") {
            Write-Output "VM $VMName is not running (state: $powerState). Starting VM..."
            Start-AzVM -Name $VMName -ResourceGroupName $ResourceGroupName
            Write-Output "VM $VMName has been started."
        } else {
            Write-Output "VM $VMName is running but unhealthy. Restarting..."
            Restart-AzVM -Name $VMName -ResourceGroupName $ResourceGroupName
            Write-Output "VM $VMName has been restarted."
        }
      POWERSHELL
    }
  ]
}

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = {}
}
