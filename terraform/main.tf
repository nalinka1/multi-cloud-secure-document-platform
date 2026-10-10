terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
  }
}
provider "azuread" {}
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

resource "azurerm_resource_group" "workload" {
  name     = "rg-mcdp-workload-aue"
  location = "australiaeast"

  tags = {
    project   = "mcdp"
    env       = "dev"
    lifecycle = "ephemeral"
    owner     = "nalinka"
  }
}

resource "azurerm_virtual_network" "main" {
  name                = "vnet-mcdp-dev-aue"
  resource_group_name = "rg-mcdp-platform-aue"
  location            = "australiaeast"
  address_space       = ["10.1.0.0/16"]
}

resource "azurerm_key_vault" "main" {
  name                       = "kv-mcdp-dev-nh01"
  resource_group_name        = azurerm_resource_group.identity.name
  location                   = azurerm_resource_group.identity.location
  tenant_id                  = var.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
}

resource "azurerm_resource_group" "identity" {
  name     = "rg-mcdp-identity-aue"
  location = "australiaeast"
  tags = {
    project   = "mcdp"
    env       = "dev"
    lifecycle = "persistent"
    owner     = "nalinka"
  }
}

resource "azurerm_resource_group" "platform" {
  name     = "rg-mcdp-platform-aue"
  location = "australiaeast"
  tags = {
    project   = "mcdp"
    env       = "dev"
    lifecycle = "persistent"
    owner     = "nalinka"
  }
}

provider "aws" {
  region = "ap-southeast-2"
}

resource "aws_s3_bucket" "docs" {
  bucket = "mcdp-documents-nh01"

  tags = {
    project   = "mcdp"
    env       = "dev"
    lifecycle = "persistent"
    owner     = "nalinka"
  }
}

resource "aws_kms_key" "docs" {
  description             = "CMK for the mcdp document bucket"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    project = "mcdp"
    env     = "dev"
    owner   = "nalinka"
  }
}

resource "aws_kms_alias" "docs" {
  name          = "alias/mcdp-documents"
  target_key_id = aws_kms_key.docs.key_id
}

resource "aws_s3_bucket_server_side_encryption_configuration" "docs" {
  bucket = aws_s3_bucket.docs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.docs.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_versioning" "docs" {
  bucket = aws_s3_bucket.docs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "docs" {
  bucket                  = aws_s3_bucket.docs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket_policy" "docs" {
  bucket = aws_s3_bucket.docs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyUnencryptedUploads"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.docs.arn}/*"
        Condition = {
          StringNotEqualsIfExists = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      },
      {
        Sid       = "DenyWrongKey"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.docs.arn}/*"
        Condition = {
          StringNotEqualsIfExists = {
            "s3:x-amz-server-side-encryption-aws-kms-key-id" = aws_kms_key.docs.arn
          }
        }
      },
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [aws_s3_bucket.docs.arn, "${aws_s3_bucket.docs.arn}/*"]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

data "azurerm_client_config" "current" {}

resource "aws_iam_openid_connect_provider" "entra" {
  url             = "https://sts.windows.net/${var.tenant_id}/"
  client_id_list  = [var.federated_audience]
  thumbprint_list = [var.oidc_thumbprint]

  tags = {
    project = "mcdp"
    env     = "dev"
    owner   = "nalinka"
  }
}

resource "aws_iam_role" "databricks_federated" {
  name = "mcdp-databricks-federated-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.entra.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "sts.windows.net/${var.tenant_id}/:aud" = var.federated_audience
            "sts.windows.net/${var.tenant_id}/:sub" = var.federated_subject
          }
        }
      }
    ]
  })

  tags = {
    project = "mcdp"
    env     = "dev"
    owner   = "nalinka"
  }
}

resource "aws_iam_role_policy" "databricks_s3_read" {
  name = "mcdp-databricks-s3-inbound-read"
  role = aws_iam_role.databricks_federated.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadInboundPrefix"
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.docs.arn}/inbound/*"
      },
      {
        Sid      = "ListInboundPrefixOnly"
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.docs.arn
        Condition = {
          StringLike = {
            "s3:prefix" = "inbound/*"
          }
        }
      },
      {
        Sid      = "DecryptWithDocumentsKey"
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = aws_kms_key.docs.arn
      }
    ]
  })
}
