# ==============================================================================
# Project Anvil - Application Layer (Dev)
# modules/rds/main.tf
#
# This module creates an RDS database instance and its required subnet group
# for the application's data tier. Used by the dev environment.
#
# Author: Carrick Bradley
# Last Updated: 2025-09-24
# ==============================================================================

# ------------------------------------------------------------------------------
# DB Subnet Group
# ------------------------------------------------------------------------------

resource "aws_db_subnet_group" "this" {
  name       = "${var.name_prefix}-sng"
  subnet_ids = var.db_subnet_ids
  tags       = var.tags
}

# ------------------------------------------------------------------------------
# Secrets Manager Secret for DB Master Password
# ------------------------------------------------------------------------------
# Creates a secret container to store the auto-generated database master password.
# RDS manages the actual password and stores it in this secret.

resource "aws_secretsmanager_secret" "db_password" {
  name        = "${var.name_prefix}-master-password"
  description = "Master password for the ${var.name_prefix} RDS instance."
  tags        = var.tags
}

# ------------------------------------------------------------------------------
# RDS Database Instance
# ------------------------------------------------------------------------------

resource "aws_db_instance" "this" {
  identifier           = "${var.name_prefix}-instance"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = var.db_instance_class
  db_subnet_group_name = aws_db_subnet_group.this.name

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username

  # Let RDS generate and manage the password, storing it in aws_secretsmanager_secret.db_password
  manage_master_user_password   = true
  master_user_secret_kms_key_id = aws_secretsmanager_secret.db_password.kms_key_id

  vpc_security_group_ids = var.vpc_security_group_ids

  multi_az                = var.multi_az_deployment
  deletion_protection     = var.multi_az_deployment
  skip_final_snapshot     = !var.multi_az_deployment
  backup_retention_period = var.multi_az_deployment ? 7 : 0

  tags = var.tags
}
