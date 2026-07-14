module "vpc" {
  source = "./modules/vpc"

  project_name = var.project_name
  vpc_cidr     = var.vpc_cidr
}

module "eks" {
  source = "./modules/eks"

  project_name           = var.project_name
  vpc_id                 = module.vpc.vpc_id
  vpc_cidr               = var.vpc_cidr
  private_subnet_ids     = module.vpc.private_subnet_ids
  private_subnet_cidrs   = [for subnet_id in module.vpc.private_subnet_ids : cidrsubnet(var.vpc_cidr, 8, index(module.vpc.private_subnet_ids, subnet_id) + 11)]
  kubernetes_version     = var.kubernetes_version
  instance_type          = var.eks_instance_type
  desired_size           = var.eks_desired_capacity
}

module "rds" {
  source = "./modules/rds"

  project_name         = var.project_name
  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_subnet_ids
  private_subnet_cidrs = [for subnet_id in module.vpc.private_subnet_ids : cidrsubnet(var.vpc_cidr, 8, index(module.vpc.private_subnet_ids, subnet_id) + 11)]
  instance_class       = var.rds_instance_class
  storage_gb           = var.rds_storage_gb
  database_name        = "memos"
  database_username    = "memos_user"
  multi_az             = false
  backup_retention_days = 7
}
