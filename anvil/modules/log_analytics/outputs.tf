# Defines the outputs for the Log Analytics module.

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
