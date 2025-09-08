# This file declares the input variables that the Route 53 module accepts.

variable "zone_id" {
  description = "The ID of the Hosted Zone where records will be created."
  type        = string
}

variable "records" {
  description = "A map of DNS records to create. Supports standard records and alias records."
  type        = any
  default     = {}
}
