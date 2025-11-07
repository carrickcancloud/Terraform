# ==============================================================================
# Project Anvil - shared-modules/dynamodb-lock-table
# variables.tf
#
# This module defines the input variables for the DynamoDB lock table module.
#
# Author: Carrick Bradley
# Last Updated: 2025-10-05
# ==============================================================================

variable "table_name" { type = string }
variable "tags" { type = map(string) }
