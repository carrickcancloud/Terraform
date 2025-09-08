# This file is the main entrypoint. It defines the provider, calculates dynamic
# values, and calls all the child modules to build the complete infrastructure.

provider "aws" {
  region = var.aws_region
}

terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.4"
    }
  }
}

# Defines a set of reusable local values for naming, tagging, and IP management.
locals {
  # --- Naming & Tagging ---
  name_prefix = "${var.project_name}-${terraform.workspace}"
  common_tags = {
    Project     = var.project_name
    Environment = terraform.workspace
    CMS         = var.cms_name
    CMSVersion  = var.cms_version
    ManagedBy   = "Terraform"
    CreatedOn   = var.build_timestamp
  }

  # --- Hierarchical IP Address Management ---
  env_cidrs = {
    "default" = 10, "dev" = 10, "qa" = 20, "uat" = 30, "prod" = 40
  }
  tier_cidrs = {
    "public"  = 0,
    "private" = 1,
    "db"      = 2 # Reserved for future database subnets
  }
  vpc_cidr = cidrsubnet("10.0.0.0/8", 8, local.env_cidrs[terraform.workspace])

  public_subnet_cidrs = [
    for i, az in var.availability_zones :
    cidrsubnet(cidrsubnet(local.vpc_cidr, 4, i), 4, local.tier_cidrs["public"])
  ]
  private_subnet_cidrs = [
    for i, az in var.availability_zones :
    cidrsubnet(cidrsubnet(local.vpc_cidr, 4, i), 4, local.tier_cidrs["private"])
  ]
  db_subnet_cidrs = [
    for i, az in var.availability_zones :
    cidrsubnet(cidrsubnet(local.vpc_cidr, 4, i), 4, local.tier_cidrs["db"])
  ]

  # --- Pluggable Database Interface ---
  database_config = {
    endpoint = var.database_provider == "aws_rds" ? module.rds[0].db_instance_endpoint : null
    port     = var.database_provider == "aws_rds" ? module.rds[0].db_instance_port : null
    name     = var.database_provider == "aws_rds" ? module.rds[0].db_name : null
    username = var.database_provider == "aws_rds" ? module.rds[0].db_username : null
  }
}

# +------------------------------------------+
# |        Data Sources & Lookups            |
# +------------------------------------------+

# Looks up the Hosted Zone so we can get its ID for the dns and acm modules.
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

# Looks up the current AWS Account ID for use in IAM Policies.
data "aws_caller_identity" "current" {}

# Looks up the PagerDuty Integration URL from Secrets Manager at apply time.
data "aws_secretsmanager_secret_version" "pagerduty" {
  # This data source will only be read if PagerDuty is the selected provider.
  count = var.alerting_provider == "pagerduty" ? 1 : 0

  secret_id = aws_secretsmanager_secret.pagerduty[0].id
}

# Read operational configurations from SSM Parameter Store at apply time.
data "aws_ssm_parameter" "ssm_web_instance_type" {
  name = "/anvil/${terraform.workspace}/web_instance_type"
}

data "aws_ssm_parameter" "ssm_app_instance_type" {
  name = "/anvil/${terraform.workspace}/app_instance_type"
}

data "aws_ssm_parameter" "ssm_db_instance_class" {
  count = var.database_provider == "aws_rds" ? 1 : 0
  name  = "/anvil/${terraform.workspace}/db_instance_class"
}

data "aws_ssm_parameter" "ssm_web_min_size" {
  name = "/anvil/${terraform.workspace}/web_min_size"
}

data "aws_ssm_parameter" "ssm_web_max_size" {
  name = "/anvil/${terraform.workspace}/web_max_size"
}

data "aws_ssm_parameter" "ssm_web_desired_capacity" {
  name = "/anvil/${terraform.workspace}/web_desired_capacity"
}

data "aws_ssm_parameter" "ssm_app_min_size" {
  name = "/anvil/${terraform.workspace}/app_min_size"
}

data "aws_ssm_parameter" "ssm_app_max_size" {
  name = "/anvil/${terraform.workspace}/app_max_size"
}

