# Configure the Microsoft Azure Provider
provider "azurerm" {
  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
  features {}
}

# Create a resource group if it doesn't exist
resource "azurerm_resource_group" "desafio-m2-rg" {
  name     = "engenharia-rg"
  location = var.location

  tags = {
    departamento = var.tag
  }
}

resource "azurerm_virtual_network" "desafio-m2-vnet" {
  name                = "engenharia-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.desafio-m2-rg.name

  tags = {
    departamento = var.tag
  }
}

resource "azurerm_subnet" "desafio-m2-subnet" {
  name                 = "engenharia-subnet"
  resource_group_name  = azurerm_resource_group.desafio-m2-rg.name
  virtual_network_name = azurerm_virtual_network.desafio-m2-vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}


resource "azurerm_network_security_group" "desafio-m2-nsg" {
    name = "SERVERS"
    location = var.location
    resource_group_name = azurerm_resource_group.desafio-m2-rg.name

    tags = {
        departamento = var.tag
    }
}

resource "azurerm_network_security_rule" "desafio-m2-nsr1" {
  name                          = "HTTP"
  priority                      = 100
  direction                     = "Inbound"
  access                        = "Allow"
  protocol                      = "Tcp"
  source_port_range             = "*"
  destination_port_range        = "80"
  source_address_prefix         = "*"
  destination_address_prefix    = "*"
  resource_group_name           = azurerm_resource_group.desafio-m2-rg.name
  network_security_group_name   = azurerm_network_security_group.desafio-m2-nsg.name
}

resource "azurerm_network_security_rule" "desafio-m2-nsr2" {
  name                          = "HTTPS"
  priority                      = 101
  direction                     = "Inbound"
  access                        = "Allow"
  protocol                      = "Tcp"
  source_port_range             = "*"
  destination_port_range        = "443"
  source_address_prefix         = "*"
  destination_address_prefix    = "*"
  resource_group_name           = azurerm_resource_group.desafio-m2-rg.name
  network_security_group_name   = azurerm_network_security_group.desafio-m2-nsg.name
}


resource "azurerm_public_ip" "desafio-m2-pip" {
    name                    = "PUBLICIP"
    location                = var.location
    resource_group_name     = azurerm_resource_group.desafio-m2-rg.name
    allocation_method       = "Dynamic"

    tags = {
      departamento = var.tag
    }
}


resource "azurerm_lb" "desafio-m2-lb" {
  name                  = "LOADBALANCER"
  location              = azurerm_resource_group.desafio-m2-rg.location
  resource_group_name   = azurerm_resource_group.desafio-m2-rg.name

  frontend_ip_configuration {
    name                  = "PUBLICIPADDRESS"
    public_ip_address_id  = azurerm_public_ip.desafio-m2-pip.id
  }

  tags = {
      departamento = var.tag
  }
}


resource "azurerm_network_interface" "desafio-m2-ni" {
  count               = var.instance_count
  name                = "${var.prefix}-${count.index}NI"
  location            = var.location
  resource_group_name = azurerm_resource_group.desafio-m2-rg.name

  ip_configuration {
    name                            = "${var.prefix}-${count.index}-NIConfiguration"
    subnet_id                       = azurerm_subnet.desafio-m2-subnet.id
    private_ip_address_allocation   = "Dynamic"
  }

  tags = {
    departamento = var.tag
  }
}
    

resource "azurerm_lb_backend_address_pool" "desafio-m2-lb-ap" {
  name                  = "BackEndAddressPool"
  resource_group_name   = azurerm_resource_group.desafio-m2-rg.name
  loadbalancer_id       = azurerm_lb.desafio-m2-lb.id
}


resource "azurerm_network_interface_backend_address_pool_association" "desafio-m2-nib-apa" {
  count = var.instance_count
  backend_address_pool_id = azurerm_lb_backend_address_pool.desafio-m2-lb-ap.id
  ip_configuration_name = element(azurerm_network_interface.desafio-m2-ni.*.ip_configuration.name, count.index)
  network_interface_id = element(azurerm_network_interface.desafio-m2-ni.*.id, count.index)
}


resource "azurerm_availability_set" "desafio-m2-avset" {
  name                          = "${var.prefix}AVSET"
  location                      = var.location
  resource_group_name           = azurerm_resource_group.desafio-m2-rg.name
  platform_fault_domain_count   = 2
  platform_update_domain_count  = 2
  managed                       = true

  tags = {
    departamento = var.tag
  }
}


resource "azurerm_storage_account" "desafio-m2-sa" {
  name = "sadesafiom2"
  resource_group_name       = azurerm_resource_group.desafio-m2-rg.name
  location                  = var.location
  account_tier              = "Standard"
  account_replication_type  = "GRS"

  blob_properties {
    delete_retention_policy = 7
  }
  

  tags = {
    departamento = var.tag
  }
}

resource "azurerm_storage_account_network_rules" "desafio-m2-sa-nr" {
  resource_group_name = azurerm_resource_group.desafio-m2-rg.name
  storage_account_name = azurerm_storage_account.desafio-m2-sa.name

  default_action              = "Allow"
  ip_rules                    = ["10.0.2.0/24"]
  virtual_network_subnet_ids  = [azurerm_subnet.desafio-m2-subnet.id]
  bypass                      = ["Metrics"]
}


resource "azurerm_storage_share" "desafio-m2-ss" {
  name                 = "storageshare"
  storage_account_name = azurerm_storage_account.desafio-m2-sa.name
}


# Create (and display) an SSH key
resource "tls_private_key" "desafio-m2-pk" {
  algorithm = "RSA"
  rsa_bits = 4096
}
output "tls_private_key" { value = tls_private_key.desafio-m2-pk.private_key_pem }


