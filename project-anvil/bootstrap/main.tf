# ==============================================================================
# Project Anvil - Bootstrap Layer
# main.tf
#
# This file provisions the foundational AWS resources required for the
# Project Anvil infrastructure, including IAM roles, S3 buckets for Terraform
# state, DynamoDB tables for state locking, SSH key pairs, Secrets Manager
# secrets, and CloudWatch Agent configuration parameters.
#
# Author: Carrick Bradley
# Last Updated: 2025-10-17 - Corrected for strict layered architecture and
#                            updated IAM role module inputs, including KMS ARNs.
#                            Fixed vulnerability_reports KMS key to be per-environment.
# ==============================================================================

# ------------------------------------------------------------------------------
# Version and Provider Configuration
# ------------------------------------------------------------------------------
terraform {
  required_version = ">= 1.13.3" # Updated to latest stable

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.15" # Updated to target latest 6.x series, specifically 6.15.0+
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.1" # Updated to target latest 4.x series, specifically 4.1.0+
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2" # Updated to target latest 3.x series, specifically 3.2.4+
    }
    archive = { # Added for creating Lambda deployment package
      source  = "hashicorp/archive"
      version = "~> 2.7" # Updated to target latest 2.x series, specifically 2.7.1+
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data source to retrieve the AWS Account ID for use in KMS key policies and other ARNs
data "aws_caller_identity" "current" {}

# Data source to look up the Route 53 hosted zone by domain name
data "aws_route53_zone" "main" {
  name = "${var.domain_name}."
}

# ------------------------------------------------------------------------------
# Tags Module
# (Provides a consistent set of tags for all resources)
# ------------------------------------------------------------------------------
module "tags" {
  source           = "../shared-modules/tags"
  project_name     = var.project_name
  environment_name = var.environment_name
  managedby        = var.managedby
  owner            = var.owner
  build_timestamp  = var.build_timestamp
}

# ------------------------------------------------------------------------------
# IAM Roles and Policies (via shared module)
# This module now manages all IAM roles and policies required for automation
# and CI/CD workflows.
# ------------------------------------------------------------------------------
module "iam_roles" {
  source           = "../shared-modules/iam-roles"
  aws_region       = var.aws_region
  github_org       = var.github_org
  github_repo      = var.github_repo
  project_name     = var.project_name
  oidc_thumbprint  = var.oidc_thumbprint
  environments     = var.environments
  environment_name = var.environment_name
  route53_zone_id  = data.aws_route53_zone.main.zone_id
  domain_name      = var.domain_name
  tags             = module.tags.tags

  # NEW: Pass KMS key ARNs to the iam_roles module for explicit permissions (no wildcards)
  # vulnerability_reports_kms_key_arn is now a map because the resource is for_each based
  vulnerability_reports_kms_key_arns = { for env, key in aws_kms_key.vulnerability_reports : env => key.arn }
  secrets_manager_kms_key_arn        = aws_kms_key.secrets_manager.arn
  terraform_lock_table_kms_key_arns  = { for env, mod in module.lock_table : env => mod.kms_key_arn }
  central_logs_kms_key_arn           = module.central_logs.kms_key_arn
}

# ------------------------------------------------------------------------------
# Central S3 Logging Bucket (via shared module)
# This bucket collects access logs from all other S3 buckets in the project.
# ------------------------------------------------------------------------------
module "central_logs" {
  source = "../shared-modules/s3-central-logs"
  tags   = module.tags.tags
}

# ------------------------------------------------------------------------------
# DynamoDB Tables for Terraform State Locking (per environment, via shared module)
# These tables handle state locking for each environment.
# Prevent accidental deletion to avoid concurrent state changes.
# ------------------------------------------------------------------------------
module "lock_table" {
  source     = "../shared-modules/dynamodb-lock-table"
  for_each   = toset(var.environments)
  table_name = "acmelabs-terraform-lock-table-${each.key}"
  tags       = module.tags.tags
}

# ------------------------------------------------------------------------------
# NEW: KMS Key for Vulnerability Reports S3 Buckets (now per-environment)
# This customer-managed key will be used for server-side encryption of the
# S3 buckets storing Trivy scan reports.
# ------------------------------------------------------------------------------
resource "aws_kms_key" "vulnerability_reports" {
  for_each                = toset(var.environments) # <-- ADDED for_each here
  description             = "KMS key for S3 vulnerability reports encryption for ${each.key} environment"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "Enable IAM User Permissions",
        Effect    = "Allow",
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" },
        Action    = "kms:*",
        Resource  = "*",
      },
      {
        Sid       = "Allow S3 to use KMS key",
        Effect    = "Allow",
        Principal = { Service = "s3.amazonaws.com" },
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = "*",
      }
    ]
  })
  tags = merge(module.tags.tags, {
    Environment = each.key
  })
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "vulnerability_reports" {
  for_each      = toset(var.environments)                            # <-- ADDED for_each here
  name          = "alias/${each.key}/vulnerability-reports"          # Uses each.key for environment specific alias
  target_key_id = aws_kms_key.vulnerability_reports[each.key].key_id # References the specific key
}