data "aws_ssm_parameter" "ssm_app_desired_capacity" {
  name = "/anvil/${terraform.workspace}/app_desired_capacity"
}

# +------------------------------------------+
# |           Secrets Management             |
# +------------------------------------------+

# Generate 8 random strings for the WordPress salts.
resource "random_string" "wp_salt" {
  count   = 8
  length  = 64
  special = true
  # Add extra special characters to ensure high entropy.
  override_special = "!@#$%^&*()-_=+[]{}|;:,.<>/?~"
}

# Populate the WordPress salts secret with the generated random values.
# This runs on every apply, ensuring the salts are always fresh for new instances.
resource "aws_secretsmanager_secret_version" "wp_salts_values" {
  secret_id = aws_secretsmanager_secret.wp_salts.id
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

# +------------------------------------------+
# |          Foundational Modules            |
# +------------------------------------------+

# Deploys the core networking infrastructure.
module "vpc" {
  source = "./modules/vpc"

  vpc_name             = "${local.name_prefix}-vpc"
  subnet_name          = "${local.name_prefix}-subnet"
  igw_name             = "${local.name_prefix}-igw"
  route_table_name     = "${local.name_prefix}-rt"
  vpc_cidr             = local.vpc_cidr
  public_subnet_cidrs  = local.public_subnet_cidrs
  private_subnet_cidrs = local.private_subnet_cidrs
  db_subnet_cidrs      = local.db_subnet_cidrs
  availability_zones   = var.availability_zones
}

# Deploys the shared S3 bucket for logs and application data.
module "s3" {
  source      = "./modules/s3"
  bucket_name = "${local.name_prefix}-data-bucket"
  tags        = local.common_tags
}

# Creates and validates the public ACM certificate for the domain.
module "acm_public" {
  source      = "./modules/acm_public"
  domain_name = "*.${terraform.workspace}.${var.domain_name}"
  zone_id     = data.aws_route53_zone.primary.id
  common_tags = local.common_tags
}

# Creates the Private Certificate Authority for issuing internal TLS certificates.
module "private_ca" {
  source = "./modules/acm_private"

  organization_name    = "AcmeLabs Inc."
  common_name          = "internal.${terraform.workspace}.${var.domain_name}"
  crl_s3_bucket_name   = module.s3.bucket_name
  common_tags          = local.common_tags

  depends_on = [module.s3]
}

# --- IAM & Permissions (Root Level) ---

# Creates the IAM policy that grants EC2 instances access to the S3 bucket.
module "s3_policy" {
  source      = "./modules/s3_access_policy"
  name_prefix = local.name_prefix
  bucket_arn  = module.s3.bucket_arn
}

# Attaches the S3 access policy to the shared EC2 instance role defined in security.tf.
resource "aws_iam_role_policy_attachment" "s3_access_attach" {
  role       = aws_iam_role.instance_role.name
  policy_arn = module.s3_policy.arn
}

# Defines the policy allowing Kinesis Firehose to write to S3 for log archiving.
resource "aws_iam_policy" "firehose_to_s3_policy" {
  count = var.logging_provider == "aws_s3_firehose" ? 1 : 0

  name   = "${local.name_prefix}-firehose-to-s3-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["s3:PutObject", "s3:AbortMultipartUpload"],
      Resource = "${module.s3.bucket_arn}/archived-logs/*"
    }]
  })
}

# Attaches the policy to the Firehose role defined in security.tf.
resource "aws_iam_role_policy_attachment" "firehose_to_s3_attach" {
  count = var.logging_provider == "aws_s3_firehose" ? 1 : 0

  role       = aws_iam_role.firehose_to_s3_role[0].name
  policy_arn = aws_iam_policy.firehose_to_s3_policy[0].arn
}

# Defines the policy allowing CloudWatch Logs to write to Kinesis Firehose for log archiving.
resource "aws_iam_policy" "logs_to_firehose_policy" {
  count = var.logging_provider == "aws_s3_firehose" ? 1 : 0

  name   = "${local.name_prefix}-logs-to-firehose-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = "firehose:PutRecord",
      Resource = module.archive_app_logs[0].firehose_stream_arn
    }]
  })
}

