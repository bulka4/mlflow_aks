output "primary_blob_endpoint" {
    value = azurerm_storage_account.my_storage_account.primary_blob_endpoint
}

output "name" {
    value = azurerm_storage_account.my_storage_account.name
}

output "primary_access_key" {
    value = azurerm_storage_account.my_storage_account.primary_access_key
}
