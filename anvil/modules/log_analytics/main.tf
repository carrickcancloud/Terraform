# Creates an Amazon OpenSearch Serverless collection for log analytics,
# along with necessary access policies and VPC endpoints for secure access.

# This data source gets the current AWS account ID.
data "aws_caller_identity" "current" {}

# The OpenSearch Serverless collection itself.
resource "aws_opensearchserverless_collection" "this" {
  name        = var.collection_name
  description = "Log analytics collection for ${var.name_prefix}"
  type        = "TIMESERIES" # Optimized for time-series data like logs
  tags        = var.common_tags
}

# Defines the network access policy for the collection.
# This restricts access to the collection via VPC endpoints.
resource "aws_opensearchserverless_access_policy" "network_access" {
  name        = "${var.name_prefix}-network-policy"
  type        = "network"
  description = "Restricts network access to the OpenSearch collection via VPC."
  policy      = jsonencode([
    {
      Rules = [
        {
          # Grant access to the collection from specified VPC endpoints.
          ResourceType = "collection",
          Resource     = ["collection/${aws_opensearchserverless_collection.this.name}"]
        },
        {
          # Grant access to dashboards and OpenSearch API through specific VPC endpoints.
          ResourceType = "dashboard",
          Resource     = ["collection/${aws_opensearchserverless_collection.this.name}"]
        }
      ],
      # IMPORTANT: AllowFromPublic must be FALSE for production.
      AllowFromPublic = false,
      # List of VPC Endpoint IDs allowed to access this collection.
      # These endpoints will be created in the root module or another network module.
      SourceVPCEs = [aws_vpc_endpoint.opensearch_endpoint.id]
    }
  ])
}

# Defines the data access policy for the collection.
# This grants necessary permissions for users/roles to interact with the data.
resource "aws_opensearchserverless_access_policy" "data_access" {
  name        = "${var.name_prefix}-data-access-policy"
  type        = "data"
  description = "Grants data access to the OpenSearch collection for root."
  policy      = jsonencode([
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
      # Grant access to the current AWS account root for initial setup/testing.
      # For production, replace with specific IAM roles/users.
      Principal = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  ])
}

# Defines the encryption policy for the collection.
resource "aws_opensearchserverless_security_policy" "encryption" {
  name        = "${var.name_prefix}-encryption-policy"
  type        = "encryption"
  description = "Enforces encryption at rest for the collection."
  policy      = jsonencode({
    Rules = [
      {
        ResourceType = "collection",
        Resource     = ["collection/${aws_opensearchserverless_collection.this.name}"]
      }
    ],
    AWSOwnedKey = true # Use AWS managed keys for encryption (default and recommended)
  })
}

# Create a VPC Endpoint for the OpenSearch Serverless collection.
# This allows secure, private access from resources within your VPC.
resource "aws_vpc_endpoint" "opensearch_endpoint" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.aoss" # The service name for OpenSearch Serverless
  vpc_endpoint_type = "Interface"
  subnet_ids        = var.private_subnet_ids # Place endpoints in private subnets
  security_group_ids = var.vpc_endpoint_security_group_ids
}