# Attaches the policy to the CloudWatch Logs role defined in security.tf.
resource "aws_iam_role_policy_attachment" "logs_to_firehose_attach" {
  count = var.logging_provider == "aws_s3_firehose" ? 1 : 0

  role       = aws_iam_role.logs_to_firehose_role[0].name
  policy_arn = aws_iam_policy.logs_to_firehose_policy[0].arn
}

# Defines the policy allowing X-Ray traces to be sent.
resource "aws_iam_policy" "xray_policy" {
  count = var.apm_provider == "aws_xray" ? 1 : 0

  name   = "${local.name_prefix}-xray-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "xray:PutTraceSegments",
        "xray:PutTelemetryRecords",
        "xray:GetSamplingRules",
        "xray:GetSamplingTargets",
        "xray:GetSamplingStatisticSummaries"
      ],
      Resource = "*"
    }]
  })
}

# Attaches the X-Ray policy to the instance role.
resource "aws_iam_role_policy_attachment" "xray_attach" {
  count = var.apm_provider == "aws_xray" ? 1 : 0

  role       = aws_iam_role.instance_role.name
  policy_arn = aws_iam_policy.xray_policy[0].arn
}

# Defines the policy allowing CloudWatch RUM events to be sent.
resource "aws_iam_policy" "rum_policy" {
  count = var.rum_provider == "aws_rum" ? 1 : 0

  name   = "${local.name_prefix}-rum-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "rum:PutRumEvents",
        Resource = "*"
      }
    ]
  })
}

# Attaches the RUM policy to the instance role.
resource "aws_iam_role_policy_attachment" "rum_attach" {
  count = var.rum_provider == "aws_rum" ? 1 : 0

  role       = aws_iam_role.instance_role.name
  policy_arn = aws_iam_policy.rum_policy[0].arn
}

# --- Policy to Read DB Password Secret ---
resource "aws_iam_policy" "db_secret_read_policy" {
  # Create this policy only if RDS is the provider
  count = var.database_provider == "aws_rds" ? 1 : 0

  name   = "${local.name_prefix}-db-secret-read-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = "secretsmanager:GetSecretValue",
      Resource = module.rds[0].db_password_secret_arn
    }]
  })
}

# Attaches the DB Secret read policy to the shared EC2 instance role.
resource "aws_iam_role_policy_attachment" "db_secret_read_attach" {
  # Attach this policy only if RDS is the provider
  count = var.database_provider == "aws_rds" ? 1 : 0

  role       = aws_iam_role.instance_role.name
  policy_arn = aws_iam_policy.db_secret_read_policy[0].arn
}

# --- Policy to Read WordPress Salts Secret ---
resource "aws_iam_policy" "wp_salts_read_policy" {
  name   = "${local.name_prefix}-wp-salts-read-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = "secretsmanager:GetSecretValue",
      Resource = aws_secretsmanager_secret.wp_salts.arn
    }]
  })
}

# Attaches the WordPress Salts read policy to the shared EC2 instance role.
resource "aws_iam_role_policy_attachment" "wp_salts_read_attach" {
  role       = aws_iam_role.instance_role.name
  policy_arn = aws_iam_policy.wp_salts_read_policy.arn
}

# Deploys the RDS database for the application's data tier.
module "rds" {
  count  = var.database_provider == "aws_rds" ? 1 : 0
  source = "./modules/rds"

  name_prefix            = "${local.name_prefix}-db"
  vpc_id                 = module.vpc.vpc_id
  db_subnet_ids          = module.vpc.db_subnet_ids
  db_instance_class      = data.aws_ssm_parameter.ssm_db_instance_class[0].value
  db_name                = "${var.cms_name}_${terraform.workspace}"
  db_username            = "dbadmin"
  vpc_security_group_ids = [aws_security_group.db_tier.id]
  common_tags            = local.common_tags
  multi_az_deployment    = var.db_multi_az

  depends_on = [module.vpc]
}

