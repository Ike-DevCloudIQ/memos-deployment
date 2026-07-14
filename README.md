# Memos Deployment - Production-Grade DevOps Learning Project 🚀

> **Building production infrastructure step-by-step from Docker → Terraform → Kubernetes → GitOps → CI/CD → Monitoring**

A **complete, self-paced DevOps learning journey** through 6 stages, culminating in a production-ready deployment of Memos (self-hosted note-taking app) to AWS EKS.

---

## 🎯 Project Status

| Stage | Topic | Status | Guide | Commands |
|-------|-------|--------|-------|----------|
| **1** | **Docker & Containerization** | ✅ COMPLETE | [STAGE1_BEGINNER_GUIDE.md](docs/STAGE1_BEGINNER_GUIDE.md) | [Quick Ref](STAGE1_QUICK_REFERENCE.md) |
| **2** | **Terraform Infrastructure** | ✅ COMPLETE | [STAGE2_TERRAFORM.md](docs/STAGE2_TERRAFORM.md) | [VPC](STAGE2_QUICK_REFERENCE.md) \| [EKS/RDS](STAGE2_EXTENDED_QUICK_REFERENCE.md) |
| **3** | **Kubernetes Deployment** | ⏳ COMING | docs/STAGE3_KUBERNETES.md | Stage 3 Quick Ref |
| **4** | **GitOps with ArgoCD** | ⏳ COMING | docs/STAGE4_GITOPS.md | Stage 4 Quick Ref |
| **5** | **CI/CD with GitHub Actions** | ⏳ COMING | docs/STAGE5_CICD.md | Stage 5 Quick Ref |
| **6** | **Monitoring & Observability** | ⏳ COMING | docs/STAGE6_MONITORING.md | Stage 6 Quick Ref |

**Estimated Total Duration:** 10-15 days of learning

---

## 🏗️ Completed Infrastructure

```
AWS Account (us-west-1) - DEPLOYED ✅

BOOTSTRAP (S3, ECR, IAM) ✅
├─ S3: Terraform state (versioned, encrypted)
├─ ECR: Docker image registry
├─ Secrets Manager: Database credentials
└─ GitHub OIDC: CI/CD automation

NETWORKING (VPC) ✅
├─ VPC: 10.0.0.0/16
├─ Public Subnets: 2x (load balancers)
├─ Private Subnets: 2x (EKS nodes)
├─ NAT Gateways: 2x (private subnet internet)
└─ Internet Gateway (public subnet)

KUBERNETES (EKS) ✅
├─ Cluster: v1.31
├─ Worker Nodes: 2x t3.medium
├─ IAM Roles: Cluster + Node + Pod
├─ OIDC Provider: Pod identity (IRSA)
└─ CloudWatch: Logging & monitoring

DATABASE (RDS) ✅
├─ Engine: PostgreSQL 15.4
├─ Storage: 20GB (gp3)
├─ Backups: 7-day retention
├─ Monitoring: Enhanced CloudWatch
└─ Security: Private subnet only
```

---

## 📚 Quick Links to Guides

### Stage 1: Docker ✅
- **[docs/STAGE1_BEGINNER_GUIDE.md](docs/STAGE1_BEGINNER_GUIDE.md)** - 7-part Docker tutorial (1000+ lines with explanations)
- **[docs/STAGE1_APP.md](docs/STAGE1_APP.md)** - Understanding Memos application
- **[STAGE1_QUICK_REFERENCE.md](STAGE1_QUICK_REFERENCE.md)** - Copy-paste commands

