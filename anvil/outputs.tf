# This file defines the outputs that will be displayed on the command line
# after a successful `terraform apply`.

# +-------------------------------------+
# |        Networking Outputs           |
# +-------------------------------------+

output "vpc_id" {
  description = "The ID of the deployed VPC."
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "List of IDs for the public subnets."
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "List of IDs for the private subnets."
  value       = module.vpc.private_subnet_ids
}

output "db_subnet_ids" {
  description = "List of IDs for the isolated database subnets."
  value       = module.vpc.db_subnet_ids
}

# +-------------------------------------+
# |       Load Balancer Outputs         |
# +-------------------------------------+

output "web_tier_load_balancer_dns_name" {
  description = "The public DNS name of the web tier's Application Load Balancer."
  value       = module.web_tier.load_balancer_dns_name
}

output "app_tier_load_balancer_dns_name" {
  description = "The internal DNS name of the app tier's Application Load Balancer."
  value       = module.app_tier.load_balancer_dns_name
}

# +-------------------------------------+
# |           Data Tier Outputs         |
# +-------------------------------------+

output "database_endpoint" {
  description = "The connection endpoint for the database instance."
  value       = local.database_config.endpoint
}

output "database_name" {
  description = "The name of the provisioned database."
  value       = local.database_config.name
}

# +-------------------------------------+
# |          Storage Outputs            |
# +-------------------------------------+

output "s3_bucket_name" {
  description = "The name of the S3 bucket created for logs and data."
  value       = module.s3.bucket_name
}

# +-------------------------------------+
# |           DNS Outputs               |
# +-------------------------------------+

output "web_application_url" {
  description = "The primary public URL for the web application."
  value       = "https://${var.web_subdomain}.${terraform.workspace}.${var.domain_name}"
}
