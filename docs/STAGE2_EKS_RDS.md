# Stage 2 Extended: EKS & RDS Deployment Guide

> **Time required:** 2-3 hours for full deployment
> **Cost note:** EKS cluster adds ~$70-100/month, RDS adds ~$15-30/month on AWS Free Tier eligible tier

---

## Part 6: Deploy EKS Kubernetes Cluster

### Overview: What is EKS?

**EKS = Elastic Kubernetes Service**

- Managed Kubernetes service (AWS handles control plane)
- You manage worker nodes (EC2 instances)
- Runs your containerized apps
- Integrates with AWS services (RDS, Secrets Manager, etc.)

**What we're creating:**
- 1 Kubernetes cluster with 2 worker nodes
- IAM roles for cluster and nodes
- Security groups for network access
- Pod execution role for apps to access AWS services

### Step 6.1: Validate Terraform files

```bash
cd ~/Desktop/Nouriva/memos-deployment

# Validate EKS module syntax
terraform -chdir=terraform validate
```

**Expected output:**
```
Success! The configuration is valid.
```

### Step 6.2: Plan EKS infrastructure

```bash
terraform -chdir=terraform plan -target=module.eks
```

**Review the output:**
- Should show ~15-20 resources to be created
- EKS cluster, security groups, IAM roles, node group
- Takes ~2 minutes to read all resources

**Expected major resources:**
```
+ aws_eks_cluster.main
+ aws_eks_node_group.main
+ aws_iam_role.eks_cluster_role
+ aws_iam_role.eks_node_role
+ aws_security_group.eks_cluster
+ aws_security_group.eks_nodes
+ aws_cloudwatch_log_group.eks_cluster
+ aws_iam_role.pod_execution_role
+ (plus ~8 more IAM policies and attachments)
```

### Step 6.3: Deploy EKS cluster

```bash
terraform -chdir=terraform apply -target=module.eks
```

**When prompted:** Type `yes`

**Expected duration:** 10-15 minutes

**Expected output (end result):**
```
Apply complete! Resources: 16 added, 0 changed, 0 destroyed.

Outputs:

eks_cluster_name = "memos-eks"
eks_cluster_endpoint = "https://abc123.eks.us-west-1.amazonaws.com"
eks_cluster_ca_certificate = "LS0tLS1CRUdJTi..."
eks_oidc_issuer_url = "https://oidc.eks.us-west-1.amazonaws.com/id/ABC123"
pod_execution_role_arn = "arn:aws:iam::123456789:role/memos-pod-execution-role"
```

### Step 6.4: Verify EKS cluster

```bash
# List EKS clusters
aws eks list-clusters --region us-west-1

# Describe the cluster
aws eks describe-cluster --name memos-eks --region us-west-1

# Get kubeconfig
aws eks update-kubeconfig --name memos-eks --region us-west-1

# Verify you can connect to cluster
kubectl get nodes
```

**Expected output from kubectl:**
```
NAME                           STATUS   ROLES    AGE   VERSION
ip-10-0-11-xxx.ec2.internal   Ready    <none>   5m    v1.31.0
ip-10-0-12-xxx.ec2.internal   Ready    <none>   5m    v1.31.0
```

If you see 2 nodes with STATUS=Ready, EKS is working! ✅

---

## Part 7: Deploy RDS PostgreSQL Database

### Overview: What is RDS?

**RDS = Relational Database Service**

- Managed PostgreSQL database (AWS handles backups, patching)
- Automatic failover with Multi-AZ (optional)
- Automated backups (7 days retention)
- Encryption at rest and in transit
- Secrets stored in AWS Secrets Manager

**What we're creating:**
- PostgreSQL 15.4 database
- 20GB storage
- Multi-AZ failover (optional in this config)
- Automated backups
- Security group restricting access to private subnets only
- CloudWatch monitoring

### Step 7.1: Plan RDS infrastructure

```bash
terraform -chdir=terraform plan -target=module.rds
```

**Review the output:**
- Should show ~10-15 resources to be created
- RDS instance, parameter group, subnet group, security group, IAM role, Secrets Manager

