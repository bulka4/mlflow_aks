output "client_id" {
  description = "The Azure AD service principal's application (client) ID."
  value       = azuread_application.this.client_id
}

output "client_password" {
  description = "The Azure AD service principal's client secret value."
  value       = azuread_service_principal_password.this.value
  sensitive   = true
}