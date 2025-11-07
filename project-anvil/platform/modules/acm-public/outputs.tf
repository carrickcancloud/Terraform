# ==============================================================================
# Project Anvil - Platform Layer
# modules/acm_public/outputs.tf
#
# Outputs for the ACM Public Certificate module.
#
# Author: Carrick Bradley
# Last Updated: 2025-09-24
# ==============================================================================

# By default, just output the certificate ARN
output "certificate_arn" {
  description = "The ARN of the ACM certificate."
  value       = aws_acm_certificate.this.arn
}

output "certificate_arn" {
  description = "The ARN of the validated ACM certificate."
  value       = aws_acm_certificate_validation.this.certificate_arn
}
