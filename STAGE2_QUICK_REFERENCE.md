# Stage 2: Terraform - QUICK REFERENCE

> **Copy-paste this entire section to set up Terraform**

---

## Part 0: Prerequisites

### Step 0.1: Verify you have Terraform installed

```bash
terraform -v
```

**Expected output:**
```
Terraform v1.15.6
```

**If not installed:**
```bash
# macOS
brew install terraform

# Verify
terraform -v
```

### Step 0.2: Verify AWS CLI is configured

```bash
aws sts get-caller-identity
```

**Expected output:**
```json
{
    "UserId": "...",
    "Account": "YOUR_ACCOUNT_ID",
    "Arn": "arn:aws:iam::YOUR_ACCOUNT_ID:user/..."
}
```

### Step 0.3: Create AWS account and configure

```bash
# Configure AWS credentials (if not done)
aws configure

# Enter:
# AWS Access Key ID: [your key]
# AWS Secret Access Key: [your secret]
# Default region: us-west-1
# Default output format: json
```

---

## Part 1: Create Bootstrap Terraform Files

### Step 1.1: Create terraform/bootstrap directory

```bash
cd ~/Desktop/Nouriva/memos-deployment
mkdir -p terraform/bootstrap
```

### Step 1.2: Create provider.tf

```bash
cat > terraform/bootstrap/provider.tf << 'EOF'
terraform {
  required_version = ">= 1.15"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
EOF
```

### Step 1.3: Create variables.tf

```bash
cat > terraform/bootstrap/variables.tf << 'EOF'
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
  description = "Environment name"
  type        = string
  default     = "dev"
}
EOF
```

### Step 1.4: Create main.tf (Bootstrap)

```bash
cat > terraform/bootstrap/main.tf << 'EOF'
# Get current AWS account ID
data "aws_caller_identity" "current" {}

# S3 bucket for Terraform state
resource "aws_s3_bucket" "terraform_state" {
  bucket = "${data.aws_caller_identity.current.account_id}-memos-tfstate"

  tags = {
    Name        = "memos-terraform-state"
    Environment = var.environment
  }
}

# Enable versioning (can rollback state)
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypt state (security!)
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access (security!)
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle rule to delete old versions
resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    id     = "delete-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# ECR repository for Docker images
resource "aws_ecr_repository" "memos" {
  name                 = "${var.project_name}-ecr"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "memos-ecr"
    Environment = var.environment
  }
}

# ECR lifecycle policy (clean up old images)
resource "aws_ecr_lifecycle_policy" "memos" {
  repository = aws_ecr_repository.memos.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 5 images, delete rest"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 5
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# GitHub OIDC provider (for CI/CD)
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = {
    Name = "github-oidc"
  }
}

# IAM role for GitHub Actions
resource "aws_iam_role" "github_actions" {
  name = "${var.project_name}-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:Ike-DevCloudIQ/memos-deployment:ref:refs/heads/main"
          }
        }
      }
    ]
  })

  tags = {
    Environment = var.environment
  }
}

# ECR push permissions for GitHub Actions
resource "aws_iam_role_policy" "github_actions_ecr" {
  name = "${var.project_name}-github-actions-ecr-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories",
          "ecr:GetAuthorizationToken"
        ]
        Resource = aws_ecr_repository.memos.arn
      }
    ]
  })
}
EOF
```

### Step 1.5: Create outputs.tf (Bootstrap)

```bash
cat > terraform/bootstrap/outputs.tf << 'EOF'
output "s3_bucket_name" {
  value       = aws_s3_bucket.terraform_state.id
  description = "Name of S3 bucket for Terraform state"
}

output "s3_bucket_region" {
  value       = aws_s3_bucket.terraform_state.region
  description = "Region of S3 bucket"
}

output "ecr_repository_url" {
  value       = aws_ecr_repository.memos.repository_url
  description = "URL of ECR repository"
}

output "ecr_repository_name" {
  value       = aws_ecr_repository.memos.name
  description = "Name of ECR repository"
}

output "github_actions_role_arn" {
  value       = aws_iam_role.github_actions.arn
  description = "ARN of GitHub Actions role"
}

output "github_oidc_provider_arn" {
  value       = aws_iam_openid_connect_provider.github.arn
  description = "ARN of GitHub OIDC provider"
}
EOF
```

---

## Part 2: Deploy Bootstrap

### Step 2.1: Initialize Terraform (Bootstrap)

```bash
cd ~/Desktop/Nouriva/memos-deployment
terraform -chdir=terraform/bootstrap init
```

**Expected output:**
```
Terraform has been successfully configured!
You may now begin working with Terraform.
```

### Step 2.2: Validate (Check for syntax errors)

