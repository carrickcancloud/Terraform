# This file defines all shared security resources for the project,
# including network firewalls (Security Groups), permissions (IAM Roles), and secret containers.

# +--------------------------------+
# |        Security Groups         |
# +--------------------------------+

# 1. Controls traffic for the public-facing web load balancer.
resource "aws_security_group" "web_lb" {
  name        = "${local.name_prefix}-web-lb-sg"
  description = "Allows public web traffic to the Web ALB"
  vpc_id      = module.vpc.vpc_id

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
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

# 2. Controls traffic for the web server EC2 instances.
resource "aws_security_group" "web_tier" {
  name        = "${local.name_prefix}-web-tier-sg"
  description = "Allows traffic from Web ALB to Web instances"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "HTTPS from the Web LB"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.web_lb.id] # Source is the LB's Security Group
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

# 3. Controls traffic for the internal app load balancer.
resource "aws_security_group" "app_lb" {
  name        = "${local.name_prefix}-app-lb-sg"
  description = "Allows traffic from Web Tier to the App ALB"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "HTTPS from the Web Tier"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.web_tier.id] # Source is the Web Tier's Security Group
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

# 4. Controls traffic for the application server EC2 instances.
resource "aws_security_group" "app_tier" {
  name        = "${local.name_prefix}-app-tier-sg"
  description = "Allows traffic from App ALB to App instances"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "HTTPS from the App LB"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.app_lb.id] # Source is the App LB's Security Group
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

# 5. Controls traffic for the RDS database instance.
resource "aws_security_group" "db_tier" {
  name        = "${local.name_prefix}-db-tier-sg"
  description = "Allows traffic from App Tier to the RDS Database"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "MySQL traffic from the App Tier"
    from_port       = 3306 # Standard MySQL port
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app_tier.id] # Source is the App Tier's Security Group
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

# +------------------------------------------+
# |            IAM Roles & Profiles          |
# +------------------------------------------+

# --- Role for Application Instances (EC2) ---
# Defines a role that the EC2 service can assume. Policies are attached in main.tf.
resource "aws_iam_role" "instance_role" {
  name               = "${local.name_prefix}-instance-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
  tags = local.common_tags
}

# Creates an instance profile, which makes the role available to EC2 instances.
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${local.name_prefix}-ec2-profile"
  role = aws_iam_role.instance_role.name
}

# --- Roles for Log Archiving Pipeline ---

# This IAM Role allows CloudWatch Logs to send data to a Kinesis Firehose.
# It will only be created if the logging_provider is set to 'aws_s3_firehose'.
resource "aws_iam_role" "logs_to_firehose_role" {
  count = var.logging_provider == "aws_s3_firehose" ? 1 : 0

  name = "${local.name_prefix}-logs-to-firehose-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "logs.${var.aws_region}.amazonaws.com" }
    }]
  })
}

# This IAM Role allows Kinesis Firehose to write logs to your S3 bucket.
# It will also only be created if the logging_provider is set to 'aws_s3_firehose'.
resource "aws_iam_role" "firehose_to_s3_role" {
  count = var.logging_provider == "aws_s3_firehose" ? 1 : 0

  name = "${local.name_prefix}-firehose-to-s3-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "firehose.amazonaws.com" }
    }]
  })
}

# +------------------------------------------+
# |        Secrets Manager Containers        |
# +------------------------------------------+

# Secret container for the PagerDuty integration URL.
# The value for this secret must be populated manually in the AWS Console once.
resource "aws_secretsmanager_secret" "pagerduty" {
  count = var.alerting_provider == "pagerduty" ? 1 : 0

  name        = "${local.name_prefix}-pagerduty-url"
  description = "Stores the PagerDuty integration URL for SNS."
  tags        = local.common_tags
}

# Secret container for the WordPress authentication salts.
# This will be populated dynamically by a resource in main.tf.
resource "aws_secretsmanager_secret" "wp_salts" {
  name        = "${local.name_prefix}-wordpress-salts"
  description = "Stores the authentication unique keys and salts for WordPress."
  tags        = local.common_tags
}
