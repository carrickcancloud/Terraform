# This file contains the logic for the log archiving pipeline.

# 1. This resource manages the CloudWatch Log Group itself.
#    We use this to set the "hot" retention period to 30 days.
resource "aws_cloudwatch_log_group" "this" {
  name              = var.log_group_name
  retention_in_days = 30
}

# 2. This is the Kinesis Data Firehose Delivery Stream. It receives logs
#    and forwards them to S3 for long-term archiving.
resource "aws_kinesis_firehose_delivery_stream" "this" {
  name        = "${replace(var.log_group_name, "/", "-")}-s3-archive-stream"
  destination = "extended_s3"

  # This block is always required when destination is "extended_s3".
  extended_s3_configuration {
    role_arn   = var.firehose_iam_role_arn
    bucket_arn = var.archive_s3_bucket_arn
    # Organizes logs by date for efficient querying with Athena.
    prefix     = "archived-logs/${replace(var.log_group_name, "/", "_")}/!{timestamp:yyyy/MM/dd}/"
    error_output_prefix = "archived-logs-errors/${replace(var.log_group_name, "/", "_")}/!{timestamp:yyyy/MM/dd}/!{firehose:error-output-type}"
    compression_format = "GZIP"
  }
}

# 3. This is the subscription filter that connects the Log Group to the Firehose stream.
#    It sends every log event from CloudWatch to Kinesis Firehose.
resource "aws_cloudwatch_log_subscription_filter" "this" {
  name            = "${replace(var.log_group_name, "/", "-")}-s3-filter"
  log_group_name  = aws_cloudwatch_log_group.this.name
  filter_pattern  = "" # An empty pattern matches all log events.
  destination_arn = aws_kinesis_firehose_delivery_stream.this.arn
  role_arn        = var.logs_to_firehose_role_arn
  
  depends_on = [aws_kinesis_firehose_delivery_stream.this]
}
