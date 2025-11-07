# ==============================================================================
# Project Anvil - Shared Modules - Tags
# variables.tf
#
# Input variables for the central tags module. These control the standard
# tags applied to all resources in the project.
#
# Author: Carrick Bradley
# Last Updated: 2025-10-01
# ==============================================================================

variable "project_name" {
  description = "The base name for the project (e.g., 'acmelabs-website')."
  type        = string
}

variable "environment_name" {
  description = "The environment this layer is for (e.g., 'dev', 'qa', 'prod')."
  type        = string
}

variable "managedby" {
  description = "The entity managing the resources (default: 'Terraform')."
  type        = string
  default     = "Terraform"
}

variable "build_timestamp" {
  description = "The timestamp of the build, injected by the CI/CD pipeline."
  type        = string
}

variable "owner" {
  description = "The owner of the resources, typically a team or individual."
  type        = string
  default     = "AcmeLabsCloud_SRE"
}