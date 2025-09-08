# This file defines the input variables for the S3 access policy module.

variable "name_prefix" {
  description = "A unique name prefix for the policy."
  type        = string
}

variable "bucket_arn" {
  description = "The ARN of the S3 bucket this policy will grant access to."
  type        = string
}
