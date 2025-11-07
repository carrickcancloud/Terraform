# ==============================================================================
# Project Anvil - Shared Modules - Secrets Manager Secret
# variables.tf
#
# This module defines the input variables for the Secrets Manager secret module.
#
# Author: Carrick Bradley
# Last Updated: 2025-10-06 - Added variables for secret rotation configuration.
# ==============================================================================

variable "name" { type = string }
variable "description" { type = string }
variable "tags" { type = map(string) }

variable "prevent_destroy" {
  type    = bool
  default = true
}

variable "kms_key_id" {
  description = "Optional: The ARN or ID of the KMS key to use for encrypting the secret. If not provided, AWS-managed key will be used."
  type        = string
  default     = null
}

variable "rotation_enabled" {
  description = "Set to true to enable automatic rotation for the secret. Requires rotation_lambda_arn to be provided by the calling module."
  type        = bool
  default     = false
}

variable "rotation_lambda_arn" {
  description = "The ARN of the Lambda function that will rotate the secret. Required if rotation_enabled is true."
  type        = string
  default     = null
}

variable "rotation_schedule_days" {
  description = "The number of days between secret rotations, used if rotation_enabled is true. Default is 30 days."
  type        = number
  default     = 30
}
