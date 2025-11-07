# ==============================================================================
# Project Anvil - Platform Layer
# modules/acm_private/main.tf
#
# This module creates a private ACM Certificate Authority (CA) for issuing
# internal TLS certificates. It also provisions the CA's certificate and
# installs it, enabling internal mTLS or service-to-service encryption.
#
# Author: Carrick Bradley
# Last Updated: 2025-09-24
# ==============================================================================

# ------------------------------------------------------------------------------
# Private Certificate Authority (CA)
# ------------------------------------------------------------------------------

resource "aws_acmpca_certificate_authority" "this" {
  type = "SUBORDINATE"

  certificate_authority_configuration {
    key_algorithm     = "RSA_4096"
    signing_algorithm = "SHA512WITHRSA"
    subject {
      organization = var.organization_name
      common_name  = var.common_name
    }
  }

  # Certificate Revocation List (CRL) for security compliance.
  revocation_configuration {
    crl_configuration {
      enabled            = true
      s3_bucket_name     = var.crl_s3_bucket_name
      expiration_in_days = 7
    }
  }

  tags = var.tags
}

# ------------------------------------------------------------------------------
# CA Certificate (signed by parent or root CA)
# ------------------------------------------------------------------------------

resource "aws_acmpca_certificate" "this" {
  certificate_authority_arn   = aws_acmpca_certificate_authority.this.arn
  certificate_signing_request = aws_acmpca_certificate_authority.this.certificate_signing_request
  signing_algorithm           = "SHA512WITHRSA"

  validity {
    type  = "YEARS"
    value = var.ca_validity_period_years
  }

  template_arn = "arn:aws:acm-pca:::template/SubordinateCACertificate_PathLen0/V1"
}

# ------------------------------------------------------------------------------
# Install the CA's certificate to activate the CA
# ------------------------------------------------------------------------------

resource "aws_acmpca_certificate_authority_certificate" "this" {
  certificate_authority_arn = aws_acmpca_certificate_authority.this.arn
  certificate               = aws_acmpca_certificate.this.certificate
  certificate_chain         = aws_acmpca_certificate.this.certificate_chain
}