# ------------------------------------------------------------------------------
# S3 Buckets for Vulnerability Reports (per environment)
# These buckets are used by the AMI builder pipeline to store Trivy scan reports.
# Prevent accidental deletion to preserve audit trail.
# ------------------------------------------------------------------------------
resource "aws_s3_bucket" "vulnerability_reports" {
  for_each = toset(var.environments) # Changed to var.environments for consistency with kms_key
  bucket   = "acmelabs-vulnerability-reports-${each.key}"
  tags     = module.tags.tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_logging" "vulnerability_reports" {
  for_each      = toset(var.environments)
  bucket        = aws_s3_bucket.vulnerability_reports[each.key].id
  target_bucket = module.central_logs.central_logs_bucket_name
  target_prefix = "s3-access-logs/vulnerability-reports-${each.key}/"
}

resource "aws_s3_bucket_versioning" "vulnerability_reports" {
  for_each = toset(var.environments) # Changed to var.environments for consistency with kms_key
  bucket   = aws_s3_bucket.vulnerability_reports[each.key].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "vulnerability_reports" {
  for_each = toset(var.environments) # Changed to var.environments for consistency with kms_key
  bucket   = aws_s3_bucket.vulnerability_reports[each.key].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "vulnerability_reports" {
  for_each = toset(var.environments) # Changed to var.environments for consistency with kms_key
  bucket   = aws_s3_bucket.vulnerability_reports[each.key].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.vulnerability_reports[each.key].arn # <-- UPDATED to reference specific key
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "vulnerability_reports_lifecycle" {
  for_each = toset(var.environments) # Changed to var.environments for consistency with kms_key
  bucket   = aws_s3_bucket.vulnerability_reports[each.key].id

  rule {
    id     = "expire_old_reports"
    status = "Enabled"
    expiration {
      days = 90
    }
  }
}

# ==============================================================================
# NEW: S3 Buckets and Dedicated KMS Keys for Downstream Layer State
# This block creates secure, versioned, and CMK-encrypted S3 buckets with
# a DEDICATED KMS KEY PER BUCKET to store state for downstream layers.
# ==============================================================================

locals {
  # Define the layers that need a state bucket
  state_bucket_layers = toset(["network", "platform", "apps"])
}

# Create a dedicated KMS key for EACH layer's state bucket
resource "aws_kms_key" "layer_state_key" {
  for_each                = local.state_bucket_layers
  description             = "KMS key for encrypting the ${each.key} layer state bucket"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  tags                    = module.tags.tags
}

resource "aws_kms_alias" "layer_state_key" {
  for_each      = local.state_bucket_layers
  name          = "alias/${var.project_name}-${var.environment_name}/${each.key}-state-key"
  target_key_id = aws_kms_key.layer_state_key[each.key].key_id
}

# Create the S3 buckets
# tfsec:ignore:aws-s3-enable-bucket-encryption
# tfsec:ignore:aws-s3-enable-bucket-logging
# tfsec:ignore:aws-s3-enable-versioning
# tfsec:ignore:aws-s3-specify-public-access-block
# tfsec:ignore:aws-s3-block-public-acls
# tfsec:ignore:aws-s3-block-public-policy
# tfsec:ignore:aws-s3-ignore-public-acls
# tfsec:ignore:aws-s3-no-public-buckets
# tfsec:ignore:aws-s3-encryption-customer-key
resource "aws_s3_bucket" "layer_state" {

  for_each = local.state_bucket_layers
  bucket   = "acmelabs-terraform-state-${each.key}-${var.environment_name}"

  lifecycle {
    prevent_destroy = true
  }

  tags = merge(module.tags.tags, {
    Name = "acmelabs-terraform-state-${each.key}-${var.environment_name}"
  })
}

# Apply security settings to each bucket
resource "aws_s3_bucket_versioning" "layer_state_buckets" {
  for_each = aws_s3_bucket.layer_state
  bucket   = each.value.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "layer_state_buckets" {
  for_each = aws_s3_bucket.layer_state
  bucket   = each.value.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "layer_state_buckets" {
  for_each = aws_s3_bucket.layer_state
  bucket   = each.value.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.layer_state_key[each.key].arn
    }
  }
}

resource "aws_s3_bucket_logging" "layer_state_buckets" {
  for_each      = aws_s3_bucket.layer_state
  bucket        = each.value.id
  target_bucket = module.central_logs.central_logs_bucket_name
  target_prefix = "s3-access-logs/state-${each.key}-${var.environment_name}/"
}

# ------------------------------------------------------------------------------
# NEW: KMS Key for Secrets Manager Secrets
# This customer-managed key will be used for server-side encryption of all
# Secrets Manager secrets managed by the bootstrap layer.
# ------------------------------------------------------------------------------
resource "aws_kms_key" "secrets_manager" {
  description             = "KMS key for Secrets Manager secrets encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "Enable IAM User Permissions",
        Effect    = "Allow",
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" },
        Action    = "kms:*",
        Resource  = "*",
      },
      {
        Sid       = "Allow Secrets Manager to use KMS key",
        Effect    = "Allow",
        Principal = { Service = "secretsmanager.amazonaws.com" },
        Action    = ["kms:GenerateDataKey", "kms:Decrypt", "kms:Encrypt"],
        Resource  = "*",
      },
    ],
  })
  tags = module.tags.tags
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "secrets_manager" {
  name          = "alias/${var.environment_name}/secretsmanager"
  target_key_id = aws_kms_key.secrets_manager.key_id
}

