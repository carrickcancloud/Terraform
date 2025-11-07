# ==============================================================================
# Project Anvil - Application Layer (Dev Environment)
# main.tf
#
# This file defines the entire application infrastructure for the dev environment.
# It provisions compute (web/app tiers), database, CDN, WAF, and configures
# application-specific IAM roles and security groups. It relies on outputs
# from the network and platform layers.
#
# Author: Carrick Bradley
# Last Updated: 2025-09-24
# ==============================================================================

provider "aws" {
  region = var.aws_region
}

terraform {
  # Backend config is provided dynamically via -backend-config at init.
  backend "s3" {}

  required_providers {
    # Include providers that are directly used by resources in this file,
    # or implicitly by modules called from this file.
    random = {
      source  = "hashicorp/random"
      version = "~> 3.4"
    }
  }
}

# ------------------------------------------------------------------------------
# Global Values: Tagging
# ------------------------------------------------------------------------------
module "tags" {
  source           = "../../shared-modules/tags"
  project_name     = var.project_name
  environment_name = var.environment_name
  managedby        = var.managedby
  owner            = var.owner
  build_timestamp  = var.build_timestamp
}

# ------------------------------------------------------------------------------
# Local Values: Naming, Tagging, and IP Management
# ------------------------------------------------------------------------------

locals {
  # --- Naming & Tagging ---
  # Uses var.environment_name instead of terraform.workspace for environment context.
  name_prefix = "${var.project_name}-${var.environment_name}"

  # --- Database Configuration (Pluggable Interface) ---
  database_config = {
    endpoint = var.database_provider == "aws_rds" ? module.rds[0].db_instance_endpoint : null
    port     = var.database_provider == "aws_rds" ? module.rds[0].db_instance_port : null
    name     = var.database_provider == "aws_rds" ? module.rds[0].db_name : null
    username = var.database_provider == "aws_rds" ? module.rds[0].db_username : null
  }
}

# ------------------------------------------------------------------------------
# Data Sources for Remote State and Configuration
# (Connecting to network, platform, and bootstrap layers)
# ------------------------------------------------------------------------------

# Access outputs from the 'network' layer
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "acmelabs-terraform-state-network"
    key    = "network/terraform.tfstate"
    region = var.aws_region
  }
}

# Access outputs from the 'platform' layer
data "terraform_remote_state" "platform" {
  backend = "s3"
  config = {
    bucket = "acmelabs-terraform-state-platform"
    key    = "platform/terraform.tfstate"
    region = var.aws_region
  }
}

# Access outputs from the 'bootstrap' layer for ACM certificate validation
data "terraform_remote_state" "bootstrap" {
  backend = "s3"
  config = {
    bucket = "acmelabs-terraform-state-bootstrap"
    key    = "bootstrap/terraform.tfstate"
    region = var.aws_region
  }
}

# Looks up the Hosted Zone so we can get its ID for DNS records.
data "aws_route53_zone" "primary" {
  name = "${var.domain_name}."
}

# Dynamically looks up the Golden AMI IDs from SSM Parameter Store.
data "aws_ssm_parameter" "web_ami" {
  name = "/anvil/ami/web/${var.ami_version}"
}

data "aws_ssm_parameter" "app_ami" {
  name = "/anvil/ami/app/${var.ami_version}"
}

# Looks up operational configurations from SSM Parameter Store at apply time.
data "aws_ssm_parameter" "ssm_web_instance_type" {
  name = "/anvil/${var.environment_name}/web_instance_type" # Corrected to var.environment_name
}

data "aws_ssm_parameter" "ssm_app_instance_type" {
  name = "/anvil/${var.environment_name}/app_instance_type" # Corrected to var.environment_name
}

data "aws_ssm_parameter" "ssm_db_instance_class" {
  count = var.database_provider == "aws_rds" ? 1 : 0
  name  = "/anvil/${var.environment_name}/db_instance_class" # Corrected to var.environment_name
}

data "aws_ssm_parameter" "ssm_web_min_size" {
  name = "/anvil/${var.environment_name}/web_min_size" # Corrected to var.environment_name
}

data "aws_ssm_parameter" "ssm_web_max_size" {
  name = "/anvil/${var.environment_name}/web_max_size" # Corrected to var.environment_name
}

data "aws_ssm_parameter" "ssm_web_desired_capacity" {
  name = "/anvil/${var.environment_name}/web_desired_capacity" # Corrected to var.environment_name
}

data "aws_ssm_parameter" "ssm_app_min_size" {
  name = "/anvil/${var.environment_name}/app_min_size" # Corrected to var.environment_name
}