```bash
terraform -chdir=terraform/bootstrap validate
```

**Expected output:**
```
Success! The configuration is valid.
```

### Step 2.3: Plan (Review what will be created)

```bash
terraform -chdir=terraform/bootstrap plan
```

**Expected output:**
```
Plan: 9 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + ecr_repository_name = "memos-ecr"
  + ecr_repository_url  = "123456789.dkr.ecr.us-west-1.amazonaws.com/memos-ecr"
  + s3_bucket_name      = "123456789-memos-tfstate"
  ...
```

**Review:** Make sure you see S3, ECR, IAM role, and OIDC provider

### Step 2.4: Apply (Actually create resources)

```bash
terraform -chdir=terraform/bootstrap apply
```

**When prompted:** Type `yes` and press Enter

**Expected output:**
```
Apply complete! Resources: 9 added, 0 changed, 0 destroyed.

Outputs:
ecr_repository_name = "memos-ecr"
ecr_repository_url = "123456789.dkr.ecr.us-west-1.amazonaws.com/memos-ecr"
github_actions_role_arn = "arn:aws:iam::123456789:role/memos-github-actions-role"
s3_bucket_name = "123456789-memos-tfstate"
s3_bucket_region = "us-west-1"
```

**Save these outputs!** You'll need them next.

### Step 2.5: Verify in AWS Console

```bash
# List S3 buckets
aws s3 ls | grep memos

# List ECR repositories
aws ecr describe-repositories --region us-west-1
```

---

## Part 3: Create Main Infrastructure Terraform Files

### Step 3.1: Create terraform/ directory structure

```bash
cd ~/Desktop/Nouriva/memos-deployment
mkdir -p terraform/modules/vpc
mkdir -p terraform/modules/eks
mkdir -p terraform/modules/rds
```

### Step 3.2: Create main terraform provider.tf

```bash
cat > terraform/provider.tf << 'EOF'
terraform {
  required_version = ">= 1.15"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }

  backend "s3" {
    # Will be configured during init
  }
}

provider "aws" {
  region = var.aws_region
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
  token                  = data.aws_eks_cluster_auth.main.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
    token                  = data.aws_eks_cluster_auth.main.token
  }
}

data "aws_eks_cluster_auth" "main" {
  name = module.eks.cluster_name
}
EOF
```

### Step 3.3: Create main terraform variables.tf

```bash
cat > terraform/variables.tf << 'EOF'
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
EOF
```

### Step 3.4: Create modules/vpc/main.tf

```bash
cat > terraform/modules/vpc/main.tf << 'EOF'
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# Public Subnets (for load balancers)
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 1)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-${count.index + 1}"
  }
}

# Private Subnets (for EKS nodes)
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 11)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.project_name}-private-${count.index + 1}"
  }
}

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  count  = 2
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-eip-${count.index + 1}"
  }
}

# NAT Gateways (for private subnets to reach internet)
resource "aws_nat_gateway" "main" {
  count         = 2
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "${var.project_name}-nat-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.main]
}

# Route table for public subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block      = "0.0.0.0/0"
    gateway_id      = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# Associate public subnets with public route table
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Route tables for private subnets
resource "aws_route_table" "private" {
  count  = 2
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = {
    Name = "${var.project_name}-private-rt-${count.index + 1}"
  }
}

# Associate private subnets with private route tables
resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Get available AZs
data "aws_availability_zones" "available" {
  state = "available"
}
EOF
```

### Step 3.5: Create modules/vpc/variables.tf

```bash
cat > terraform/modules/vpc/variables.tf << 'EOF'
variable "project_name" {
  type = string
}

variable "vpc_cidr" {
  type = string
}
EOF
```

### Step 3.6: Create modules/vpc/outputs.tf

```bash
cat > terraform/modules/vpc/outputs.tf << 'EOF'
output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}
EOF
```

### Step 3.7: Create main terraform/main.tf (simplified - Stage 2 intro)

```bash
cat > terraform/main.tf << 'EOF'
module "vpc" {
  source = "./modules/vpc"

  project_name = var.project_name
  vpc_cidr     = var.vpc_cidr
}

# More modules will be added in next sections
# For now, we focus on VPC to understand modules
EOF
```

### Step 3.8: Create terraform/outputs.tf

```bash
cat > terraform/outputs.tf << 'EOF'
output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnets" {
  value = module.vpc.public_subnet_ids
}

output "private_subnets" {
  value = module.vpc.private_subnet_ids
}
EOF
```

---

## Part 4: Deploy Main Infrastructure (VPC only for Stage 2)

### Step 4.1: Get S3 bucket name from Bootstrap

