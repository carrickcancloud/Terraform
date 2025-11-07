# ==============================================================================
# Project Anvil - Platform Layer
# modules/cloudwatch_dashboard/main.tf
#
# This module creates a CloudWatch Dashboard from a provided JSON definition.
# Used for shared observability and SRE dashboards across environments.
#
# Author: Carrick Bradley
# Last Updated: 2025-09-24
# ==============================================================================

resource "aws_cloudwatch_dashboard" "this" {
  dashboard_name = var.dashboard_name
  dashboard_body = var.dashboard_body
}
