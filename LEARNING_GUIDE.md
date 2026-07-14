# DevOps Mastery: Memos on EKS - Complete Learning Guide

> **Goal**: Build, containerize, and deploy the Memos app to AWS EKS with production-grade DevOps practices.
> You'll learn by **doing**, understanding **why** at each step.

---

## 📚 6-Stage Learning Path

### **Stage 1: The Application** (Current)
**What you'll learn**: Docker, containerization, local development workflow
- Understand the Memos application
- Create Dockerfile for Memos
- Run app locally with Docker
- Use docker-compose for multi-service setup
- **Outcome**: App runs in container on your machine

### **Stage 2: Infrastructure as Code (Terraform)**
**What you'll learn**: IaC principles, modular architecture, AWS resources
- Write Terraform modules for AWS resources (VPC, EKS, RDS)
- Understand state management, variables, outputs
- Practice dependency management
- **Outcome**: Infrastructure deployable with `terraform apply`

### **Stage 3: Kubernetes Deployments**
**What you'll learn**: Container orchestration, K8s primitives, cloud-native apps
- Deploy Memos to EKS cluster
- Learn Deployments, Services, ConfigMaps, StatefulSets
- Manage scaling, health checks, resource limits
- **Outcome**: Memos app runs on Kubernetes cluster

### **Stage 4: GitOps with ArgoCD**
**What you'll learn**: GitOps workflow, declarative deployments, sync automation
- Install and configure ArgoCD
- Create ArgoCD Applications for automated sync
- Implement GitOps best practices
- **Outcome**: Changes in Git automatically deploy to K8s

### **Stage 5: CI/CD Pipelines (GitHub Actions)**
**What you'll learn**: Automation, workflows, testing, deployment orchestration
- Create GitHub Actions workflows
- Automate Docker builds and ECR pushes
- Automate Terraform deployments
- **Outcome**: Commit code → auto-build → auto-deploy

### **Stage 6: Monitoring & Observability**
**What you'll learn**: Observability stack, metrics, logging, alerting
- Deploy Prometheus for metrics collection
- Create Grafana dashboards
- Set up application monitoring
- **Outcome**: Real-time visibility into app and infrastructure health

---

## 🎯 Stage 1: The Application - Deep Dive

### Why Start with the App?

**Good DevOps starts with understanding what you're deploying.**

Many DevOps engineers learn infrastructure first, then wonder why apps don't run. Instead, we'll:
1. **Understand** the Memos app (what it does, dependencies, requirements)
2. **Containerize** it (create a production-grade Dockerfile)
3. **Run it locally** (verify it works before infrastructure)
4. **Document** it (so others can contribute)

### Stage 1: Learning Objectives

By the end of Stage 1, you will understand:
- ✅ What Memos is and how it works
- ✅ Application dependencies (Node.js, Go, databases)
- ✅ Docker concepts (images, containers, registries)
- ✅ How to write a Dockerfile
- ✅ Docker-compose for local multi-container development
- ✅ How to debug containerized applications

### Stage 1: Hands-On Tasks

#### Task 1.1: Understand the Memos Application
- Clone the Memos repository
- Read README and architecture documentation
- Identify key components: frontend, backend, database
- Document system requirements

#### Task 1.2: Create Dockerfile
- Write production-grade Dockerfile
- Multi-stage builds (reduce image size)
- Non-root user (security best practice)
- Proper entrypoint handling

#### Task 1.3: Create docker-compose.yaml
- Memos service (our built container)
- PostgreSQL database
- Network and volumes
- Environment configuration

#### Task 1.4: Run & Test Locally
- Build Docker image
- Run with docker-compose
- Verify app is accessible at localhost:5230
- Test basic functionality
- Verify database persistence

#### Task 1.5: Document Everything
- Add deployment documentation
- Document environment variables
- Create troubleshooting guide
- Add to README

---

## 📋 Repository Structure

```
memos-deployment/
├── README.md                  # Project overview
├── LEARNING_GUIDE.md          # This file
├── docs/
│   ├── ARCHITECTURE.md        # System design
│   ├── STAGE1_APP.md          # Stage 1 detailed guide
│   ├── STAGE2_TERRAFORM.md    # (Coming in Stage 2)
│   └── ...
├── app/
│   ├── Dockerfile             # Multi-stage Dockerfile
│   └── docker-compose.yaml    # Local development
├── terraform/                 # (Stage 2)
│   ├── bootstrap/
│   ├── modules/
│   └── main.tf
├── k8s/                       # (Stage 3)
│   ├── deployments/
│   ├── services/
│   └── configmaps/
├── argocd/                    # (Stage 4)
└── .github/
    └── workflows/             # (Stage 5)
```

---

## 🚀 Starting Stage 1

**Next Steps**:
1. Proceed to Stage 1 detailed guide
2. Start Task 1.1: Understand the Memos application
3. We'll validate each task before moving forward

Ready? Let's begin! 🎓
