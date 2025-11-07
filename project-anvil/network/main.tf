# ==============================================================================
# Project Anvil - Network Layer
# main.tf
#
# Entry point for the network layer. Provisions the VPC, subnets, NAT, and
# Route 53 DNS records required by all downstream layers (platform, apps).
#
# Author: Carrick Bradley
# Last Updated: 2025-09-24
# ==============================================================================

provider "aws" {
  region = var.aws_region
}

# ------------------------------------------------------------------------------
# Data source to retrieve the AWS Account ID for use in KMS key policies and other ARNs
# ------------------------------------------------------------------------------
data "aws_route53_zone" "main" {
  name = "${var.domain_name}."
}

# ------------------------------------------------------------------------------
# Tags Module
# (Provides a consistent set of tags for all resources)
# ------------------------------------------------------------------------------

module "tags" {
  source           = "../shared-modules/tags"
  project_name     = var.project_name
  environment_name = var.environment_name
  managedby        = var.managedby
  owner            = var.owner
  build_timestamp  = var.build_timestamp
}

# ------------------------------------------------------------------------------
# Local Values for Naming
# ------------------------------------------------------------------------------

locals {
  # Uses var.environment_name for explicit environment context.
  name_prefix = "${var.project_name}-${var.environment_name}"
}

# ------------------------------------------------------------------------------
# VPC Module
# (Provisions the core network infrastructure)
# ------------------------------------------------------------------------------

module "vpc" {
  source               = "./modules/vpc"
  vpc_name             = "${local.name_prefix}-vpc"
  subnet_name          = "${local.name_prefix}-subnet"
  igw_name             = "${local.name_prefix}-igw"
  route_table_name     = "${local.name_prefix}-rt"
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  db_subnet_cidrs      = var.db_subnet_cidrs
  availability_zones   = var.availability_zones
}

# ------------------------------------------------------------------------------
# Route 53 DNS Module
# (Manages shared DNS records for the environment's hosted zone)
# ------------------------------------------------------------------------------

module "dns" {
  source  = "./modules/route53"
  zone_id = data.aws_route53_zone.main.zone_id # This should be the ID of the shared Hosted Zone

  records = var.shared_dns_records
}