# +------------------------------------------+
# |           Log Archiving Pipeline         |
# +------------------------------------------+

# This module call sets up the actual archiving pipeline (Log Group -> Firehose -> S3)
# for the application tier's logs.
module "archive_app_logs" {
  count = var.logging_provider == "aws_s3_firehose" ? 1 : 0

  source = "./modules/log_archiving"
  
  log_group_name            = "/anvil/${terraform.workspace}/app-tier"
  archive_s3_bucket_arn     = module.s3.bucket_arn
  firehose_iam_role_arn     = aws_iam_role.firehose_to_s3_role[0].arn
  logs_to_firehose_role_arn = aws_iam_role.logs_to_firehose_role[0].arn

  depends_on = [
    aws_iam_role_policy_attachment.firehose_to_s3_attach,
    aws_iam_role_policy_attachment.logs_to_firehose_attach
  ]
}

# +------------------------------------------+
# |          Application Tiers               |
# +------------------------------------------+

# Deploys the Web Tier as a public, load-balanced service.
module "web_tier" {
  source = "./modules/ec2"

  name_prefix               = "${local.name_prefix}-web"
  vpc_id                    = module.vpc.vpc_id
  subnet_ids                = module.vpc.private_subnet_cidrs
  common_tags               = local.common_tags
  lb_subnet_ids             = module.vpc.public_subnet_cidrs
  s3_bucket_for_logs        = module.s3.bucket_name
  min_size                  = data.aws_ssm_parameter.ssm_web_min_size.value
  max_size                  = data.aws_ssm_parameter.ssm_web_max_size.value
  desired_capacity          = data.aws_ssm_parameter.ssm_web_desired_capacity.value
  instance_type             = data.aws_ssm_parameter.ssm_web_instance_type.value
  ami_id                    = data.aws_ssm_parameter.web_ami.value
  key_name                  = var.key_name
  iam_instance_profile_name = aws_iam_instance_profile.ec2_profile.name
  security_group_ids        = [aws_security_group.web_tier.id]
  lb_security_group_ids     = [aws_security_group.web_lb.id]
  lb_certificate_arn        = module.acm_public.certificate_arn
  enable_https_listener     = false # Set to true in a second apply step

  # Inject X-Ray daemon logic via user_data if X-Ray is enabled.
  user_data_script_base64 = base64encode(templatefile("${path.module}/templates/instance_setup.sh.tpl", {
    certificate_authority_arn = module.private_ca.certificate_authority_arn,
    aws_region                = var.aws_region,
    cms_name                  = var.cms_name,
    cms_version               = var.cms_version,
    env                       = terraform.workspace,
    domain_name               = var.domain_name,
    app_tier_dns              = module.app_tier.load_balancer_dns_name,
    db_endpoint               = local.database_config.endpoint,
    db_port                   = local.database_config.port,
    db_name                   = local.database_config.name,
    db_username               = local.database_config.username,
    db_password_secret_arn    = var.database_provider == "aws_rds" ? module.rds[0].db_password_secret_arn : "",
    wp_salts_secret_arn       = aws_secretsmanager_secret.wp_salts.arn,
    xray_enabled              = var.apm_provider == "aws_xray" ? true : false
  }))

  depends_on = [module.s3]
}

# Deploys the App Tier as a private, internal, load-balanced service.
module "app_tier" {
  source = "./modules/ec2"

  name_prefix               = "${local.name_prefix}-app"
  vpc_id                    = module.vpc.vpc_id
  subnet_ids                = module.vpc.private_subnet_cidrs
  common_tags               = local.common_tags
  lb_subnet_ids             = module.vpc.private_subnet_cidrs
  s3_bucket_for_logs        = module.s3.bucket_name
  min_size                  = data.aws_ssm_parameter.ssm_app_min_size.value
  max_size                  = data.aws_ssm_parameter.ssm_app_max_size.value
  desired_capacity          = data.aws_ssm_parameter.ssm_app_desired_capacity.value
  instance_type             = data.aws_ssm_parameter.ssm_app_instance_type.value
  ami_id                    = data.aws_ssm_parameter.app_ami.value
  key_name                  = var.key_name
  iam_instance_profile_name = aws_iam_instance_profile.ec2_profile.name
  security_group_ids        = [aws_security_group.app_tier.id]
  lb_security_group_ids     = [aws_security_group.app_lb.id]
  lb_certificate_arn        = module.acm_public.certificate_arn
  enable_https_listener     = false # Set to true in a second apply step

