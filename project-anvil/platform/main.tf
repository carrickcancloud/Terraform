# ==============================================================================
# Project Anvil - Platform Layer
# main.tf
#
# Entry point for the platform layer. Provisions shared services such as
# logging, monitoring, dashboards, shared S3 buckets, shared secrets,
# and platform-wide IAM policies. All app environments depend on these.
#
# Author: Carrick Bradley
# Last Updated: 2025-10-17 - Updated to create Firehose and CloudWatch Logs
# service roles, and consume new IAM role structure, and correctly
# reference remote states.
# ==============================================================================

provider "aws" {
  region = var.aws_region
}

terraform {
  backend "s3" {}
}

# ------------------------------------------------------------------------------
# Data Source for AWS Account ID
# Needed for constructing ARNs for IAM policies below.
# ------------------------------------------------------------------------------
data "aws_caller_identity" "current" {}

# ------------------------------------------------------------------------------
# Remote State from Bootstrap Layer
# To get outputs from the foundational bootstrap layer.
# ------------------------------------------------------------------------------
data "terraform_remote_state" "bootstrap" {
  backend = "s3"
  config = {
    # Dynamically construct the bucket name based on the environment
    bucket = "acmelabs-terraform-state-bootstrap-${var.environment_name}"
    key    = "bootstrap/terraform.tfstate"
    region = var.aws_region
  }
}

# ------------------------------------------------------------------------------
# Remote State from Network Layer
# To get VPC ID, subnet IDs, etc., from the network layer.
# ------------------------------------------------------------------------------
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    # Dynamically construct the bucket name based on the environment
    bucket = "acmelabs-terraform-state-network-${var.environment_name}"
    key    = "network/terraform.tfstate"
    region = var.aws_region
  }
}

# ------------------------------------------------------------------------------
# Local Values for Naming Tag
# ------------------------------------------------------------------------------
locals {
  # Uses var.environment_name for explicit environment context.
  name_prefix = "${var.project_name}-${var.environment_name}"
}

# ------------------------------------------------------------------------------
# Tags Module (Central Tagging)
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
# Shared S3 Bucket (for logs, application data, CRL, etc.)
# ------------------------------------------------------------------------------
module "s3" {
  source      = "./modules/s3"
  bucket_name = "${local.name_prefix}-data-bucket"
  tags        = module.tags.tags
}

# ------------------------------------------------------------------------------
# S3 Access Policy (shared policy for EC2 roles, ALB logs, ACM PCA CRLs)
# Note: This policy is for other resources to *access* the S3 bucket.
# The IAM role for the `platform` workflow has permissions to *manage* the S3 bucket.
# ------------------------------------------------------------------------------
module "s3_access_policy" {
  source      = "./modules/s3_access_policy"
  name_prefix = local.name_prefix
  bucket_arn  = module.s3.bucket_arn
}

# ------------------------------------------------------------------------------
# ACM Certificates (public and private CA for environment)
# ------------------------------------------------------------------------------
module "acm_public" {
  source      = "./modules/acm_public"
  domain_name = "*.${var.environment_name}.${var.domain_name}"
  zone_id     = var.route53_zone_id # This should be consistent across layers
  tags        = module.tags.tags
}

module "acm_private" {
  source                   = "./modules/acm_private"
  organization_name        = var.organization_name
  common_name              = "internal.${var.environment_name}.${var.domain_name}"
  crl_s3_bucket_name       = module.s3.bucket_name
  ca_validity_period_years = var.ca_validity_period_years
  tags                     = module.tags.tags
}

# ------------------------------------------------------------------------------
# CloudWatch Dashboards (shared monitoring and SRE views)
# ------------------------------------------------------------------------------
module "cloudwatch_dashboard" {
  source         = "./modules/cloudwatch_dashboard"
  dashboard_name = "${local.name_prefix}-Overview"
  dashboard_body = var.dashboard_body_overview
}

# ------------------------------------------------------------------------------
# Log Analytics (OpenSearch Serverless, if enabled)
# ------------------------------------------------------------------------------
module "log_analytics" {
  source          = "./modules/log_analytics"
  name_prefix     = "${local.name_prefix}-logs"
  collection_name = "${local.name_prefix}-logs"
  aws_region      = var.aws_region
  # These come from the network layer's remote state
  vpc_id             = data.terraform_remote_state.network.outputs.vpc_id
  private_subnet_ids = data.terraform_remote_state.network.outputs.private_subnet_ids
  # This variable still makes sense as an input from platform's variables.tf
  vpc_endpoint_security_group_ids = var.vpc_endpoint_security_group_ids
  tags                            = module.tags.tags
}

