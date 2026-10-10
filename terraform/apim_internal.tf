resource "azurerm_network_security_group" "apim_internal" {
  name                = "nsg-apim-internal-aue"
  location            = "australiaeast"
  resource_group_name = "rg-mcdp-platform-aue"

  security_rule {
    name                       = "AllowApimManagement"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3443"
    source_address_prefix      = "ApiManagement"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "AllowAzureLoadBalancer"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6390"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "VirtualNetwork"
  }

  tags = {
    project = "mcdp"
    env     = "dev"
  }
}

resource "azurerm_subnet" "apim_internal" {
  name                 = "snet-apim-internal"
  resource_group_name  = "rg-mcdp-platform-aue"
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.1.2.0/24"]
}

resource "azurerm_subnet_network_security_group_association" "apim_internal" {
  subnet_id                 = azurerm_subnet.apim_internal.id
  network_security_group_id = azurerm_network_security_group.apim_internal.id
}
resource "azurerm_api_management" "internal" {
  name                = "apim-mcdp-int-dev-aue"
  location            = "australiaeast"
  resource_group_name = azurerm_resource_group.workload.name

  publisher_name  = "MCDP Document Platform"
  publisher_email = var.publisher_email

  sku_name = "Developer_1"

  virtual_network_type = "Internal"

  virtual_network_configuration {
    subnet_id = azurerm_subnet.apim_internal.id
  }

  tags = {
    project   = "mcdp"
    env       = "dev"
    lifecycle = "ephemeral"
  }
  identity {
    type = "SystemAssigned"
  }
}

output "apim_internal_private_ip" {
  value = azurerm_api_management.internal.private_ip_addresses
}
resource "azurerm_role_assignment" "apim_kv_secrets" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_api_management.internal.identity[0].principal_id
}
resource "azurerm_api_management_api" "internal_secrets" {
  name                = "internal-secrets-api"
  resource_group_name = azurerm_resource_group.workload.name
  api_management_name = azurerm_api_management.internal.name
  revision            = "1"
  display_name        = "MCDP Internal Secrets API"
  path                = "internal"
  protocols           = ["https"]
  service_url         = "https://kv-mcdp-dev-nh01.vault.azure.net"
}

resource "azurerm_api_management_api_operation" "get_secret" {
  operation_id        = "get-secret"
  api_name            = azurerm_api_management_api.internal_secrets.name
  api_management_name = azurerm_api_management.internal.name
  resource_group_name = azurerm_resource_group.workload.name
  display_name        = "Get secret"
  method              = "GET"
  url_template        = "/secret"
}

resource "azurerm_api_management_api_operation_policy" "get_secret" {
  api_name            = azurerm_api_management_api.internal_secrets.name
  api_management_name = azurerm_api_management.internal.name
  resource_group_name = azurerm_resource_group.workload.name
  operation_id        = azurerm_api_management_api_operation.get_secret.operation_id

  xml_content = <<XML
<policies>
  <inbound>
    <base />
    <authentication-managed-identity resource="https://vault.azure.net" />
    <rewrite-uri template="/secrets/test-secret?api-version=7.4" />
  </inbound>
  <backend><base /></backend>
  <outbound><base /></outbound>
  <on-error><base /></on-error>
</policies>
XML
}
