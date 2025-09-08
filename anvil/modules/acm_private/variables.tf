# This file declares the input variables for the ACM Private CA module.

variable "organization_name" {
  description = "The legal name of your organization for the CA's subject."
  type        = string
}

variable "common_name" {
  description = "The common name for the Certificate Authority (e.g., internal.acmelabs.cloud)."
  type        = string
}

variable "ca_validity_period_years" {
  description = "The number of years the Certificate Authority's own certificate will be valid."
  type        = number
  default     = 10
}

variable "crl_s3_bucket_name" {
  description = "The name of the S3 bucket to store the Certificate Revocation List (CRL)."
  type        = string
}

variable "common_tags" {
  description = "A map of common tags to apply to all resources."
  type        = map(string)
  default     = {}
}
