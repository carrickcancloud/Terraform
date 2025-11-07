# ==============================================================================
# Project Anvil - Platform Layer
# modules/log_archiving/main.tf
#
# This module sets up a log archiving pipeline: CloudWatch Log Group →
# Kinesis Firehose Delivery Stream → S3. It creates the log group, the
# Firehose stream, and the subscription filter to forward logs.
#
# Author: Carrick Bradley
# Last Updated: 2025-09-24
# ==============================================================================

# ------------------------------------------------------------------------------
# CloudWatch Log Group (source of logs)
# ------------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "this" {
  name              = var.log_group_name
  retention_in_days = 30
  tags              = var.tags
}

# ------------------------------------------------------------------------------
# Kinesis Firehose Delivery Stream (to S3)
# ------------------------------------------------------------------------------

resource "aws_kinesis_firehose_delivery_stream" "this" {
  name        = "${replace(var.log_group_name, "/", "-")}-s3-archive-stream"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn            = var.firehose_iam_role_arn
    bucket_arn          = var.archive_s3_bucket_arn
    prefix              = "archived-logs/${replace(var.log_group_name, "/", "_")}/!{timestamp:yyyy/MM/dd}/"
    error_output_prefix = "archived-logs-errors/${replace(var.log_group_name, "/", "_")}/!{timestamp:yyyy/MM/dd}/!{firehose:error-output-type}"
    compression_format  = "GZIP"
  }

  tags = var.tags
}

# ------------------------------------------------------------------------------
# Log Subscription Filter (forwards every log event to Firehose)
# ------------------------------------------------------------------------------

resource "aws_cloudwatch_log_subscription_filter" "this" {
  name            = "${replace(var.log_group_name, "/", "-")}-s3-filter"
  log_group_name  = aws_cloudwatch_log_group.this.name
  filter_pattern  = "" # Empty pattern matches all log events.
  destination_arn = aws_kinesis_firehose_delivery_stream.this.arn
  role_arn        = var.logs_to_firehose_role_arn

  depends_on = [aws_kinesis_firehose_delivery_stream.this]
}
