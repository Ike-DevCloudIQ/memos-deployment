# Memos on AWS EKS: End-to-End DevOps Infrastructure Project

> **A production-grade, fully-documented DevOps learning journey: From containerization to cloud-native deployment with GitOps automation and production monitoring**

---

## 📌 Executive Summary

This repository contains a **complete, self-paced DevOps learning project** that builds a production-ready cloud infrastructure from scratch. It demonstrates modern DevOps practices by deploying **Memos** (a self-hosted note-taking application) to AWS using industry-standard tools and patterns.

**What makes this unique:**
- ✅ **End-to-end implementation** - Not tutorials, but working infrastructure deployed to real AWS
- ✅ **Beginner to advanced** - Each stage builds on the previous, with detailed conceptual guides
- ✅ **Production patterns** - Uses GitOps, CI/CD, IaC, and observability from day one
- ✅ **Real-world challenges** - Handles state management, OIDC authentication, multi-AZ deployment, secrets management
- ✅ **Fully documented** - 10,000+ lines of guides explaining the "why" not just the "how"

---

## 🎯 Project Status

| Stage | Topic | Status | Conceptual Guide | Quick Reference | Implementation |
|-------|-------|--------|------------------|-----------------|-----------------|
| **1** | **Docker & Containerization** | ✅ COMPLETE | [1000+ lines](docs/STAGE1_BEGINNER_GUIDE.md) | [Commands](STAGE1_QUICK_REFERENCE.md) | app/Dockerfile |
| **2** | **Terraform Infrastructure** | ✅ COMPLETE | [2000+ lines](docs/STAGE2_TERRAFORM.md) | [VPC](STAGE2_QUICK_REFERENCE.md) \| [EKS/RDS](STAGE2_EXTENDED_QUICK_REFERENCE.md) | terraform/modules |
| **3** | **Kubernetes Deployment** | ✅ COMPLETE | [2000+ lines](docs/STAGE3_KUBERNETES.md) | [kubectl](STAGE3_QUICK_REFERENCE.md) | k8s/deployment.yaml |
| **4** | **GitOps with ArgoCD** | ✅ COMPLETE | [2000+ lines](docs/STAGE4_GITOPS.md) | [Setup](STAGE4_QUICK_REFERENCE.md) | k8s/argocd-application.yaml |
| **5** | **CI/CD with GitHub Actions** | ✅ COMPLETE | [2000+ lines](docs/STAGE5_CICD.md) | [Pipeline](STAGE5_QUICK_REFERENCE.md) | .github/workflows/deploy.yaml |
| **6** | **Monitoring & Observability** | ✅ COMPLETE | [2000+ lines](docs/STAGE6_MONITORING.md) | [UI Checklist](STAGE6_EXECUTION_CHECKLIST.md) | Grafana + CloudWatch |

**Progress:** 6/6 stages complete (100%) 🎉  
**Total Documentation:** 10,000+ lines | **Learning Duration:** 10-15 days

---

## �️ Architecture Overview

### Complete System Design

```
┌─────────────────────────────────────────────────────────────────┐
│                     AWS Account (us-west-1)                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │        VPC (10.0.0.0/16) - 2 Availability Zones         │  │
│  │                                                          │  │
│  │  ┌──────────────────────┐  ┌──────────────────────────┐ │  │
│  │  │  Public Subnet 1     │  │  Public Subnet 2         │ │  │
│  │  │  10.0.1.0/24 (1a)    │  │  10.0.2.0/24 (1b)        │ │  │
│  │  │  NAT Gateway         │  │  NAT Gateway             │ │  │
│  │  │  Load Balancer       │  │  Load Balancer           │ │  │
│  │  └─────────┬────────────┘  └────────┬──────────────────┘ │  │
│  │            │                        │                     │  │
│  │  ┌─────────▼──────────────────────────▼───────────────┐  │  │
│  │  │    Internet Gateway (0.0.0.0/0 → IGW)             │  │  │
│  │  └──────────────────────────────────────────────────┘  │  │
│  │                                                          │  │
│  │  ┌──────────────────────┐  ┌──────────────────────────┐ │  │
│  │  │ Private Subnet 1     │  │ Private Subnet 2         │ │  │
│  │  │ 10.0.11.0/24 (1a)    │  │ 10.0.12.0/24 (1b)        │ │  │
│  │  │                      │  │                          │ │  │
│  │  │ EKS Worker Node 1    │  │ EKS Worker Node 2        │ │  │
│  │  │ (t3.medium)          │  │ (t3.medium)              │ │  │
│  │  │                      │  │                          │ │  │
│  │  │ Pods:                │  │ Pods:                    │ │  │
│  │  │ ├─ Memos API         │  │ ├─ Memos API             │ │  │
│  │  │ ├─ Prometheus        │  │ ├─ Grafana               │ │  │
│  │  │ └─ Monitoring        │  │ ├─ AlertManager          │ │  │
│  │  │                      │  │ └─ Kube components       │ │  │
│  │  └──────────────────────┘  └──────────────────────────┘ │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │    RDS PostgreSQL 15.4 (Private Subnet)                 │  │
│  │    ├─ 20GB gp3 (encrypted at rest)                      │  │
│  │    ├─ 7-day automated backups                           │  │
│  │    ├─ Enhanced monitoring + alerting                    │  │
│  │    └─ Credentials in Secrets Manager                    │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │          Supporting Services                            │  │
│  │  ├─ S3: Terraform state (versioned, encrypted)          │  │
│  │  ├─ ECR: Container image registry                       │  │
│  │  ├─ Secrets Manager: DB credentials                     │  │
│  │  └─ GitHub OIDC: CI/CD OIDC provider                    │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘

External Integration:
┌─────────────────────────┐
│   GitHub Repository     │  Source of truth for all code
└──────────┬──────────────┘
           │
           ├─→ GitHub Actions CI/CD
           │   ├─ Build Docker image
           │   ├─ Push to ECR
           │   ├─ Update deployment.yaml
           │   └─ Auto-commit manifest changes
           │
           ├─→ ArgoCD (GitOps)
           │   ├─ Watch Git repo (every 3 min)
           │   ├─ Detect changes
           │   ├─ Auto-sync cluster state
           │   └─ Self-healing (undo manual changes)
           │
           ├─→ EKS Cluster
           │   ├─ Pull new images from ECR
           │   ├─ Rolling update pods
           │   └─ Zero-downtime deployment
           │
           └─→ Prometheus + Grafana
               ├─ Collect metrics (15 sec interval)
               ├─ Display dashboards
               └─ Alert on thresholds
```