```bash
# Show bootstrap outputs
terraform -chdir=terraform/bootstrap output

# Save S3 bucket name (you'll use it next)
BUCKET_NAME=$(terraform -chdir=terraform/bootstrap output -raw s3_bucket_name)
echo $BUCKET_NAME
```

**Should print something like:** `123456789-memos-tfstate`

### Step 4.2: Initialize Main Terraform with S3 backend

```bash
# Get the S3 bucket name
BUCKET_NAME=$(terraform -chdir=terraform/bootstrap output -raw s3_bucket_name)

# Initialize with S3 backend
terraform -chdir=terraform init \
  -backend-config="bucket=$BUCKET_NAME" \
  -backend-config="key=terraform.tfstate" \
  -backend-config="region=us-west-1" \
  -backend-config="encrypt=true"
```

**Expected output:**
```
Successfully configured the backend "s3"!
Terraform has been successfully configured!
```

### Step 4.3: Plan Main Infrastructure

```bash
terraform -chdir=terraform plan
```

**Expected output:**
```
Plan: 12 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + private_subnets = [
      + "subnet-...",
      + "subnet-..."
    ]
  + public_subnets = [
      + "subnet-...",
      + "subnet-..."
    ]
  + vpc_id = (known after apply)
```

### Step 4.4: Apply Main Infrastructure

```bash
terraform -chdir=terraform apply
```

**When prompted:** Type `yes`

**Expected output:**
```
Apply complete! Resources: 12 added, 0 changed, 0 destroyed.

Outputs:
private_subnets = [
  "subnet-...",
  "subnet-..."
]
public_subnets = [
  "subnet-...",
  "subnet-..."
]
vpc_id = "vpc-..."
```

---

## Part 5: Verify in AWS Console

### Step 5.1: Check VPC

```bash
aws ec2 describe-vpcs \
  --filters "Name=cidr-block,Values=10.0.0.0/16" \
  --region us-west-1 \
  --query 'Vpcs[0].VpcId'
```

**Expected:** VPC ID like `vpc-12345abc`

### Step 5.2: Check Subnets

```bash
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$(terraform -chdir=terraform output -raw vpc_id)" \
  --region us-west-1 \
  --query 'Subnets[*].[SubnetId,AvailabilityZone,CidrBlock]' \
  --output table
```

**Expected:**
```
|  SubnetId    |  AvailabilityZone  |  CidrBlock    |
|  subnet-...  |  us-west-1a        |  10.0.1.0/24  |
|  subnet-...  |  us-west-1b        |  10.0.2.0/24  |
```

### Step 5.3: Check Route Tables

```bash
aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$(terraform -chdir=terraform output -raw vpc_id)" \
  --region us-west-1
```

---

## ✅ Part 1 (VPC) Complete!

**What you accomplished:**
- ✅ Created bootstrap infrastructure (S3, ECR, IAM)
- ✅ Deployed VPC with public and private subnets
- ✅ NAT Gateways for private subnet internet access
- ✅ Route tables properly configured

---

## What's Next?

In the full Stage 2 (next iteration):
- ✅ EKS module (Kubernetes cluster)
- ✅ RDS module (PostgreSQL database)
- ✅ Security groups
- ✅ IAM roles for pods

For now: Commit this work to git!

```bash
cd ~/Desktop/Nouriva/memos-deployment
git add terraform/
git commit -m "Stage 2 WIP: Add Terraform bootstrap and VPC infrastructure

- Create bootstrap stack: S3, ECR, IAM roles, OIDC provider
- Create VPC module with public/private subnets
- Deploy VPC across 2 availability zones
- Configure NAT gateways for private subnet internet access

Status: VPC working, next: EKS and RDS modules"

git push origin main
```

---

## Troubleshooting

### Error: "Backend initialization required"
```bash
# Run this to reconfigure backend
terraform -chdir=terraform init -reconfigure
```

### Error: "Resource already exists"
```bash
# This means S3 or other resource exists. 
# Either destroy and retry:
terraform -chdir=terraform/bootstrap destroy

# Or import the existing resource:
terraform import aws_s3_bucket.terraform_state bucket-name
```

### Error: "Permission denied"
```bash
# Check AWS credentials are configured
aws sts get-caller-identity

# Verify you have IAM permissions to create these resources
```

---

## Summary

**Stage 2 teaches you:**
- ✅ Terraform syntax and workflow
- ✅ Bootstrap infrastructure patterns
- ✅ Modular infrastructure design
- ✅ Provider and backend configuration
- ✅ VPC networking fundamentals
- ✅ Public/private subnet design
- ✅ NAT gateway for security

**Next:** EKS and RDS modules will follow the same pattern!
