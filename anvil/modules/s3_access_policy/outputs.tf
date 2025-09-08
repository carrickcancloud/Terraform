# This file defines the outputs for the S3 access policy module.

output "arn" {
  description = "The ARN of the created IAM policy."
  value       = aws_iam_policy.this.arn
}
