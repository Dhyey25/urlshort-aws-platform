output "rds_endpoint" {
  value = aws_db_instance.main.endpoint
}

output "rds_address" {
  value = aws_db_instance.main.address
}

output "rds_port" {
  value = aws_db_instance.main.port
}

output "database_name" {
  value = aws_db_instance.main.db_name
}

output "redis_primary_endpoint" {
  value = aws_elasticache_replication_group.main.primary_endpoint_address
}

output "redis_port" {
  value = aws_elasticache_replication_group.main.port
}

# Secret ARNs are what ECS task definitions consume
output "rds_credentials_secret_arn" {
  value = aws_secretsmanager_secret.rds_credentials.arn
}

output "redis_credentials_secret_arn" {
  value = aws_secretsmanager_secret.redis_credentials.arn
}

output "app_secrets_arn" {
  value = aws_secretsmanager_secret.app_secrets.arn
}
