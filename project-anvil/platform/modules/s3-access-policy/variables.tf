# ==============================================================================
# Project Anvil - Platform Layer
# modules/s3_access_policy/variables.tf
#
# Input variables for the S3 access policy module.
#
# Author: Carrick Bradley
# Last Updated: 2025-09-24
# ==============================================================================

variable "name_prefix" {
  description = "A unique name prefix for the policy (e.g., 'acmelabs-dev')."
  type        = string
}

variable "bucket_arn" {
  description = "The ARN of the S3 bucket this policy will grant access to."
  type        = string
}
