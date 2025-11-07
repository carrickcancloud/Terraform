# ==============================================================================
# Project Anvil - Shared Modules - IAM Roles
# variables.tf
#
# Input variables for the IAM roles shared module. These control which
# environments are provisioned and the AWS region for all resources.
#
# Author: Carrick Bradley
# Last Updated: 2025-10-17 (for platform role policy refinement,
# added domain_name, and KMS key ARNs for explicit permissions)
# ==============================================================================

variable "aws_region" {
  description = "The AWS region where IAM resources will be created."
  type        = string
}

variable "github_org" {
  description = "GitHub organization or username."
  type        = string
}

variable "github_repo" {
  description = "The name of the GitHub repository for OIDC trust."
  type        = string
}

variable "project_name" {
  description = "Root project name (e.g., 'acmelabs-website')."
  type        = string
}

variable "oidc_thumbprint" {
  description = "OIDC thumbprint for GitHub Actions. Can be retrieved from the AWS IAM console."
  type        = string
}

variable "environments" {
  description = "A list of environments (e.g., 'dev', 'qa', 'uat, 'prod') for which IAM roles/policies might need environment-specific configurations or ARN construction."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "A map of tags to assign to resources."
  type        = map(string)
  default     = {}
}

variable "environment_name" {
  description = "The environment (e.g., dev, qa, uat, prod) this role is for."
  type        = string
}

variable "route53_zone_id" {
  description = "The Route53 Hosted Zone ID for DNS permissions."
  type        = string
}

# This variable was added to support ACM ARN patterns in locals.
variable "domain_name" {
  description = "The primary domain name of the hosted zone in Route 53. Used for ACM ARN patterns."
  type        = string
}

# ------------------------------------------------------------------------------
# NEW: KMS Key ARNs (for explicit IAM permissions - no wildcards)
# These are passed from the bootstrap layer to allow fine-grained KMS policies.
# ------------------------------------------------------------------------------
# Map of ARNs for KMS keys used for S3 vulnerability reports encryption, keyed by environment.
variable "vulnerability_reports_kms_key_arns" {
  description = "Map of ARNs for KMS keys used for S3 vulnerability reports encryption (from bootstrap layer), keyed by environment."
  type        = map(string)
  default     = {} # Provide an empty map default for initial runs
}

# ARN for the KMS key used for Secrets Manager secrets encryption.
variable "secrets_manager_kms_key_arn" {
  description = "ARN of the KMS key used for Secrets Manager secrets encryption (from bootstrap layer)."
  type        = string
  default     = "" # Provide a default for initial runs
}

# Map of ARNs for KMS keys used by DynamoDB Terraform lock tables, keyed by environment.
variable "terraform_lock_table_kms_key_arns" {
  description = "Map of ARNs for KMS keys used by DynamoDB Terraform lock tables (from bootstrap layer), keyed by environment."
  type        = map(string)
  default     = {} # Provide an empty map default
}

# ARN for the KMS key used for the central S3 logging bucket and its access logs.
variable "central_logs_kms_key_arn" {
  description = "ARN of the KMS key used for the central S3 logging bucket and its access logs (from bootstrap layer)."
  type        = string
  default     = "" # Provide a default for initial runs
}
