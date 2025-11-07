# ==============================================================================
# Project Anvil - Network Layer
# modules/vpc/main.tf
#
# This module creates a highly available VPC with public, private, and database
# subnets across multiple Availability Zones, including Internet Gateway, NAT
# Gateways, and route tables. Outputs are used by platform and application layers.
#
# Author: Carrick Bradley
# Last Updated: 2025-09-24
# ==============================================================================

# ------------------------------------------------------------------------------
# VPC & Core Networking
# ------------------------------------------------------------------------------

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, { Name = var.vpc_name })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, { Name = var.igw_name })
}

# ------------------------------------------------------------------------------
# NAT Gateways and Elastic IPs (one per AZ for HA)
# ------------------------------------------------------------------------------

resource "aws_eip" "nat" {
  for_each = toset(var.availability_zones)
  domain   = "vpc"
  tags = merge(var.tags, {
    Name = "${var.vpc_name}-nat-eip-${each.key}"
  })
}

resource "aws_nat_gateway" "nat" {
  for_each      = toset(var.availability_zones)
  allocation_id = aws_eip.nat[each.key].id
  tags = merge(var.tags, {
    Name = "${var.vpc_name}-nat-gw-${each.key}"
  })
  # Find the public subnet in this AZ
  subnet_id = [
    for idx, subnet in aws_subnet.public : subnet.id
    if subnet.availability_zone == each.key
  ][0]

  depends_on = [aws_internet_gateway.main]
}

# ------------------------------------------------------------------------------
# Subnets (public, private, db) across all AZs
# ------------------------------------------------------------------------------

resource "aws_subnet" "public" {
  for_each                = { for idx, cidr in var.public_subnet_cidrs : idx => cidr }
  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value
  availability_zone       = var.availability_zones[each.key]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.subnet_name}-public-${each.key + 1}"
  })
}

resource "aws_subnet" "private" {
  for_each = { for idx, cidr in var.private_subnet_cidrs : idx => cidr }
  vpc_id   = aws_vpc.main.id
  tags = merge(var.tags, {
    Name = "${var.subnet_name}-private-${each.key + 1}"
  })
  cidr_block        = each.value
  availability_zone = var.availability_zones[each.key]
}

resource "aws_subnet" "db" {
  for_each   = { for idx, cidr in var.db_subnet_cidrs : idx => cidr }
  vpc_id     = aws_vpc.main.id
  cidr_block = each.value

  tags = merge(var.tags, {
    Name = "${var.subnet_name}-db-${each.key + 1}"
  })
  availability_zone = var.availability_zones[each.key]
}

# ------------------------------------------------------------------------------
# Route Tables and Associations
# ------------------------------------------------------------------------------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.tags, {
    Name = "${var.route_table_name}-public"
  })
}

resource "aws_route_table" "private" {
  for_each = toset(var.availability_zones)
  vpc_id   = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[each.key].id
  }

  tags = merge(var.tags, {
    Name = "${var.route_table_name}-private-${each.key}"
  })
}

# Associates the public route table with all created public subnets.
resource "aws_route_table_association" "public" {
  for_each       = { for idx, cidr in var.public_subnet_cidrs : idx => cidr }
  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public.id
}

# Associates each private route table with all private subnets in the same AZ.
resource "aws_route_table_association" "private" {
  for_each       = { for idx, cidr in var.private_subnet_cidrs : idx => cidr }
  route_table_id = aws_route_table.private[var.availability_zones[each.key]].id
  subnet_id      = aws_subnet.private[each.key].id
}
