# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

# Security group for RDS
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = var.private_subnet_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-rds-sg"
  }
}

# RDS Parameter Group for PostgreSQL
resource "aws_db_parameter_group" "main" {
  family = "postgres15"
  name   = "${var.project_name}-postgres-params"

  # Optimize for Memos app
  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements"
  }

  tags = {
    Name = "${var.project_name}-postgres-params"
  }
}

# RDS Database Instance
resource "aws_db_instance" "main" {
  identifier = "${var.project_name}-postgres"

  # Database configuration
  engine               = "postgres"
  engine_version       = "15"
  instance_class       = var.instance_class
  allocated_storage    = var.storage_gb
  storage_type         = "gp3"
  storage_encrypted    = true
  publicly_accessible  = false

  # Credentials
  db_name  = var.database_name
  username = var.database_username
  password = random_password.db_password.result

  # Network
  db_subnet_group_name            = aws_db_subnet_group.main.name
  vpc_security_group_ids          = [aws_security_group.rds.id]
  parameter_group_name            = aws_db_parameter_group.main.name
  skip_final_snapshot             = false
  final_snapshot_identifier       = "${var.project_name}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  # Backups and maintenance
  backup_retention_period = var.backup_retention_days
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:00-mon:05:00"
  multi_az                = var.multi_az

  # Monitoring
  enabled_cloudwatch_logs_exports = ["postgresql"]
  monitoring_interval             = 60
  monitoring_role_arn             = aws_iam_role.rds_monitoring.arn

  # Deletion protection
  deletion_protection = true

  tags = {
    Name = "${var.project_name}-postgres"
  }

  depends_on = [aws_security_group.rds]
}

# Generate random password for database
resource "random_password" "db_password" {
  length  = 32
  special = true
}

# Store password in Secrets Manager (for apps to retrieve)
resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${var.project_name}/rds/password"
  recovery_window_in_days = 0

  tags = {
    Name = "${var.project_name}-rds-password"
  }
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id = aws_secretsmanager_secret.db_password.id

  secret_string = jsonencode({
    username = var.database_username
    password = random_password.db_password.result
    engine   = "postgres"
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    dbname   = var.database_name
  })
}

# IAM role for RDS monitoring
resource "aws_iam_role" "rds_monitoring" {
  name = "${var.project_name}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-rds-monitoring-role"
  }
}

# Attach monitoring policy
resource "aws_iam_role_policy_attachment" "rds_monitoring_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
  role       = aws_iam_role.rds_monitoring.name
}
