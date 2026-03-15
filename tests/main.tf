resource "azurerm_resource_group" "test" {
  name     = "rg-automanage-test"
  location = "eastus2"
}

resource "azurerm_virtual_network" "test" {
  name                = "vnet-automanage-test"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.test.location
  resource_group_name = azurerm_resource_group.test.name
}

resource "azurerm_subnet" "test" {
  name                 = "snet-automanage-test"
  resource_group_name  = azurerm_resource_group.test.name
  virtual_network_name = azurerm_virtual_network.test.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_interface" "test" {
  name                = "nic-automanage-test"
  location            = azurerm_resource_group.test.location
  resource_group_name = azurerm_resource_group.test.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.test.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "test" {
  name                            = "vm-automanage-test"
  resource_group_name             = azurerm_resource_group.test.name
  location                        = azurerm_resource_group.test.location
  size                            = "Standard_D2s_v3"
  admin_username                  = "azureadmin"
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.test.id]

  admin_ssh_key {
    username   = "azureadmin"
    public_key = tls_private_key.test.public_key_openssh
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

resource "tls_private_key" "test" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

module "test" {
  source = "../"

  name_prefix         = "automanage-test"
  location            = azurerm_resource_group.test.location
  resource_group_name = azurerm_resource_group.test.name

  vm_ids = [azurerm_linux_virtual_machine.test.id]

  maintenance_window = {
    day        = "Saturday"
    start_time = "02:00"
    duration   = "05:00"
  }

  backup_frequency      = "Daily"
  backup_retention_days = 30

  enable_antimalware   = true
  enable_auto_patching = true

  alert_email_addresses = ["admin@contoso.com"]
  log_retention_days    = 90

  tags = {
    Environment = "test"
    Terraform   = "true"
  }
}
