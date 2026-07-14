# Stage 2: Terraform - Infrastructure as Code (BEGINNER GUIDE)

> **Welcome to Stage 2!** Here you'll learn to build AWS infrastructure using code instead of clicking buttons.

---

## Table of Contents
- [Why Terraform?](#why-terraform)
- [Key Concepts](#key-concepts)
- [AWS Services Overview](#aws-services-overview)
- [Part 1: Terraform Basics (1 hour)](#part-1-terraform-basics)
- [Part 2: Create Bootstrap Infrastructure (1-2 hours)](#part-2-create-bootstrap-infrastructure)
- [Part 3: Create Main Infrastructure (2-3 hours)](#part-3-create-main-infrastructure)
- [Part 4: Deploy to AWS (1 hour)](#part-4-deploy-to-aws)
- [Part 5: Verify Everything Works (30 min)](#part-5-verify-everything-works)

---

## Why Terraform?

### Problem: Manual AWS Setup

**Without Terraform:**
1. Click AWS Console → Create VPC
2. Click → Create Subnets
3. Click → Create EKS cluster
4. Click → Create RDS database
5. Click → Configure IAM roles
6. Click → Create security groups
... **50+ clicks later**, you have your infrastructure

**Problems:**
- ❌ Takes hours
- ❌ Easy to misconfigure
- ❌ No version control
- ❌ Hard to recreate elsewhere
- ❌ Impossible to replicate in another region

### Solution: Terraform (Infrastructure as Code)

**With Terraform:**
```hcl
# Write code once
terraform apply
# All 50+ resources created automatically ✅
```

**Benefits:**
- ✅ Version controlled (Git)
- ✅ Reproducible (same every time)
- ✅ Documented (code is documentation)
- ✅ Safe (plan before apply)
- ✅ Reusable (modules)
- ✅ Destroyable (cleanup easily)

---

## Key Concepts

### 1. **Infrastructure as Code (IaC)**

```
Traditional DevOps:
  AWS Console (point-and-click) → Infrastructure

Modern DevOps (Infrastructure as Code):
  Code (Terraform) → Infrastructure
```

**Advantage:** Same code = same infrastructure everywhere

---

### 2. **Terraform Workflow**

```
Write Code → Plan → Review → Apply → Infrastructure
   ↓          ↓       ↓       ↓         ↓
 .tf files  terraform  Review  Terraform  AWS
            plan output changes  creates   resources
```

**Three main commands:**
```bash
terraform init     # Initialize (download providers)
terraform plan     # Show what will be created
terraform apply    # Actually create resources
terraform destroy  # Delete all resources
```

---

### 3. **State File**

```
State File = What Terraform created
```

**Think of it like:**
- Git tracks files: `.git/` folder
- Terraform tracks resources: `terraform.tfstate` file

**Important:**
- Terraform reads state to know what exists
- If state is lost, Terraform doesn't know what was created
- Typically stored in AWS S3 (remote) or local (dev)

---

### 4. **Providers**

```
Provider = Connection to a cloud service
```

**Examples:**
```hcl
provider "aws" {
  region = "us-west-1"
}  # Connects to AWS, region us-west-1
```

**Other providers:**
- Google Cloud Platform (GCP)
- Microsoft Azure
- Kubernetes
- Docker

---

### 5. **Resources**

```
Resource = A thing you want to create
```

**Examples:**
```hcl
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}  # Creates a VPC

resource "aws_instance" "web" {
  ami           = "ami-12345"
  instance_type = "t3.micro"
}  # Creates an EC2 instance

resource "aws_db_instance" "postgres" {
  engine = "postgres"
  db_name = "memos"
}  # Creates a database
```

---

### 6. **Variables**

```
Variable = Input you can change
```

**Without variables:**
```hcl
resource "aws_instance" "web" {
  instance_type = "t3.micro"  # Hardcoded
}
```

**With variables:**
```hcl
variable "instance_type" {
  default = "t3.micro"
}

resource "aws_instance" "web" {
  instance_type = var.instance_type  # Can change!
}
```

**Set variable when running:**
```bash
terraform apply -var="instance_type=t3.small"
```

---

### 7. **Outputs**

```
Output = Value Terraform shows you after creating resources
```

**Example:**
```hcl
output "database_endpoint" {
  value = aws_db_instance.postgres.endpoint
}
```

**After terraform apply:**
```
Outputs:
database_endpoint = memos-db.abc123.us-west-1.rds.amazonaws.com
```

---

### 8. **Modules**

```
Module = Reusable package of resources
```

**Without modules:**
```hcl
# VPC code (10 lines)
resource "aws_vpc" "main" { ... }
resource "aws_subnet" "public" { ... }
resource "aws_subnet" "private" { ... }
# ... repeat for all resources
```

**With modules:**
```hcl
module "vpc" {
  source = "./modules/vpc"
}  # All VPC resources created in one line!
```

**Modules are reusable:**
- Use same VPC module in different projects
- No code duplication

---

## AWS Services Overview

### 1. **VPC (Virtual Private Cloud)**
```
VPC = Your own network in the cloud
```

**What it includes:**
- CIDR block: `10.0.0.0/16` (IP range)
- Public subnets: For load balancers (internet-facing)
- Private subnets: For apps/databases (not internet-facing)
- Internet Gateway: For internet access
- NAT Gateway: For private subnets to reach internet

**Why?** Security - isolate resources, control traffic

---

### 2. **EKS (Elastic Kubernetes Service)**
```
EKS = Managed Kubernetes cluster on AWS
```

**What it gives you:**
- Kubernetes control plane (AWS manages it)
- Worker nodes (EC2 instances where pods run)
- Networking integration (uses VPC)
- Load balancing (distributes traffic)

**Why?** Container orchestration - run many containers, auto-scaling

---

### 3. **RDS (Relational Database Service)**
```
RDS = Managed PostgreSQL database
```

**What it gives you:**
- PostgreSQL database
- Automatic backups
- Multi-AZ failover (if one fails, another takes over)
- Easy scaling

**Why?** Don't want to manage database - AWS does it

---

### 4. **ECR (Elastic Container Registry)**
```
ECR = Docker image storage in AWS
```

**Like:** Docker Hub, but private and in your AWS account

**Why?** Store your Docker images where EKS can access them

---

### 5. **IAM (Identity and Access Management)**
```
IAM = Who can do what
```

**Examples:**
- "EKS can access ECR" (role)
- "GitHub Actions can push images to ECR" (role)
- "Pods can read from Secrets Manager" (role)

**Why?** Security - least privilege access

---

### 6. **Security Groups**
```
Security Group = Network firewall
```

**Example:**
- Allow port 5230 from load balancer
- Allow port 5432 from EKS nodes
- Deny everything else

**Why?** Security - control who can talk to what

---

## Architecture We'll Build

```
┌────────────────────────────────────────────────┐
│              AWS Account                       │
│  ┌──────────────────────────────────────────┐  │
│  │         VPC (10.0.0.0/16)                │  │
│  │  ┌─────────────────────────────────────┐ │  │
│  │  │ Public Subnets (Load Balancers)     │ │  │
│  │  │ - us-west-1a: 10.0.1.0/24          │ │  │
│  │  │ - us-west-1b: 10.0.2.0/24          │ │  │
│  │  └─────────────────────────────────────┘ │  │
│  │  ┌─────────────────────────────────────┐ │  │
│  │  │ Private Subnets (EKS Nodes)         │ │  │
│  │  │ - us-west-1a: 10.0.11.0/24         │ │  │
│  │  │ - us-west-1b: 10.0.12.0/24         │ │  │
│  │  └─────────────────────────────────────┘ │  │
│  │  ┌─────────────────────────────────────┐ │  │
│  │  │ EKS Cluster                         │ │  │
│  │  │ - Control Plane (AWS managed)       │ │  │
│  │  │ - Worker Nodes (t3.medium x2)       │ │  │
│  │  │ - Runs Memos pods                   │ │  │
│  │  └─────────────────────────────────────┘ │  │
│  └──────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────┐  │
│  │ RDS PostgreSQL                           │  │
│  │ - Multi-AZ (us-west-1a + failover)      │  │
│  │ - Database for Memos                     │  │
│  └──────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────┐  │
│  │ ECR Repository                           │  │
│  │ - Store memos-deployment:latest image    │  │
│  └──────────────────────────────────────────┘  │
└────────────────────────────────────────────────┘
```

---

# Part 1: Terraform Basics

## What You'll Learn

By the end of Part 1:
- ✅ Understand Terraform syntax
- ✅ Know what `terraform init`, `plan`, `apply` do
- ✅ Understand state management
- ✅ Know how to structure Terraform files

---

## Terraform File Structure

```
terraform/
├── main.tf              # Main resources
├── variables.tf         # Input variables
├── outputs.tf           # Output values
├── provider.tf          # AWS provider config
├── terraform.tfvars     # Variable values
├── terraform.tfstate    # STATE FILE (created by Terraform)
└── modules/
    ├── vpc/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── eks/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── rds/
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

---

## Terraform Syntax (HCL)

### Comments
```hcl
# This is a comment
# Terraform ignores it
```

### Variable Declaration
```hcl
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-1"
}
```

### Resource Declaration
```hcl
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "memos-vpc"
  }
}
```

### Using Variables
```hcl
resource "aws_instance" "web" {
  instance_type = var.instance_type  # Reference variable
}
```

### Using Resource Outputs
```hcl
resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.main.id  # Reference another resource
  cidr_block = "10.0.1.0/24"
}
```

### Output Declaration
```hcl
output "vpc_id" {
  value = aws_vpc.main.id
}
```

---

## Terraform Workflow

### Step 1: Write Code
```bash
# Create main.tf, variables.tf, etc.
# Write resources you want
```

### Step 2: Initialize
```bash
terraform init
```

**What it does:**
- Creates `.terraform/` directory
- Downloads AWS provider
- Sets up local state

**Output:**
```
Terraform has been successfully configured!
```

### Step 3: Plan
```bash
terraform plan
```

**What it does:**
- Reads your code
- Checks what exists on AWS
- Shows what will be created/changed/destroyed

**Output:**
```
Plan: 20 to add, 0 to change, 0 to destroy.
```

**Why?** Review before applying. Safety first!

### Step 4: Review
```bash
# Read the plan output carefully
# Make sure you expect all those changes
```

### Step 5: Apply
```bash
terraform apply
```

**What it does:**
- Creates resources on AWS
- Updates `.tfstate` file

**Output:**
```
Apply complete! Resources: 20 added, 0 changed, 0 destroyed.
```

---

## State Management

### What is terraform.tfstate?

```
A JSON file that tracks what Terraform created
```

**Example:**
```json
{
  "resources": [
    {
      "type": "aws_vpc",
      "name": "main",
      "instances": [
        {
          "attributes": {
            "id": "vpc-12345abc",
            "cidr_block": "10.0.0.0/16"
          }
        }
      ]
    }
  ]
}
```

### Local vs Remote State

**Local (development):**
```
terraform.tfstate → Stored on your computer
```
- Easy to start
- Not shared (only you can apply)
- Lost if computer dies

**Remote (production):**
```
terraform.tfstate → Stored in AWS S3
```
- Team can share
- Backed up
- Locked (prevent simultaneous changes)

**For this project:** We'll use remote S3 state

---

## Bootstrap vs Main Infrastructure

### Bootstrap Stack (First)
```
Creates resources needed for Terraform itself:
- S3 bucket (store state)
- ECR repository (store Docker images)
- IAM roles for GitHub Actions
- OIDC provider for GitHub
```

**Why separate?** Can't store state in S3 until S3 exists!

### Main Stack (Second)
```
Uses bootstrap resources:
- VPC, EKS, RDS
- Uses ECR from bootstrap
- Uses S3 from bootstrap for state
```

---

# Part 2: Create Bootstrap Infrastructure

## Step 2.1: Create Bootstrap Terraform Files

You'll create these files in `terraform/bootstrap/`:

### File 1: `terraform/bootstrap/provider.tf`
```hcl
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
```

### File 2: `terraform/bootstrap/variables.tf`
```hcl
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-1"
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
```

### File 3: `terraform/bootstrap/main.tf`
```hcl
# S3 bucket for Terraform state
resource "aws_s3_bucket" "terraform_state" {
  bucket = "${data.aws_caller_identity.current.account_id}-${var.s3_bucket_name}"

  tags = {
    Name = "terraform-state"
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

# ECR repository for Docker images
resource "aws_ecr_repository" "memos" {
  name                 = var.ecr_repository_name
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "memos-ecr"
  }
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

# Get current AWS account ID
data "aws_caller_identity" "current" {}
```

### File 4: `terraform/bootstrap/outputs.tf`
```hcl
output "s3_bucket_name" {
  value = aws_s3_bucket.terraform_state.id
}

output "ecr_repository_url" {
  value = aws_ecr_repository.memos.repository_url
}

output "github_oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.github.arn
}
```

---

## Step 2.2: Deploy Bootstrap

```bash
# Initialize
terraform -chdir=terraform/bootstrap init

# Review plan
terraform -chdir=terraform/bootstrap plan

# Apply
terraform -chdir=terraform/bootstrap apply
```

**Expected output:**
```
Apply complete! Resources: 4 added, 0 changed, 0 destroyed.

Outputs:
s3_bucket_name = memos-tfstate
ecr_repository_url = 123456789.dkr.ecr.us-west-1.amazonaws.com/memos
```

---

# Part 3: Create Main Infrastructure

(This part is detailed in the Quick Reference with actual Terraform code)

---

# Part 4: Deploy to AWS

```bash
# Initialize with S3 backend
terraform -chdir=terraform init -backend-config="bucket=YOUR_BUCKET"

# Review plan
terraform -chdir=terraform plan -out=tfplan

# Apply
terraform -chdir=terraform apply tfplan
```

---

# Part 5: Verify Everything Works

```bash
# Check EKS cluster
aws eks describe-cluster --name memos-eks-cluster --region us-west-1

# Get kubeconfig
aws eks update-kubeconfig --name memos-eks-cluster --region us-west-1

# Verify nodes
kubectl get nodes

# Check RDS
aws rds describe-db-instances --region us-west-1
```

---

## Next: Stage 2 Quick Reference & Implementation

Move to `STAGE2_QUICK_REFERENCE.md` for copy-paste commands!