**Expected major resources:**
```
+ aws_db_instance.main
+ aws_db_subnet_group.main
+ aws_db_parameter_group.main
+ aws_security_group.rds
+ aws_secretsmanager_secret.db_password
+ aws_secretsmanager_secret_version.db_password
+ aws_iam_role.rds_monitoring
+ random_password.db_password
```

### Step 7.2: Deploy RDS database

```bash
terraform -chdir=terraform apply -target=module.rds
```

**When prompted:** Type `yes`

**Expected duration:** 10-15 minutes (database creation takes time)

**Expected output (end result):**
```
Apply complete! Resources: 12 added, 0 changed, 0 destroyed.

Outputs:

rds_address = "memos-postgres.c9akciq32.us-west-1.rds.amazonaws.com"
rds_endpoint = "memos-postgres.c9akciq32.us-west-1.rds.amazonaws.com:5432"
rds_database_name = "memos"
rds_username = "memos_user"
rds_connection_string = "postgresql://memos_user:PASSWORD@memos-postgres.c9akciq32.us-west-1.rds.amazonaws.com:5432/memos"
rds_secret_arn = "arn:aws:secretsmanager:us-west-1:123456789:secret:memos/rds/password-ABC123"
```

### Step 7.3: Verify RDS database

```bash
# List RDS instances
aws rds describe-db-instances --region us-west-1

# Check database status
aws rds describe-db-instances \
  --db-instance-identifier memos-postgres \
  --region us-west-1 \
  --query 'DBInstances[0].[DBInstanceIdentifier,DBInstanceStatus,Engine,EngineVersion]'
```

**Expected output:**
```
[
    "memos-postgres",
    "available",
    "postgres",
    "15.4"
]
```

If status is "available", database is ready! ✅

---

## Part 8: Deploy Everything Together

Now that you understand both modules, deploy complete infrastructure:

### Step 8.1: Validate everything

```bash
terraform -chdir=terraform validate
```

### Step 8.2: Plan full infrastructure

```bash
terraform -chdir=terraform plan > terraform-plan.txt

# Review the plan
cat terraform-plan.txt | head -100

# Check resource count
grep "Plan:" terraform-plan.txt
```

**Expected:**
```
Plan: 38 to add, 0 to change, 0 to destroy.
```

### Step 8.3: Apply full infrastructure

```bash
terraform -chdir=terraform apply
```

**When prompted:** Type `yes`

**Expected duration:** 20-30 minutes total

**Final output:**
```
Apply complete! Resources: 38 added, 0 changed, 0 destroyed.

Outputs:

eks_cluster_name = "memos-eks"
eks_cluster_endpoint = "https://..."
rds_endpoint = "memos-postgres.c9akciq32.us-west-1.rds.amazonaws.com:5432"
rds_database_name = "memos"
...
```

---

## Part 9: Verify Complete Infrastructure

### Step 9.1: Check all AWS resources

```bash
# VPC
aws ec2 describe-vpcs --filters "Name=cidr-block,Values=10.0.0.0/16" --region us-west-1 --query 'Vpcs[0].VpcId'

# Subnets
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$(terraform -chdir=terraform output -raw vpc_id)" --region us-west-1 --query 'Subnets[].SubnetId'

# EKS Cluster
aws eks list-clusters --region us-west-1

# RDS Instance
aws rds describe-db-instances --db-instance-identifier memos-postgres --region us-west-1 --query 'DBInstances[0].DBInstanceStatus'

# Node Group
aws eks list-nodegroups --cluster-name memos-eks --region us-west-1
```

### Step 9.2: Verify Kubernetes access

```bash
# Update kubeconfig
aws eks update-kubeconfig --name memos-eks --region us-west-1

# Check nodes
kubectl get nodes

# Check namespaces
kubectl get namespaces

# Check all pods
kubectl get pods --all-namespaces
```

### Step 9.3: Test database connection from EC2

```bash
# Get EC2 instance ID
EC2_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=memos-node-group" \
  --region us-west-1 \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text)

# Get RDS endpoint
RDS_ENDPOINT=$(terraform -chdir=terraform output -raw rds_endpoint)

# Get password from Secrets Manager
SECRET_ARN=$(terraform -chdir=terraform output -raw rds_secret_arn)
SECRET=$(aws secretsmanager get-secret-value --secret-id $SECRET_ARN --region us-west-1 --query 'SecretString' --output text)

# Parse connection details
DB_HOST=$(echo $RDS_ENDPOINT | cut -d: -f1)
DB_USER=$(echo $SECRET | jq -r .username)
DB_PASS=$(echo $SECRET | jq -r .password)

# Test connection (if you have psql installed)
# PGPASSWORD=$DB_PASS psql -h $DB_HOST -U $DB_USER -d memos -c "SELECT version();"
```

