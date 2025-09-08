# This file declares the input variables that the VPC module accepts.
# As a best practice for child modules, no default values are provided,
# forcing the root module to be explicit about configuration.

# +-------------------------------------+
# |        VPC & Naming Variables       |
# +-------------------------------------+

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

# +-------------------------------------+
# |        Networking Variables         |
# +-------------------------------------+

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
