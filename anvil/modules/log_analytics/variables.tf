# Declares the inputs for the OpenSearch Serverless Log Analytics module.

variable "name_prefix" {
  description = "A unique name prefix for all resources (e.g., 'acmelabs-dev')."
  type        = string
}

variable "collection_name" {
  description = "The name for the OpenSearch Serverless collection."
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC where the OpenSearch collection will be deployed (for network access policy)."
  type        = string
}

variable "private_subnet_ids" {
  description = "A list of private subnet IDs where VPC endpoints for OpenSearch might reside."
  type        = list(string)
  default     = [] # Default to empty for now
}

variable "vpc_endpoint_security_group_ids" {
  description = "A list of security group IDs to associate with the OpenSearch VPC endpoint."
  type        = list(string)
}

variable "common_tags" {
  description = "A map of common tags to apply to the resources."
  type        = map(string)
  default     = {}
}

variable "aws_region" {
  description = "The AWS region where the resources are being created."
  type        = string
}
