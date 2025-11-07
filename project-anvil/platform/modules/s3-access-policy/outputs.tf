# ==============================================================================
# Project Anvil - Platform Layer
# modules/s3_access_policy/outputs.tf
#
# Outputs for the S3 access policy module.
#
# Author: Carrick Bradley
# Last Updated: 2025-09-24
# ==============================================================================

output "arn" {
  description = "The ARN of the created IAM policy."
  value       = aws_iam_policy.this.arn
}
