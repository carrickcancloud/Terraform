# ==============================================================================
# Project Anvil - Shared Modules - SSH Key Pair
# outputs.tf
#
# This module outputs the key name and ARN of the SSH key pair.
# It is used as part of the bootstrap infrastructure layer.
#
# Author: Carrick Bradley
# Last Updated: 2025-10-01
# ==============================================================================

output "key_name" {
  value = aws_key_pair.this.key_name
}
output "arn" {
  value = aws_key_pair.this.arn
}
