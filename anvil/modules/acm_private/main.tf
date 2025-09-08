# This file contains the logic to create a production-grade ACM Private Certificate Authority.

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

  # A Certificate Revocation List (CRL) is a list of certificates that have been
  # revoked and should no longer be trusted. This is a critical security feature.
  revocation_configuration {
    crl_configuration {
      enabled = true
      # The CRL will be automatically published to the specified S3 bucket.
      s3_bucket_name = var.crl_s3_bucket_name
      # How long a cached CRL is valid before a client must re-fetch it.
      expiration_in_days = 7
    }
  }

  tags = var.common_tags
}

# This resource generates the certificate for the CA itself.
resource "aws_acmpca_certificate" "this" {
  certificate_authority_arn   = aws_acmpca_certificate_authority.this.arn
  certificate_signing_request = aws_acmpca_certificate_authority.this.certificate_signing_request
  signing_algorithm           = "SHA512WITHRSA"

  # The validity period is now configurable via a variable.
  validity {
    type  = "YEARS"
    value = var.ca_validity_period_years
  }

  template_arn = "arn:aws:acm-pca:::template/SubordinateCACertificate_PathLen0/V1"
}

# This resource installs the CA's certificate into the CA, making it ACTIVE.
resource "aws_acmpca_certificate_authority_certificate" "this" {
  certificate_authority_arn = aws_acmpca_certificate_authority.this.arn
  certificate               = aws_acmpca_certificate.this.certificate
  certificate_chain         = aws_acmpca_certificate.this.certificate_chain
}
