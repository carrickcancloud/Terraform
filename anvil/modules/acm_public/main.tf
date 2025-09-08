# This file contains the logic for creating and validating an ACM certificate.

# 1. Requests a new public certificate from AWS Certificate Manager.
resource "aws_acm_certificate" "this" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  tags = var.common_tags
}

# 2. Creates the DNS record in Route 53 that ACM will use to validate domain ownership.
#    ACM provides the details for this record automatically.
resource "aws_route53_record" "validation" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options : dvo.domain_name => {
      name    = dvo.resource_record_name
      record  = dvo.resource_record_value
      type    = dvo.resource_record_type
      zone_id = var.zone_id
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = each.value.zone_id
}

# 3. This special resource tells Terraform to wait until ACM has successfully
#    used the DNS record to validate the certificate before proceeding.
resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for record in aws_route53_record.validation : record.fqdn]
}