---

## Part 10: Set Up Kubernetes Secrets for Database

Now apps running in EKS can access database via Kubernetes Secrets:

### Step 10.1: Create Kubernetes secret

```bash
# Get database credentials
SECRET_ARN=$(terraform -chdir=terraform output -raw rds_secret_arn)
SECRET=$(aws secretsmanager get-secret-value --secret-id $SECRET_ARN --region us-west-1 --query 'SecretString' --output text)

DB_HOST=$(echo $SECRET | jq -r .host)
DB_USER=$(echo $SECRET | jq -r .username)
DB_PASS=$(echo $SECRET | jq -r .password)
DB_NAME=$(echo $SECRET | jq -r .dbname)
DB_PORT=$(echo $SECRET | jq -r .port)

# Create secret in Kubernetes
kubectl create secret generic rds-credentials \
  --from-literal=username=$DB_USER \
  --from-literal=password=$DB_PASS \
  --from-literal=host=$DB_HOST \
  --from-literal=port=$DB_PORT \
  --from-literal=database=$DB_NAME \
  -n default

# Verify secret created
kubectl get secrets
kubectl describe secret rds-credentials
```

**Expected output:**
```
Name:         rds-credentials
Namespace:    default
Type:         Opaque

Data
====
username:   10 bytes
password:   32 bytes
host:       37 bytes
port:       4 bytes
database:   5 bytes
```

---

## Part 11: Create Terraform Outputs Summary

Save infrastructure details to a file:

```bash
# Create summary file
cat > terraform/outputs.txt << 'EOF'
=== INFRASTRUCTURE SUMMARY ===

VPC:
$(terraform -chdir=terraform output vpc_id)

SUBNETS:
Public: $(terraform -chdir=terraform output public_subnets)
Private: $(terraform -chdir=terraform output private_subnets)

EKS CLUSTER:
Name: $(terraform -chdir=terraform output eks_cluster_name)
Endpoint: $(terraform -chdir=terraform output eks_cluster_endpoint)
OIDC Issuer: $(terraform -chdir=terraform output eks_oidc_issuer_url)

KUBERNETES NODES:
$(kubectl get nodes -o wide)

RDS DATABASE:
Endpoint: $(terraform -chdir=terraform output rds_endpoint)
Database: $(terraform -chdir=terraform output rds_database_name)
User: $(terraform -chdir=terraform output rds_username)

SECRET MANAGER:
ARN: $(terraform -chdir=terraform output rds_secret_arn)

COST ESTIMATE:
- VPC: Free
- EKS Control Plane: $73/month
- 2 t3.medium EC2 nodes: ~$60/month
- RDS db.t3.micro: ~$30/month
- NAT Gateway: ~$32/month
- S3 state bucket: <$1/month
TOTAL: ~$195/month (or less with AWS Free Tier)

=== READY TO DEPLOY APPS ===
EOF

cat terraform/outputs.txt
```

---

## Part 12: Commit to Git

```bash
cd ~/Desktop/Nouriva/memos-deployment

# Check what changed
git status

# Add all files
git add terraform/

# Commit
git commit -m "Stage 2: Add complete AWS infrastructure with EKS and RDS

Added EKS Kubernetes cluster:
- EKS cluster with version 1.31
- 2 t3.medium worker nodes across 2 availability zones
- IAM roles for cluster and nodes
- Security groups for cluster and nodes
- Pod execution role for IRSA (pod service accounts)
- CloudWatch logs for debugging
- OIDC provider for pod identity

Added RDS PostgreSQL database:
- PostgreSQL 15.4 with 20GB storage
- Automated backups (7-day retention)
- Multi-AZ failover (disabled for dev cost control)
- Enhanced monitoring via CloudWatch
- Secrets stored in AWS Secrets Manager
- Security group restricting access to private subnets

Infrastructure deployment:
- All Terraform modules working and deployed
- VPC with public/private subnets across 2 AZs
- NAT gateways for private subnet internet access
- EKS cluster ready for app deployment
- PostgreSQL database ready for memos app
- State stored in S3 with encryption and versioning

Estimated cost: ~$195/month
Ready for: Stage 3 (Kubernetes app deployment)

Status: Infrastructure complete, ready for container deployment"

git push origin main
```

