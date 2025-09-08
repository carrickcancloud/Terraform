# This file creates an IAM policy that grants read/write access to a specific S3 bucket.

resource "aws_iam_policy" "this" {
  name        = "${var.name_prefix}-s3-access-policy"
  description = "Grants read/write access to a specific S3 bucket."
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
        Resource = "${var.bucket_arn}/*"
      },
      {
        Effect   = "Allow",
        Action   = "s3:ListBucket",
        Resource = var.bucket_arn
      }
    ]
  })
}
