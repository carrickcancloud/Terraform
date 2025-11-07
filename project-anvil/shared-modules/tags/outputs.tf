# ==============================================================================
# Project Anvil - Shared Modules - Tags
# outputs.tf
#
# Outputs the standard tag map for use in all layers and modules.
#
# Author: Carrick Bradley
# Last Updated: 2025-10-01
# ==============================================================================

output "tags" {
  description = "Standard tags to apply to all resources."
  value = {
    Project     = var.project_name
    Environment = var.environment_name
    ManagedBy   = var.managedby
    Owner       = var.owner
  }
}