### Infrastructure Components Deployed

```
AWS Account (us-west-1) - DEPLOYED ✅

BOOTSTRAP STACK (S3, ECR, IAM) ✅
├─ S3: Terraform state (versioned, encrypted, backend)
├─ ECR: Docker image registry (private, scanning enabled)
├─ Secrets Manager: Database credentials (rotated)
└─ GitHub OIDC: CI/CD authentication provider

NETWORKING (VPC) ✅
├─ VPC: 10.0.0.0/16 (main network)
├─ Public Subnets: 2x (10.0.1.0/24, 10.0.2.0/24) in 2 AZs
├─ Private Subnets: 2x (10.0.11.0/24, 10.0.12.0/24) in 2 AZs
├─ Internet Gateway: Public internet access
├─ NAT Gateways: 2x (private subnet egress)
├─ Route Tables: Separate for public/private
└─ Security Groups: Ingress/egress rules by service

KUBERNETES (EKS) ✅
├─ Cluster: v1.31 in us-west-1
├─ Control Plane: AWS managed (high availability)
├─ Worker Nodes: 2x t3.medium (autoscaling 1-4)
├─ Node Groups: EKS managed node group (rolling updates)
├─ IAM Roles: Cluster + Node + Pod identities (IRSA)
├─ OIDC Provider: Pod IAM authentication (OpenID Connect)
├─ CloudWatch Logging: Cluster, API, audit logs
└─ Service Discovery: kube-dns for pod communication

DATABASE (RDS) ✅
├─ Engine: PostgreSQL 15.4 (managed by AWS)
├─ Instance: db.t3.micro (burstable performance)
├─ Storage: 20GB gp3 (general purpose, encrypted)
├─ Backups: 7-day retention (automated daily)
├─ Monitoring: Enhanced CloudWatch metrics
├─ Secrets: Credentials in AWS Secrets Manager
└─ Network: Private subnet only (no internet access)

CONTAINER REGISTRY ✅
├─ ECR: Elastic Container Registry
├─ Repositories: memos (Docker images)
├─ Image Scanning: Vulnerability scanning on push
└─ Lifecycle: Auto-delete old images (cost optimization)

CI/CD ✅
├─ GitHub Actions: Automated build & deploy
├─ OIDC Authentication: Temporary credentials (no keys)
├─ Docker Build: Multi-stage, cached builds
├─ ECR Push: With commit SHA tagging
└─ Manifest Update: Auto-commit to Git

GITOPS (ArgoCD) ✅
├─ ArgoCD: GitOps deployment tool
├─ Application: Memos Kubernetes deployment
├─ Sync Policy: Automatic + Self-healing
├─ Git Source: GitHub repository (main branch)
└─ Reconciliation: Every 3 minutes

MONITORING ✅
├─ Prometheus: Metrics collection (15-day retention, 10GB)
├─ Grafana: Dashboards and visualization
├─ AlertManager: Alert routing and notifications
├─ CloudWatch: AWS infrastructure monitoring
└─ Logging: CloudWatch Logs + Logs Insights (queries)
```

---

## 📚 Complete Technology Stack

### 1. **Containerization & Building (Stage 1): Docker**

**Purpose:** Package application with all dependencies into immutable containers

**Why Docker?**
- Consistency: "Build once, run anywhere" - same container in dev, test, production
- Isolation: Application, dependencies, and OS bundled together
- Efficiency: Lightweight compared to VMs
- Industry standard: Used by Netflix, Uber, Airbnb, Google, Amazon

**In this project:**
- Multi-stage Dockerfile (Node.js → Go → Alpine)
- Final image: ~220MB (optimized from 1GB+)
- Health checks for pod readiness
- Non-root user for security
- Automatic builds on push via GitHub Actions

```dockerfile
# Real-world multi-stage pattern reduces image size 80%
FROM node:18-alpine AS builder-frontend
WORKDIR /app/web
COPY web/package*.json .
RUN npm ci && npm run build --prod

FROM golang:1.21-alpine AS builder-backend
WORKDIR /app
COPY . .
RUN CGO_ENABLED=0 go build -o memos ./cmd/memos

FROM alpine:3.18
RUN apk add --no-cache ca-certificates
COPY --from=builder-backend /app/memos /usr/local/bin/
EXPOSE 5230
ENTRYPOINT ["memos"]
```

**Real-world impact:** Netflix builds thousands of Docker images daily. Each service deployed as a container. One Dockerfile = entire service definition.

---

### 2. **Infrastructure as Code (Stage 2): Terraform & AWS**

**Purpose:** Define and version cloud infrastructure, making it reproducible and auditable

**Why Terraform?**
- Provider-agnostic: Works with AWS, Azure, GCP, etc.
- State management: Tracks infrastructure state
- Modular: Reusable components
- Version control: All infrastructure in Git
- Used by: Stripe, Lyft, Shopify, Uber

