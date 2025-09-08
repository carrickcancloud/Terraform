# This file defines the outputs for the ACM Private CA module.

output "certificate_authority_arn" {
  description = "The ARN of the newly created private Certificate Authority."
  value       = aws_acmpca_certificate_authority.this.arn
}
