terraform {
  backend "azurerm" {
    resource_group_name  = "rg-mcdp-tfstate-aue"
    storage_account_name = "stmcdptfstatenh01"
    container_name       = "tfstate"
    key                  = "phase1.tfstate"
    use_azuread_auth     = true
  }
}
