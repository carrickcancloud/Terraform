# Creates an RDS database instance and its required subnet group.

resource "aws_db_subnet_group" "this" {
  name       = "${var.name_prefix}-sng"
  subnet_ids = var.db_subnet_ids
  tags       = var.common_tags
}

# Creates a secret to store the auto-generated database password.
resource "aws_secretsmanager_secret" "db_password" {
  name        = "${var.name_prefix}-master-password"
  description = "Master password for the ${var.name_prefix} RDS instance."
  tags        = var.common_tags
}

resource "aws_db_instance" "this" {
  identifier           = "${var.name_prefix}-instance"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = var.db_instance_class
  db_subnet_group_name = aws_db_subnet_group.this.name

  allocated_storage    = 20
  storage_type         = "gp3"
  storage_encrypted      = true

  db_name  = var.db_name
  username = var.db_username
  manage_master_user_password = true # Let RDS generate and manage the password.
  master_user_secret_kms_key_id = aws_secretsmanager_secret.db_password.kms_key_id # Associate with our secret

  vpc_security_group_ids = var.vpc_security_group_ids

  # Use the direct 'multi_az_deployment' variable for these settings.
  multi_az               = var.multi_az_deployment
  deletion_protection    = var.multi_az_deployment # Enable deletion protection along with Multi-AZ
  skip_final_snapshot    = !var.multi_az_deployment # Only skip snapshot if not Multi-AZ
  backup_retention_period = var.multi_az_deployment ? 7 : 0 # Keep backups for 7 days if Multi-AZ

  tags = var.common_tags
}
