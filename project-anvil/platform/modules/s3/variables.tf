# ==============================================================================
# Project Anvil - Platform Layer
# modules/s3/variables.tf
#
# Input variables for the shared S3 bucket module.
#
# Author: Carrick Bradley
# Last Updated: 2025-09-24
# ==============================================================================

variable "bucket_name" {
  description = "The globally unique name for the S3 bucket."
  type        = string
}

variable "tags" {
  description = "A map of tags to apply to the bucket."
  type        = map(string)
  default     = {}
}
