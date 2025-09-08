# This file defines all resources related to monitoring, alerting, and notifications for the project.
# It establishes CloudWatch Alarms and sets up pluggable log archiving and alerting channels.

# +------------------------------------------+
# |           Log Analytics (OpenSearch)     |
# +------------------------------------------+

# This module call creates the OpenSearch Serverless collection.
# It is conditional on the 'logging_provider' being 'aws_opensearch'.
module "opensearch_analytics" {
  count = var.logging_provider == "aws_opensearch" ? 1 : 0

  source = "./modules/log_analytics"

  name_prefix                     = "${local.name_prefix}-logs"
  collection_name                 = "${local.name_prefix}-logs"
  vpc_id                          = module.vpc.vpc_id
  private_subnet_ids              = module.vpc.private_subnet_ids
  vpc_endpoint_security_group_ids = [] # Placeholder: You'll define a SG for VPC endpoints in security.tf if needed
  common_tags                     = local.common_tags
  aws_region                      = var.aws_region
}

# +------------------------------------------+
# |        Alerting & Notifications          |
# +------------------------------------------+

# A central SNS Topic that receives all alarm notifications.
resource "aws_sns_topic" "alarms" {
  name = "${local.name_prefix}-alarms-topic"
  tags = local.common_tags
}

# Subscribes the PagerDuty integration endpoint to the SNS topic.
resource "aws_sns_topic_subscription" "pagerduty_alert" {
  count = var.alerting_provider == "pagerduty" && var.pagerduty_integration_url != null ? 1 : 0

  topic_arn              = aws_sns_topic.alarms.arn
  protocol               = "https"
  endpoint               = var.pagerduty_integration_url
  endpoint_auto_confirms = true
}

# +------------------------------------------+
# |           CloudWatch Alarms              |
# +------------------------------------------+

# --- 1. Web Tier Alarms ---

resource "aws_cloudwatch_metric_alarm" "web_unhealthy_hosts" {
  alarm_name          = "${local.name_prefix} [ALARM] Web Tier - Unhealthy Hosts"
  alarm_description   = "ALARM: One or more web servers are failing ELB health checks."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Maximum"
  threshold           = 1
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  dimensions = {
    TargetGroup = module.web_tier.target_group_name
  }
}

resource "aws_cloudwatch_metric_alarm" "web_5xx_warning" {
  alarm_name          = "${local.name_prefix} [WARNING] Web Tier - High 5xx Errors"
  alarm_description   = "WARNING: The web tier is producing a high number of server-side 5xx errors."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 5
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  dimensions = {
    LoadBalancer = module.web_tier.load_balancer_name
  }
}

resource "aws_cloudwatch_metric_alarm" "web_latency_warning" {
  alarm_name          = "${local.name_prefix} [WARNING] Web Tier - High Latency"
  alarm_description   = "WARNING: Web tier p95 latency has been over 1 second for 15 minutes."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 3
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "p95"
  threshold           = 1.0
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  dimensions = {
    LoadBalancer = module.web_tier.load_balancer_name
  }
}

# --- 2. App Tier Alarms ---

resource "aws_cloudwatch_metric_alarm" "app_unhealthy_hosts" {
  alarm_name          = "${local.name_prefix} [ALARM] App Tier - Unhealthy Hosts"
  alarm_description   = "ALARM: One or more app servers are failing ELB health checks."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Maximum"
  threshold           = 1
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  dimensions = {
    TargetGroup = module.app_tier.target_group_name
  }
}

resource "aws_cloudwatch_metric_alarm" "app_cpu_warning" {
  alarm_name          = "${local.name_prefix} [WARNING] App Tier - High CPU"
  alarm_description   = "WARNING: App tier average CPU has been over 75% for 15 minutes."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 75
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  dimensions = {
    AutoScalingGroupName = module.app_tier.autoscaling_group_name
  }
}

# --- 3. Data Tier (RDS) Alarms ---

resource "aws_cloudwatch_metric_alarm" "db_cpu_critical" {
  count = var.database_provider == "aws_rds" ? 1 : 0

  alarm_name          = "${local.name_prefix} [ALARM] Database - CPU Critical"
  alarm_description   = "ALARM: RDS CPU utilization has been over 90% for 15 minutes."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 90
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  dimensions = {
    DBInstanceIdentifier = module.rds[0].db_instance_id
  }
}

resource "aws_cloudwatch_metric_alarm" "db_storage_warning" {
  count = var.database_provider == "aws_rds" ? 1 : 0

  alarm_name          = "${local.name_prefix} [WARNING] Database - Low Free Storage"
  alarm_description   = "WARNING: RDS free storage space is below 10 GB."
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 3600
  statistic           = "Minimum"
  threshold           = 10000000000
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  dimensions = {
    DBInstanceIdentifier = module.rds[0].db_instance_id
  }
}

resource "aws_cloudwatch_metric_alarm" "db_connections_warning" {
  count = var.database_provider == "aws_rds" ? 1 : 0

  alarm_name          = "${local.name_prefix} [WARNING] Database - High Connections"
  alarm_description   = "WARNING: The number of database connections is high."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 3
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Maximum"
  threshold           = 100
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  dimensions = {
    DBInstanceIdentifier = module.rds[0].db_instance_id
  }
}
