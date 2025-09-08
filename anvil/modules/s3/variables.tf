# This file declares the input variables that the S3 module accepts.

variable "bucket_name" {
  description = "The globally unique name for the S3 bucket."
  type        = string
}

variable "tags" {
  description = "A map of tags to apply to the bucket."
  type        = map(string)
  default     = {}
}
