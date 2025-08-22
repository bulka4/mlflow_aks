# Create virtual network
resource "azurerm_virtual_network" "my_terraform_network" {
  name                = var.network_name
  address_space       = ["10.0.0.0/16"]
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name
}

# Create subnet
resource "azurerm_subnet" "my_terraform_subnet" {
  name                 = "mySubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.my_terraform_network.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "my_terraform_nsg" {
  name                = "myNetworkSecurityGroup"
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name

  # Open port 22 for SSH connection
  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*" # or restrict to your IP
    destination_address_prefix = "*"
  }
  
/*
  # Open port 8888 for inbound traffic so we can access the Jupyter Notebook.
  security_rule {
    name                       = "Allow-Jupyter"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8888"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
*/

  # Open port 6443 for Kubernetes API Server
  security_rule {
    name                       = "AllowKubeAPI"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow full internal traffic between Kubernetes nodes 
  security_rule {
    name                       = "AllowInternal"
    priority                   = 1004
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = azurerm_virtual_network.my_terraform_network.address_space[0] # "10.0.0.0/16"
    destination_address_prefix = azurerm_virtual_network.my_terraform_network.address_space[0]
  }

  # Open port 10250 needed used by the Kubelet
  security_rule {
    name                       = "AllowKubelet"
    priority                   = 1005
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "10250"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Open ports used by NodePort Services
  security_rule {
    name                       = "AllowNodePort"
    priority                   = 1006
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["30000-32767"]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Open port 53 used by DNS
  security_rule {
    name                       = "AllowDNS"
    priority                   = 1007
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "53"
    source_address_prefix      = azurerm_virtual_network.my_terraform_network.address_space[0] # "10.0.0.0/16"
    destination_address_prefix = "*"
  }
}