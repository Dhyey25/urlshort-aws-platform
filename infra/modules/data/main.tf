terraform {
  required_version = ">= 1.9.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

locals {
  name_prefix = "${var.project}-${var.environment}"
}

resource "random_password" "rds_master" {
  length  = 32
  special = true
  # RDS Postgres has restrictions on special chars in master password
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "rds_credentials" {
  name        = "${local.name_prefix}/rds/credentials"
  description = "RDS master credentials for ${local.name_prefix}"

  recovery_window_in_days = 7 # set to 0 if you want immediate deletion in staging
}

resource "aws_secretsmanager_secret_version" "rds_credentials" {
  secret_id = aws_secretsmanager_secret.rds_credentials.id
  secret_string = jsonencode({
    username = var.rds_master_username
    password = random_password.rds_master.result
  })
}

resource "aws_db_subnet_group" "main" {
  name       = "${local.name_prefix}-rds-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "${local.name_prefix}-rds-subnet-group"
  }
}

resource "aws_db_parameter_group" "main" {
  name   = "${local.name_prefix}-rds-pg16"
  family = "postgres16"

  parameter {
    name  = "log_statement"
    value = "ddl" # log schema changes; "all" is too noisy
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000" # log queries slower than 1s
  }
}

resource "aws_db_instance" "main" {
  identifier     = "${local.name_prefix}-postgres"
  engine         = "postgres"
  engine_version = "16.3"
  instance_class = var.db_instance_class

  allocated_storage     = 20
  max_allocated_storage = 100 # autoscaling cap
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.database_name
  username = var.rds_master_username
  password = random_password.rds_master.result
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.main.name
  parameter_group_name   = aws_db_parameter_group.main.name
  vpc_security_group_ids = [var.rds_security_group_id]
  publicly_accessible    = false

  multi_az                = var.multi_az
  backup_retention_period = var.backup_retention_days
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = !var.deletion_protection
  final_snapshot_identifier = var.deletion_protection ? "${local.name_prefix}-postgres-final-${formatdate("YYYY-MM-DD", timestamp())}" : null

  performance_insights_enabled          = true
  performance_insights_retention_period = 7 # free tier

  # Add this line to encrypt the performance data
  performance_insights_kms_key_id = "arn:aws:kms:us-east-1:825765386578:alias/aws/rds"

  # Ensure storage is also encrypted to satisfy other security checks

  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = {
    Name = "${local.name_prefix}-postgres"
  }

  lifecycle {
    ignore_changes = [final_snapshot_identifier]
  }
}

resource "random_password" "redis_auth" {
  length  = 32
  special = false # Redis AUTH dislikes some special chars
}

resource "aws_secretsmanager_secret" "redis_credentials" {
  name        = "${local.name_prefix}/redis/credentials"
  description = "Redis AUTH token for ${local.name_prefix}"

  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "redis_credentials" {
  secret_id = aws_secretsmanager_secret.redis_credentials.id
  secret_string = jsonencode({
    auth_token = random_password.redis_auth.result
  })
}

resource "aws_elasticache_subnet_group" "main" {
  name       = "${local.name_prefix}-redis-subnet-group"
  subnet_ids = var.private_subnet_ids
}

resource "aws_elasticache_replication_group" "main" {
  replication_group_id = "${local.name_prefix}-redis"
  description          = "Redis for ${local.name_prefix}"

  engine               = "redis"
  engine_version       = "7.1"
  node_type            = var.redis_node_type
  num_cache_clusters   = var.redis_num_nodes
  port                 = 6379
  parameter_group_name = "default.redis7"

  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [var.redis_security_group_id]

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = random_password.redis_auth.result

  automatic_failover_enabled = var.redis_num_nodes > 1
  multi_az_enabled           = var.redis_num_nodes > 1

  snapshot_retention_limit = var.environment == "prod" ? 7 : 1

  tags = {
    Name = "${local.name_prefix}-redis"
  }
}

resource "random_password" "jwt_secret" {
  length  = 64
  special = false
}

resource "aws_secretsmanager_secret" "app_secrets" {
  name        = "${local.name_prefix}/app/secrets"
  description = "Application-level secrets"

  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "app_secrets" {
  secret_id = aws_secretsmanager_secret.app_secrets.id
  secret_string = jsonencode({
    jwt_secret = random_password.jwt_secret.result
    # Add any other app secrets here
  })
}
