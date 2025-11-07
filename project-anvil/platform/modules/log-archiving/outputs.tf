# ==============================================================================
# Project Anvil - Platform Layer
# modules/log_archiving/outputs.tf
#
# Outputs for the log archiving module.
#
# Author: Carrick Bradley
# Last Updated: 2025-09-24
# ==============================================================================

output "log_group_name" {
  description = "The name of the managed CloudWatch Log Group."
  value       = aws_cloudwatch_log_group.this.name
}

output "firehose_stream_arn" {
  description = "The ARN of the Kinesis Data Firehose delivery stream."
  value       = aws_kinesis_firehose_delivery_stream.this.arn
}