  # Add user_data for internal TLS and X-Ray daemon
  user_data_script_base64 = base64encode(templatefile("${path.module}/templates/instance_setup.sh.tpl", {
    certificate_authority_arn = module.private_ca.certificate_authority_arn,
    aws_region                = var.aws_region,
    cms_name                  = var.cms_name,
    cms_version               = var.cms_version,
    env                       = terraform.workspace,
    domain_name               = var.domain_name,
    app_tier_dns              = module.app_tier.load_balancer_dns_name,
    db_endpoint               = local.database_config.endpoint,
    db_port                   = local.database_config.port,
    db_name                   = local.database_config.name,
    db_username               = local.database_config.username,
    db_password_secret_arn    = var.database_provider == "aws_rds" ? module.rds[0].db_password_secret_arn : "",
    wp_salts_secret_arn       = aws_secretsmanager_secret.wp_salts.arn,
    xray_enabled              = var.apm_provider == "aws_xray" ? true : false
  }))

  depends_on = [module.s3]
}

# +------------------------------------------+
# |           Real User Monitoring           |
# +------------------------------------------+

# Creates a CloudWatch RUM App Monitor for tracking real user performance.
# This monitor is only created if the 'rum_provider' is set to 'aws_rum'.
resource "aws_rum_app_monitor" "web_monitor" {
  count = var.rum_provider == "aws_rum" ? 1 : 0

  name     = "${local.name_prefix}-web-rum"
  domain   = "${var.web_subdomain}.${terraform.workspace}.${var.domain_name}"
  app_monitor_configuration {
    session_sample_rate = 0.1 # Sample 10% of sessions
    telemetries         = ["errors", "performance", "http"]
  }

  tags = local.common_tags

  # Ensures this resource is created after the web tier is ready.
  depends_on = [module.web_tier]
}

# +------------------------------------------+
# |           Web Application Firewall       |
# +------------------------------------------+

resource "aws_wafv2_web_acl" "this" {
  name        = "${local.name_prefix}-web-acl"
  scope       = "REGIONAL" # Use REGIONAL for ALBs
  default_action {
    allow {}
  }

  # Rule 1: Block common web exploits
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

  # Rule 2: Block known bad IP addresses
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

  tags = local.common_tags
}

# Associate the WAF with the web tier's load balancer
resource "aws_wafv2_web_acl_association" "this" {
  resource_arn = module.web_tier.load_balancer_arn
  web_acl_arn  = aws_wafv2_web_acl.this.arn
}

# +------------------------------------------+
# |          CDN (CloudFront)                |
# +------------------------------------------+

resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CDN for ${local.name_prefix}"
  default_root_object = "index.php"

  origin {
    domain_name = module.web_tier.load_balancer_dns_name
    origin_id   = "alb-${local.name_prefix}"
    custom_origin_config {
      http_port                = 80
      https_port               = 443
      origin_protocol_policy   = "https-only"
      origin_ssl_protocols     = ["TLSv1.2"]
    }
  }

  # Default cache behavior (forward most things to origin)
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
    acm_certificate_arn = module.acm_public.certificate_arn
    ssl_support_method  = "sni-only"
  }

  tags = local.common_tags
}

# +------------------------------------------+
# |            Final DNS Record              |
# +------------------------------------------+

# Creates the primary public DNS record for the web application.
module "dns" {
  source  = "./modules/route53"
  zone_id = data.aws_route53_zone.primary.id

  records = {
    "web_tier_alias" = {
      name = "${var.web_subdomain}.${terraform.workspace}"
      type = "A"
      alias = {
        name                   = aws_cloudfront_distribution.this.domain_name
        zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
        evaluate_target_health = true
      }
    }
  }
}
