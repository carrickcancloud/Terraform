# ==============================================================================
# Project Anvil - Shared Modules - Secrets Manager Secret
# outputs.tf
#
# This module outputs the ARN and ID of the Secrets Manager secret.
# It is used as part of the bootstrap infrastructure layer.
#
# Author: Carrick Bradley
# Last Updated: 2025-10-01
# ==============================================================================

output "arn" {
  value = aws_secretsmanager_secret.this.arn
}
output "id" {
  value = aws_secretsmanager_secret.this.id
}
