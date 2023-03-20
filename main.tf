terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "tf-example" {
  name     = "tf-example"
  location = "East Us"
}

resource "azurerm_virtual_network" "tf-vn" {
  name                = "tf-network"
  location            = azurerm_resource_group.tf-example.location
  resource_group_name = azurerm_resource_group.tf-example.name
  address_space       = ["10.123.0.0/16"]
}

resource "azurerm_subnet" "tf-subnet" {
  name                 = "tf-subnet"
  resource_group_name  = azurerm_resource_group.tf-example.name
  virtual_network_name = azurerm_virtual_network.tf-vn.name
  address_prefixes     = ["10.123.1.0/24"]
}

resource "azurerm_network_security_group" "tf-group" {
  name                = "acceptanceTestSecurityGroup1"
  location            = azurerm_resource_group.tf-example.location
  resource_group_name = azurerm_resource_group.tf-example.name
}

resource "azurerm_network_security_rule" "tf-rule" {
  name                        = "tf-rule"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.tf-example.name
  network_security_group_name = azurerm_network_security_group.tf-group.name
}

resource "azurerm_subnet_network_security_group_association" "tf-asc" {
  subnet_id                 = azurerm_subnet.tf-subnet.id
  network_security_group_id = azurerm_network_security_group.tf-group.id
}

resource "azurerm_public_ip" "tf-ip" {
  name                = "tf-ip"
  resource_group_name = azurerm_resource_group.tf-example.name
  location            = azurerm_resource_group.tf-example.location
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "tf-nic" {
  name                = "tf-nic"
  location            = azurerm_resource_group.tf-example.location
  resource_group_name = azurerm_resource_group.tf-example.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.tf-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.tf-ip.id
  }
}

resource "azurerm_virtual_machine" "tf-vm" {
  name                  = "tf-vm"
  location              = azurerm_resource_group.tf-example.location
  resource_group_name   = azurerm_resource_group.tf-example.name
  network_interface_ids = [azurerm_network_interface.tf-nic.id]
  vm_size               = "Standard_B1s"

  # Uncomment this line to delete the OS disk automatically when deleting the VM
  delete_os_disk_on_termination = true

  # Uncomment this line to delete the data disks automatically when deleting the VM
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
  storage_os_disk {
    name              = "myosdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "hostname"
    admin_username = "username"
    admin_password = "Testing123456"
  }
  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      key_data = file("~/.ssh/tf-key.pub")
      path     = "/home/{username}/.ssh/authorized_keys"
    }
  }

}

output "virtual_machine_id" {
  value = "${data.azurerm_virtual_machine.tf-vm.name}: ${azurerm_public_ip.tf-ip.ip}"
}
