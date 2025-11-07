# ==============================================================================
# Project Anvil - Shared Modules - SSH Key Pair
# main.tf
#
# This module creates an SSH key pair with optional tags.
# It is used as part of the bootstrap infrastructure layer.
#
# Author: Carrick Bradley
# Last Updated: 2025-10-01
# ==============================================================================

resource "aws_key_pair" "this" {
  key_name   = var.key_name
  public_key = var.public_key
  tags       = var.tags
}
