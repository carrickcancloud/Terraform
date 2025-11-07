# ==============================================================================
# Project Anvil - Platform Layer
# modules/s3/main.tf
#
# This module creates a secure, versioned S3 bucket for shared logs, data,
# and certificate revocation lists (CRL), with best-practice access controls.
#
# Author: Carrick Bradley
# Last Updated: 2025-09-24
# ==============================================================================

# ------------------------------------------------------------------------------
# Look up the ELB service account ARN for the current region (for ALB logs)
# ------------------------------------------------------------------------------

data "aws_elb_service_account" "this" {}

# ------------------------------------------------------------------------------
# S3 Bucket (shared logs/data/CRL)
# ------------------------------------------------------------------------------

resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name

  tags = merge(var.tags, {
    Name = var.bucket_name
  })
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ------------------------------------------------------------------------------
# S3 Bucket Policy (allows ALB access logs and ACM PCA CRL writes)
# ------------------------------------------------------------------------------

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.bucket_access.json
}

data "aws_iam_policy_document" "bucket_access" {
  statement {
    sid = "AllowElbAccessLogs"
    principals {
      type        = "AWS"
      identifiers = [data.aws_elb_service_account.this.arn]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.this.arn}/alb-logs/*"]
  }

  statement {
    sid    = "AllowACMPCAAccess"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["acm-pca.amazonaws.com"]
    }
    actions = [
      "s3:PutObject",
      "s3:GetBucketAcl",
      "s3:GetBucketLocation"
    ]
    resources = [
      aws_s3_bucket.this.arn,
      "${aws_s3_bucket.this.arn}/*"
    ]
  }
}
