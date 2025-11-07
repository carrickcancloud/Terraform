# ==============================================================================
# Project Anvil - Shared Modules - SSH Key Pair
# variables.tf
#
# This module defines the input variables for the SSH key pair module.
#
# Author: Carrick Bradley
# Last Updated: 2025-10-05
# ==============================================================================

variable "key_name" { type = string }
variable "public_key" { type = string }
variable "tags" { type = map(string) }
