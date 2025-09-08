# This file contains the core logic for building a highly available and
# secure three-tier networking infrastructure.

# +-------------------------------------+
# |         VPC & Core Gateways         |
# +-------------------------------------+

# Creates the main Virtual Private Cloud container.
resource "aws_vpc" "acmelabs-tf" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = var.vpc_name
  }
}

# Creates the Internet Gateway to allow public subnets to reach the internet.
resource "aws_internet_gateway" "acmelabs-tf" {
  vpc_id = aws_vpc.acmelabs-tf.id

  tags = {
    Name = var.igw_name
  }
}

# Creates one NAT Gateway and its associated Elastic IP in each Availability Zone.
resource "aws_eip" "nat" {
  for_each = toset(var.availability_zones)
  domain   = "vpc"
  tags = {
    Name = "${var.vpc_name}-nat-eip-${each.key}"
  }
}

resource "aws_nat_gateway" "nat" {
  for_each      = toset(var.availability_zones)
  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = [for s in aws_subnet.public : s if s.availability_zone == each.key][0].id

  tags = {
    Name = "${var.vpc_name}-nat-gw-${each.key}"
  }

  depends_on = [aws_internet_gateway.acmelabs-tf]
}


# +-------------------------------------+
# |              Subnets                |
# +-------------------------------------+

# Creates a public subnet for each CIDR block in the provided list.
resource "aws_subnet" "public" {
  for_each                = toset(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.acmelabs-tf.id
  cidr_block              = each.value
  availability_zone       = var.availability_zones[index(var.public_subnet_cidrs, each.value)]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.subnet_name}-public-${index(var.public_subnet_cidrs, each.value) + 1}"
  }
}

# Creates a private subnet for each CIDR block in the provided list.
resource "aws_subnet" "private" {
  for_each          = toset(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.acmelabs-tf.id
  cidr_block        = each.value
  availability_zone = var.availability_zones[index(var.private_subnet_cidrs, each.value)]

  tags = {
    Name = "${var.subnet_name}-private-${index(var.private_subnet_cidrs, each.value) + 1}"
  }
}

# Creates an isolated database subnet for each CIDR block in the provided list.
resource "aws_subnet" "db" {
  for_each          = toset(var.db_subnet_cidrs)
  vpc_id            = aws_vpc.acmelabs-tf.id
  cidr_block        = each.value
  availability_zone = var.availability_zones[index(var.db_subnet_cidrs, each.value)]

  tags = {
    Name = "${var.subnet_name}-db-${index(var.db_subnet_cidrs, each.value) + 1}"
  }
}


# +-------------------------------------+
# |        Routing & Associations       |
# +-------------------------------------+

# Creates a single route table for all public subnets.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.acmelabs-tf.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.acmelabs-tf.id
  }

  tags = {
    Name = "${var.route_table_name}-public"
  }
}

# Creates one private route table for each Availability Zone.
resource "aws_route_table" "private" {
  for_each = toset(var.availability_zones)
  vpc_id   = aws_vpc.acmelabs-tf.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[each.key].id
  }

  tags = {
    Name = "${var.route_table_name}-private-${each.key}"
  }
}

# Associates the public route table with all created public subnets.
resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Associates each private route table with all private subnets in the same AZ.
resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  route_table_id = aws_route_table.private[each.value.availability_zone].id
  subnet_id      = each.value.id
}
