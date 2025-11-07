# ==============================================================================
# Project Anvil - Shared Modules - SSM Parameter
# outputs.tf
#
# This module outputs the name and ARN of the SSM parameter.
# It is used as part of the bootstrap infrastructure layer.
#
# Author: Carrick Bradley
# Last Updated: 2025-10-01
# ==============================================================================

output "name" {
  value = aws_ssm_parameter.this.name
}
output "arn" {
  value = aws_ssm_parameter.this.arn
}
