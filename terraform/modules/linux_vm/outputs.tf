output "public_ip_address" {
  value = azurerm_linux_virtual_machine.my_terraform_vm.public_ip_address
}

output "private_ip_address" {
  value = azurerm_network_interface.my_terraform_nic.private_ip_address
}

output "vm_id" {
  value = azurerm_linux_virtual_machine.my_terraform_vm.id
}