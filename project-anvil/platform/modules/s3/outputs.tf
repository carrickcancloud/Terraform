# ==============================================================================
# Project Anvil - Platform Layer
# modules/s3/outputs.tf
#
# Outputs for the shared S3 bucket module.
#
# Author: Carrick Bradley
# Last Updated: 2025-09-24
# ==============================================================================

output "bucket_name" {
  description = "The name of the created S3 bucket."
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "The ARN of the created S3 bucket."
  value       = aws_s3_bucket.this.arn
}

output "bucket_region" {
  description = "The AWS region where the S3 bucket was created."
  value       = aws_s3_bucket.this.region
}
