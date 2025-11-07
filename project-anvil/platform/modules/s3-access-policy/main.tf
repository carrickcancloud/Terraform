# ==============================================================================
# Project Anvil - Platform Layer
# modules/s3_access_policy/main.tf
#
# This module creates an IAM policy that grants read/write access to a specific
# S3 bucket. Used by EC2 instance roles, Lambda, or other services that require
# access to the shared data/log bucket.
#
# Author: Carrick Bradley
# Last Updated: 2025-09-24
# ==============================================================================

resource "aws_iam_policy" "this" {
  name        = "${var.name_prefix}-s3-access-policy"
  description = "Grants read/write access to a specific S3 bucket."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "${var.bucket_arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = var.bucket_arn
      }
    ]
  })
}
