# ==============================================================================
# Project Anvil - Platform Layer
# modules/cloudwatch_dashboard/variables.tf
#
# Input variables for the CloudWatch Dashboard module.
#
# Author: Carrick Bradley
# Last Updated: 2025-09-24
# ==============================================================================

variable "dashboard_name" {
  description = "The name that will appear for the dashboard in the CloudWatch console."
  type        = string
}

variable "dashboard_body" {
  description = "The JSON document that defines the dashboard's layout and widgets."
  type        = string
}
