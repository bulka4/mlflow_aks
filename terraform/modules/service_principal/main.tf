resource "azuread_application" "this" {
  display_name = var.service_principal_display_name
}

resource "azuread_service_principal" "this" {
  client_id = azuread_application.this.client_id
}

resource "time_rotating" "month" {
  rotation_days = 30
}

resource "azuread_service_principal_password" "this" {
  service_principal_id = azuread_service_principal.this.id
  rotate_when_changed  = { rotation = time_rotating.month.id }
}

/*
resource "azurerm_role_assignment" "test" {
  scope                = var.scope
  role_definition_name = var.role
  principal_id = azuread_service_principal.this.object_id
  skip_service_principal_aad_check = true # without this running this code is taking a lot of time.
}
*/

resource "azurerm_role_assignment" "this" {
  for_each             = { for i, v in var.role_assignments : i => v }
  scope                = each.value.scope
  role_definition_name = each.value.role
  principal_id         = azuread_service_principal.this.object_id
  skip_service_principal_aad_check = true # without this running this code is taking a lot of time.
}