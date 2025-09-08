# This file defines the outputs that this module makes available to the root module.

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
