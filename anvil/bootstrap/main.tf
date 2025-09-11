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
    # Add the null provider for the null_resource for cleanup
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
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
  for_each = toset(var.environments)

  name         = "acmelabs-terraform-lock-table-${each.key}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  lifecycle {
    prevent_destroy = true
  }

  tags = {
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

  # Add this provisioner to write the private key to a file
  provisioner "local-exec" {
    # Ensure the directory exists
    command = "mkdir -p ${path.module}/.tmp_keys && echo \"${self.private_key_pem}\" > ${path.module}/.tmp_keys/acmelabs-${each.key}-key.pem && chmod 600 ${path.module}/.tmp_keys/acmelabs-${each.key}-key.pem"
    # This ensures the provisioner only runs when the key itself is created or changed
    when    = create
  }
}

resource "aws_key_pair" "environment_keys" {
  for_each = toset(var.environments)

  key_name   = "acmelabs-${each.key}-key"
  public_key = tls_private_key.ssh[each.key].public_key_openssh
}

# Add a null_resource to clean up the keys after they are uploaded as artifacts
# This makes the cleanup explicit within Terraform's lifecycle
resource "null_resource" "cleanup_private_keys" {
  # This resource only exists to trigger a local-exec that cleans up the private keys.
  # We make it depend on the aws_key_pair creation to ensure keys are generated before cleanup.
  # The actual deletion should happen after the GitHub Actions artifact upload, which is external
  # to this Terraform apply. The 'destroy' provisioner is for 'terraform destroy' operations.

  triggers = {
    # A change in any of the private keys will cause this null_resource to "change"
    # and thus trigger its create-time provisioners.
    # We use a hash to ensure it triggers only if key content changes, not just on any apply.
    all_private_keys_hash = sha256(jsonencode([for k in tls_private_key.ssh : k.private_key_pem]))
  }

  provisioner "local-exec" {
    # This command will execute after creation of this null_resource,
    # effectively after the main 'terraform apply' is done.
    # We clean up the temporary directory immediately.
    command = "rm -rf ${path.module}/.tmp_keys || true"
  }

  # For cleanup on 'terraform destroy'
  provisioner "local-exec" {
    command = "rm -rf ${path.module}/.tmp_keys || true"
    when    = destroy
  }
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
