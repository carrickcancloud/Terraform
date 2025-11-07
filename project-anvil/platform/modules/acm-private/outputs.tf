# ==============================================================================
# Project Anvil - Platform Layer
# modules/acm_private/outputs.tf
#
# Outputs for the ACM Private CA module.
#
# Author: Carrick Bradley
# Last Updated: 2025-09-24
# ==============================================================================

output "certificate_authority_arn" {
  description = "The ARN of the newly created private Certificate Authority."
  value       = aws_acmpca_certificate_authority.this.arn
}