---

## ✅ Stage 2 Complete!

**What you've accomplished:**

✅ **Bootstrap Infrastructure**
- S3 bucket for Terraform state
- ECR repository for Docker images
- GitHub OIDC provider for CI/CD
- IAM roles for automated deployments

✅ **Networking (VPC)**
- VPC with 10.0.0.0/16 CIDR
- 2 public subnets for load balancers
- 2 private subnets for EKS nodes
- NAT gateways for private subnet internet access
- Internet gateway for public subnet access

✅ **Kubernetes (EKS)**
- Managed Kubernetes cluster (v1.31)
- 2 worker nodes (t3.medium)
- IAM roles for cluster and nodes
- Pod execution role for apps
- OIDC provider for pod identity

✅ **Database (RDS)**
- PostgreSQL 15.4 database
- 20GB storage with auto-scaling
- Automated backups and monitoring
- Credentials stored in Secrets Manager
- Security group restricting access

---

## Cost Estimate

```
AWS Free Tier eligible:
- VPC, subnets, NAT Gateway (first 1) = FREE
- EC2 instances (1 year free, then paid)

Monthly costs (after free tier):
- EKS Control Plane: $73.00
- 2 x t3.medium nodes: $58.56
- RDS db.t3.micro: $29.93
- NAT Gateway (1): $32.00
- Data transfer: varies
- S3 state: <$1.00

TOTAL: ~$195/month

Ways to reduce:
1. Use Spot instances for EKS nodes (~30% savings)
2. Disable Multi-AZ for dev (~50% RDS savings)
3. Use db.t3.micro for RDS (already done)
4. Delete unused resources when not in use
```

---

## Next: Stage 3 - Kubernetes Deployment

Ready to deploy Memos app to EKS!

**Stage 3 will cover:**
- Creating Kubernetes Deployment for Memos
- Creating Kubernetes Service for networking
- Creating ConfigMap and Secrets for configuration
- Deploying app to EKS cluster
- Accessing app via Kubernetes Service

---

## Troubleshooting

### EKS: "Nodes not ready"
```bash
# Check node logs
kubectl describe node <node-name>
kubectl get pods --all-namespaces

# Check security groups
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=memos-eks-nodes-sg" \
  --region us-west-1
```

### RDS: "Cannot connect to database"
```bash
# Check security group allows private subnet access
aws ec2 describe-security-groups \
  --group-ids sg-xxxxx \
  --region us-west-1

# Check database is available
aws rds describe-db-instances \
  --db-instance-identifier memos-postgres \
  --region us-west-1 \
  --query 'DBInstances[0].DBInstanceStatus'

# Check credentials in Secrets Manager
aws secretsmanager get-secret-value \
  --secret-id memos/rds/password \
  --region us-west-1
```

### Terraform: "Resource creation timeout"
```bash
# Reapply (may be transient AWS issue)
terraform -chdir=terraform apply

# Or destroy and retry
terraform -chdir=terraform destroy -target=module.eks
terraform -chdir=terraform apply -target=module.eks
```

---

## Summary

**Stage 2 learned you:**
- Infrastructure as Code with Terraform
- Bootstrap pattern for state management
- VPC networking fundamentals
- Managed Kubernetes with EKS
- Managed database with RDS
- AWS IAM roles and policies
- Terraform modules and outputs
- State management with S3

**You now have:**
- Production-ready infrastructure on AWS
- Kubernetes cluster ready for apps
- PostgreSQL database ready for data
- Everything secured and monitored

**Ready for:**
- Stage 3: Deploy Memos app to Kubernetes
- Stage 4: GitOps with ArgoCD
- Stage 5: CI/CD with GitHub Actions
- Stage 6: Monitoring with CloudWatch/Prometheus

Congratulations! You've built enterprise-grade infrastructure! 🎉
