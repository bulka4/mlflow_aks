output "name" {
    value = azurerm_container_registry.acr.name
    description = "Name of the created ACR (without the azurecr.io)."
}

output id {
    value = azurerm_container_registry.acr.id
}

output url {
    value = azurerm_container_registry.acr.login_server
    description = "URL to the ACR (of the following format: <my-registry-name>.azurecr.io)."
}