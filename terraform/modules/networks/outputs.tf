output "subnet_id" {
    value = azurerm_subnet.my_terraform_subnet.id
}

output nsg_id {
    value = azurerm_network_security_group.my_terraform_nsg.id
}