# Declares the inputs for the RDS database module.

variable "name_prefix" {
  description = "A unique name prefix for all resources (e.g., 'acmelabs-dev-db')."
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC where the database will be deployed."
  type        = string
}

variable "db_subnet_ids" {
  description = "A list of private subnet IDs for the database subnet group."
  type        = list(string)
}

variable "db_instance_class" {
  description = "The instance class for the RDS instance (e.g., 'db.t3.micro')."
  type        = string
}

variable "db_name" {
  description = "The name of the initial database to create."
  type        = string
}

variable "db_username" {
  description = "The username for the master database user."
  type        = string
}

variable "vpc_security_group_ids" {
  description = "A list of security group IDs to attach to the database."
  type        = list(string)
}

variable "multi_az_deployment" {
  description = "If true, creates a Multi-AZ standby replica for high availability."
  type        = bool
  default     = false
}

variable "common_tags" {
  description = "A map of common tags to apply to all resources."
  type        = map(string)
  default     = {}
}
