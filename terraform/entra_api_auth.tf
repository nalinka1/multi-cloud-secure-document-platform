resource "azuread_application" "api" {
  display_name    = "mcdp-documents-api"
  identifier_uris = ["api://${data.azurerm_client_config.current.tenant_id}/mcdp-documents-api"]

  app_role {
    id                   = "b5307a5b-1e7e-4f6a-9a3c-9d1a0e2f4c11"
    allowed_member_types = ["Application"]
    description          = "Allows an application to call the Documents API"
    display_name         = "Api.Access"
    value                = "Api.Access"
    enabled              = true
  }
}

resource "azuread_service_principal" "api" {
  client_id = azuread_application.api.client_id
}

resource "azuread_application" "client" {
  display_name = "mcdp-api-test-client"
}

resource "azuread_service_principal" "client" {
  client_id = azuread_application.client.client_id
}

resource "azuread_application_password" "client_secret" {
  application_id = azuread_application.client.id
  display_name   = "terraform-managed-secret"
}

resource "azuread_app_role_assignment" "client_to_api" {
  app_role_id         = "b5307a5b-1e7e-4f6a-9a3c-9d1a0e2f4c11"
  principal_object_id = azuread_service_principal.client.object_id
  resource_object_id  = azuread_service_principal.api.object_id
}

output "api_app_id" {
  value = azuread_application.api.client_id
}

output "client_app_id" {
  value = azuread_application.client.client_id
}

output "client_secret" {
  value     = azuread_application_password.client_secret.value
  sensitive = true
}
