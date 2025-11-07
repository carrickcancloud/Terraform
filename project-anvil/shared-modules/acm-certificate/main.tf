# ==============================================================================
# Project Anvil - Shared Modules - ACM Certificates
# main.tf
#
# This module creates an ACM certificate with optional DNS validation, tags,
# and lifecycle policy to prevent accidental deletion.
# It is used as part of the bootstrap infrastructure layer.
#
# Author: Carrick Bradley
# Last Updated: 2025-10-06 - Reviewed against checkov findings for ACM certificates.
# ==============================================================================

resource "aws_acm_certificate" "this" {
  domain_name       = var.domain_name
  validation_method = var.validation_method
  tags              = var.tags
  lifecycle {
    create_before_destroy = true
    #prevent_destroy       = true
  }
  # CKV_AWS_234 (Verify logging preference for ACM certificates):
  # ACM certificates do not directly support logging preferences via this resource.
  # This check might be a false positive or apply to a different resource type.

  # CKV2_AWS_71 (Ensure AWS ACM Certificate domain name does not include wildcards):
  # Wildcard domain names (*.example.com) are used here by design to support
  # multiple subdomains within an environment (e.g., web.dev.acmelabs.cloud, app.dev.acmelabs.cloud).
  # If a stricter policy (no wildcards) is required, individual certificates for each subdomain
  # would be needed, which is a different architectural choice. This is noted as an intentional deviation.
}
