# ==============================================================================
# Project Anvil - Platform Layer
# modules/acm_public/variables.tf
#
# Input variables for the ACM Public Certificate module.
#
# Author: Carrick Bradley
# Last Updated: 2025-09-24
# ==============================================================================

variable "domain_name" {
  description = "The domain name to issue the certificate for (e.g., '*.dev.acmelabs.cloud')."
  type        = string
}

variable "zone_id" {
  description = "The ID of the Route 53 Hosted Zone for DNS validation."
  type        = string
}

variable "tags" {
  description = "A map of common tags to apply to the certificate."
  type        = map(string)
  default     = {}
}