# ------------------------------------------------------------------------------
# IAM Role for Kinesis Firehose to write to S3
# This role is assumed by the Firehose service itself.
# The platform role (from IAM Roles module) needs PassRole permissions for this.
# ------------------------------------------------------------------------------
resource "aws_iam_role" "firehose_s3_role" {
  name = "${local.name_prefix}-firehose-to-s3-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "firehose.amazonaws.com" }
        Action    = "sts:AssumeRole"
      },
    ]
  })
  tags = module.tags.tags
}

resource "aws_iam_policy" "firehose_s3_policy" {
  name        = "${local.name_prefix}-firehose-to-s3-policy"
  description = "Allows Kinesis Firehose to write to the designated S3 bucket."
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject"
        ]
        Resource = [
          module.s3.bucket_arn,
          "${module.s3.bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
        ]
        # Assuming the shared S3 bucket uses KMS for encryption.
        # This ARN should ideally be more specific to the key used for module.s3.
        # For this project, we might need a KMS Key output from module "s3"
        # or from the bootstrap layer if that's where the shared KMS key is.
        # For now, it remains a broad wildcard, but in a real-world scenario,
        # you'd make this more specific.
        Resource = [
          "arn:aws:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:key/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "logs:PutLogEvents"
        ],
        # Firehose error logs go to a CloudWatch Log Group it creates.
        Resource = [
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/kinesisfirehose/${local.name_prefix}-firehose-to-s3-role:log-stream:*"
        ]
      }
    ]
  })
  tags = module.tags.tags
}

resource "aws_iam_role_policy_attachment" "firehose_s3_attach" {
  role       = aws_iam_role.firehose_s3_role.name
  policy_arn = aws_iam_policy.firehose_s3_policy.arn
}

# ------------------------------------------------------------------------------
# IAM Role for CloudWatch Logs to send to Kinesis Firehose
# This role is assumed by the CloudWatch Logs service itself.
# The platform role (from IAM Roles module) needs PassRole permissions for this.
# ------------------------------------------------------------------------------
resource "aws_iam_role" "logs_firehose_role" {
  name = "${local.name_prefix}-logs-to-firehose-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "logs.${var.aws_region}.amazonaws.com" }
        Action    = "sts:AssumeRole"
      },
    ]
  })
  tags = module.tags.tags
}

resource "aws_iam_policy" "logs_firehose_policy" {
  name        = "${local.name_prefix}-logs-to-firehose-policy"
  description = "Allows CloudWatch Logs to put events into Kinesis Firehose."
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "firehose:PutRecordBatch"
        # Correctly reference the ARN of the Firehose stream created by the log_archiving module
        Resource = module.log_archiving.firehose_stream_arn
      }
    ]
  })
  tags = module.tags.tags
}

resource "aws_iam_role_policy_attachment" "logs_firehose_attach" {
  role       = aws_iam_role.logs_firehose_role.name
  policy_arn = aws_iam_policy.logs_firehose_policy.arn
}

# ------------------------------------------------------------------------------
# Log Archiving Pipeline (CloudWatch -> Firehose -> S3)
# ------------------------------------------------------------------------------
module "log_archiving" {
  source                    = "./modules/log_archiving"
  log_group_name            = var.log_group_name
  archive_s3_bucket_arn     = module.s3.bucket_arn
  firehose_iam_role_arn     = aws_iam_role.firehose_s3_role.arn   # Pass the role ARN created above
  logs_to_firehose_role_arn = aws_iam_role.logs_firehose_role.arn # Pass the role ARN created above
}

# ------------------------------------------------------------------------------
# Shared Secrets (PagerDuty, WP salts, etc.)
# These are containers for secrets that are environment-wide. Actual values
# or versions are managed by other processes or specific app layers.
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# CloudWatch Agent Config SSM Parameter (for environment)
# ------------------------------------------------------------------------------
resource "aws_ssm_parameter" "cloudwatch_agent_config_param" {
  name        = "/anvil/${var.environment_name}/cloudwatch-agent-config"
  description = "CloudWatch Agent config for ${var.environment_name} environment"
  type        = "String"
  value       = file("${path.module}/config/cloudwatch-agent-config-${var.environment_name}.json")
  overwrite   = true
  tags        = module.tags.tags
}
