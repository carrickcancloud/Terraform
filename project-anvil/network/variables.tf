# ==============================================================================
# Project Anvil - Network Layer
# variables.tf
#
# Input variables for the network layer. Defines VPC CIDR, subnets, AZs,
# Route 53 zone, and project-wide tags.
#
# Author: Carrick Bradley
# Last Updated: 2025-09-24
# ==============================================================================

# ------------------------------------------------------------------------------
# Project & Naming Variables
# ------------------------------------------------------------------------------

variable "project_name" {
  description = "The base name for the project (e.g., 'acmelabs-website')."
  type        = string
}

variable "environment_name" {
  description = "The explicit name of the environment this network layer is for (e.g., 'dev', 'qa', 'prod')."
  type        = string
}

variable "aws_region" {
  description = "The AWS region where network resources will be created."
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

variable "tags" {
  description = "A map of tags to apply to all resources."
  type        = map(string)
  default     = {}
}

# ------------------------------------------------------------------------------
# Networking Variables
# ------------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "The main CIDR block for the VPC (e.g., '10.10.0.0/16')."
  type        = string
}

variable "public_subnet_cidrs" {
  description = "A list of CIDR blocks for the public subnets."
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "A list of CIDR blocks for the private subnets."
  type        = list(string)
}

variable "db_subnet_cidrs" {
  description = "A list of CIDR blocks for the isolated database subnets."
  type        = list(string)
  default     = []
}

variable "availability_zones" {
  description = "A list of Availability Zones to create the subnets in."
  type        = list(string)
}

variable "domain_name" {
  description = "The Route 53 domain name to use for DNS and ACM."
  type        = string
}

variable "shared_dns_records" {
  description = <<EOF
A map of shared DNS records to create in the network layer. Each record supports:
-   name: The record name (e.g., 'bastion', 'api').
-   type: The record type (e.g., 'A', 'CNAME').
-   ttl: (Optional) The TTL for the record.
-   records: (Optional) List of record values.
-   alias: (Optional) Object with keys:
    - name: Alias target DNS name.
    - zone_id: Alias target hosted zone ID.
    - evaluate_target_health: (Optional) Boolean.
EOF
  type        = any
  default     = {}
}