data "aws_ssm_parameter" "ssm_app_max_size" {
  name = "/anvil/${var.environment_name}/app_max_size" # Corrected to var.environment_name
}

data "aws_ssm_parameter" "ssm_app_desired_capacity" {
  name = "/anvil/${var.environment_name}/app_desired_capacity" # Corrected to var.environment_name
}

# ------------------------------------------------------------------------------
# Secrets Management (application-specific values)
# ------------------------------------------------------------------------------

# Generate 8 random strings for the WordPress salts.
resource "random_string" "wp_salt" {
  count            = 8
  length           = 64
  special          = true
  override_special = "!@#$%^&*()-_=+[]{}|;:,.<>/?~"
}

# Populate the WordPress salts secret with the generated random values.
# This ensures the salts are always fresh for new instances.
resource "aws_secretsmanager_secret_version" "wp_salts_values" {
  # The 'wp_salts' container secret is managed in the 'platform' layer.
  # This layer populates the version for this specific app environment.
  secret_id = data.terraform_remote_state.platform.outputs.wp_salts_secret_arn[var.environment_name]
  secret_string = jsonencode({
    AUTH_KEY         = random_string.wp_salt[0].result
    SECURE_AUTH_KEY  = random_string.wp_salt[1].result
    LOGGED_IN_KEY    = random_string.wp_salt[2].result
    NONCE_KEY        = random_string.wp_salt[3].result
    AUTH_SALT        = random_string.wp_salt[4].result
    SECURE_AUTH_SALT = random_string.wp_salt[5].result
    LOGGED_IN_SALT   = random_string.wp_salt[6].result
    NONCE_SALT       = random_string.wp_salt[7].result
  })
}

# ---------------------------------------------------------------------------------------
# ACM Certificate Validation (uses cert created by bootstrap and DNS from network)
# ---------------------------------------------------------------------------------------