### Stage 2: Terraform ✅
- **[docs/STAGE2_TERRAFORM.md](docs/STAGE2_TERRAFORM.md)** - Terraform fundamentals (2000+ lines)
- **[STAGE2_QUICK_REFERENCE.md](STAGE2_QUICK_REFERENCE.md)** - VPC & Bootstrap deployment (Parts 0-5)
- **[docs/STAGE2_EKS_RDS.md](docs/STAGE2_EKS_RDS.md)** - EKS & RDS conceptual guide (2000+ lines)
- **[STAGE2_EXTENDED_QUICK_REFERENCE.md](STAGE2_EXTENDED_QUICK_REFERENCE.md)** - EKS & RDS deployment (Parts 6-11)

---

## 🚀 Quick Start

### Prerequisites
```bash
# Required tools
brew install terraform aws-cli kubernetes-cli docker

# Verify
terraform -v
aws configure
aws sts get-caller-identity
```

### Stage 1: Local Docker (15 min)
```bash
cd ~/Desktop/Nouriva/memos-deployment
docker build -t memos:local app/
docker-compose up -d
# Access: http://localhost:5230
```

### Stage 2: AWS Infrastructure (2-3 hours)
```bash
# Follow STAGE2_QUICK_REFERENCE.md (Parts 0-5)
terraform -chdir=terraform/bootstrap apply
terraform -chdir=terraform apply

# Then follow STAGE2_EXTENDED_QUICK_REFERENCE.md (Parts 6-11)
terraform -chdir=terraform apply -target=module.eks
terraform -chdir=terraform apply -target=module.rds
```

---

## 📊 Architecture

```
┌────────────────────────────────────────────────────┐
│          AWS Account (us-west-1)                   │
├────────────────────────────────────────────────────┤
│  VPC (10.0.0.0/16) with 2 Availability Zones      │
│                                                    │
│  Public Subnets (NAT, IGW)                        │
│  ├─ 10.0.1.0/24 (us-west-1a)                     │
│  └─ 10.0.2.0/24 (us-west-1b)                     │
│                                                    │
│  Private Subnets (EKS Nodes)                      │
│  ├─ 10.0.11.0/24 (us-west-1a)                    │
│  └─ 10.0.12.0/24 (us-west-1b)                    │
├────────────────────────────────────────────────────┤
│  EKS Kubernetes Cluster v1.31                     │
│  ├─ Control Plane (Managed)                       │
│  ├─ 2 Worker Nodes (t3.medium)                    │
│  ├─ Pod Identity (IRSA)                           │
│  └─ Service Discovery & Load Balancing            │
├────────────────────────────────────────────────────┤
│  RDS PostgreSQL 15.4                              │
│  ├─ 20GB Storage (gp3, encrypted)                 │
│  ├─ 7-day Automated Backups                       │
│  ├─ Enhanced Monitoring                           │
│  └─ Multi-AZ Ready (disabled for dev cost)        │
├────────────────────────────────────────────────────┤
│  Bootstrap Services                               │
│  ├─ S3: Terraform State (versioned)               │
│  ├─ ECR: Docker Image Registry                    │
│  ├─ Secrets Manager: Credentials                  │
│  └─ IAM OIDC: GitHub Actions                      │
└────────────────────────────────────────────────────┘
```

---

## 💰 Cost Estimate

```
STAGE 1 (Local Docker)
Cost: FREE | Resources: None

STAGE 2 (AWS Infrastructure)
After free tier: ~$195/month

Breakdown:
├─ EKS Control Plane: $73/month
├─ 2x t3.medium EC2: $59/month
├─ RDS db.t3.micro: $30/month
├─ NAT Gateway: $32/month
└─ Other (S3, ECR, Secrets): <$5/month

Optimization:
• Use Spot instances: -70% EC2 costs
• Delete when not in use: -$0
• AWS Free Tier: First 12 months free eligible
```

---

## 📁 Project Structure