# ------------------------------------------------------------------------------
# SSH Key Pairs (per environment, via shared module)
# Generates RSA SSH key pairs for each environment. Public key is registered in AWS,
# private key is stored securely in Secrets Manager.
# ------------------------------------------------------------------------------
resource "tls_private_key" "ssh" {
  for_each  = toset(var.environments)
  algorithm = "RSA"
  rsa_bits  = 4096
}

module "ssh_key_pair" {
  source     = "../shared-modules/ssh-key-pair"
  for_each   = toset(var.environments)
  key_name   = "acmelabs-${each.key}-key"
  public_key = tls_private_key.ssh[each.key].public_key_openssh
  tags       = module.tags.tags
}

resource "null_resource" "write_private_keys_to_files" {
  for_each = toset([var.environment_name])
  triggers = {
    private_key_content_hash = sha256(tls_private_key.ssh[each.key].private_key_pem)
    run_on_every_apply       = timestamp()
  }
}

# ------------------------------------------------------------------------------
# Secrets Manager Containers (per environment, via shared module)
# These secrets are containers only; values are populated by other workflows.
# ------------------------------------------------------------------------------
module "ssh_private_keys_secret" {
  source           = "../shared-modules/secretsmanager-secret"
  for_each         = toset(var.environments)
  name             = "acmelabs-ssh-private-key-${each.key}"
  description      = "Metadata for the generated SSH private key for the ${each.key} environment."
  tags             = module.tags.tags
  kms_key_id       = aws_kms_key.secrets_manager.arn
  rotation_enabled = false
}

module "pagerduty_secret" {
  source           = "../shared-modules/secretsmanager-secret"
  for_each         = toset(var.environments)
  name             = "acmelabs-website-${each.key}-pagerduty-url"
  description      = "Stores the PagerDuty integration URL for the ${each.key} environment's SNS topic."
  tags             = module.tags.tags
  kms_key_id       = aws_kms_key.secrets_manager.arn
  rotation_enabled = false
}

module "wp_salts_secret" {
  source           = "../shared-modules/secretsmanager-secret"
  for_each         = toset(var.environments)
  name             = "acmelabs-website-${each.key}-wordpress-salts"
  description      = "Stores the authentication unique keys and salts for the ${each.key} WordPress environment."
  tags             = module.tags.tags
  kms_key_id       = aws_kms_key.secrets_manager.arn
  rotation_enabled = false
}

resource "aws_secretsmanager_secret_version" "ssh_private_keys_content" {
  for_each      = toset(var.environments)
  secret_id     = module.ssh_private_keys_secret[each.key].id
  secret_string = tls_private_key.ssh[each.key].private_key_pem
}

resource "null_resource" "cleanup_private_keys" {
  triggers = {
    all_private_keys_hash = sha256(jsonencode([for k in tls_private_key.ssh : k.private_key_pem]))
  }
  provisioner "local-exec" {
    command = "rm -rf ${path.module}/.tmp_keys || true"
    when    = destroy
  }
}

# ------------------------------------------------------------------------------
# Per-Environment CloudWatch Agent Config SSM Parameter (via shared module)
# Stores the CloudWatch Agent configuration as a string in SSM Parameter Store.
# ------------------------------------------------------------------------------
module "cloudwatch_agent_config" {
  source      = "../shared-modules/ssm-parameter"
  for_each    = toset(var.environments)
  name        = "/anvil/${each.key}/cloudwatch-agent-config"
  description = "CloudWatch Agent config for ${each.key} environment"
  tags        = module.tags.tags
  type        = "SecureString"
  kms_key_id  = aws_kms_key.secrets_manager.arn
  value       = file("${path.module}/../platform/config/cloudwatch-agent-config-${each.key}.json")
}

# ------------------------------------------------------------------------------
# Per-Environment ACM Certificate (Bootstrap Only, No Validation, via shared module)
# Creates a wildcard ACM certificate for each environment (for DNS validation).
# ------------------------------------------------------------------------------
module "bootstrap_public_cert" {
  source      = "../shared-modules/acm-certificate"
  for_each    = toset(var.environments)
  domain_name = "*.${each.key}.acmelabs.cloud"
  tags        = module.tags.tags
}