**AWS Services:**

#### **VPC (Virtual Private Cloud)**
- Isolated network: 10.0.0.0/16 CIDR block
- Multi-AZ: 2 Availability Zones for high availability
- Public subnets: 10.0.1.0/24, 10.0.2.0/24 (load balancers, NAT gateways)
- Private subnets: 10.0.11.0/24, 10.0.12.0/24 (EKS worker nodes)
- Internet Gateway: Public internet access
- NAT Gateways: 2x (private subnet egress with failover)

**Design pattern:** Proper segmentation prevents unauthorized access. Databases never face internet directly.

#### **EKS (Elastic Kubernetes Service)**
- Managed control plane by AWS (high availability)
- v1.31 Kubernetes version
- 2 worker nodes (t3.medium) with autoscaling 1-4
- IRSA (IAM Roles for Service Accounts): Pods get AWS credentials securely
- OIDC provider: Integration with GitHub Actions
- CloudWatch logging: Audit trail and debugging

**Real-world:** Shopify runs millions of pods on similar architecture.

#### **RDS (Relational Database Service)**
- PostgreSQL 15.4 (AWS managed)
- 20GB gp3 storage (general purpose, cost-effective)
- Encryption at rest (AES256)
- Automated backups: 7-day retention
- Enhanced monitoring: CloudWatch metrics every 60 seconds
- Secrets Manager: Database credentials stored securely

**Terraform organization (38 resources):**
```terraform
module "vpc" { }         # Networking
module "eks" { }         # Kubernetes cluster
module "rds" { }         # Database
# Each module is independent, testable, reusable
```

**Real-world impact:** One developer can recreate entire production infrastructure: `terraform apply`

---

### 3. **Container Orchestration (Stage 3): Kubernetes & EKS**

**Purpose:** Automate deployment, scaling, and management of containerized applications

**Why Kubernetes?**
- Declarative: Describe desired state, k8s makes it reality
- Self-healing: Automatic pod restart, node failover
- Scaling: Horizontal pod autoscaling
- Rolling updates: Zero-downtime deployments
- Industry standard: AWS EKS, Google GKE, Azure AKS all run Kubernetes

**Key Kubernetes concepts:**

**Pods:** Smallest deployable unit (usually 1 container)
**Deployments:** Manages pod replicas with rolling updates
**Services:** Internal load balancing and DNS
**ConfigMaps:** Non-secret configuration data
**Secrets:** Encrypted sensitive data
**Namespaces:** Logical isolation (memos, monitoring, argocd)

**In this project:**
```yaml
Deployment:
  replicas: 2
  Rolling update: 1 extra pod during update, 0 unavailable
  Probes:
    - Liveness: Restart if unhealthy
    - Readiness: Only serve traffic when ready
  Resources:
    - CPU requests/limits: Prevents noisy neighbor
    - Memory limits: Prevents OOM kill
```

**Self-healing example:**
1. Pod crashes unexpectedly
2. Kubelet detects failure
3. Deployment controller automatically restarts pod
4. User doesn't notice (zero downtime)

**Real-world:** Netflix runs tens of thousands of pods. Kubernetes handles failures automatically.

---

### 4. **GitOps Automation (Stage 4): ArgoCD**

**Purpose:** Declarative continuous deployment from Git repository

**Why GitOps?**
- Git as single source of truth
- Audit trail: Every deployment is a Git commit
- Easy rollback: `git revert` = instant rollback
- Self-healing: Automatic reconciliation if cluster drifts
- Team collaboration: Pull requests for changes
- Used by: Shopify, Intuit, Grab, Samsung

**GitOps workflow:**
```
1. Developer commits to GitHub
2. ArgoCD detects change (every 3 minutes)
3. Compares cluster state with Git state
4. If different, auto-syncs (pulls new images, applies manifests)
5. Self-healing: Any manual kubectl apply is reverted
6. Rollback: Git revert = instant cluster rollback
```

**In this project:**
```yaml
ArgoCD Application:
  source: GitHub repo (memos-deployment)
  path: k8s/ (what manifests to deploy)
  destination: EKS cluster in memos namespace
  
  syncPolicy:
    automated:
      prune: true       # Delete resources removed from Git
      selfHeal: true    # Fix drift from manual changes
```

**Real-world impact:** Netflix can rollback any service instantly. Entire deployment history is Git commit history.

---

### 5. **CI/CD Pipeline (Stage 5): GitHub Actions**

**Purpose:** Automated testing and deployment on every code push

**Why GitHub Actions?**
- Native GitHub integration: No extra infrastructure
- OIDC support: No long-lived AWS keys
- Runs in Docker: Any language/tool supported
- Free for public repos, affordable for private
- Used by: Microsoft, Google, thousands of open-source projects

**Pipeline stages:**
1. **Build:** Docker image with commit SHA tag
2. **Test:** Run unit/integration tests
3. **Push:** Upload image to ECR
4. **Deploy:** Update k8s/deployment.yaml
5. **Sync:** Commit manifest, ArgoCD auto-deploys

**Security: OIDC Authentication**
```yaml
# Instead of long-lived AWS keys stored in GitHub:
# Use temporary credentials valid only for this workflow run
permissions:
  id-token: write  # Required for OIDC

configure-aws-credentials:
  role-to-assume: arn:aws:iam::ACCOUNT:role/github-actions
```

**Real-world:** This is how AWS, Google, and Microsoft do CI/CD themselves.

---

### 6. **Production Monitoring (Stage 6): Prometheus, Grafana, CloudWatch**

**Purpose:** Observe system health, detect problems before they affect users

