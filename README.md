# multi-cloud-secure-document-platform
Cross-cloud OIDC workload identity federation between Azure and AWS, in one Terraform configuration. An Azure workload reads an encrypted S3 bucket with no stored access keys — with negative tests proving wrong identities, expired tokens, out-of-scope prefixes and missing KMS grants are all denied.
