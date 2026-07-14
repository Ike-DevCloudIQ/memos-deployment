variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "memos"
}

variable "environment" {
  description = "Environment"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "eks_instance_type" {
  description = "EKS node instance type"
  type        = string
  default     = "t3.medium"
}

variable "eks_desired_capacity" {
  description = "Desired EKS node capacity"
  type        = number
  default     = 2
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.31"
}

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_storage_gb" {
  description = "RDS storage in GB"
  type        = number
  default     = 20
}

variable "container_image" {
  description = "Memos container image"
  type        = string
  default     = "ghcr.io/usememos/memos:latest"
}