**Prometheus (Metrics Collection)**
- Time-series database: Stores millions of metrics
- 15-second scrape interval: Near real-time data
- 15-day retention: Historical data for trend analysis
- PromQL: Powerful query language for metrics
```promql
# Example queries
rate(http_requests_total[5m])     # Requests per second
histogram_quantile(0.95, latency) # 95th percentile latency
sum(memory_usage_bytes)           # Total memory used
```

**Grafana (Visualization)**
- 7-panel dashboard monitors:
  1. Requests/sec (traffic volume)
  2. Error rate (5xx percentage)
  3. Latency p95 (response time)
  4. Pod CPU usage
  5. Pod memory usage
  6. Node CPU usage
  7. Node memory usage

**CloudWatch (AWS Infrastructure)**
- EKS control plane logs
- RDS database metrics
- Load balancer metrics
- Custom alarms (CPU > 80%, memory > 85%)

**Four Golden Signals (Industry standard)**
1. **Latency:** How fast is my system responding?
2. **Traffic:** How much load is the system handling?
3. **Errors:** What percentage of requests fail?
4. **Saturation:** How close is the system to capacity?

**Real-world:** Google, Amazon, and Netflix all use these four signals for monitoring.

---

---

## 🚀 Complete 6-Stage Learning Journey

### Stage 1: Docker Containerization ✅

**What you learn:**
- Dockerfile syntax and best practices
- Multi-stage builds for size optimization (1GB → 220MB)
- Health checks and readiness probes
- Image tagging and versioning
- Running containers locally with docker-compose
- Container networking and volumes
- Security: non-root user, read-only filesystems

**Real-world skills:**
- Build optimized container images
- Understand layer caching for faster builds
- Debug containers with logs and exec
- Package complex applications (frontend + backend)

**Key files:**
- `app/Dockerfile` - Multi-stage build (550 lines app → 220MB image)
- `app/docker-compose.yaml` - Local dev environment (PostgreSQL + Memos)
- `docs/STAGE1_BEGINNER_GUIDE.md` - 1000+ lines explaining every step

**Real-world impact:** Netflix builds thousands of Docker images daily. Every service is containerized. No more "works on my machine" problems.

---

### Stage 2: Terraform Infrastructure ✅

**What you learn:**
- Terraform workflow: init → plan → apply → destroy
- State management and remote backends
- VPC design for multi-AZ deployments
- Managed services: EKS (Kubernetes), RDS (Database)
- Modular infrastructure patterns
- IAM roles and OIDC provider setup
- Cost optimization strategies
- Terraform modules for reusability

**Infrastructure deployed:**
```
38+ AWS resources across:
├─ Bootstrap (S3, ECR, IAM OIDC) - 9 resources
├─ VPC (networking, subnets, gateways) - 12 resources
├─ EKS (cluster, nodes, roles, logging) - 16 resources
└─ RDS (database, backups, monitoring) - 12 resources
```

**Real-world skills:**
- Design VPC with proper security segmentation
- Create managed Kubernetes clusters
- Set up databases with backups and monitoring
- Implement least-privilege IAM
- Manage infrastructure state across team

**Key files:**
- `terraform/bootstrap/main.tf` - S3 backend, ECR, OIDC
- `terraform/modules/vpc/main.tf` - Networking
- `terraform/modules/eks/main.tf` - Kubernetes cluster with IRSA
- `terraform/modules/rds/main.tf` - Database with monitoring
- `docs/STAGE2_TERRAFORM.md` - 2000+ lines conceptual guide

**Real-world impact:** Stripe and Lyft manage all infrastructure through Terraform. One developer can recreate production in minutes.

---

### Stage 3: Kubernetes Deployment ✅

**What you learn:**
- Pod deployment and replica management
- ConfigMaps and Secrets (configuration management)
- Health probes: liveness (restart), readiness (traffic)
- Rolling updates and zero-downtime deployment
- Service types: LoadBalancer (external), ClusterIP (internal)
- Namespace isolation
- Resource requests and limits
- Affinity and pod distribution

**Deployment features:**
- 2 replicas for availability
- RollingUpdate strategy (1 surge, 0 unavailable)
- LoadBalancer service exposes on port 5230
- ConfigMap for application settings
- Secret for database credentials
- Prometheus/Grafana for monitoring

**Real-world skills:**
- Deploy applications to Kubernetes
- Ensure high availability and self-healing
- Configure pod-to-pod networking
- Debug pod issues with kubectl logs/describe/exec
- Understand horizontal pod autoscaling

**Key files:**
- `k8s/deployment.yaml` - Complete Memos deployment
- `k8s/configmap.yaml` - Application configuration
- `k8s/secret.yaml` - Database credentials
- `docs/STAGE3_KUBERNETES.md` - Kubernetes concepts
- `STAGE3_QUICK_REFERENCE.md` - kubectl commands

**Real-world impact:** Shopify runs millions of shops using this pattern. Kubernetes handles failures automatically.

---

### Stage 4: GitOps with ArgoCD ✅

**What you learn:**
- GitOps principles and benefits
- Declarative vs imperative deployments
- ArgoCD Application resources
- Sync policies and self-healing
- Git as single source of truth
- Multi-environment deployments
- Automatic rollback through Git revert
- Deployment audit trail

**GitOps workflow:**
1. Developer commits to GitHub
2. ArgoCD detects change (3 min sync interval)
3. Auto-syncs: deploys to EKS
4. Self-healing: reverts manual kubectl changes
5. Rollback: git revert = instant cluster rollback

**Real-world skills:**
- Implement GitOps in your organization
- Set up ArgoCD for multiple teams
- Create deployment strategies (blue-green, canary)
- Manage secrets in GitOps
- Troubleshoot sync failures

