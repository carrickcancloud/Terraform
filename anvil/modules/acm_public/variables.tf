# This file declares the input variables for the ACM module.

variable "domain_name" {
  description = "The domain name to issue the certificate for."
  type        = string
}

variable "zone_id" {
  description = "The ID of the Route 53 Hosted Zone for DNS validation."
  type        = string
}

variable "common_tags" {
  description = "A map of common tags to apply to the certificate."
  type        = map(string)
  default     = {}
}
