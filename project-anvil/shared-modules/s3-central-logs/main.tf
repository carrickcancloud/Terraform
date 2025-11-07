# ==============================================================================
# Project Anvil - shared-modules/s3-central-logs
# main.tf
#
# This module creates an S3 bucket configured for central logging,
# including versioning, encryption, and access policies.
# It is used as part of the bootstrap infrastructure layer.
#
# Author: Carrick Bradley
# Last Updated: 2025-10-05 - Updated to address aws-s3-enable-bucket-logging tfsec finding
# ==============================================================================

resource "aws_s3_bucket" "central_logs" {
  bucket = "acmelabs-central-logs"

  lifecycle {
    prevent_destroy = true
  }

  tags = merge(var.tags, {
    Name        = "acmelabs-central-logs"
    Environment = "all"
  })
}

# Add this block to enable versioning for the central_logs bucket
resource "aws_s3_bucket_versioning" "central_logs_versioning" {
  bucket = aws_s3_bucket.central_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_kms_key" "central_logs" {
  description         = "KMS key for central S3 logging bucket and its audit logs"
  enable_key_rotation = true
  tags = merge(var.tags, {
    Name        = "acmelabs-central-logs-kms-key"
    Environment = "all"
  })
}

resource "aws_kms_alias" "central_logs" {
  name          = "alias/central-logs-and-audit"
  target_key_id = aws_kms_key.central_logs.key_id
}

resource "aws_s3_bucket_public_access_block" "central_logs_public_access" {
  bucket                  = aws_s3_bucket.central_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "central_logs_encryption" {
  bucket = aws_s3_bucket.central_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.central_logs.arn
    }
  }
}

resource "aws_s3_bucket_logging" "central_logs_self_access_logs_access" {
  bucket        = aws_s3_bucket.central_logs_self_access_logs.id
  target_bucket = aws_s3_bucket.audit_access_logs.id
  target_prefix = "s3-access-logs/central-logs-self-access-logs-access/"
}

resource "aws_s3_bucket" "central_logs_self_access_logs" {
  bucket = "acmelabs-central-logs-self-access-logs"

  lifecycle {
    prevent_destroy = true
  }

  tags = merge(var.tags, {
    Name        = "acmelabs-central-logs-self-access-logs"
    Purpose     = "Access Logs for Central Logs Bucket"
    Environment = "all"
  })
}

resource "aws_s3_bucket_versioning" "central_logs_self_access_logs_versioning" {
  bucket = aws_s3_bucket.central_logs_self_access_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "central_logs_self_access_logs_public_access" {
  bucket                  = aws_s3_bucket.central_logs_self_access_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "central_logs_self_access_logs_encryption" {
  bucket = aws_s3_bucket.central_logs_self_access_logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.central_logs.arn
    }
  }
}

resource "aws_s3_bucket_logging" "central_logs_access" {
  bucket        = aws_s3_bucket.central_logs.id
  target_bucket = aws_s3_bucket.central_logs_self_access_logs.bucket
  target_prefix = "s3-access-logs/central-logs-bucket-access/"
}

resource "aws_s3_bucket" "audit_access_logs" {
  bucket = "acmelabs-audit-access-logs"

  lifecycle {
    prevent_destroy = true
  }

  tags = merge(var.tags, {
    Name        = "acmelabs-audit-access-logs"
    Purpose     = "Audit Access Logs for Central Logs Self Access Logs Bucket"
    Environment = "all"
  })
}

resource "aws_s3_bucket_public_access_block" "audit_access_logs_public_access" {
  bucket                  = aws_s3_bucket.audit_access_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "audit_access_logs_encryption" {
  bucket = aws_s3_bucket.audit_access_logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.central_logs.arn
    }
  }
}

resource "aws_s3_bucket_versioning" "audit_access_logs_versioning" {
  bucket = aws_s3_bucket.audit_access_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_logging" "audit_access_logs_logging" {
  bucket        = aws_s3_bucket.audit_access_logs.id
  target_bucket = aws_s3_bucket.audit_access_logs.id
  target_prefix = "s3-access-logs/audit-access-logs-access/"
}
