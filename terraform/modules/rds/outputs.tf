output "database_endpoint" {
  value       = aws_db_instance.main.endpoint
  description = "Database endpoint (host:port)"
}

output "database_address" {
  value       = aws_db_instance.main.address
  description = "Database host address"
}

output "database_port" {
  value       = aws_db_instance.main.port
  description = "Database port"
}

output "database_name" {
  value       = aws_db_instance.main.db_name
  description = "Database name"
}

output "database_username" {
  value       = aws_db_instance.main.username
  description = "Database master username"
  sensitive   = true
}

output "database_password" {
  value       = random_password.db_password.result
  description = "Database master password"
  sensitive   = true
}

output "database_connection_string" {
  value       = "postgresql://${var.database_username}:${random_password.db_password.result}@${aws_db_instance.main.address}:${aws_db_instance.main.port}/${var.database_name}"
  description = "PostgreSQL connection string"
  sensitive   = true
}

output "secret_arn" {
  value       = aws_secretsmanager_secret.db_password.arn
  description = "ARN of Secrets Manager secret containing database credentials"
}

output "security_group_id" {
  value       = aws_security_group.rds.id
  description = "Security group ID for RDS"
}

output "db_instance_id" {
  value       = aws_db_instance.main.id
  description = "RDS instance identifier"
}
