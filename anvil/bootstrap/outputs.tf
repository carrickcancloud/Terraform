# This file contains output variables for the Terraform bootstrap module.

output "terraform_state_s3_buckets" {
  description = "A map of the S3 bucket names created for Terraform remote state, keyed by environment."
  value       = { for env, bucket in aws_s3_bucket.terraform_state : env => bucket.id }
}

output "terraform_state_lock_table" {
  description = "A map of the DynamoDB table names for Terraform state locking, keyed by environment."
  value       = { for env, table in aws_dynamodb_table.terraform_locks : env => table.name }
}

output "vulnerability_reports_s3_buckets" {
  description = "A map of the S3 bucket names for storing vulnerability scan reports, keyed by environment."
  value       = { for env, bucket in aws_s3_bucket.vulnerability_reports : env => bucket.id }
}

output "ssh_key_names" {
  description = "A map of the SSH key names created, keyed by environment."
  value       = { for env, key in aws_key_pair.environment_keys : env => key.key_name }
}

output "pagerduty_secret_arns" {
  description = "The ARNs of the PagerDuty secret containers."
  value       = { for env, secret in aws_secretsmanager_secret.pagerduty : env => secret.arn }
}

output "ssh_private_keys_pem" {
  description = "A map of the generated SSH private keys in PEM format. These should be stored securely."
  value       = { for env, key in tls_private_key.ssh : env => key.private_key_pem }
  sensitive   = true
}
