# ==============================================================================
# Project Anvil - Network Layer
# modules/route53/outputs.tf
#
# Outputs for the Route 53 DNS module.
#
# Author: Carrick Bradley
# Last Updated: 2025-09-24
# ==============================================================================

output "record_fqdns" {
  description = "A map of the fully-qualified domain names for the created records."
  value       = { for key, record in aws_route53_record.this : key => record.fqdn }
}
