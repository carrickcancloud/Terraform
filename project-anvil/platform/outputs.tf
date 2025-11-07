# ==============================================================================
# Project Anvil - Platform Layer
# outputs.tf
#
# Outputs for the platform layer. These values are used by application layers
# (apps) to connect to shared services like S3, ACM, and notification endpoints.
# This file also exports ARNs of service roles created within the platform layer
# for use by upstream layers (e.g., bootstrap to grant PassRole permissions).
#
# Author: Carrick Bradley
# Last Updated: 2025-10-17 - Added outputs for Firehose and CloudWatch Logs
# service roles, and updated remote state reference.
# ==============================================================================

# ------------------------------------------------------------------------------
# Shared S3 Bucket Outputs
# ------------------------------------------------------------------------------

output "shared_s3_bucket_name" {
  description = "The name of the shared S3 bucket for logs and data."
  value       = module.s3.bucket_name
}

output "shared_s3_bucket_arn" {
  description = "The ARN of the shared S3 bucket for logs and data."
  value       = module.s3.bucket_arn
}

output "shared_s3_access_policy_arn" {
  description = "The ARN of the IAM policy granting access to the shared S3 bucket."
  value       = module.s3_access_policy.arn
}

# ------------------------------------------------------------------------------
# ACM Certificates Outputs
# ------------------------------------------------------------------------------

output "acm_public_certificate_arn" {
  description = "The ARN of the public ACM certificate for this environment."
  value       = module.acm_public.certificate_arn
}

output "acm_private_ca_arn" {
  description = "The ARN of the private CA for internal TLS."
  value       = module.acm_private.certificate_authority_arn
}

# ------------------------------------------------------------------------------
# Monitoring and Logging Outputs
# ------------------------------------------------------------------------------

output "cloudwatch_dashboard_name" {
  description = "The name of the shared CloudWatch dashboard."
  value       = module.cloudwatch_dashboard.dashboard_name
}

output "opensearch_collection_endpoint" {
  description = "The endpoint for the OpenSearch Serverless collection (if enabled)."
  value       = module.log_analytics.collection_endpoint
}

output "log_archiving_firehose_stream_arn" {
  description = "The ARN of the Kinesis Firehose delivery stream for log archiving."
  value       = module.log_archiving.firehose_stream_arn
}

output "cloudwatch_agent_config_ssm_param_name" {
  description = "The name of the SSM Parameter storing the CloudWatch Agent config."
  value       = aws_ssm_parameter.cloudwatch_agent_config_param.name
}

# ------------------------------------------------------------------------------
# IAM Role ARNs for Service Integrations (Newly added)
# These are roles created in this platform layer and are needed by
# upstream layers (e.g., bootstrap's iam-roles module for PassRole permissions).
# ------------------------------------------------------------------------------
output "firehose_s3_role_arn" {
  description = "The ARN of the IAM role assumed by Kinesis Firehose to write to S3."
  value       = aws_iam_role.firehose_s3_role.arn
}

output "logs_firehose_role_arn" {
  description = "The ARN of the IAM role assumed by CloudWatch Logs to put events to Kinesis Firehose."
  value       = aws_iam_role.logs_firehose_role.arn
}

# ------------------------------------------------------------------------------
# Secrets Outputs (Containers managed by Bootstrap, but exposed by Platform)
# These expose the ARNs of secret containers to other layers.
# ------------------------------------------------------------------------------

# This output relies on the 'bootstrap' layer having created the secret containers.
# It uses remote state to fetch the ARN from the bootstrap layer's outputs.
data "terraform_remote_state" "bootstrap" {
  backend = "s3"
  config = {
    # Dynamically construct the bucket name based on the environment
    bucket = "acmelabs-terraform-state-bootstrap-${var.environment_name}"
    key    = "bootstrap/terraform.tfstate"
    region = var.aws_region
  }
}

output "pagerduty_secret_arn" {
  description = "The ARN of the PagerDuty secret container for this environment."
  value       = data.terraform_remote_state.bootstrap.outputs.pagerduty_secret_arns[var.environment_name]
}

output "wp_salts_secret_arn" {
  description = "The ARN of the WordPress salts secret container for this environment."
  value       = data.terraform_remote_state.bootstrap.outputs.wp_salts_secret_arns[var.environment_name]
}

output "ssh_private_keys_secret_arn" {
  description = "The ARN of the SSH private key secret container for this environment."
  value       = data.terraform_remote_state.bootstrap.outputs.ssh_private_keys_secret_arns[var.environment_name]
  sensitive   = true
}
