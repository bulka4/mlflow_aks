output "name" {
    value = azurerm_storage_share.this.name
    description = "Name of the created File share."
}

output "storage_account" {
    value = azurerm_storage_share.this.storage_account_name
    description = "Name of the Storage Account where we created a File share."
}