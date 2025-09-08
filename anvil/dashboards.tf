# This file defines the CloudWatch Dashboards for the project.
# The creation of these dashboards is conditional on the 'monitoring_provider' variable.

# +------------------------------------------+
# |         DevOps Overview Dashboard        |
# +------------------------------------------+

module "dashboard_devops_overview" {
  # This dashboard will only be created if CloudWatch is the selected provider.
  count = var.monitoring_provider == "aws_cloudwatch" ? 1 : 0

  source = "./modules/cloudwatch_dashboard"

  dashboard_name = "${local.name_prefix}-Overview"
  dashboard_body = jsonencode({
    "widgets" : [
      # --- Row 1: High-Level Tier Health ---
      {
        "type" : "metric", "x" : 0, "y" : 0, "width" : 8, "height" : 6,
        "properties" : {
          "title" : "Web Tier Health", "region" : var.aws_region, "view" : "timeSeries", "stacked" : false,
          "metrics" : [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", module.web_tier.load_balancer_name, { "stat": "Sum" }],
            [".", "HTTPCode_Target_5XX_Count", ".", ".", { "stat" : "Sum", "color" : "#d62728", "yAxis": "right", "label": "5xx Errors" }]
          ]
        }
      },
      {
        "type" : "metric", "x" : 8, "y" : 0, "width" : 8, "height" : 6,
        "properties" : {
          "title" : "App Tier Health", "region" : var.aws_region, "view" : "timeSeries", "stacked" : false,
          "metrics" : [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", module.app_tier.load_balancer_name, { "stat": "Sum" }],
            [".", "HTTPCode_Target_5XX_Count", ".", ".", { "stat" : "Sum", "color" : "#d62728", "yAxis": "right", "label": "5xx Errors" }]
          ]
        }
      },
      {
        "type" : "metric", "x" : 16, "y" : 0, "width" : 8, "height" : 6,
        "properties" : {
          "title" : "Database Health", "region" : var.aws_region, "view" : "timeSeries", "stacked" : false,
          # This widget's metrics will only be rendered if the RDS module is active.
          "metrics" : var.database_provider != "aws_rds" ? [] : [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", module.rds[0].db_instance_id, { "label": "CPU Utilization %" }],
            ["...", { "yAxis": "right", "label": "Database Connections" }]
          ]
        }
      },
      # --- Row 2: Compute Saturation ---
      {
        "type" : "metric", "x" : 0, "y" : 6, "width" : 24, "height" : 6,
        "properties" : {
          "title" : "Compute Fleet CPU Utilization (Average)", "region" : var.aws_region, "view" : "timeSeries", "stacked" : false, "stat" : "Average",
          "metrics" : [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", module.web_tier.autoscaling_group_name, { "label" : "Web Tier CPU" }],
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", module.app_tier.autoscaling_group_name, { "label" : "App Tier CPU" }]
          ]
        }
      }
    ]
  })
}

# +------------------------------------------+
# |         SRE Deep-Dive Dashboard          |
# +------------------------------------------+

module "dashboard_sre_deep_dive" {
  # This dashboard will also only be created if CloudWatch is the selected provider.
  count = var.monitoring_provider == "aws_cloudwatch" ? 1 : 0

  source = "./modules/cloudwatch_dashboard"

  dashboard_name = "${local.name_prefix}-SRE-DeepDive"
  dashboard_body = jsonencode({
    "widgets" : [
      # Web & App Tier widgets are unchanged from your file...
      { "type": "text", "x": 0, "y": 0, "width": 24, "height": 1, "properties": { "markdown": "# 1. Web Tier (Public Facing)" } },
      # ... (Web Tier Latency/Errors & Traffic Widgets) ...
      { "type": "text", "x": 0, "y": 7, "width": 24, "height": 1, "properties": { "markdown": "# 2. App Tier (Internal Logic)" } },
      # ... (App Tier Latency/Errors & Traffic Widgets) ...
      { "type": "text", "x": 0, "y": 14, "width": 24, "height": 1, "properties": { "markdown": "# 3. Compute Saturation (CPU, Memory)" } },
      # ... (Web & App Tier Saturation Widgets) ...

      # --- Section 4: DATA TIER (Database) ---
      { "type": "text", "x": 0, "y": 21, "width": 24, "height": 1, "properties": { "markdown": "# 4. Data Tier (RDS)" } },
      {
        "type" : "metric", "x" : 0, "y" : 22, "width" : 12, "height" : 6,
        "properties" : {
          "title" : "RDS - Saturation (CPU & Memory)", "region" : var.aws_region, "view" : "timeSeries", "stat" : "Average",
          "metrics" : var.database_provider != "aws_rds" ? [] : [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", module.rds[0].db_instance_id, { "label" : "CPU Utilization %" }],
            ["AWS/RDS", "FreeableMemory", "DBInstanceIdentifier", module.rds[0].db_instance_id, { "yAxis" : "right", "label" : "Freeable Memory (Bytes)" }]
          ]
        }
      },
      {
        "type" : "metric", "x" : 12, "y" : 22, "width" : 12, "height" : 6,
        "properties" : {
          "title" : "RDS - Saturation (Connections & Disk)", "region" : var.aws_region, "view" : "timeSeries", "stat" : "Average",
          "metrics" : var.database_provider != "aws_rds" ? [] : [
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", module.rds[0].db_instance_id, { "label" : "DB Connections" }],
            ["AWS/RDS", "DiskQueueDepth", "DBInstanceIdentifier", module.rds[0].db_instance_id, { "yAxis" : "right", "label" : "Disk Queue Depth" }]
          ]
        }
      }
    ]
  })
}
