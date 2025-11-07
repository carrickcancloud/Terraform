# ==============================================================================
# Project Anvil - shared-modules/s3-central-logs
# outputs.tf
#
# This module outputs the S3 bucket name and ARN for the central logging bucket,
# and its associated KMS key ARN.
# It is used as part of the bootstrap infrastructure layer.
#
# Author: Carrick Bradley
# Last Updated: 2025-10-17 - Added KMS key ARN output for
# explicit IAM permissions.
# ==============================================================================

output "central_logs_bucket_arn" {
  description = "The ARN of the central S3 logging bucket."
  value       = aws_s3_bucket.central_logs.arn
}

output "central_logs_bucket_name" {
  description = "The name of the central S3 logging bucket."
  value       = aws_s3_bucket.central_logs.id
}
output "kms_key_arn" {
  description = "The ARN of the KMS key used for encrypting the central S3 logging bucket."
  value       = aws_kms_key.central_logs.arn
}
