# ==============================================================================
# Project Anvil - Platform Layer
# modules/log_analytics/main.tf
#
# This module creates an Amazon OpenSearch Serverless collection for log analytics,
# along with the necessary access and encryption policies and a VPC endpoint.
#
# Author: Carrick Bradley
# Last Updated: 2025-09-24
# ==============================================================================

# ------------------------------------------------------------------------------
# Get Current AWS Account ID (for principal in access policy)
# ------------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

# ------------------------------------------------------------------------------
# OpenSearch Serverless Collection
# ------------------------------------------------------------------------------

resource "aws_opensearchserverless_collection" "this" {
  name        = var.collection_name
  description = "Log analytics collection for ${var.name_prefix}"
  type        = "TIMESERIES"
  tags        = var.tags
}

# ------------------------------------------------------------------------------
# Data Access Policy for Collection
# ------------------------------------------------------------------------------

resource "aws_opensearchserverless_access_policy" "data_access" {
  name        = "${var.name_prefix}-data-access-policy"
  type        = "data"
  description = "Grants data access to the OpenSearch collection for root."

  policy = jsonencode([
    {
      Rules = [
        {
          Resource = ["collection/${aws_opensearchserverless_collection.this.name}"],
          Permission = [
            "aoss:CreateAccessor",
            "aoss:DeleteAccessor",
            "aoss:ListAccessors",
            "aoss:UpdateAccessor"
          ],
          ResourceType = "collection"
        },
        {
          Resource = ["index/${aws_opensearchserverless_collection.this.name}/*"],
          Permission = [
            "aoss:CreateIndex", "aoss:DeleteIndex", "aoss:UpdateIndex", "aoss:DescribeIndex",
            "aoss:ReadDocument", "aoss:WriteDocument", "aoss:QueryResult",
            "aoss:UpdateSetting", "aoss:ReadConfiguration"
          ],
          ResourceType = "index"
        }
      ],
      Principal = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  ])
}

# ------------------------------------------------------------------------------
# Encryption Policy for Collection
# ------------------------------------------------------------------------------

resource "aws_opensearchserverless_security_policy" "encryption" {
  name        = "${var.name_prefix}-encryption-policy"
  type        = "encryption"
  description = "Enforces encryption at rest for the collection."

  policy = jsonencode({
    Rules = [
      {
        ResourceType = "collection",
        Resource     = ["collection/${aws_opensearchserverless_collection.this.name}"]
      }
    ],
    AWSOwnedKey = true
  })
}

# ------------------------------------------------------------------------------
# VPC Endpoint for Secure Access
# ------------------------------------------------------------------------------

resource "aws_vpc_endpoint" "opensearch_endpoint" {
  vpc_id             = var.vpc_id
  service_name       = "com.amazonaws.${var.aws_region}.aoss"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = var.private_subnet_ids
  security_group_ids = var.vpc_endpoint_security_group_ids
  tags               = var.tags
}
