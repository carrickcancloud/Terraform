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

# --- SSH Key Pairs ---\

resource "tls_private_key" "ssh" {
  for_each  = toset(var.environments)
  algorithm = "RSA"
  rsa_bits  = 4096

  # IMPORTANT: The local-exec for writing keys is now in 'null_resource.write_private_keys_to_files'
  # It should NOT be here with 'when = create' as that causes issues on subsequent runs.
}

resource "aws_key_pair" "environment_keys" {
  for_each = toset(var.environments)

  key_name   = "acmelabs-${each.key}-key"
  public_key = tls_private_key.ssh[each.key].public_key_openssh
}

# NEW: This null_resource ensures the private keys are reliably written to files.
# Its provisioner will run on every 'terraform apply' due to the timestamp trigger.
resource "null_resource" "write_private_keys_to_files" {
  for_each = toset(var.environments)

  triggers = {
    private_key_content_hash = sha256(tls_private_key.ssh[each.key].private_key_pem)
    run_on_every_apply       = timestamp()
  }

  provisioner "local-exec" {
    # This command writes the private key content to a file.
    # The sensitive value is passed directly to the shell, avoiding logging.
    # IMPORTANT: Ensure 'EOF' is on a line by itself and not indented.
    command = <<EOF
mkdir -p "${path.module}/.tmp_keys/"
echo "${tls_private_key.ssh[each.key].private_key_pem}" > "${path.module}/.tmp_keys/acmelabs-${each.key}-key.pem"
chmod 600 "${path.module}/.tmp_keys/acmelabs-${each.key}-key.pem"
EOF
  }
}

# The existing null_resource for cleanup is fine as is, running on destroy.
# Its 'triggers' are correct for detecting changes in keys.
resource "null_resource" "cleanup_private_keys" {
  triggers = {
    all_private_keys_hash = sha256(jsonencode([for k in tls_private_key.ssh : k.private_key_pem]))
  }

  # This provisioner should be the ONLY one that cleans up the temporary directory, and it runs ONLY on destroy.
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
  lifecycle {
    prevent_destroy = true
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
  lifecycle {
    prevent_destroy = true
  }
}