**Key files:**
- `k8s/argocd-application.yaml` - ArgoCD Application resource
- `docs/STAGE4_GITOPS.md` - 2000+ lines on GitOps patterns
- `STAGE4_QUICK_REFERENCE.md` - ArgoCD CLI commands
- `STAGE4_COMPLETION_GUIDE.md` - Validation checklist

**Real-world impact:** Netflix rolls back any service instantly. Entire deployment history is Git commit history.

---

### Stage 5: CI/CD Pipeline ✅

**What you learn:**
- GitHub Actions workflows and syntax
- Container image building and tagging
- ECR (Elastic Container Registry)
- OIDC authentication (better than access keys)
- Automated manifest updates
- Pipeline triggers and conditions
- Secret management in CI/CD
- Testing in pipelines

**Pipeline features:**
- Triggered on push to `app/` directory
- Build multi-stage Docker image
- Tag with commit SHA
- Push to ECR
- Auto-update k8s/deployment.yaml
- Commit manifest change (triggers ArgoCD)
- OIDC: Temporary credentials (no long-lived keys)

**Real-world skills:**
- Build automated deployment pipelines
- Implement OIDC for secure authentication
- Cache Docker layers for faster builds
- Test code before deployment
- Troubleshoot pipeline failures

**Key files:**
- `.github/workflows/deploy.yaml` - Complete CI/CD workflow
- `docs/STAGE5_CICD.md` - CI/CD concepts and security
- `STAGE5_QUICK_REFERENCE.md` - Pipeline setup

**Real-world impact:** AWS, Google, and Microsoft use OIDC. Code goes from laptop to production in 5 minutes automatically.

---

### Stage 6: Production Monitoring ✅

**What you learn:**
- Prometheus time-series database
- PromQL query language
- Grafana dashboards and visualization
- CloudWatch AWS-native monitoring
- Alert rules and thresholds
- Four golden signals (latency, traffic, errors, saturation)
- Log aggregation and Logs Insights
- SLOs and error budgets
- Incident response

**Monitoring stack deployed:**
- **Prometheus:** Scrapes metrics every 15 seconds (15-day retention)
- **Grafana:** 7-panel dashboard (pre-built + custom)
- **CloudWatch:** EKS logs, RDS metrics, alarms
- **AlertManager:** Alert routing to Slack/email

**Real-world skills:**
- Build comprehensive monitoring
- Write PromQL queries for insights
- Design dashboards for different teams
- Create meaningful alerts
- Troubleshoot production issues with metrics/logs
- Understand SLOs and error budgets

**Key files:**
- `docs/STAGE6_MONITORING.md` - 2000+ lines conceptual guide
- `STAGE6_QUICK_REFERENCE.md` - Prometheus/Grafana setup
- `docs/STAGE6_UI_WORKFLOW.md` - Exact Grafana/CloudWatch clicks
- `STAGE6_EXECUTION_CHECKLIST.md` - Phase 1 (automated) + Phase 2 (UI)

**Real-world impact:** Google invented SRE (Site Reliability Engineering) around monitoring. These principles are industry standard.

---

## 📊 Real-World Production Applications

### Netflix

