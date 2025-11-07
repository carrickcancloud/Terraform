# ==============================================================================
# Project Anvil - Platform Layer
# modules/log_analytics/variables.tf
#
# Input variables for the OpenSearch Serverless log analytics module.
#
# Author: Carrick Bradley
# Last Updated: 2025-09-24
# ==============================================================================

variable "name_prefix" {
  description = "A unique name prefix for all resources (e.g., 'acmelabs-dev')."
  type        = string
}

variable "collection_name" {
  description = "The name for the OpenSearch Serverless collection."
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC where the OpenSearch collection will be deployed."
  type        = string
}

variable "private_subnet_ids" {
  description = "A list of private subnet IDs where VPC endpoints for OpenSearch might reside."
  type        = list(string)
  default     = []
}

variable "vpc_endpoint_security_group_ids" {
  description = "A list of security group IDs to associate with the OpenSearch VPC endpoint."
  type        = list(string)
}

variable "tags" {
  description = "A map of tags to apply to all resources."
  type        = map(string)
  default     = {}
}

variable "aws_region" {
  description = "The AWS region where the resources are being created."
  type        = string
}
