# ==============================================================================
# Project Anvil - Network Layer
# outputs.tf
#
# Outputs for the network layer. These are used by platform and application
# layers to connect resources to the correct VPC and subnets.
#
# Author: Carrick Bradley
# Last Updated: 2025-09-24
# ==============================================================================

# ------------------------------------------------------------------------------
# VPC and Subnet Outputs
# ------------------------------------------------------------------------------

output "vpc_id" {
  description = "The ID of the created VPC."
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "List of IDs for the created public subnets."
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "List of IDs for the created private subnets."
  value       = module.vpc.private_subnet_ids
}

output "db_subnet_ids" {
  description = "List of IDs for the isolated database subnets."
  value       = module.vpc.db_subnet_ids
}

output "igw_id" {
  description = "The ID of the created Internet Gateway."
  value       = module.vpc.igw_id
}

output "nat_gateway_ids" {
  description = "A map of the created NAT Gateway IDs, keyed by Availability Zone."
  value       = module.vpc.nat_gateway_ids
}

# ------------------------------------------------------------------------------
# Route 53 DNS Outputs
# ------------------------------------------------------------------------------

output "dns_record_fqdns" {
  description = "A map of the FQDNs for DNS records created by the network layer."
  value       = module.dns.record_fqdns
}
