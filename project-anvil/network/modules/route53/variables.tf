# ==============================================================================
# Project Anvil - Network Layer
# modules/route53/variables.tf
#
# Input variables for the Route 53 DNS module.
# Allows creation of flexible DNS records (including alias records).
#
# Author: Carrick Bradley
# Last Updated: 2025-09-24
# ==============================================================================

variable "zone_id" {
  description = "The ID of the Hosted Zone where records will be created."
  type        = string
}

variable "records" {
  description = <<EOF
A map of DNS records to create. Each record supports:
-  name: The record name (e.g., 'www', 'api').
-  type: The record type (e.g., 'A', 'CNAME').
-  ttl: (Optional) The TTL for the record.
-  records: (Optional) List of record values.
-  alias: (Optional) Object with keys:
    - name: Alias target DNS name.
    - zone_id: Alias target hosted zone ID.
    - evaluate_target_health: (Optional) Boolean.
EOF
  type        = any
  default     = {}
}
