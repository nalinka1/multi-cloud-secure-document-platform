variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "tenant_id" {
  description = "Entra ID tenant ID — appears in the OIDC issuer URL"
  type        = string
}

variable "federated_audience" {
  description = "Audience claim AWS requires, e.g. api://<app-id>"
  type        = string
}

variable "federated_subject" {
  description = "Principal ID of the managed identity permitted to assume the role"
  type        = string
}

variable "oidc_thumbprint" {
  description = "SHA-1 thumbprint of the issuer's TLS certificate chain"
  type        = string
}

variable "publisher_email" {
  description = "Contact address required by API Management"
  type        = string
}

variable "bucket_name" {
  description = "Globally unique S3 bucket name"
  type        = string
}

variable "key_vault_name" {
  description = "Globally unique Key Vault name"
  type        = string
}