# ==============================================================================
# Project Anvil - Network Layer
# modules/route53/main.tf
#
# This module creates DNS records in a specified Route 53 hosted zone.
# It supports standard records and alias records, and can be used by
# other layers to publish environment-specific DNS.
#
# Author: Carrick Bradley
# Last Updated: 2025-09-24
# ==============================================================================

# ------------------------------------------------------------------------------
# Route 53 DNS Records
# ------------------------------------------------------------------------------

resource "aws_route53_record" "this" {
  for_each = var.records

  zone_id = var.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = lookup(each.value, "ttl", null)     # Optional TTL
  records = lookup(each.value, "records", null) # Optional records

  # Create an alias block if alias is defined in the input.
  dynamic "alias" {
    for_each = lookup(each.value, "alias", null) != null ? [each.value.alias] : []
    content {
      name                   = alias.value.name
      zone_id                = alias.value.zone_id
      evaluate_target_health = lookup(alias.value, "evaluate_target_health", false)
    }
  }
}
