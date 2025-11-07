# ==============================================================================
# Project Anvil - Shared Modules - ACM Certificates
# outputs.tf
#
# This module outputs the ARN and domain validation options of the ACM certificate.
# It is used as part of the bootstrap infrastructure layer.
#
# Author: Carrick Bradley
# Last Updated: 2025-10-01
# ==============================================================================

output "arn" {
  value = aws_acm_certificate.this.arn
}
output "domain_validation_options" {
  value = aws_acm_certificate.this.domain_validation_options
}
