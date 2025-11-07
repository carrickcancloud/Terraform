# ==============================================================================
# Project Anvil - Platform Layer
# modules/log_analytics/outputs.tf
#
# Outputs for the OpenSearch Serverless log analytics module.
#
# Author: Carrick Bradley
# Last Updated: 2025-09-24
# ==============================================================================

output "collection_arn" {
  description = "The ARN of the OpenSearch Serverless collection."
  value       = aws_opensearchserverless_collection.this.arn
}

output "collection_id" {
  description = "The ID of the OpenSearch Serverless collection."
  value       = aws_opensearchserverless_collection.this.id
}

output "collection_endpoint" {
  description = "The endpoint of the OpenSearch Serverless collection."
  value       = aws_opensearchserverless_collection.this.collection_endpoint
}