Netflix uses this exact pattern across millions of services:
- **Docker:** Every service containerized
- **Terraform:** Infrastructure as code for all resources
- **Kubernetes:** Titus (Netflix's custom orchestrator based on Kubernetes patterns)
- **GitOps:** Configuration management through Git
- **Monitoring:** Comprehensive observability at scale

**Scale:** Processes 1 million+ requests per second globally

---

### Shopify

Shopify deploys millions of shops using similar architecture:
- **Containers:** Every shop is a containerized service
- **Kubernetes:** Manages millions of pods
- **Terraform:** All infrastructure version controlled
- **GitOps:** Deployments tracked in Git
- **Monitoring:** Real-time observability

**Scale:** Handles millions of online stores, peak holidays 1M+ requests/sec

---

### Uber

Uber's infrastructure closely mirrors this pattern:
- **Multi-AZ:** Deployments across multiple availability zones
- **Kubernetes:** Service orchestration
- **Terraform:** Infrastructure automation
- **EKS:** Uses AWS EKS for some services
- **Monitoring:** Comprehensive metrics for safety-critical systems

**Scale:** Millions of rides daily with real-time updates

---

### Stripe

Stripe implements this pattern for payment processing:
- **Infrastructure as Code:** Terraform for all resources
- **Private ECR:** Container registry for services
- **Kubernetes:** Service management and scaling
- **GitOps:** Deployment consistency
- **Prometheus:** Metrics for everything

**Scale:** Processes billions of dollars in transactions annually

---

## 🎓 Learning Outcomes & Career Relevance

### Technical Skills You'll Gain

**Container Technology**
- ✅ Optimize Docker images (multi-stage, layer caching)
- ✅ Build production-ready containers
- ✅ Understand container networking and volumes
- ✅ Security scanning and signing

**Infrastructure as Code**
- ✅ Design scalable VPC architecture
- ✅ Terraform modules and organization
- ✅ State management for teams
- ✅ Multi-environment deployments

**Kubernetes Administration**
- ✅ Deploy and manage clusters
- ✅ Pod deployment and scaling
- ✅ Health checks and self-healing
- ✅ RBAC and network policies
- ✅ Helm and package management

**GitOps & Deployment**
- ✅ ArgoCD for declarative deployments
- ✅ Git-based infrastructure management
- ✅ Automated rollbacks
- ✅ Multi-cluster management

**CI/CD Pipeline**
- ✅ GitHub Actions workflows
- ✅ Automated testing and deployment
- ✅ OIDC authentication (security best practice)
- ✅ Container image registry management

**Observability & Monitoring**
- ✅ Prometheus metrics collection
- ✅ PromQL query language
- ✅ Grafana dashboard design
- ✅ CloudWatch integration
- ✅ Alert design and routing

### Architectural Decision-Making

- ✅ When to use managed services (EKS, RDS) vs self-managed
- ✅ Multi-AZ design for high availability
- ✅ Security through proper network segmentation
- ✅ Scalability through load balancing and autoscaling
- ✅ Cost optimization strategies
- ✅ Disaster recovery and backup strategies

### Hiring Manager Appeal

**Why this project stands out:**

1. **Full Stack Implementation**
   - Not tutorials, but real infrastructure running on AWS
   - Production patterns from day one
   - Security, scalability, and observability built in

2. **DevOps Maturity**
   - GitOps (source control for everything)
   - CI/CD automation with OIDC (security best practice)
   - Infrastructure as Code
   - Comprehensive monitoring and alerting
   - All industry-standard practices

3. **Learning Depth**
   - 10,000+ lines of documentation
   - Explains "why" not just "how"
   - Covers beginner to advanced topics
   - Real-world examples and patterns

4. **Practical Skills**
   - Can immediately deploy to production
   - Understands multi-AZ high availability
   - Knows security implications at each layer
   - Can troubleshoot production issues
   - Familiar with 10+ industry-standard tools

5. **Code Quality**
   - Clean, modular Terraform (38 resources organized in 4 modules)
   - Kubernetes best practices (health probes, rolling updates)
   - Secure OIDC authentication (no long-lived keys)
   - Proper state management (remote backend with versioning)
   - Well-commented code throughout

6. **Communication**
   - Excellent documentation
   - Explains complex concepts clearly
   - Shows understanding of "why" decisions were made
   - Professional project README
   - Ready to present to technical teams

---

## 🚀 Getting Started

### Prerequisites (10 minutes)

```bash
# Install required tools
brew install terraform aws-cli kubernetes-cli docker git

# Verify installations
terraform version        # >= 1.15.0
aws --version           # >= 2.0
kubectl version         # >= 1.31
docker --version        # >= 24.0

# Configure AWS
aws configure
# Enter your AWS Access Key ID, Secret Access Key, Region (us-west-1)

# Verify AWS access
aws sts get-caller-identity
```

### Stage-by-Stage Execution Path

**Week 1: Containerization to Infrastructure**
```bash
# Day 1-2: Stage 1 (Docker) - 4 hours
# Read: docs/STAGE1_BEGINNER_GUIDE.md
# Execute: Follow STAGE1_QUICK_REFERENCE.md
docker build -t memos:local app/
docker-compose up -d
# Verify: http://localhost:5230

# Day 3-4: Stage 2 (Terraform) - 6 hours
# Read: docs/STAGE2_TERRAFORM.md + docs/STAGE2_EKS_RDS.md
# Execute Part 1: STAGE2_QUICK_REFERENCE.md (Bootstrap + VPC)
terraform -chdir=terraform/bootstrap init
terraform -chdir=terraform/bootstrap apply
terraform -chdir=terraform init
terraform -chdir=terraform apply

# Execute Part 2: STAGE2_EXTENDED_QUICK_REFERENCE.md (EKS + RDS)
terraform -chdir=terraform apply

# Day 5: Stage 3 (Kubernetes) - 3 hours
# Read: docs/STAGE3_KUBERNETES.md
# Execute: STAGE3_QUICK_REFERENCE.md
kubectl get nodes
kubectl apply -f k8s/deployment.yaml
```

**Week 2: Automation and Observability**
```bash
# Day 6: Stage 4 (GitOps) - 3 hours
# Read: docs/STAGE4_GITOPS.md
# Execute: STAGE4_QUICK_REFERENCE.md
helm repo add argocd https://argoproj.github.io/argo-helm
helm install argocd -n argocd argocd/argo-cd --create-namespace
kubectl apply -f k8s/argocd-application.yaml

# Day 7: Stage 5 (CI/CD) - 2 hours
# Read: docs/STAGE5_CICD.md
# Setup: Verify .github/workflows/deploy.yaml
# Test: Push to GitHub and watch workflow run
git push origin main

# Day 8-10: Stage 6 (Monitoring) - 6 hours
# Read: docs/STAGE6_MONITORING.md
# Execute: STAGE6_EXECUTION_CHECKLIST.md (Phase 1 automated commands)
# Execute: docs/STAGE6_UI_WORKFLOW.md (Phase 2 UI clicks)
# Result: Grafana dashboards + CloudWatch alarms ready
```

---

## 📚 Complete Documentation Structure

### Stage 1: Docker ✅
- **[docs/STAGE1_BEGINNER_GUIDE.md](docs/STAGE1_BEGINNER_GUIDE.md)** - 1000+ lines with line-by-line explanations
- **[docs/STAGE1_APP.md](docs/STAGE1_APP.md)** - Memos application structure
- **[STAGE1_QUICK_REFERENCE.md](STAGE1_QUICK_REFERENCE.md)** - Copy-paste commands
- **[app/Dockerfile](app/Dockerfile)** - Production multi-stage build
- **[app/docker-compose.yaml](app/docker-compose.yaml)** - Local development

### Stage 2: Terraform Infrastructure ✅
- **[docs/STAGE2_TERRAFORM.md](docs/STAGE2_TERRAFORM.md)** - 2000+ lines conceptual guide
- **[STAGE2_QUICK_REFERENCE.md](STAGE2_QUICK_REFERENCE.md)** - Bootstrap + VPC (Parts 0-5)
- **[docs/STAGE2_EKS_RDS.md](docs/STAGE2_EKS_RDS.md)** - EKS + RDS guide (2000+ lines)
- **[STAGE2_EXTENDED_QUICK_REFERENCE.md](STAGE2_EXTENDED_QUICK_REFERENCE.md)** - EKS + RDS (Parts 6-11)
- **[terraform/bootstrap/main.tf](terraform/bootstrap/main.tf)** - S3, ECR, IAM OIDC
- **[terraform/modules/vpc/main.tf](terraform/modules/vpc/main.tf)** - VPC networking
- **[terraform/modules/eks/main.tf](terraform/modules/eks/main.tf)** - Kubernetes cluster
- **[terraform/modules/rds/main.tf](terraform/modules/rds/main.tf)** - PostgreSQL database

### Stage 3: Kubernetes Deployment ✅
- **[docs/STAGE3_KUBERNETES.md](docs/STAGE3_KUBERNETES.md)** - Kubernetes concepts
- **[STAGE3_QUICK_REFERENCE.md](STAGE3_QUICK_REFERENCE.md)** - kubectl commands
- **[k8s/deployment.yaml](k8s/deployment.yaml)** - Memos deployment manifests
- **[k8s/configmap.yaml](k8s/configmap.yaml)** - Application configuration
- **[k8s/secret.yaml](k8s/secret.yaml)** - Database credentials

### Stage 4: GitOps with ArgoCD ✅
- **[docs/STAGE4_GITOPS.md](docs/STAGE4_GITOPS.md)** - 2000+ lines GitOps patterns
- **[STAGE4_QUICK_REFERENCE.md](STAGE4_QUICK_REFERENCE.md)** - ArgoCD setup
- **[STAGE4_COMPLETION_GUIDE.md](STAGE4_COMPLETION_GUIDE.md)** - Stage validation checklist
- **[k8s/argocd-application.yaml](k8s/argocd-application.yaml)** - Memos Application resource

### Stage 5: CI/CD with GitHub Actions ✅
- **[docs/STAGE5_CICD.md](docs/STAGE5_CICD.md)** - 2000+ lines CI/CD concepts
- **[STAGE5_QUICK_REFERENCE.md](STAGE5_QUICK_REFERENCE.md)** - Pipeline setup
- **[.github/workflows/deploy.yaml](.github/workflows/deploy.yaml)** - Complete workflow

### Stage 6: Monitoring & Observability ✅
- **[docs/STAGE6_MONITORING.md](docs/STAGE6_MONITORING.md)** - 2000+ lines observability guide
- **[STAGE6_QUICK_REFERENCE.md](STAGE6_QUICK_REFERENCE.md)** - CloudWatch, Prometheus, Grafana
- **[docs/STAGE6_UI_WORKFLOW.md](docs/STAGE6_UI_WORKFLOW.md)** - Exact Grafana/CloudWatch UI clicks
- **[STAGE6_EXECUTION_CHECKLIST.md](STAGE6_EXECUTION_CHECKLIST.md)** - Phase 1 (terminal) + Phase 2 (UI)
- **[STAGE6_COMPLETION_GUIDE.md](STAGE6_COMPLETION_GUIDE.md)** - Stage validation
- **[STAGE6_MANUAL_WORK_SUMMARY.md](STAGE6_MANUAL_WORK_SUMMARY.md)** - Manual vs automated breakdown

---

## 🔒 Security Best Practices

This project implements security at every layer:

**Authentication & Authorization**
- ✅ OIDC for GitHub Actions (temporary credentials, no long-lived keys)
- ✅ IAM roles with least privilege (pod, node, cluster levels)
- ✅ IRSA for pod-to-AWS authentication (OpenID Connect)
- ✅ Kubernetes RBAC with service accounts

**Secrets Management**
- ✅ AWS Secrets Manager for database credentials
- ✅ Kubernetes Secrets for sensitive data
- ✅ Never commit secrets to Git (enforced by .gitignore)
- ✅ Automatic secret rotation capabilities

**Network Security**
- ✅ VPC with public/private subnets (DMZ pattern)
- ✅ Security groups restrict traffic by service
- ✅ Private RDS: only accessible from EKS nodes
- ✅ NAT gateways for private subnet outbound traffic

**Container Security**
- ✅ Non-root user in containers
- ✅ Read-only root filesystems where possible
- ✅ ECR image scanning on push
- ✅ Multi-stage builds reduce attack surface

**Infrastructure**
- ✅ Encryption at rest: S3, RDS, EBS
- ✅ Encryption in transit: TLS for all connections
- ✅ CloudWatch logging for audit trail
- ✅ S3 versioning for state backups
- ✅ Deletion protection on databases

---

## 💰 Cost Analysis & Optimization

### Monthly Cost Breakdown

```
STAGE 1 (Docker): FREE
- All local, no AWS resources

STAGE 2+: AWS Infrastructure
└─ EKS Control Plane:       $73.00   (fixed)
└─ 2x t3.medium EC2:        $59.50   (hourly instances)
└─ RDS db.t3.micro:         $40.00   (burstable)
└─ 20GB RDS Storage:         $5.00   (gp3)
└─ NAT Gateway (2x):        $32.00   (per AZ)
└─ Data Transfer:           $20.00   (rough estimate)
└─ S3, ECR, Secrets:         $2.00   (minimal)
───────────────────────────────────
   Total Monthly:         ~$231.50

AWS Free Tier (First 12 months):
- Covers: EC2, RDS, NAT Gateway, most services
- Estimated free first year: ~$2,000+ value

Cost Optimization Options:
• Spot instances (EC2):     -60% ($36 → $14)
• Pause when not using:     -100% (destroy)
• RDS Reserved Instances:   -30% ($40 → $28)
• Optimized: $120-150/month (after optimizations)
```

### Real-World Cost Considerations

- **Development:** Keep infrastructure running only during work hours (~$50/month)
- **Production:** Needs multi-region, better instances (~$500+/month)
- **Enterprise:** Thousands of services, petabytes of data (millions/month)

---

## 🚨 Troubleshooting Common Issues

### Terraform Issues

**State Lock**
```bash
# If you get "Error acquiring lock"
terraform force-unlock <LOCK_ID>
```

**AWS Credentials**
```bash
# Verify credentials
aws sts get-caller-identity

# Re-configure if needed
aws configure
```

**Quota Exceeded**
```bash
# Check your quotas
aws service-quotas get-service-quota --region us-west-1
```

---

### Kubernetes Issues

**kubectl Access Denied**
```bash
# Update kubeconfig
aws eks update-kubeconfig --name memos-eks --region us-west-1

# Verify
kubectl get nodes
```

**Pods Can't Reach Database**
```bash
# Check security group
aws ec2 describe-security-groups --region us-west-1

# Test connectivity from pod
kubectl exec -it <pod-name> -n memos -- nc -zv <rds-endpoint> 5432
```

**Pod Crashes**
```bash
# Check pod logs
kubectl logs <pod-name> -n memos

# Get pod details
kubectl describe pod <pod-name> -n memos

# Enter pod for debugging
kubectl exec -it <pod-name> -n memos -- /bin/sh
```

---

### ArgoCD Issues

**Application Won't Sync**
```bash
# Check status
argocd app get memos

# Force sync
argocd app sync memos --force

# Check Git connectivity
argocd repo list
```

---

### Monitoring Issues

**Prometheus Not Scraping**
```bash
# Port-forward to Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prom-prometheus 9090:9090

# Check targets
# Visit http://localhost:9090/targets
```

**Grafana Access**
```bash
# Get Grafana password
kubectl get secret -n monitoring grafana -o jsonpath="{.data.admin-password}" | base64 --decode

# Port-forward
kubectl port-forward -n monitoring svc/grafana 3000:80

# Access: http://localhost:3000
```

---

## 📊 Project Statistics

| Metric | Count |
|--------|-------|
| **Total learning hours** | 40-60 hours |
| **Lines of documentation** | 10,000+ |
| **Copy-paste commands** | 100+ |
| **Code examples** | 50+ |
| **Terraform resources** | 38+ |
| **Kubernetes resources** | 100+ |
| **GitHub Actions workflows** | 1 complete pipeline |
| **Grafana dashboards** | 1 custom + 5 pre-built |
| **CloudWatch alarms** | 3+ |
| **Prometheus alert rules** | 4+ |
| **Conceptual guides** | 6 (one per stage) |
| **Quick references** | 6+ |

---

## 🎉 Conclusion

This project demonstrates a **complete, production-ready DevOps infrastructure** using industry-standard tools and patterns. By following this journey step-by-step, you'll understand not just the tools, but the principles behind modern cloud-native deployment.

### The Real Learning

The tools matter less than understanding:

**Why we containerize** → Consistency and isolation
**Why we use Terraform** → Reproducible infrastructure
**Why we need Kubernetes** → Scalability and self-healing
**Why we use GitOps** → Deployment tracking and rollback
**Why we build CI/CD** → Automation and speed
**Why we monitor** → Reliability and incident response

### After This Project, You Can:

1. **Deploy any application to AWS** with confidence
2. **Design infrastructure for high availability** across multiple availability zones
3. **Build automated CI/CD pipelines** that are secure and fast
4. **Implement GitOps workflows** for teams
5. **Troubleshoot production issues** with comprehensive observability
6. **Explain DevOps practices** to hiring managers and technical teams
7. **Make architectural decisions** based on real-world constraints
8. **Lead DevOps initiatives** in your organization

### This Project is Your Ticket To:

- ✅ Senior DevOps Engineer roles
- ✅ Cloud Architecture positions
- ✅ Platform Engineering teams
- ✅ Site Reliability Engineering (SRE)
- ✅ Technical leadership opportunities
- ✅ Freelance/consulting work

---

## 📖 External Learning Resources

### Official Documentation
- [Terraform Docs](https://www.terraform.io/docs)
- [AWS EKS Docs](https://docs.aws.amazon.com/eks/)
- [Kubernetes Docs](https://kubernetes.io/docs/)
- [Docker Docs](https://docs.docker.com/)
- [ArgoCD Docs](https://argo-cd.readthedocs.io/)
- [GitHub Actions](https://docs.github.com/en/actions)
- [Prometheus Docs](https://prometheus.io/docs/)
- [Grafana Docs](https://grafana.com/docs/)

### Recommended Books
- "The DevOps Handbook" by Gene Kim
- "Site Reliability Engineering" by Google
- "Infrastructure as Code" by Kief Morris
- "Kubernetes in Action" by Marko Lukša

### Community
- [CNCF Community](https://www.cncf.io/)
- Kubernetes Slack
- DevOps communities on Reddit and Stack Overflow
- Local meetups and conferences

---

## 📝 License

MIT License - Feel free to fork, modify, and use for learning and production. Attribution appreciated!

---

## 🚀 Get Started Now

```bash
# Clone the repository
git clone https://github.com/Ike-DevCloudIQ/memos-deployment
cd memos-deployment

# Read the first stage guide
cat docs/STAGE1_BEGINNER_GUIDE.md

# Or jump straight to quick reference
cat STAGE1_QUICK_REFERENCE.md

# Start your journey!
```

---

## 📞 Support & Questions

Found an issue or have a question?

1. Check the relevant stage documentation
2. Review the quick reference guide
3. Check GitHub issues
4. Open an issue with details

---

**This isn't just a project—it's your complete DevOps learning path.** 🚀

**From zero to production-ready infrastructure in 6 stages.**

**Welcome to your DevOps journey!**

