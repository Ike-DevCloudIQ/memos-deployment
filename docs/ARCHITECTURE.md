# Memos Deployment Architecture

## High-Level System Design

```
┌─────────────────────────────────────────────────────────────────┐
│                    STAGE 5: CI/CD & Automation                  │
│  GitHub Actions: Build → Push to ECR → Deploy to EKS            │
└─────────────────────────────────────────────────────────────────┘
                              ▲
                              │ (automated deployment)
┌─────────────────────────────────────────────────────────────────┐
│             STAGE 4: GitOps (ArgoCD)                             │
│  Watches GitHub → Syncs to Kubernetes → Auto-Deploy             │
└─────────────────────────────────────────────────────────────────┘
                              ▲
                              │ (manifest sync)
┌─────────────────────────────────────────────────────────────────┐
│        STAGE 3: Kubernetes (EKS on AWS)                          │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ Memos Deployment        Database StatefulSet            │    │
│  │ - 3 replicas           - RDS PostgreSQL (AWS managed)   │    │
│  │ - Service load balancer - Automated backups             │    │
│  │ - ConfigMaps            - Multi-AZ failover             │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
                              ▲
              Created by (Stage 2: Terraform)
┌─────────────────────────────────────────────────────────────────┐
│     STAGE 2: Infrastructure as Code (Terraform)                  │
│  Modules:                                                        │
│  - VPC (networking)                                             │
│  - EKS (managed Kubernetes)                                     │
│  - RDS (managed database)                                       │
│  - Security Groups, IAM, ECR                                    │
└─────────────────────────────────────────────────────────────────┘
                              ▲
                   Runs inside (containerized)
┌─────────────────────────────────────────────────────────────────┐
│      STAGE 1: Application (Docker Container)                     │
│  ┌──────────────────┐  ┌──────────────────┐                     │
│  │ Memos Backend    │  │ Frontend (React) │                     │
│  │ - Go REST API    │  │ - Web UI         │                     │
│  │ - Port 5230      │  │ - Built & served │                     │
│  └──────────────────┘  └──────────────────┘                     │
│              ▼                                                    │
│  ┌──────────────────────────────────────────┐                   │
│  │ PostgreSQL Database (local dev)          │                   │
│  │ - Port 5432                              │                   │
│  └──────────────────────────────────────────┘                   │
└─────────────────────────────────────────────────────────────────┘

STAGE 6: Monitoring & Observability (runs across all layers)
  - Prometheus: Metrics collection
  - Grafana: Visualization & dashboards
  - Application Insights: Application performance monitoring
  - CloudWatch: AWS infrastructure monitoring
```

---

## Component Breakdown

### Stage 1: Application Layer
**Purpose**: Package and run the Memos application

**Components**:
- **Dockerfile**: Defines how to build the container image
- **docker-compose**: Local development multi-container setup
- **App**: Containerized Memos (backend + frontend)
- **Database**: PostgreSQL for data persistence

**Outputs**:
- Docker image ready for deployment
- Verified running locally

---

### Stage 2: Infrastructure Layer (Terraform)
**Purpose**: Create cloud infrastructure on AWS

**Components**:
- **VPC Module**: Virtual network, subnets, routing
- **EKS Module**: Managed Kubernetes cluster
- **RDS Module**: Managed PostgreSQL database
- **IAM Module**: Identity and access management
- **Security Module**: Network policies, security groups
- **ECR Module**: Container registry for images

**Outputs**:
- VPC with public/private subnets
- EKS cluster with worker nodes
- RDS PostgreSQL database
- ECR repository for container images
- All networking/security configured

---

### Stage 3: Kubernetes Layer
**Purpose**: Deploy and manage containerized apps

**Concepts**:
- **Deployment**: Manages pod replicas (usually 3 for HA)
- **Service**: Load balancer for pod traffic
- **ConfigMap**: Configuration data (passed to pods)
- **PersistentVolume**: Storage that survives pod restarts
- **Namespace**: Logical isolation of resources

**Our Deployment**:
```
Namespace: production
├── Memos Deployment (3 replicas)
│   ├── Pod 1 (memos container)
│   ├── Pod 2 (memos container)
│   └── Pod 3 (memos container)
├── Service (ClusterIP load balancer)
├── Ingress (external access via DNS)
└── ConfigMap (environment config)

RDS (outside K8s):
└── PostgreSQL database
```

---

### Stage 4: GitOps Layer (ArgoCD)
**Purpose**: Automated deployment from Git

**Workflow**:
```
1. Developer commits changes to Git
2. ArgoCD detects changes (every 3 minutes or via webhook)
3. ArgoCD reads K8s manifests from Git
4. ArgoCD applies manifests to K8s cluster
5. Cluster state matches Git state (declarative)
```

**Benefits**:
- Single source of truth: Git
- Automated deployments
- Easy rollback (revert Git commit)
- Audit trail (Git history)
- No manual kubectl commands

---

