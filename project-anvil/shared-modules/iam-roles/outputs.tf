# ==============================================================================
# Project Anvil - Shared Modules - IAM Roles
# outputs.tf
#
# This module outputs the ARNs of the IAM roles and policies used by various
# GitHub Actions workflows. It is used as part of the bootstrap infrastructure
# layer.
#
# Author: Carrick Bradley
# Last Updated: 2025-10-17 - Updated to reflect granular platform policies.
# ==============================================================================

# --- Bootstrap Role Outputs ---
output "bootstrap_role_arn" {
  description = "ARN for the role used by the bootstrap workflow."
  value       = aws_iam_role.bootstrap.arn
}

# --- Network Role Outputs ---
output "network_role_arn" {
  description = "ARN for the role used by the network workflow."
  value       = aws_iam_role.network.arn
}

# --- Platform Role and Policy Outputs ---
output "platform_role_arn" {
  description = "ARN for the main platform workflow role."
  value       = aws_iam_role.platform.arn
}

output "platform_s3_policy_arn" {
  description = "ARN of the S3 management policy for the platform role."
  value       = aws_iam_policy.platform_s3.arn
}

output "platform_acm_policy_arn" {
  description = "ARN of the ACM & PCA management policy for the platform role."
  value       = aws_iam_policy.platform_acm.arn
}

output "platform_observability_policy_arn" {
  description = "ARN of the Observability (CloudWatch, Firehose, AOSS, SSM) policy for the platform role."
  value       = aws_iam_policy.platform_observability.arn
}

output "platform_cross_cutting_policy_arn" {
  description = "ARN of the Cross-Cutting (Tagging & KMS) policy for the platform role."
  value       = aws_iam_policy.platform_cross_cutting.arn
}

# --- Packer Role Outputs ---
output "packer_role_arn" {
  description = "ARN for the role used by the Packer AMI builder workflow."
  value       = aws_iam_role.packer.arn
}

# --- Ops Sync Role Outputs ---
output "ops_sync_role_arn" {
  description = "ARN for the role used by the ops-sync workflow."
  value       = aws_iam_role.ops_sync.arn
}
