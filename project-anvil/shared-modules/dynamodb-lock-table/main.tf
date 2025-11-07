# ==============================================================================
# Project Anvil - shared-modules/dynamodb-lock-table
# main.tf
#
# This module creates a DynamoDB table configured for Terraform state locking.
# It is used as part of the bootstrap infrastructure layer.
#
# Author: Carrick Bradley
# Last Updated: 2025-10-05 - Addressed KMS and DynamoDB encryption/recovery checkov findings
# ==============================================================================

data "aws_caller_identity" "current" {}

resource "aws_kms_key" "dynamodb" {
  description         = "KMS key for DynamoDB table encryption"
  enable_key_rotation = true
  tags                = var.tags
  lifecycle {
    prevent_destroy = true
  }

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "Enable IAM User Permissions",
        Effect    = "Allow",
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" },
        Action    = "kms:*",
        Resource  = "*",
      },
      {
        Sid       = "Allow DynamoDB Service to use KMS key",
        Effect    = "Allow",
        Principal = { Service = "dynamodb.amazonaws.com" },
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = "*",
      },
    ],
  })
}

resource "aws_dynamodb_table" "this" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.dynamodb.arn
  }

  point_in_time_recovery {
    enabled = true
  }

  lifecycle { prevent_destroy = true }
  tags = var.tags
}

resource "aws_kms_alias" "dynamodb" {
  name          = "alias/${var.table_name}/lock"
  target_key_id = aws_kms_key.dynamodb.key_id
}
