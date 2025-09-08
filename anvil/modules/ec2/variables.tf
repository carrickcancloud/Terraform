# This file declares all the input variables for the reusable EC2 service module.

# +-------------------------------------+
# |        Core & Naming Variables      |
# +-------------------------------------+

variable "name_prefix" {
  description = "A unique name prefix for all resources in this service tier (e.g., 'acmelabs-dev-web')."
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC where the resources will be deployed."
  type        = string
}

variable "common_tags" {
  description = "A map of common tags to apply to all resources."
  type        = map(string)
  default     = {}
}

# +-------------------------------------+
# |      Instance & Fleet Variables     |
# +-------------------------------------+

variable "desired_capacity" {
  description = "The initial number of instances to run in the fleet."
  type        = number
  default     = 1
}

variable "min_size" {
  description = "The minimum number of instances for the auto scaling group."
  type        = number
  default     = 1
}

variable "max_size" {
  description = "The maximum number of instances for the auto scaling group."
  type        = number
  default     = 2
}

variable "instance_type" {
  description = "The EC2 instance type to use (e.g., 't3.small')."
  type        = string
}

variable "ami_id" {
  description = "The AMI ID for the instances."
  type        = string
}

variable "key_name" {
  description = "The name of the SSH key pair to attach to the instances."
  type        = string
}

variable "iam_instance_profile_name" {
  description = "The name of the IAM Instance Profile to attach to the instances."
  type        = string
}

variable "user_data_script_base64" {
  description = "Base64 encoded user data script to execute on instance launch."
  type        = string
  default     = "" # Default to an empty string if no script is provided.
}

# +-------------------------------------+
# |      Networking & Security          |
# +-------------------------------------+

variable "subnet_ids" {
  description = "A list of subnet IDs where the EC2 instances will be deployed."
  type        = list(string)
}

variable "security_group_ids" {
  description = "A list of security group IDs to attach to the EC2 instances."
  type        = list(string)
}

# +-------------------------------------+
# |    Load Balancer Configuration      |
# +-------------------------------------+

variable "create_load_balancer" {
  description = "If true, a load balancer and its related components will be created for this service."
  type        = bool
  default     = true
}

variable "lb_is_internal" {
  description = "If true, the load balancer will be internal. If false, it will be internet-facing."
  type        = bool
  default     = false
}

variable "lb_subnet_ids" {
  description = "A list of subnet IDs where the Load Balancer will be deployed."
  type        = list(string)
  default     = []
}

variable "lb_security_group_ids" {
  description = "A list of security group IDs to attach to the Load Balancer."
  type        = list(string)
  default     = []
}

variable "s3_bucket_for_logs" {
  description = "The name of the S3 bucket to store Load Balancer access logs."
  type        = string
  default     = ""
}

variable "lb_certificate_arn" {
  description = "The ARN of the SSL/TLS certificate for the LB's HTTPS listener."
  type        = string
  default     = null
}

variable "enable_https_listener" {
  description = "If true, the HTTPS listener will be created for the load balancer."
  type        = bool
  default     = true
}
