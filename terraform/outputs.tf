output "acr_name" {
  value     = module.acr.name
  description = "Name of the created ACR."
}

output "rg_name" {
  value     = module.resource_group.name
  description = "Name of the created resource group"
}

output "aks_name" {
  value     = azurerm_kubernetes_cluster.aks.name
  description = "Name of the created AKS"
}

output "tenant_id" {
  value = data.azurerm_client_config.current.tenant_id
  description = "Tenant ID of the currently used Azure client."
}

output "subscription_id" {
  value = data.azurerm_client_config.current.subscription_id
  description = "Azure subscription ID"
}

output "sp_id" {
  value = module.service_principal.client_id
  description = "Service Principal Client (app) ID."
}

output "sp_password" {
  value = module.service_principal.client_password
  description = "Service Principal password."
  sensitive = true
}