resource "azurerm_linux_virtual_machine" "desafio-m2-vm" {
  count                 = var.instance_count
  name                  = "${var.prefix}-${count.index}"
  resource_group_name   = azurerm_resource_group.desafio-m2-rg.name
  location              = azurerm_resource_group.desafio-m2-rg.location
  size                  = "Standard_F2"
  admin_username        = "adminuser"
  availability_set_id   = azurerm_availability_set.desafio-m2-avset.id

  network_interface_ids = [
    azurerm_network_interface.desafio-m2-ni[count.index].id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = tls_private_key.desafio-m2-pk.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  tags = {
    departamento = var.tag
  }
}

resource "azurerm_managed_disk" "desafio-m2-md" {
  count                 = var.instance_count
  name                  = "${var.prefix}-${count.index}MD"
  location              = azurerm_resource_group.desafio-m2-rg.location
  create_option         = "Empty"
  disk_size_gb          = 100
  resource_group_name   = azurerm_resource_group.desafio-m2-rg.name
  storage_account_type  = "Standard_LRS"

  tags = {
    departamento = var.tag
  }
}

resource "azurerm_virtual_machine_data_disk_attachment" "desafio-m2-dda" {
  count               = var.instance_count 
  virtual_machine_id  = azurerm_linux_virtual_machine.desafio-m2-vm[count.index].id
  managed_disk_id     = azurerm_managed_disk.desafio-m2-md[count.index].id
  lun                 = 0
  caching             = "ReadWrite"
}


resource "azurerm_recovery_services_vault" "desafio-m2-rsv" {
  name                  = "RECOVERY-VAULT"
  location              = var.location
  resource_group_name   = azurerm_resource_group.desafio-m2-rg.name
  sku                   = "Standard"

  tags = {
    departamento = var.tag
  }
}

resource "azurerm_backup_policy_vm" "desafio-m2-bp" {
  name                  = "RECOVERY-VAULT-POLICY"
  resource_group_name   = azurerm_resource_group.desafio-m2-rg.name
  recovery_vault_name   = azurerm_recovery_services_vault.desafio-m2-rsv.name

  backup {
    frequency       = "Daily"
    time            = "18:00"
  }

  retention_daily {
    count = 7
  }

  tags = {
    departamento = var.tag
  }
}


resource "azurerm_automation_account" "desafio-m2-aa" {
  name                = "AUTOMATION-ACCOUNT"
  location            = var.location
  resource_group_name = azurerm_resource_group.desafio-m2-rg.name

  sku_name = "Basic"

  tags = {
    departamento = var.tag
  }
}

resource "azurerm_automation_schedule" "desafio-m2-aa-as1" {
  name                    = "AUTOMATION-SCHEDULE-ON"
  resource_group_name     = azurerm_resource_group.desafio-m2-rg.name
  automation_account_name = azurerm_automation_account.desafio-m2-aa.name
  frequency               = "Day"
  interval                = 1
  start_time              = "2020-10-20T07:53:00Z"
  description             = "Ligar as VMs"
}


resource "azurerm_automation_schedule" "desafio-m2-aa-as2" {
  name                    = "AUTOMATION-SCHEDULE-OFF"
  resource_group_name     = azurerm_resource_group.desafio-m2-rg.name
  automation_account_name = azurerm_automation_account.desafio-m2-aa.name
  frequency               = "Day"
  interval                = 1
  start_time              = "2020-10-20T17:53:00Z"
  description             = "Desligar as VMs"
}

resource "azurerm_automation_runbook" "desafio-m2-aa-rb" {
  name                    = "ON-OFF_VM"
  location                = var.location
  resource_group_name     = azurerm_resource_group.desafio-m2-rg.name
  automation_account_name = azurerm_automation_account.desafio-m2-aa.name
  log_verbose             = "true"
  log_progress            = "true"
  description             = "Ligar e desligar VMs"
  runbook_type            = "PowerShell"

  publish_content_link {
    uri = "https://github.com/rodrigofuku/bootcampIGTI-cloud-desafioM2/blob/main/automacao.ps1"
  }

  tags = {
    departamento = var.tag
  }
}

resource "azurerm_automation_job_schedule" "desafio-m2-aa-js1" {
  count = var.instance_count
  resource_group_name     = azurerm_resource_group.desafio-m2-rg.name
  automation_account_name = azurerm_automation_account.desafio-m2-aa.name
  schedule_name           = azurerm_automation_schedule.desafio-m2-aa-as2.name
  runbook_name            = azurerm_automation_runbook.desafio-m2-aa-rb.name

  parameters = {
    resourcegroup = azurerm_resource_group.desafio-m2-rg.name
    vmname        = element(azurerm_linux_virtual_machine.desafio-m2-vm.*.name, count.index)
    vmaction      = "Ligar"
  }
}

resource "azurerm_automation_job_schedule" "desafio-m2-aa-js2" {
  count = var.instance_count
  resource_group_name     = azurerm_resource_group.desafio-m2-rg.name
  automation_account_name = azurerm_automation_account.desafio-m2-aa.name
  schedule_name           = azurerm_automation_schedule.desafio-m2-aa-as1.name
  runbook_name            = azurerm_automation_runbook.desafio-m2-aa-rb.name

  parameters = {
    resourcegroup = azurerm_resource_group.desafio-m2-rg.name
    vmname        = element(azurerm_linux_virtual_machine.desafio-m2-vm.*.name, count.index)
    vmaction      = "Desligar"
  }
}


resource "azurerm_container_registry" "desafio-m2-cr" {
  name                     = "containerRegistrydesafiom2"
  resource_group_name      = azurerm_resource_group.desafio-m2-rg.name
  location                 = var.location
  sku                      = "Premium"
  admin_enabled            = false
  georeplication_locations = ["East US", "West Europe"]
}