```
memos-deployment/
├── README.md                                   (This file)
├── LEARNING_GUIDE.md                           (6-stage overview)
├── STAGE1_QUICK_REFERENCE.md                  (Docker commands)
├── STAGE2_QUICK_REFERENCE.md                  (VPC/Bootstrap)
├── STAGE2_EXTENDED_QUICK_REFERENCE.md         (EKS/RDS)
│
├── docs/
│   ├── STAGE1_BEGINNER_GUIDE.md              (Docker tutorial)
│   ├── STAGE1_APP.md                          (Memos app structure)
│   ├── STAGE2_TERRAFORM.md                    (Terraform concepts)
│   ├── STAGE2_EKS_RDS.md                      (EKS & RDS guide)
│   ├── ARCHITECTURE.md                        (System design)
│   └── STAGES/
│       ├── 01-foundation.md
│       ├── 02-kubernetes.md (coming)
│       └── ...
│
├── app/                                        (Memos source code)
│   ├── Dockerfile
│   ├── docker-compose.yaml
│   ├── go.mod, package.json
│   ├── cmd/, web/, server/, store/, internal/
│   └── ...
│
├── terraform/
│   ├── main.tf, variables.tf, outputs.tf
│   ├── provider.tf
│   ├── bootstrap/                              (S3, ECR, IAM)
│   │   ├── main.tf, variables.tf
│   │   ├── outputs.tf, provider.tf
│   │   └── terraform.tfstate
│   └── modules/
│       ├── vpc/                                (VPC networking)
│       ├── eks/                                (Kubernetes cluster)
│       └── rds/                                (PostgreSQL database)
│
├── k8s/                                        (Kubernetes manifests)
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── configmap.yaml
│   ├── secrets.yaml
│   └── root-application.yaml (ArgoCD)
│
└── .github/workflows/
    └── deploy.yaml (CI/CD)
```

---

## 🎓 What You'll Learn

### Stage 1: Docker ✅
- Multi-stage builds for optimization
- docker-compose for local development
- Container networking and volumes
- Health checks and signals
- Security best practices

### Stage 2: Terraform ✅
- Infrastructure as Code principles
- Terraform workflow (init → plan → apply)
- AWS VPC architecture
- Managed Kubernetes (EKS)
- Managed databases (RDS)
- Terraform state management
- Modular infrastructure design

### Stage 3: Kubernetes (Coming)
- Deployments and Services
- ConfigMaps and Secrets
- Health checks and rolling updates
- Pod networking and scaling

### Stage 4: GitOps (Coming)
- ArgoCD deployment
- Git-based automation
- Rollback strategies

### Stage 5: CI/CD (Coming)
- GitHub Actions workflows
- Automated builds and deployments

### Stage 6: Monitoring (Coming)
- CloudWatch dashboards
- Application logging
- Prometheus and Grafana
- Alerting strategies

---

## 🔗 Resources

### AWS
- [VPC Docs](https://docs.aws.amazon.com/vpc/)
- [EKS Docs](https://docs.aws.amazon.com/eks/)
- [RDS Docs](https://docs.aws.amazon.com/rds/)
- [Secrets Manager](https://docs.aws.amazon.com/secretsmanager/)

### DevOps Tools
- [Terraform Docs](https://www.terraform.io/docs)
- [Kubernetes Docs](https://kubernetes.io/docs)
- [Docker Docs](https://docs.docker.com/)
- [ArgoCD Docs](https://argoproj.github.io/cd/)
- [GitHub Actions](https://docs.github.com/en/actions)

---

## ❓ FAQ

**Q: Do I need AWS experience?**  
A: No! This teaches everything from scratch.

**Q: How much does this cost?**  
A: Free first 12 months (AWS free tier), then ~$195/month.

**Q: Can I delete everything?**  
A: Yes! Just run `terraform destroy`.

**Q: Do I need to complete stages in order?**  
A: Yes - each stage depends on the previous one.

---

## 📝 License

Open source - MIT License

---

**Status:** Stages 1-2 Complete ✅ | Stages 3-6 Coming ⏳

**Last Updated:** July 2026 | **Maintained By:** Ike-DevCloudIQ

Happy learning! 🎓
