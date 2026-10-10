# ============================================================
# Azure external API tier — step 1: APIM instance
# ============================================================
# NOTE: takes 30-45 minutes to provision. Kick off apply, then
# move on to other work — don't wait on it synchronously.

resource "azurerm_api_management" "external" {
  name                = "apim-mcdp-ext-dev-aue"
  location            = "australiaeast"
  resource_group_name = azurerm_resource_group.workload.name

  publisher_name  = "MCDP Document Platform"
  publisher_email = var.publisher_email

  sku_name = "Developer_1"

  tags = {
    project   = "mcdp"
    env       = "dev"
    lifecycle = "ephemeral"
  }
}

output "apim_gateway_url" {
  value = azurerm_api_management.external.gateway_url
}
resource "azurerm_api_management_api" "documents" {
  name                = "documents-api"
  resource_group_name = azurerm_resource_group.workload.name
  api_management_name = azurerm_api_management.external.name
  revision            = "1"
  display_name        = "MCDP Documents API"
  path                = "documents"
  protocols           = ["https"]
}
resource "azurerm_api_management_api_operation" "get_upload_url" {
  operation_id        = "get-upload-url"
  api_name            = azurerm_api_management_api.documents.name
  api_management_name = azurerm_api_management.external.name
  resource_group_name = azurerm_resource_group.workload.name
  display_name        = "Get upload URL"
  method              = "GET"
  url_template        = "/upload-url"
}
resource "azurerm_api_management_api_operation_policy" "get_upload_url" {
  api_name            = azurerm_api_management_api.documents.name
  api_management_name = azurerm_api_management.external.name
  resource_group_name = azurerm_resource_group.workload.name
  operation_id        = azurerm_api_management_api_operation.get_upload_url.operation_id

  xml_content = <<XML
<policies>
  <inbound>
    <base />
    <validate-jwt header-name="Authorization"
                  failed-validation-httpcode="401"
                  failed-validation-error-message="Unauthorized. Token invalid, expired, or wrong audience.">
      <openid-config url="https://login.microsoftonline.com/${data.azurerm_client_config.current.tenant_id}/.well-known/openid-configuration" />
      <audiences>
        <audience>api://${data.azurerm_client_config.current.tenant_id}/mcdp-documents-api</audience>
      </audiences>
      <issuers>
        <issuer>https://sts.windows.net/${data.azurerm_client_config.current.tenant_id}/</issuer>
      </issuers>
      <required-claims>
        <claim name="roles" match="any">
          <value>Api.Access</value>
        </claim>
      </required-claims>
    </validate-jwt>
    <mock-response status-code="200" content-type="application/json" />
  </inbound>
  <backend><base /></backend>
  <outbound><base /></outbound>
  <on-error><base /></on-error>
</policies>
XML
}
