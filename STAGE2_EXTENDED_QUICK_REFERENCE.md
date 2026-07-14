# Stage 2 Extended: EKS & RDS - QUICK REFERENCE

> **Follow this section after completing Parts 0-5 of STAGE2_QUICK_REFERENCE.md**

---

## Part 6: Deploy EKS Kubernetes Cluster

### Step 6.1: Validate Terraform

```bash
cd ~/Desktop/Nouriva/memos-deployment
terraform -chdir=terraform validate
```

### Step 6.2: Plan EKS

```bash
terraform -chdir=terraform plan -target=module.eks > eks-plan.txt
cat eks-plan.txt | head -50
```

### Step 6.3: Deploy EKS

```bash
terraform -chdir=terraform apply -target=module.eks
```

**When prompted:** Type `yes`

**Takes:** 10-15 minutes

**Expected output:**
```
Apply complete! Resources: 16 added, 0 changed, 0 destroyed.

eks_cluster_name = "memos-eks"
eks_cluster_endpoint = "https://..."
```

### Step 6.4: Verify EKS

```bash
# Get kubeconfig
aws eks update-kubeconfig --name memos-eks --region us-west-1

# Check nodes
kubectl get nodes

# Should show 2 nodes with STATUS=Ready
```

---

## Part 7: Deploy RDS PostgreSQL Database

### Step 7.1: Plan RDS

```bash
terraform -chdir=terraform plan -target=module.rds > rds-plan.txt
cat rds-plan.txt | head -50
```

### Step 7.2: Deploy RDS

```bash
terraform -chdir=terraform apply -target=module.rds
```

**When prompted:** Type `yes`

**Takes:** 10-15 minutes

**Expected output:**
```
Apply complete! Resources: 12 added, 0 changed, 0 destroyed.

rds_endpoint = "memos-postgres.c9akciq32.us-west-1.rds.amazonaws.com:5432"
rds_database_name = "memos"
rds_secret_arn = "arn:aws:secretsmanager:..."
```

### Step 7.3: Verify RDS

```bash
# Check database status
aws rds describe-db-instances \
  --db-instance-identifier memos-postgres \
  --region us-west-1 \
  --query 'DBInstances[0].[DBInstanceIdentifier,DBInstanceStatus,Engine]'
```

**Expected:**
```
[
    "memos-postgres",
    "available",
    "postgres"
]
```

---

## Part 8: Deploy Everything Together

### Step 8.1: Full validation

```bash
terraform -chdir=terraform validate
```

### Step 8.2: Full plan

```bash
terraform -chdir=terraform plan > full-plan.txt

# Check count
grep "Plan:" full-plan.txt
# Should show: Plan: 38 to add, 0 to change, 0 to destroy.
```

### Step 8.3: Full deploy

```bash
terraform -chdir=terraform apply
```

**When prompted:** Type `yes`

**Takes:** 20-30 minutes total

---

## Part 9: Verify Complete Infrastructure

### All resources

```bash
# VPC
aws ec2 describe-vpcs \
  --filters "Name=cidr-block,Values=10.0.0.0/16" \
  --region us-west-1 \
  --query 'Vpcs[0].VpcId'

# EKS
aws eks list-clusters --region us-west-1

# RDS
aws rds describe-db-instances \
  --db-instance-identifier memos-postgres \
  --region us-west-1 \
  --query 'DBInstances[0].DBInstanceStatus'
```

### Kubernetes

```bash
# Nodes
kubectl get nodes

# Namespaces
kubectl get namespaces

# All pods
kubectl get pods --all-namespaces
```

---

## Part 10: Create Kubernetes Secret for Database

```bash
# Get credentials from Secrets Manager
SECRET_ARN=$(terraform -chdir=terraform output -raw rds_secret_arn)
SECRET=$(aws secretsmanager get-secret-value \
  --secret-id $SECRET_ARN \
  --region us-west-1 \
  --query 'SecretString' \
  --output text)

DB_HOST=$(echo $SECRET | jq -r .host)
DB_USER=$(echo $SECRET | jq -r .username)
DB_PASS=$(echo $SECRET | jq -r .password)
DB_NAME=$(echo $SECRET | jq -r .dbname)
DB_PORT=$(echo $SECRET | jq -r .port)

# Create Kubernetes secret
kubectl create secret generic rds-credentials \
  --from-literal=username=$DB_USER \
  --from-literal=password=$DB_PASS \
  --from-literal=host=$DB_HOST \
  --from-literal=port=$DB_PORT \
  --from-literal=database=$DB_NAME \
  -n default

# Verify
kubectl get secrets
```

---

## Part 11: Commit to Git

```bash
cd ~/Desktop/Nouriva/memos-deployment

git add terraform/

git commit -m "Stage 2: Complete AWS infrastructure with EKS and RDS

Added:
- EKS Kubernetes cluster v1.31 with 2 t3.medium nodes
- RDS PostgreSQL 15.4 with 20GB storage
- All IAM roles and security groups
- Database credentials in Secrets Manager
- Pod execution role for Kubernetes service accounts
- CloudWatch monitoring and logs

All 38 resources deployed and verified:
✅ VPC with public/private subnets
✅ EKS cluster with worker nodes
✅ PostgreSQL database
✅ Kubernetes access configured
✅ Database credentials in Kubernetes secret

Ready for: Stage 3 (Deploy Memos app)"

git push origin main
```

---

## ✅ Stage 2 Extended Complete!

**What you've accomplished:**

✅ Complete AWS infrastructure
✅ Kubernetes cluster ready
✅ PostgreSQL database ready
✅ All resources secured and monitored
✅ Committed to GitHub

---

## Cost Summary

```
Monthly (after free tier):
- EKS: $73
- EC2 nodes: $59
- RDS: $30
- NAT: $32
- Other: ~$5
TOTAL: ~$195/month
```

---

## Next Steps

**Stage 3: Deploy Memos app to Kubernetes**
- Create Kubernetes Deployment
- Create Kubernetes Service
- Deploy Memos container to EKS
- Access app via load balancer

**Then:**
- Stage 4: GitOps with ArgoCD
- Stage 5: CI/CD with GitHub Actions
- Stage 6: Monitoring and observability

---

## Troubleshooting

### Nodes not ready
```bash
kubectl describe node <node-name>
kubectl get events --all-namespaces
```

### Cannot connect to database
```bash
# Check security group
aws ec2 describe-security-groups \
  --group-ids sg-xxxxx \
  --region us-west-1

# Check DB status
aws rds describe-db-instances \
  --db-instance-identifier memos-postgres \
  --region us-west-1
```

### Stuck waiting for resource
```bash
# Reapply same target
terraform -chdir=terraform apply -target=module.eks

# Or destroy and retry
terraform -chdir=terraform destroy -target=module.eks
```

---

## Summary

**Stage 2 infrastructure complete!**

You now have:
- VPC with proper networking
- EKS Kubernetes cluster
- PostgreSQL database
- Secrets management
- Monitoring and logs
- Everything production-ready

**Ready for Stage 3: Kubernetes deployment!** 🚀
