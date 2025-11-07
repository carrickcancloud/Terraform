# ==============================================================================
# Project Anvil - shared-modules/dynamodb-lock-table
# outputs.tf
#
# This module outputs the DynamoDB table name and ARN for the Terraform state locking table.
# It is used as part of the bootstrap infrastructure layer.
#
# Author: Carrick Bradley
# Last Updated: 2025-10-17 - Added KMS key ARN output for
# explicit IAM permissions.
# ==============================================================================

output "table_name" {
  description = "The name of the DynamoDB table"
  value       = aws_dynamodb_table.this.name
}
output "table_arn" {
  description = "The ARN of the DynamoDB table"
  value       = aws_dynamodb_table.this.arn
}
output "kms_key_arn" {
  description = "The ARN of the KMS key used for encrypting the DynamoDB lock table."
  value       = aws_kms_key.dynamodb.arn
}
