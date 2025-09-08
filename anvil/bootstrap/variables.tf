# This file contains variables for configuring the AWS region and environments.

variable "aws_region" {
  description = "The AWS region where foundational resources will be created."
  type        = string
  default     = "us-east-1"
}

variable "environments" {
  description = "A list of environments to create prerequisites for."
  type        = list(string)
  default     = ["dev", "qa", "uat", "prod"]
}
