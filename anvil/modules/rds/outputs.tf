# Defines the outputs for the RDS module.

output "db_instance_id" {
  description = "The identifier for the created DB instance."
  value       = aws_db_instance.this.id
}

output "db_instance_endpoint" {
  description = "The connection endpoint for the database instance."
  value       = aws_db_instance.this.endpoint
}

output "db_instance_port" {
  description = "The port the database is listening on."
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "The name of the database."
  value       = aws_db_instance.this.db_name
}

output "db_username" {
  description = "The username for the master database user."
  value       = aws_db_instance.this.username
}

output "db_password_secret_arn" {
  description = "The ARN of the secret containing the database's master password."
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}
