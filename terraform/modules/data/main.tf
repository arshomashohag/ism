locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ── Random RDS credentials ────────────────────────────────────

resource "random_string" "db_name" {
  length  = 8
  upper   = false
  special = false
  numeric = false
}

resource "random_string" "db_username" {
  length  = 12
  upper   = false
  special = false
  numeric = false
}

resource "random_password" "db" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# ── RDS subnet group ──────────────────────────────────────────

resource "aws_db_subnet_group" "main" {
  name       = "${local.name_prefix}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = { Name = "${local.name_prefix}-db-subnet-group" }
}

# ── RDS parameter group (enables PostGIS) ────────────────────

resource "aws_db_parameter_group" "postgres16" {
  name   = "${local.name_prefix}-postgres16"
  family = "postgres16"

  parameter {
    name         = "shared_preload_libraries"
    value        = "pg_stat_statements"
    apply_method = "pending-reboot"
  }

  tags = { Name = "${local.name_prefix}-postgres16" }
}

# ── RDS PostgreSQL 16 instance ────────────────────────────────

resource "aws_db_instance" "main" {
  identifier     = "${local.name_prefix}-postgres"
  engine         = "postgres"
  engine_version = "16.3"
  instance_class = var.db_instance_class

  db_name  = "db${random_string.db_name.result}"
  username = "u${random_string.db_username.result}"
  password = random_password.db.result

  allocated_storage     = var.db_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.rds_sg_id]
  parameter_group_name   = aws_db_parameter_group.postgres16.name

  backup_retention_period = var.db_backup_retention_days
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  deletion_protection       = false
  skip_final_snapshot       = true
  delete_automated_backups  = true

  performance_insights_enabled = false

  tags = { Name = "${local.name_prefix}-postgres" }
}

# ── Secrets Manager — DB credentials ─────────────────────────

resource "aws_secretsmanager_secret" "db_url" {
  name                    = "${local.name_prefix}/db-url"
  description             = "PostgreSQL connection URL for IMS backend"
  recovery_window_in_days = 0

  tags = { Name = "${local.name_prefix}-db-url" }
}

resource "aws_secretsmanager_secret_version" "db_url" {
  secret_id = aws_secretsmanager_secret.db_url.id
  secret_string = jsonencode({
    url      = "postgresql+psycopg2://u${random_string.db_username.result}:${random_password.db.result}@${aws_db_instance.main.address}:5432/db${random_string.db_name.result}"
    sync_url = "postgresql+psycopg2://u${random_string.db_username.result}:${random_password.db.result}@${aws_db_instance.main.address}:5432/db${random_string.db_name.result}"
    host     = aws_db_instance.main.address
    port     = 5432
    db_name  = "db${random_string.db_name.result}"
    username = "u${random_string.db_username.result}"
    password = random_password.db.result
  })
}

# ── Secrets Manager — JWT RSA keys ────────────────────────────

resource "aws_secretsmanager_secret" "jwt_private_key" {
  name                    = "${local.name_prefix}/jwt-private-key"
  description             = "RSA private key for JWT signing"
  recovery_window_in_days = 0

  tags = { Name = "${local.name_prefix}-jwt-private-key" }
}

resource "aws_secretsmanager_secret" "jwt_public_key" {
  name                    = "${local.name_prefix}/jwt-public-key"
  description             = "RSA public key for JWT verification"
  recovery_window_in_days = 0

  tags = { Name = "${local.name_prefix}-jwt-public-key" }
}

# ── S3 bucket for Flutter web build ──────────────────────────

resource "aws_s3_bucket" "frontend" {
  bucket = "${local.name_prefix}-frontend-${data.aws_caller_identity.current.account_id}"

  tags = { Name = "${local.name_prefix}-frontend" }
}

resource "aws_s3_bucket_versioning" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

data "aws_caller_identity" "current" {}
