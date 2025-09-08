# This file declares all input variables for the root module.

# +-------------------------------------+
# |      Project & Naming Variables     |
# +-------------------------------------+

variable "project_name" {
  description = "The base name for the project (e.g., 'acmelabs-website')."
  type        = string
  default     = "acmelabs-website"
}

variable "cms_name" {
  description = "The name of the CMS application to deploy (e.g., 'wordpress')."
  type        = string
  default     = "wordpress"
}

variable "cms_version" {
  description = "The version of the CMS application, discovered by the CI/CD pipeline."
  type        = string
}

variable "build_timestamp" {
  description = "The timestamp of the build, injected by the CI/CD pipeline."
  type        = string
}

variable "aws_region" {
  description = "The AWS region where resources will be created."
  type        = string
  default     = "us-east-1"
}

# +-------------------------------------+
# |     Pluggable Service Providers     |
# +-------------------------------------+

variable "database_provider" {
  description = "The database provider to use for the data tier."
  type        = string
  default     = "aws_rds"
}

variable "monitoring_provider" {
  description = "The dashboarding and metrics provider to use."
  type        = string
  default     = "aws_cloudwatch"
}

variable "alerting_provider" {
  description = "The destination service for all alerts."
  type        = string
  default     = "pagerduty"
}

variable "logging_provider" {
  description = "The log archiving and analytics provider to use."
  type        = string
  default     = "aws_s3_firehose"
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

# +-------------------------------------+
# |      Core Infrastructure Inputs     |
# +-------------------------------------+

variable "availability_zones" {
  description = "A list of Availability Zones that defines the network topology."
  type        = list(string)
}

variable "key_name" {
  description = "The name of the SSH key pair to use for the EC2 instances."
  type        = string
}

variable "domain_name" {
  description = "The primary domain name of the hosted zone in Route 53."
  type        = string
  default     = "acmelabs.cloud"
}

variable "web_subdomain" {
  description = "The subdomain to use for the web application URL (e.g., 'www')."
  type        = string
  default     = "www"
}

variable "ami_version" {
  description = "The Git commit hash or version tag for the AMIs to deploy."
  type        = string
}

# +-------------------------------------+
# |         Application Fleet           |
# +-------------------------------------+

variable "web_min_size" {
  description = "The minimum number of web server instances."
  type        = number
}
variable "web_max_size" {
  description = "The maximum number of web server instances."
  type        = number
}
variable "web_desired_capacity" {
  description = "The desired number of web server instances to start with."
  type        = number
}

variable "app_min_size" {
  description = "The minimum number of application server instances."
  type        = number
}
variable "app_max_size" {
  description = "The maximum number of application server instances."
  type        = number
}
variable "app_desired_capacity" {
  description = "The desired number of application server instances to start with."
  type        = number
}

variable "db_multi_az" {
  description = "Set to true to deploy the RDS database in a Multi-AZ configuration."
  type        = bool
  default     = true
}
