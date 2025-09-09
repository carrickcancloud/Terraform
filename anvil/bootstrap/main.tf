# This Terraform project is designed to be run once per AWS account to set up
# the foundational resources required by all other CI/CD pipelines.

provider "aws" {
  region = var.aws_region
}

# This bootstrap project uses a local backend because it is responsible for
# creating the remote backend itself.
terraform {
  backend "local" {}

  required_providers {
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# --- Per-Environment Terraform State Backends ---

resource "aws_s3_bucket" "terraform_state" {
  for_each = toset(var.environments)
  bucket   = "acmelabs-terraform-state-${each.key}"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  for_each = toset(var.environments)
  bucket   = aws_s3_bucket.terraform_state[each.key].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  for_each = toset(var.environments)
  bucket   = aws_s3_bucket.terraform_state[each.key].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  for_each = toset(var.environments)
  bucket   = aws_s3_bucket.terraform_state[each.key].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# --- Per-Environment Terraform State Lock Tables ---

resource "aws_dynamodb_table" "terraform_locks" {
  for_each = toset(var.environments) # Added for_each here

  name         = "acmelabs-terraform-lock-table-${each.key}" # Dynamic name for each environment
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  lifecycle {
    prevent_destroy = true
  }

  tags = { # Added tags for better organization
    Environment = each.key
    ManagedBy   = "Terraform-Bootstrap"
  }
}

# --- Per-Environment Vulnerability Report Buckets ---

resource "aws_s3_bucket" "vulnerability_reports" {
  for_each = toset(var.environments)
  bucket   = "acmelabs-vulnerability-reports-${each.key}"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "vulnerability_reports" {
  for_each = toset(var.environments)
  bucket   = aws_s3_bucket.vulnerability_reports[each.key].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "vulnerability_reports" {
  for_each = toset(var.environments)
  bucket   = aws_s3_bucket.vulnerability_reports[each.key].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "vulnerability_reports" {
  for_each = toset(var.environments)
  bucket   = aws_s3_bucket.vulnerability_reports[each.key].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# --- SSH Key Pairs ---

resource "tls_private_key" "ssh" {
  for_each  = toset(var.environments)
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "environment_keys" {
  for_each = toset(var.environments)

  key_name   = "acmelabs-${each.key}-key"
  public_key = tls_private_key.ssh[each.key].public_key_openssh
}

# --- Secrets Manager Containers ---
# This creates the empty secret "vaults". They will be populated by other
# processes (manual input for PagerDuty, Terraform for salts).

resource "aws_secretsmanager_secret" "pagerduty" {
  for_each = toset(var.environments)

  name        = "acmelabs-website-${each.key}-pagerduty-url"
  description = "Stores the PagerDuty integration URL for the ${each.key} environment's SNS topic."
  tags = {
    Environment = each.key
    ManagedBy   = "Terraform-Bootstrap"
  }
}

resource "aws_secretsmanager_secret" "wp_salts" {
  for_each = toset(var.environments)

  name        = "acmelabs-website-${each.key}-wordpress-salts"
  description = "Stores the authentication unique keys and salts for the ${each.key} WordPress environment."
  tags = {
    Environment = each.key
    ManagedBy   = "Terraform-Bootstrap"
  }
}
