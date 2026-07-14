variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "s3_bucket_name" {
  description = "S3 bucket for Terraform state"
  type        = string
  default     = "memos-tfstate-bucket"
}

variable "ecr_repository_name" {
  description = "ECR repository name"
  type        = string
  default     = "memos"
}

variable "github_org" {
  description = "GitHub organization"
  type        = string
  default     = "Ike-DevCloudIQ"
}

variable "github_repo" {
  description = "GitHub repository"
  type        = string
  default     = "memos-deployment"
}