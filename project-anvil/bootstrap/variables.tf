# ==============================================================================
# Project Anvil - Bootstrap Layer
# variables.tf
#
# Input variables for the foundational bootstrap layer. These variables define
# configuration options such as AWS region, environments, project naming, and
# GitHub OIDC settings required for IAM role creation.
#
# Author: Carrick Bradley
# Last Updated: 2025-10-17 - Removed log_group_name variable as it's internally 
# derived in iam_roles module.
# ==============================================================================

# ------------------------------------------------------------------------------
# The AWS region where foundational resources will be created.
# ------------------------------------------------------------------------------
variable "aws_region" {
  description = "The AWS region where foundational resources (state buckets, lock tables, secrets) will be created."
  type        = string
  default     = "us-east-1"
}

# ------------------------------------------------------------------------------
# The list of environments to create foundational resources for.
# ------------------------------------------------------------------------------
variable "environments" {
  description = "A list of environments to create prerequisites for (e.g., dev, qa, uat, prod)."
  type        = list(string)
  default     = ["dev", "qa", "uat", "prod"]
}

# ------------------------------------------------------------------------------
# The explicit name of the environment this Terraform apply is targeting.
# Used for naming resources specific to a single environment.
# ------------------------------------------------------------------------------
variable "environment_name" {
  description = "The explicit name of the environment this Terraform apply is targeting (e.g., 'dev', 'qa', 'prod')."
  type        = string
}

# ------------------------------------------------------------------------------
# The base name for the project (used in tagging and naming).
# ------------------------------------------------------------------------------
variable "project_name" {
  description = "The base name for the project (e.g., 'acmelabs-website')."
  type        = string
}

# ------------------------------------------------------------------------------
# The timestamp of the build, injected by the CI/CD pipeline.
# ------------------------------------------------------------------------------
variable "build_timestamp" {
  description = "The timestamp of the build, injected by the CI/CD pipeline."
  type        = string
}

# ------------------------------------------------------------------------------
# The ManagedBy tag value for resource tagging.
# ------------------------------------------------------------------------------
variable "managedby" {
  description = "The ManagedBy tag value for resource tagging."
  type        = string
}

# ------------------------------------------------------------------------------
# The Owner tag value for resource tagging.
# ------------------------------------------------------------------------------
variable "owner" {
  description = "The Owner tag value for resource tagging."
  type        = string
}

# ------------------------------------------------------------------------------
# GitHub OIDC and repo info for IAM integration (used by shared-modules/iam-roles)
# ------------------------------------------------------------------------------
variable "github_org" {
  description = "Your GitHub organization or username for OIDC trust."
  type        = string
}

variable "github_repo" {
  description = "The name of the GitHub repository for OIDC trust."
  type        = string
}

variable "oidc_thumbprint" {
  description = "OIDC thumbprint for GitHub Actions. Can be retrieved from the AWS IAM console."
  type        = string
  default     = "ffffffffffffffffffffffffffffffffffffffff"
}

# ------------------------------------------------------------------------------
# The Route 53 domain name to use for DNS and ACM.
# ------------------------------------------------------------------------------
variable "domain_name" {
  description = "The Route 53 domain name to use for DNS and ACM."
  type        = string
}
