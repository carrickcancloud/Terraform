# ==============================================================================
# Project Anvil - Shared Modules - Secrets Manager Secret
# main.tf
#
# This module creates a Secrets Manager secret with optional description, tags,
# and lifecycle policy to prevent accidental deletion.
# It is used as part of the bootstrap infrastructure layer.
#
# Author: Carrick Bradley
# Last Updated: 2025-10-06 - Updated to use aws_secretsmanager_secret_rotation 
# resource (AWS Provider >= 4.26.0).
# ==============================================================================

resource "aws_secretsmanager_secret" "this" {
  name        = var.name
  description = var.description
  tags        = var.tags

  kms_key_id = var.kms_key_id != null ? var.kms_key_id : null

  lifecycle {
    prevent_destroy = true
  }
}

# CKV2_AWS_57: This resource configures automatic rotation for the secret.
# It will only be created if rotation is explicitly enabled and a Lambda ARN is provided.
# As per architectural decision (Option B), this will have count = 0 for SSH keys and WP salts.
resource "aws_secretsmanager_secret_rotation" "this" {
  # This resource is conditionally created based on rotation_enabled and rotation_lambda_arn.
  # If count is 0, the resource is not created.
  count = var.rotation_enabled && var.rotation_lambda_arn != null ? 1 : 0

  secret_id           = aws_secretsmanager_secret.this.id
  rotation_lambda_arn = var.rotation_lambda_arn
  rotation_rules {
    automatically_after_days = var.rotation_schedule_days
  }
}
