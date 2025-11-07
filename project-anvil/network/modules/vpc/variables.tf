# ==============================================================================
# Project Anvil - Network Layer
# modules/vpc/variables.tf
#
# Input variables for the VPC module. These define naming, CIDR blocks,
# subnet configuration, and Availability Zones for a highly available network.
#
# Author: Carrick Bradley
# Last Updated: 2025-09-24
# ==============================================================================

# ------------------------------------------------------------------------------
# Naming Variables
# ------------------------------------------------------------------------------

variable "vpc_name" {
  description = "The value for the Name tag of the VPC."
  type        = string
}

variable "subnet_name" {
  description = "The base name for the subnets (e.g., 'acmelabs-dev-subnet')."
  type        = string
}

variable "igw_name" {
  description = "The value for the Name tag of the Internet Gateway."
  type        = string
}

variable "route_table_name" {
  description = "The base name for the route tables."
  type        = string
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

# ------------------------------------------------------------------------------
# Tags Variable
# ------------------------------------------------------------------------------

variable "tags" {
  description = "A map of tags to apply to all resources."
  type        = map(string)
  default     = {}
}