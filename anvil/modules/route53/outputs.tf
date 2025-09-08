# Defines the outputs from this module.

output "record_fqdns" {
  description = "A map of the fully-qualified domain names for the created records."
  value       = { for key, record in aws_route53_record.this : key => record.fqdn }
}
