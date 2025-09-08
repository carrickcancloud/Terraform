# This file contains the core logic for creating an S3 bucket with
# best-practice settings for security and data protection.

# This data source dynamically looks up the correct AWS Account ID for the
# Elastic Load Balancing service in the current region. This avoids using a
# hardcoded ID, making the module more portable.
data "aws_elb_service_account" "this" {}

# Creates the S3 bucket.
resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name

  # Merges the default Name tag with any additional tags passed from the root module.
  tags = merge(
    {
      Name = var.bucket_name
    },
    var.tags,
  )
}

# Enables versioning on the S3 bucket to protect against accidental deletions.
resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enforces that the S3 bucket and its objects remain private.
resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enforces default server-side encryption for all objects stored in the bucket.
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Attaches a bucket policy that allows the Elastic Load Balancing service
# to write access logs to this bucket.
resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.lb_logs.json
}

# This data source generates the policy document required by AWS for
# ELB access logging.
data "aws_iam_policy_document" "lb_logs" {
  statement {
    principals {
      type        = "AWS"
      # This now uses the dynamic lookup instead of a hardcoded ID.
      identifiers = [data.aws_elb_service_account.this.arn]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.this.arn}/alb-logs/*"]
  }
}
