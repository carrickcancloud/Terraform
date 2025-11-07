# ==============================================================================
# Project Anvil - Bootstrap Layer
# outputs.tf
#
# Outputs for the foundational AWS resources provisioned in the bootstrap layer,
# including IAM role ARNs, S3 buckets for Terraform state, DynamoDB tables for
# state locking, SSH key names, Secrets Manager secret ARNs, CloudWatch
# Agent configuration parameter names, and KMS Key ARNs for explicit permissions.
#
# Author: Carrick Bradley
# Last Updated: 2025-10-17 - Added KMS Key ARNs for explicit
# IAM permissions (no wildcards).
# ==============================================================================

# ------------------------------------------------------------------------------
# IAM Role ARNs (from shared module)
# ------------------------------------------------------------------------------
output "bootstrap_role_arn" {
  description = "ARN for the role used by the bootstrap workflow."
  value       = module.iam_roles.bootstrap_role_arn
}
output "packer_role_arn" {
  description = "ARN for the role used by the Packer AMI builder workflow."
  value       = module.iam_roles.packer_role_arn
}
output "ops_sync_role_arn" {
  description = "ARN for the role used by the ops-sync workflow."
  value       = module.iam_roles.ops_sync_role_arn
}
output "network_role_arn" {
  description = "ARN for the role used by the network workflow."
  value       = module.iam_roles.network_role_arn
}
output "platform_role_arn" { # Added platform role ARN, as discussed
  description = "ARN for the main platform workflow role."
  value       = module.iam_roles.platform_role_arn
}


# ------------------------------------------------------------------------------
# DynamoDB Tables for State Locking (per environment, from shared module)
# ------------------------------------------------------------------------------
output "terraform_state_lock_table" {
  description = "A map of the DynamoDB table names for Terraform state locking, keyed by environment."
  value       = { for env, mod in module.lock_table : env => mod.table_name }
}

# ------------------------------------------------------------------------------
# S3 Buckets for Vulnerability Reports (per environment)
# ------------------------------------------------------------------------------
output "vulnerability_reports_s3_buckets" {
  description = "A map of the S3 bucket names for storing vulnerability scan reports, keyed by environment."
  value       = { for env, bucket in aws_s3_bucket.vulnerability_reports : env => bucket.id }
}

# ------------------------------------------------------------------------------
# SSH Key Names (per environment, from shared module)
# ------------------------------------------------------------------------------
output "ssh_key_names" {
  description = "A map of the SSH key names created, keyed by environment."
  value       = { for env, mod in module.ssh_key_pair : env => mod.key_name }
}

# ------------------------------------------------------------------------------
# PagerDuty Secret ARNs (per environment, from shared module)
# ------------------------------------------------------------------------------
output "pagerduty_secret_arns" {
  description = "The ARNs of the PagerDuty secret containers, keyed by environment."
  value       = { for env, mod in module.pagerduty_secret : env => mod.arn }
}

# ------------------------------------------------------------------------------
# SSH Private Key Secret ARNs (per environment, from shared module)
# ------------------------------------------------------------------------------
output "ssh_private_keys_secret_arns" {
  description = "The ARNs of the generated SSH private keys stored in Secrets Manager, keyed by environment."
  value       = { for env, mod in module.ssh_private_keys_secret : env => mod.arn }
  sensitive   = true # Mark as sensitive as it contains credentials
}

# ------------------------------------------------------------------------------
# WP Salts Secret ARNs (per environment, from shared module)
# ------------------------------------------------------------------------------
output "wp_salts_secret_arns" {
  description = "The ARNs of the WordPress salts secret containers, keyed by environment."
  value       = { for env, mod in module.wp_salts_secret : env => mod.arn }
}

# ------------------------------------------------------------------------------
# CloudWatch Agent Config SSM Parameter Names (per environment, from shared module)
# ------------------------------------------------------------------------------
output "cloudwatch_agent_config_ssm_parameter_names" {
  description = "A map of the names of the CloudWatch Agent config SSM parameters, keyed by environment."
  value       = { for env, mod in module.cloudwatch_agent_config : env => mod.name }
}

# ------------------------------------------------------------------------------
# ACM Certificates ARNs (per environment, from shared module)
# ------------------------------------------------------------------------------
output "bootstrap_acm_certificate_arns" {
  description = "ARNs of the ACM certificates created for each environment."
  value       = { for env, mod in module.bootstrap_public_cert : env => mod.arn }
}

# ------------------------------------------------------------------------------
# ACM Certificate Validation Options (per environment, from shared module)
# ------------------------------------------------------------------------------
output "bootstrap_acm_certificate_validation_options" {
  description = "Domain validation options for the ACM certificate created by bootstrap, keyed by environment."
  value       = { for env, mod in module.bootstrap_public_cert : env => mod.domain_validation_options }
}

# ------------------------------------------------------------------------------
# KMS Key ARNs for explicit IAM permissions (to support 'no wildcards' rule)
# ------------------------------------------------------------------------------
output "vulnerability_reports_kms_key_arns" { # Note the 's' for plural, indicating a map
  description = "A map of ARNs for KMS keys used for S3 vulnerability reports encryption, keyed by environment."
  value       = { for env in var.environments : env => aws_kms_key.vulnerability_reports[env].arn }
}

output "secrets_manager_kms_key_arn" {
  description = "ARN of the KMS key used for Secrets Manager secrets encryption."
  value       = aws_kms_key.secrets_manager.arn
}

output "terraform_lock_table_kms_key_arns" {
  description = "A map of ARNs for KMS keys used by DynamoDB Terraform lock tables, keyed by environment."
  value       = { for env, mod in module.lock_table : env => mod.kms_key_arn }
}

output "central_logs_kms_key_arn" {
  description = "ARN of the KMS key used for the central S3 logging bucket and its access logs."
  value       = module.central_logs.kms_key_arn
}
