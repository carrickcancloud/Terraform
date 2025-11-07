# ==============================================================================
# Project Anvil - Application Layer (Dev Environment)
# variables.tf
#
# Input variables for the dev application layer. These define names,
# environment-specific scaling parameters, and provider choices.
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
  description = "The explicit name of the environment this application layer is for (e.g., 'dev', 'qa', 'prod')."
  type        = string
}

variable "aws_region" {
  description = "The AWS region where application resources will be created."
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

variable "cms_name" {
  description = "The name of the CMS application to deploy (e.g., 'wordpress')."
  type        = string
}

variable "cms_version" {
  description = "The version of the CMS application, discovered by the CI/CD pipeline."
  type        = string
}

variable "ami_version" {
  description = "The AMI version to deploy (e.g., the Git commit hash like '7a4a2ae')."
  type        = string
}

variable "domain_name" {
  description = "The primary domain name of the hosted zone in Route 53."
  type        = string
}

variable "web_subdomain" {
  description = "The subdomain to use for the web application URL (e.g., 'www')."
  type        = string
  default     = "www"
}

# ------------------------------------------------------------------------------
# Application Scaling Inputs (environment-specific from .tfvars)
# ------------------------------------------------------------------------------

variable "availability_zones" {
  description = "A list of Availability Zones that defines the application topology."
  type        = list(string)
}

variable "web_min_size" {
  description = "The minimum number of instances for the web tier auto scaling group."
  type        = number
}

variable "web_max_size" {
  description = "The maximum number of instances for the web tier auto scaling group."
  type        = number
}

variable "web_desired_capacity" {
  description = "The desired number of instances for the web tier auto scaling group."
  type        = number
}

variable "app_min_size" {
  description = "The minimum number of instances for the app tier auto scaling group."
  type        = number
}

variable "app_max_size" {
  description = "The maximum number of instances for the app tier auto scaling group."
  type        = number
}

variable "app_desired_capacity" {
  description = "The desired number of instances for the app tier auto scaling group."
  type        = number
}

variable "web_instance_type" {
  description = "The EC2 instance type to use for the web tier."
  type        = string
}

variable "app_instance_type" {
  description = "The EC2 instance type to use for the app tier."
  type        = string
}

variable "db_instance_class" {
  description = "The instance class for the RDS instance."
  type        = string
}

variable "key_name" {
  description = "The name of the SSH key pair to use for the EC2 instances."
  type        = string
}

# ------------------------------------------------------------------------------
# Pluggable Service Providers (from project-level main.tf variables)
# These allow conditional creation of resources based on chosen providers.
# ------------------------------------------------------------------------------

variable "monitoring_provider" {
  description = "The dashboarding and metrics provider to use."
  type        = string
  default     = "aws_cloudwatch"
}

variable "logging_provider" {
  description = "The log archiving and analytics provider to use."
  type        = string
  default     = "aws_s3_firehose"
}

variable "database_provider" {
  description = "The database provider to use for the data tier."
  type        = string
  default     = "aws_rds"
}

variable "alerting_provider" {
  description = "The destination service for all alerts."
  type        = string
  default     = "pagerduty"
}

variable "apm_provider" {
  description = "The Application Performance Monitoring (APM) provider to use (e.g., 'aws_xray')."
  type        = string
  default     = "aws_xray"
}

variable "rum_provider" {
  description = "The Real User Monitoring (RUM) provider to use (e.g., 'aws_rum')."
  type        = string
  default     = "aws_rum"
}

# ------------------------------------------------------------------------------
# Database Configuration
# ------------------------------------------------------------------------------

variable "db_multi_az" {
  description = "Set to true to deploy the RDS database in a Multi-AZ configuration."
  type        = bool
  default     = true
}
