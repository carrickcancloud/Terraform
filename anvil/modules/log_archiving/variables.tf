# This file declares the input variables for the Log Archiving module.

variable "log_group_name" {
  description = "The name of the CloudWatch Log Group to capture logs from."
  type        = string
}

variable "archive_s3_bucket_arn" {
  description = "The ARN of the S3 bucket for long-term log archiving."
  type        = string
}

variable "firehose_iam_role_arn" {
  description = "The ARN of the IAM role that grants Kinesis Firehose permission to write to S3."
  type        = string
}

variable "logs_to_firehose_role_arn" {
  description = "The ARN of the IAM role that grants CloudWatch Logs permission to write to Kinesis Firehose."
  type        = string
}
