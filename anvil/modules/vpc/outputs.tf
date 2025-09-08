# This file defines the outputs that this module makes available to the root module.

output "vpc_id" {
  description = "The ID of the created VPC."
  value       = aws_vpc.acmelabs-tf.id
}

output "public_subnet_ids" {
  description = "List of IDs for the created public subnets."
  value       = [for s in aws_subnet.public : s.id]
}

output "private_subnet_ids" {
  description = "List of IDs for the created private subnets."
  value       = [for s in aws_subnet.private : s.id]
}

output "db_subnet_ids" {
  description = "List of IDs for the created isolated database subnets."
  value       = [for s in aws_subnet.db : s.id]
}

output "igw_id" {
  description = "The ID of the created Internet Gateway."
  value       = aws_internet_gateway.acmelabs-tf.id
}

output "nat_gateway_ids" {
  description = "A map of the created NAT Gateway IDs, keyed by Availability Zone."
  value       = { for az, gw in aws_nat_gateway.nat : az => gw.id }
}
