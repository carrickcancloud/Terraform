# ==============================================================================
# Project Anvil - Shared Modules - ACM Certificates
# variables.tf
#
# This module defines the input variables for the ACM certificate module.
#
# Author: Carrick Bradley
# Last Updated: 2025-10-05
# ==============================================================================

variable "domain_name" { type = string }

variable "validation_method" {
  type    = string
  default = "DNS"
}

variable "tags" { type = map(string) }

variable "prevent_destroy" {
  type    = bool
  default = true
}
