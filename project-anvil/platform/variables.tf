# ==============================================================================
# Project Anvil - Platform Layer
# variables.tf
#
# Input variables for the platform layer. Defines shared naming, networking,
# logging, monitoring, and certificate parameters.
#
# Author: Carrick Bradley
# Last Updated: 2025-10-17 - Removed unnecessary variables as they are sourced
# from remote state or internally created.
# ==============================================================================

# ------------------------------------------------------------------------------
# Project & Naming Variables
# ------------------------------------------------------------------------------

variable "project_name" {
  description = "The base name for the project (e.g., 'acmelabs-website')."
  type        = string
}

variable "environment_name" {
  description = "The explicit name of the environment this platform layer is for (e.g., 'dev', 'qa', 'prod')."
  type        = string
}

variable "aws_region" {
  description = "The AWS region where platform resources will be created."
  type        = string
  default     = "us-east-1"
}

variable "build_timestamp" {
  description = "The timestamp of the build, injected by the CI/CD pipeline."
  type        = string
}

variable "managedby" {
  description = "The ManagedBy tag value for resource tagging."
  type        = string
}

variable "owner" {
  description = "The Owner tag value for resource tagging."
  type        = string
}

variable "domain_name" {
  description = "The primary domain name of the hosted zone in Route 53."
  type        = string
}

variable "route53_zone_id" {
  description = "The ID of the Route 53 hosted zone for DNS records."
  type        = string
}

variable "vpc_endpoint_security_group_ids" {
  description = "A list of security group IDs to associate with VPC endpoints for shared services."
  type        = list(string)
  default     = []
}

# ------------------------------------------------------------------------------
# Log/Monitoring Configuration
# ------------------------------------------------------------------------------

variable "log_group_name" {
  description = "The name of the CloudWatch Log Group to capture logs from. This will be used in the naming convention for Firehose streams."
  type        = string
  default     = "/aws/application/${var.environment_name}/web"
}

# ------------------------------------------------------------------------------
# ACM Private CA Configuration
# ------------------------------------------------------------------------------

variable "organization_name" {
  description = "The legal name of your organization for the CA's subject."
  type        = string
  default     = "AcmeLabs Inc." # Default from original module
}

variable "ca_validity_period_years" {
  description = "The number of years the Certificate Authority's own certificate will be valid."
  type        = number
  default     = 10 # Default from original module
}

# ------------------------------------------------------------------------------
# CloudWatch Dashboard Configuration
# ------------------------------------------------------------------------------

variable "dashboard_body_overview" {
  description = "The JSON body definition for the main CloudWatch dashboard."
  type        = string
  default     = "{}" # Default to empty JSON object
}
