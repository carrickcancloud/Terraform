# ==============================================================================
# Project Anvil - Shared Modules - SSM Parameter
# variables.tf
#
# This module defines the input variables for the SSM parameter module.
#
# Author: Carrick Bradley
# Last Updated: 2025-10-06 - Added kms_key_id variable for CMK encryption.
# ==============================================================================

variable "name" { type = string }
variable "description" { type = string }
variable "value" { type = string }

variable "type" {
  type    = string
  default = "String"
}

variable "overwrite" {
  type    = bool
  default = true
}

variable "tags" { type = map(string) }

variable "kms_key_id" {
  description = "The KMS key ID to use for encrypting the parameter. Required if type is SecureString."
  type        = string
  default     = null
}
