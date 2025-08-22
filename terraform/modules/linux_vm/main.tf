# Create public IPs
resource "azurerm_public_ip" "my_terraform_public_ip" {
  name                = "${var.vm_name}_public_ip"
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name
  allocation_method   = "Dynamic"
}

# Create network interface
resource "azurerm_network_interface" "my_terraform_nic" {
  name                = "${var.vm_name}_nic"
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "${var.vm_name}_nic"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.my_terraform_public_ip.id
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "example" {
  network_interface_id      = azurerm_network_interface.my_terraform_nic.id
  network_security_group_id = var.nsg_id
}

# Create a Linux VM.
resource "azurerm_linux_virtual_machine" "my_terraform_vm" {
  name                  = var.vm_name
  location              = var.resource_group_location
  resource_group_name   = var.resource_group_name
  network_interface_ids = [azurerm_network_interface.my_terraform_nic.id]
  size                  = var.vm_size

  os_disk {
    name                 = "${var.vm_name}_disk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  computer_name  = var.hostname
  # Admin username for a user which will be created. It can be used for connecting to the VM through SSH.
  admin_username = var.username

  # Save the public SSH key so we can connect to the VM from our local computer.
  admin_ssh_key {
    username   = var.username
    public_key = var.public_key
  }

  boot_diagnostics {
    storage_account_uri = var.storage_account_uri
  }
}