### Stage 5: CI/CD Layer (GitHub Actions)
**Purpose**: Automate build, test, and deployment

**Workflows**:
1. **Build Workflow** (on push to main):
   - Build Docker image
   - Run tests
   - Push to ECR

2. **Deploy Workflow**:
   - Update K8s manifests
   - Commit to Git (triggers ArgoCD)
   - ArgoCD handles actual deployment

3. **Terraform Workflow**:
   - Plan infrastructure changes
   - Apply on approval
   - Update state

---

### Stage 6: Observability Layer
**Purpose**: Monitor, log, and alert

**Monitoring Stack**:
- **Prometheus**: Scrapes metrics from app & infrastructure
- **Grafana**: Visualizes metrics in dashboards
- **Application Insights**: Azure APM for deep app insights
- **CloudWatch**: AWS native monitoring

**Dashboards Track**:
- Pod health (CPU, memory, restarts)
- Request rates and latencies
- Error rates
- Database performance
- Infrastructure health (nodes, network)

---

## Data Flow Example: Creating a Note

```
1. User opens browser
   └─> HTTP GET http://example.com

2. Browser receives frontend (React app)
   └─> Served by Memos backend (port 5230)

3. User types note and clicks "Save"
   └─> React JS sends: POST /api/v1/memos
       └─> HTTP request to backend service

4. Service load balancer picks a pod
   └─> Any of 3 Memos pods (round-robin)

5. Pod processes request
   └─> Writes to PostgreSQL database

6. Database stores note persistently

7. Response sent back to browser

8. Prometheus collects metrics
   └─> Request count, latency, etc.

9. Grafana displays in real-time dashboard
   └─> DevOps team monitors health
```

---

## Deployment Topology

```
AWS Account (184353012435)
└── us-west-1 region
    ├── VPC (10.0.0.0/16)
    │   ├── Public Subnet AZ-1 (10.0.1.0/24)
    │   ├── Public Subnet AZ-2 (10.0.2.0/24)
    │   ├── Private Subnet AZ-1 (10.0.11.0/24)
    │   └── Private Subnet AZ-2 (10.0.12.0/24)
    │
    ├── EKS Cluster (Kubernetes 1.27+)
    │   ├── Node Group 1 (us-west-1a) - t3.medium
    │   ├── Node Group 2 (us-west-1b) - t3.medium
    │   └── Control Plane (AWS managed, multi-AZ)
    │
    ├── RDS Database (us-west-1a + failover)
    │   └── PostgreSQL 15 (db.t3.micro, Multi-AZ)
    │
    ├── ECR Repository (memos:latest)
    │
    └── Security Groups (network policies)
```

---

## Security Principles

### Network Security
- **VPC**: Private by default
- **Security Groups**: Explicit allow rules
- **Network Policies**: K8s controls pod-to-pod traffic
- **Ingress**: Only on 443 (HTTPS) to API

### Application Security
- **Non-root containers**: Run as `memos` user
- **Read-only filesystem**: Prevent code modification
- **Resource limits**: Prevent resource exhaustion
- **Health checks**: Detect unhealthy pods automatically

### Access Control (RBAC)
- **IAM**: AWS service accounts and roles
- **Kubernetes RBAC**: Pod permissions
- **Secrets Management**: No hardcoded passwords
- **Audit logging**: Track all actions

---

## High Availability & Disaster Recovery

### High Availability
- **3 Memos pods**: If one dies, 2 others handle traffic
- **Multi-AZ RDS**: Automatic failover to replica
- **Auto-scaling**: Add pods if CPU/memory high
- **Health checks**: Restart unhealthy pods automatically

### Disaster Recovery
- **Automated backups**: RDS backs up every 5 minutes
- **Git as source of truth**: Redeploy from Git in minutes
- **Regional redundancy**: Deploy to multiple regions if needed
- **Secrets backup**: Encrypt and back up credentials

---

## Cost Considerations

### AWS Services Used (rough monthly cost)
- **EKS**: ~$73 (cluster fee) + ~$0.04/node/hour
- **EC2 (t3.medium nodes)**: ~$30/month per node
- **RDS (db.t3.micro)**: ~$30/month
- **NAT Gateway**: ~$45/month
- **Data transfer**: ~$5-50/month
- **ECR**: ~$1-5/month for image storage

**Total**: ~$200-300/month for development/small production

### Cost Optimization Tips
- Use Spot instances for non-critical workloads
- Right-size databases (t3.micro → t3.small if needed)
- Archive old RDS backups
- Delete unused resources

---

## Next Steps

1. **Stage 1 (Complete)**: Containerize the app
2. **Stage 2**: Write Terraform to create AWS infrastructure
3. **Stage 3**: Deploy app to Kubernetes
4. **Stage 4**: Set up ArgoCD for GitOps
5. **Stage 5**: Build GitHub Actions CI/CD
6. **Stage 6**: Add monitoring with Prometheus + Grafana
