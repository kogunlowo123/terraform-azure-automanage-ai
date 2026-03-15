###############################################################################
# Complete Example - Azure Automanage AI
#
# This example deploys a fully configured Automanage setup with:
# - Automanage configuration profile (antimalware, backup, logging)
# - Maintenance configuration with weekly Saturday window
# - Recovery Services Vault with daily backups (30-day retention)
# - Log Analytics workspace with Updates and Security solutions
# - Metric alerts (CPU, memory, disk, availability)
# - Automation account with auto-remediation runbooks
# - Custom compliance policies
###############################################################################

resource "azurerm_resource_group" "example" {
  name     = "rg-automanage-complete"
  location = "eastus2"
}

resource "azurerm_virtual_network" "example" {
  name                = "vnet-automanage-complete"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
}

resource "azurerm_subnet" "example" {
  name                 = "snet-vms"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_interface" "example" {
  count = 2

  name                = "nic-automanage-vm-${count.index}"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.example.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "tls_private_key" "example" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "azurerm_linux_virtual_machine" "example" {
  count = 2

  name                            = "vm-automanage-${count.index}"
  resource_group_name             = azurerm_resource_group.example.name
  location                        = azurerm_resource_group.example.location
  size                            = "Standard_D2s_v3"
  admin_username                  = "azureadmin"
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.example[count.index].id]

  admin_ssh_key {
    username   = "azureadmin"
    public_key = tls_private_key.example.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

module "automanage" {
  source = "../../"

  name_prefix         = "automanage-prod"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  vm_ids = [for vm in azurerm_linux_virtual_machine.example : vm.id]

  # Maintenance Window
  maintenance_window = {
    day        = "Saturday"
    start_time = "02:00"
    duration   = "05:00"
  }

  # Backup Configuration
  backup_frequency      = "Daily"
  backup_retention_days = 30

  # Security Configuration
  enable_antimalware   = true
  enable_auto_patching = true

  # Monitoring Configuration
  alert_email_addresses = [
    "ops-team@contoso.com",
    "security@contoso.com"
  ]
  log_retention_days = 90

  # Custom Compliance Policies
  compliance_policies = [
    {
      name         = "require-tag-environment"
      display_name = "Require Environment Tag"
      description  = "Ensures all resources have an Environment tag"
      policy_rule  = jsonencode({
        if = {
          field  = "tags['Environment']"
          exists = "false"
        }
        then = {
          effect = "audit"
        }
      })
    }
  ]

  tags = {
    Environment = "production"
    Project     = "automanage"
    ManagedBy   = "terraform"
    CostCenter  = "infrastructure"
  }
}
