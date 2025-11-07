# ==============================================================================
# Project Anvil - Shared Modules - S3 Central Logs
# variables.tf
#
# Input variables for the central S3 logging bucket module.
#
# Author: Carrick Bradley
# Last Updated: 2025-10-05 - Added 'tags' variable for consistent tagging.
# ==============================================================================

variable "central_logs_access_logging_target_bucket_name" {
  description = "The name of a separate S3 bucket where access logs for this central logs bucket will be stored. Leave empty to disable access logging for this bucket."
  type        = string
  default     = ""
}

variable "tags" {
  description = "A map of tags to apply to all resources in this module."
  type        = map(string)
  default     = {}
}
