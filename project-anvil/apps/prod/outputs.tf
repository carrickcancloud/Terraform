# ==============================================================================
# Project Anvil - Application Layer (Dev Environment)
# outputs.tf
#
# Outputs for the dev application layer. These expose key application endpoints,
# IDs, and names that might be useful for monitoring, further configuration,
# or for connecting other systems.
#
# Author: Carrick Bradley
# Last Updated: 2025-09-24
# ==============================================================================

# ------------------------------------------------------------------------------
# Networking Outputs
# ------------------------------------------------------------------------------

output "web_tier_load_balancer_dns_name" {
  description = "The public DNS name of the web tier's Application Load Balancer."
  value       = module.web_tier.load_balancer_dns_name
}

output "app_tier_load_balancer_dns_name" {
  description = "The internal DNS name of the app tier's Application Load Balancer."
  value       = module.app_tier.load_balancer_dns_name
}

# ------------------------------------------------------------------------------
# Data Tier Outputs
# ------------------------------------------------------------------------------

output "database_endpoint" {
  description = "The connection endpoint for the database instance."
  value       = module.rds[0].db_instance_endpoint
}

output "database_name" {
  description = "The name of the provisioned database."
  value       = module.rds[0].db_name
}

output "database_username" {
  description = "The username for the master database user."
  value       = module.rds[0].db_username
}

# ------------------------------------------------------------------------------
# Public Application URL Output
# ------------------------------------------------------------------------------

output "web_application_url" {
  description = "The primary public URL for the web application."
  value       = "https://${var.web_subdomain}.${var.environment_name}.${var.domain_name}"
}

# ------------------------------------------------------------------------------
# IAM Outputs
# ------------------------------------------------------------------------------

output "ec2_instance_profile_arn" {
  description = "The ARN of the IAM Instance Profile attached to application EC2 instances."
  value       = aws_iam_instance_profile.ec2_profile.arn
}

output "ec2_instance_role_arn" {
  description = "The ARN of the IAM Role assumed by application EC2 instances."
  value       = aws_iam_role.instance_role.arn
}
