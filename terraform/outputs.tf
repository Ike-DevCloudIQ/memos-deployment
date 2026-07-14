output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnets" {
  value = module.vpc.public_subnet_ids
}

output "private_subnets" {
  value = module.vpc.private_subnet_ids
}

# EKS Outputs
output "eks_cluster_name" {
  value       = module.eks.cluster_name
  description = "EKS cluster name"
}

output "eks_cluster_endpoint" {
  value       = module.eks.cluster_endpoint
  description = "EKS cluster endpoint"
}

output "eks_cluster_ca_certificate" {
  value       = module.eks.cluster_ca_certificate
  description = "EKS cluster CA certificate"
  sensitive   = true
}

output "eks_oidc_issuer_url" {
  value       = module.eks.cluster_oidc_issuer_url
  description = "EKS OIDC issuer URL for IRSA"
}

output "pod_execution_role_arn" {
  value       = module.eks.pod_execution_role_arn
  description = "ARN of IAM role for pod execution"
}

# RDS Outputs
output "rds_endpoint" {
  value       = module.rds.database_endpoint
  description = "RDS database endpoint"
}

output "rds_address" {
  value       = module.rds.database_address
  description = "RDS database address"
}

output "rds_port" {
  value       = module.rds.database_port
  description = "RDS database port"
}

output "rds_database_name" {
  value       = module.rds.database_name
  description = "RDS database name"
}

output "rds_username" {
  value       = module.rds.database_username
  description = "RDS database username"
  sensitive   = true
}

output "rds_password" {
  value       = module.rds.database_password
  description = "RDS database password"
  sensitive   = true
}

output "rds_connection_string" {
  value       = module.rds.database_connection_string
  description = "RDS database connection string"
  sensitive   = true
}

output "rds_secret_arn" {
  value       = module.rds.secret_arn
  description = "ARN of Secrets Manager secret with database credentials"
}
