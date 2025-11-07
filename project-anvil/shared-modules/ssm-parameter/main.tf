# ==============================================================================
# Project Anvil - Shared Modules - SSM Parameter
# main.tf
#
# This module creates an SSM parameter with optional description, tags,
# and overwrite capability.
# It is used as part of the bootstrap infrastructure layer.
#
# Author: Carrick Bradley
# Last Updated: 2025-10-01
# ==============================================================================

resource "aws_ssm_parameter" "this" {
  name        = var.name
  description = var.description
  value       = var.value
  type        = var.type
  overwrite   = var.overwrite
  tags        = var.tags
}