# Create Route53 DNS validation records for ACM (uses network layer's Route53 zone)
resource "aws_route53_record" "acm_validation" {
  for_each = {
    for dvo in data.terraform_remote_state.bootstrap.outputs.bootstrap_acm_certificate_validation_options[var.environment_name] : dvo.domain_name => {
      name    = dvo.resource_record_name
      record  = dvo.resource_record_value
      type    = dvo.resource_record_type
      zone_id = data.aws_route53_zone.primary.zone_id
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = each.value.zone_id
}

# ACM certificate validation resource
resource "aws_acm_certificate_validation" "bootstrap_cert" {
  certificate_arn         = data.terraform_remote_state.bootstrap.outputs.bootstrap_acm_certificate_arns[var.environment_name]
  validation_record_fqdns = [for record in aws_route53_record.acm_validation : record.fqdn]
}

# ------------------------------------------------------------------------------
# Application-Specific IAM Roles & Instance Profiles
# ------------------------------------------------------------------------------

# Defines a role that the EC2 service can assume for application instances.
resource "aws_iam_role" "instance_role" {
  name = "${local.name_prefix}-instance-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
  tags = module.tags.tags
}

# Creates an instance profile, which makes the IAM role available to EC2 instances.
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${local.name_prefix}-ec2-profile"
  role = aws_iam_role.instance_role.name
}

# ------------------------------------------------------------------------------
# Application-Specific Security Groups
# (VPC ID provided by network layer)
# ------------------------------------------------------------------------------

# 1. Controls traffic for the public-facing web load balancer.
resource "aws_security_group" "web_lb" {
  name        = "${local.name_prefix}-web-lb-sg"
  description = "Allows public web traffic to the Web ALB"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [
      "0.0.0.0/0",
      # Add additional CIDR blocks for specific access if needed
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = module.tags.tags
}

# 2. Controls traffic for the web server EC2 instances.
resource "aws_security_group" "web_tier" {
  name        = "${local.name_prefix}-web-tier-sg"
  description = "Allows traffic from Web ALB to Web instances"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id

  ingress {
    description     = "HTTPS from the Web LB"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.web_lb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = module.tags.tags
}

# 3. Controls traffic for the internal app load balancer.
resource "aws_security_group" "app_lb" {
  name        = "${local.name_prefix}-app-lb-sg"
  description = "Allows traffic from Web Tier to the App ALB"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id

  ingress {
    description     = "HTTPS from the Web Tier"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.web_tier.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = module.tags.tags
}

# 4. Controls traffic for the application server EC2 instances.
resource "aws_security_group" "app_tier" {
  name        = "${local.name_prefix}-app-tier-sg"
  description = "Allows traffic from App ALB to App instances"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id

  ingress {
    description     = "HTTPS from the App LB"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.app_lb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = module.tags.tags
}

# 5. Controls traffic for the RDS database instance.
resource "aws_security_group" "db_tier" {
  name        = "${local.name_prefix}-db-tier-sg"
  description = "Allows traffic from App Tier to the RDS Database"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id

  ingress {
    description     = "MySQL traffic from the App Tier"
    from_port       = 3306 # Standard MySQL port
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app_tier.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = module.tags.tags
}

# ------------------------------------------------------------------------------
# Application Tier: Web
# (Calls local ec2 module for instances, ASG, and LB)
# ------------------------------------------------------------------------------

module "web_tier" {
  source                    = "./modules/ec2"
  name_prefix               = "${local.name_prefix}-web"
  vpc_id                    = data.terraform_remote_state.network.outputs.vpc_id
  subnet_ids                = data.terraform_remote_state.network.outputs.private_subnet_ids
  tags                      = module.tags.tags
  lb_subnet_ids             = data.terraform_remote_state.network.outputs.public_subnet_ids
  s3_bucket_for_logs        = data.terraform_remote_state.platform.outputs.shared_s3_bucket_name
  min_size                  = var.web_min_size
  max_size                  = var.web_max_size
  desired_capacity          = var.web_desired_capacity
  instance_type             = data.aws_ssm_parameter.ssm_web_instance_type.value
  ami_id                    = data.aws_ssm_parameter.web_ami.value
  key_name                  = data.terraform_remote_state.bootstrap.outputs.ssh_key_names[var.environment_name]
  iam_instance_profile_name = aws_iam_instance_profile.ec2_profile.name
  security_group_ids        = [aws_security_group.web_tier.id]
  lb_security_group_ids     = [aws_security_group.web_lb.id]
  lb_certificate_arn        = data.terraform_remote_state.platform.outputs.acm_public_certificate_arn
  enable_https_listener     = true
  user_data_script_base64 = base64encode(templatefile("${path.module}/templates/instance_setup.sh.tpl", {
    certificate_authority_arn = data.terraform_remote_state.platform.outputs.acm_private_ca_arn,
    aws_region                = var.aws_region,
    cms_name                  = var.cms_name,
    cms_version               = var.cms_version,
    env                       = var.environment_name,
    domain_name               = var.domain_name,
    app_tier_dns              = module.app_tier.load_balancer_dns_name != null ? module.app_tier.load_balancer_dns_name : "",
    db_endpoint               = local.database_config.endpoint != null ? local.database_config.endpoint : "",
    db_port                   = local.database_config.port,
    db_name                   = local.database_config.name,
    db_username               = local.database_config.username,
    db_password_secret_arn    = var.database_provider == "aws_rds" ? module.rds[0].db_password_secret_arn : "",
    wp_salts_secret_arn       = data.terraform_remote_state.platform.outputs.wp_salts_secret_arn[var.environment_name],
    xray_enabled              = var.apm_provider == "aws_xray" ? true : false,
    rum_app_monitor_script    = "" # RUM App Monitor script string here if needed
  }))
}

# ------------------------------------------------------------------------------
# Application Tier: App
# (Calls local ec2 module for instances, ASG, and internal LB)
# ------------------------------------------------------------------------------

module "app_tier" {
  source                    = "./modules/ec2"
  name_prefix               = "${local.name_prefix}-app"
  vpc_id                    = data.terraform_remote_state.network.outputs.vpc_id
  subnet_ids                = data.terraform_remote_state.network.outputs.private_subnet_ids
  tags                      = module.tags.tags
  lb_subnet_ids             = data.terraform_remote_state.network.outputs.private_subnet_ids
  s3_bucket_for_logs        = data.terraform_remote_state.platform.outputs.shared_s3_bucket_name
  min_size                  = var.app_min_size
  max_size                  = var.app_max_size
  desired_capacity          = var.app_desired_capacity
  instance_type             = var.app_instance_type
  ami_id                    = data.aws_ssm_parameter.app_ami.value
  key_name                  = data.terraform_remote_state.bootstrap.outputs.ssh_key_names[var.environment_name]
  iam_instance_profile_name = aws_iam_instance_profile.ec2_profile.name
  security_group_ids        = [aws_security_group.app_tier.id]
  lb_security_group_ids     = [aws_security_group.app_lb.id]
  lb_certificate_arn        = data.terraform_remote_state.platform.outputs.acm_private_certificate_arn
  enable_https_listener     = true
  lb_is_internal            = true # This is an internal load balancer

  user_data_script_base64 = base64encode(templatefile("${path.module}/templates/instance_setup.sh.tpl", {
    certificate_authority_arn = data.terraform_remote_state.platform.outputs.acm_private_ca_arn,
    aws_region                = var.aws_region,
    cms_name                  = var.cms_name,
    cms_version               = var.cms_version,
    env                       = var.environment_name,
    domain_name               = var.domain_name,
    app_tier_dns              = module.app_tier.load_balancer_dns_name != null ? module.app_tier.load_balancer_dns_name : "",
    db_endpoint               = local.database_config.endpoint != null ? local.database_config.endpoint : "",
    db_port                   = local.database_config.port,
    db_name                   = local.database_config.name,
    db_username               = local.database_config.username,
    db_password_secret_arn    = var.database_provider == "aws_rds" ? module.rds[0].db_password_secret_arn : "",
    wp_salts_secret_arn       = data.terraform_remote_state.platform.outputs.wp_salts_secret_arn[var.environment_name],
    xray_enabled              = var.apm_provider == "aws_xray" ? true : false,
    rum_app_monitor_script    = "" # RUM App Monitor script string here if needed
  }))
}

# ------------------------------------------------------------------------------
# Data Tier (RDS)
# ------------------------------------------------------------------------------

module "rds" {
  count  = var.database_provider == "aws_rds" ? 1 : 0
  source = "./modules/rds" # Local module for RDS

  name_prefix            = "${local.name_prefix}-db"
  vpc_id                 = data.terraform_remote_state.network.outputs.vpc_id
  db_subnet_ids          = data.terraform_remote_state.network.outputs.db_subnet_ids
  db_instance_class      = var.db_instance_class
  db_name                = "${var.cms_name}_${var.environment_name}"
  db_username            = "dbadmin" # Hardcoded in original
  vpc_security_group_ids = [aws_security_group.db_tier.id]
  tags                   = module.tags.tags
  multi_az_deployment    = var.db_multi_az
}

# ------------------------------------------------------------------------------
# Content Delivery Network (CDN - CloudFront) and Web Application Firewall (WAF)
# ------------------------------------------------------------------------------

resource "aws_wafv2_web_acl" "this" {
  name  = "${local.name_prefix}-web-acl"
  scope = "REGIONAL" # Use REGIONAL for ALBs
  default_action {
    allow {}
  }

  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 1
    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesCommonRuleSet"
      }
    }
    override_action {
      none {}
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "waf-common-rules"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWS-AWSManagedRulesAmazonIpReputationList"
    priority = 2
    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesAmazonIpReputationList"
      }
    }
    override_action {
      none {}
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "waf-ip-reputation"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "waf-main"
    sampled_requests_enabled   = true
  }

  tags = module.tags.tags
}

resource "aws_wafv2_web_acl_association" "this" {
  resource_arn = module.web_tier.load_balancer_arn
  web_acl_arn  = aws_wafv2_web_acl.this.arn
}

resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CDN for ${local.name_prefix}"
  default_root_object = "index.php"

  origin {
    domain_name = module.web_tier.load_balancer_dns_name
    origin_id   = "alb-${local.name_prefix}"
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "alb-${local.name_prefix}"

    forwarded_values {
      query_string = true
      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate_validation.bootstrap_cert.certificate_arn # Using validated cert
    ssl_support_method  = "sni-only"
  }

  tags = module.tags.tags
}

# ------------------------------------------------------------------------------
# Real User Monitoring (RUM) App Monitor
# ------------------------------------------------------------------------------

resource "aws_rum_app_monitor" "web_monitor" {
  count = var.rum_provider == "aws_rum" ? 1 : 0

  name   = "${local.name_prefix}-web-rum"
  domain = "${var.web_subdomain}.${var.environment_name}.${var.domain_name}"
  app_monitor_configuration {
    session_sample_rate = 0.1 # Sample 10% of sessions
    telemetries         = ["errors", "performance", "http"]
  }

  tags       = module.tags.tags
  depends_on = [module.web_tier] # Ensures this resource is created after the web tier is ready.
}

# ------------------------------------------------------------------------------
# Final Public DNS Record
# (Uses network layer's Route53 module via remote state)
# ------------------------------------------------------------------------------

module "dns" {
  source  = "../../network/modules/route53" # Reusing network's Route53 module
  zone_id = data.aws_route53_zone.primary.id

  records = {
    "web_tier_alias" = {
      name = "${var.web_subdomain}.${var.environment_name}"
      type = "A"
      alias = {
        name                   = aws_cloudfront_distribution.this.domain_name
        zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
        evaluate_target_health = true
      }
    }
  }
}
