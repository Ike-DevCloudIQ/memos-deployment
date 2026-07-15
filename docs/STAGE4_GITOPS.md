# Stage 4: GitOps with ArgoCD - Conceptual Guide

> **Learn how to automate Kubernetes deployments from Git using ArgoCD**

---

## What is GitOps?

**GitOps = Everything defined in Git**

Key principles:
1. **Git is the source of truth** - All infrastructure and app configs live in Git
2. **Automated deployments** - Changes in Git automatically deploy to cluster
3. **Declarative configuration** - Describe desired state, not commands
4. **Continuous reconciliation** - Controller constantly syncs cluster to Git
5. **Audit trail** - Git history = deployment history
6. **Rollback friendly** - Revert commit = rollback deployment

**Why GitOps?**

| Feature | Traditional | GitOps |
|---------|-------------|--------|
| Who deploys? | Human (CLI) | Automated (Git push) |
| Source of truth | Cluster | Git repository |
| Rollback | Manual CLI commands | Git revert |
| Audit trail | Logs (unclear) | Git history (clear) |
| Multi-environment | Manual syncing | Automatically synced |
| Disaster recovery | Manual restore | Git clone + apply |
| Compliance | Manual checks | Automated verification |

---

## What is ArgoCD?

**ArgoCD = GitOps controller for Kubernetes**

ArgoCD watches Git repositories and automatically applies changes to your Kubernetes cluster.

### How ArgoCD Works

```
┌─────────────────────────────────────┐
│         Your Git Repository         │
│  (GitHub, GitLab, Bitbucket, etc)   │
│                                     │
│  ├─ k8s/                            │
│  │  ├─ deployment.yaml              │
│  │  ├─ service.yaml                 │
│  │  ├─ configmap.yaml               │
│  │  └─ secrets.yaml                 │
│  │                                  │
│  └─ argocd/                         │
│     └─ applications/                │
│        └─ memos-app.yaml            │
└─────────────────────────────────────┘
          ↓ (watches)
┌─────────────────────────────────────┐
│      ArgoCD Application             │
│  (running in EKS cluster)           │
│                                     │
│  Every 3 minutes (default):         │
│  1. Check Git for changes           │
│  2. Compare with cluster state      │
│  3. If different, apply changes     │
│  4. Sync cluster to Git state       │
└─────────────────────────────────────┘
          ↓ (applies)
┌─────────────────────────────────────┐
│      Your EKS Cluster               │
│                                     │
│  ├─ Namespace: memos                │
│  ├─ Deployment: memos (2 replicas)  │
│  ├─ Service: memos (LoadBalancer)   │
│  ├─ ConfigMap: memos-config         │
│  └─ Secret: memos-db-secret         │
└─────────────────────────────────────┘
```

### ArgoCD Components

1. **API Server** - REST API for ArgoCD UI/CLI
2. **Repository Server** - Clones Git repo, generates Kubernetes manifests
3. **Controller** - Watches Git and EKS, syncs differences
4. **Application Controller** - Manages ArgoCD Application resources
5. **UI** - Web dashboard to view deployments
6. **Dex** - Authentication provider (optional)
7. **Redis** - Cache for performance

---

## Key Concepts

### 1. ArgoCD Application

**What is it?** A resource that defines:
- Which Git repository to watch
- Which manifests to apply
- Where to deploy (which cluster)
- Sync policy (automatic or manual)
- Health assessment

**Example:**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: memos
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/Ike-DevCloudIQ/memos-deployment
    path: k8s
    targetRevision: HEAD
  destination:
    server: https://kubernetes.default.svc
    namespace: memos
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### 2. Sync Policy

**Manual Sync:**
- Git changes are detected but NOT applied
- Human must click "Sync" in ArgoCD UI
- Good for: Testing, approval workflows, cautious deployments

**Automatic Sync:**
- Git changes are automatically applied to cluster
- No human approval needed
- Good for: Dev environments, continuous deployment
- Options:
  - `prune: true` - Delete resources removed from Git
  - `selfHeal: true` - Fix cluster drift (manual kubectl changes)

### 3. Application Health

ArgoCD evaluates if your app is healthy:

**Healthy:**
- Deployment: All replicas ready
- Service: Has endpoints
- ConfigMap/Secret: Exist

**Degraded:**
- Deployment: Some replicas not ready
- Pod: CrashLoopBackOff, ImagePullBackOff
- Missing resources

**Unknown:**
- Resource type not recognized

---

## GitOps Workflow

### Step 1: Push to Git
```bash
git add k8s/deployment.yaml
git commit -m "Update Memos replica count to 3"
git push origin main
```

### Step 2: ArgoCD Detects Change
- Repository Server clones latest commit
- Compares Git state with cluster state
- Generates report of differences

### Step 3: Sync to Cluster
**With Automatic Sync (enabled):**
- ArgoCD automatically applies changes
- Deployment scales from 2 → 3 replicas

**With Manual Sync (disabled):**
- ArgoCD shows "Out of Sync" in UI
- Admin clicks "Sync" button
- Changes applied

### Step 4: Verify Deployment
```bash
kubectl get pods -n memos

# Output:
# memos-abc123   Running
# memos-def456   Running
# memos-ghi789   Running  (new)
```

### Step 5: Rollback (if needed)
```bash
# Revert last commit in Git
git revert HEAD
git push origin main

# ArgoCD automatically syncs cluster back to previous state
```

---

## Installation & Setup

### Part 1: Install ArgoCD

**Prerequisites:**
- EKS cluster running (from Stage 2)
- kubectl configured
- Git repository set up

**Installation:**

```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD using kubectl apply
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Or use Helm (alternative):
helm repo add argocd https://argoproj.github.io/argo-helm
helm install argocd argocd/argo-cd \
  --namespace argocd \
  --set server.service.type=LoadBalancer
```

**Wait for all ArgoCD pods to be ready:**
```bash
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/part-of=argocd \
  -n argocd \
  --timeout=300s
```

### Part 2: Access ArgoCD UI

**Get admin password:**
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

**Port forward to access:**
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

**Access UI:**
- URL: https://localhost:8080
- Username: admin
- Password: (from above)

**Or expose via Load Balancer:**
```bash
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
kubectl get svc -n argocd argocd-server
# Get external IP and access at https://<IP>
```

### Part 3: Connect Git Repository

**In ArgoCD UI:**
1. Go to Settings → Repositories
2. Click "Connect Repo Using SSH" or "HTTPS"
3. Enter repository URL: `https://github.com/Ike-DevCloudIQ/memos-deployment`
4. Click Connect

**Or via CLI:**
```bash
argocd repo add https://github.com/Ike-DevCloudIQ/memos-deployment \
  --username <github-user> \
  --password <personal-access-token>
```

### Part 4: Create ArgoCD Application

**Via UI:**
1. Click "New App"
2. Fill in:
   - **Application Name:** memos
   - **Project:** default
   - **Repository URL:** https://github.com/Ike-DevCloudIQ/memos-deployment
   - **Path:** k8s
   - **Cluster URL:** https://kubernetes.default.svc
   - **Namespace:** memos
3. Click "Create"

**Or via YAML:**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: memos
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/Ike-DevCloudIQ/memos-deployment
    targetRevision: HEAD
    path: k8s
  destination:
    server: https://kubernetes.default.svc
    namespace: memos
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

---

## GitOps Best Practices

### 1. **Git Repository Structure**
```
memos-deployment/
├── k8s/                     # All Kubernetes manifests
│   ├── deployment.yaml      # Memos deployment
│   ├── service.yaml         # Load balancer
│   ├── configmap.yaml       # App config
│   └── secrets.yaml         # Secrets (encrypted)
├── argocd/                  # ArgoCD configs
│   ├── namespace.yaml       # ArgoCD namespace
│   ├── application.yaml     # Memos Application
│   └── applicationset.yaml  # Multi-environment (optional)
└── README.md                # Documentation
```

### 2. **Environment Separation**

For multiple environments (dev, staging, prod):

**Option A: Multiple branches**
```
main branch → prod
staging branch → staging
dev branch → dev
```

**Option B: Multiple directories**
```
k8s/
├── dev/
│   ├── deployment.yaml
│   └── kustomization.yaml
├── staging/
│   ├── deployment.yaml
│   └── kustomization.yaml
└── prod/
    ├── deployment.yaml
    └── kustomization.yaml
```

**Option C: Kustomize overlays**
```
k8s/
├── base/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml
└── overlays/
    ├── dev/kustomization.yaml
    ├── staging/kustomization.yaml
    └── prod/kustomization.yaml
```

### 3. **Secrets Management**

**Never commit secrets to Git!**

Options:
1. **AWS Secrets Manager** (recommended)
   - Store secrets in AWS
   - Pods retrieve at runtime
   - Secure, auditable

2. **Sealed Secrets**
   - Encrypt secrets in Git
   - Only cluster can decrypt
   - Safe to commit

3. **External Secrets Operator**
   - Fetch secrets from AWS/Azure/HashiCorp
   - Auto-update in cluster

### 4. **Approval Workflows**

For production, require code review:

```yaml
syncPolicy:
  syncOptions:
    - Validate=false  # Skip validation
  # Manual sync = requires human approval
```

Then:
```bash
# Admin reviews the ArgoCD Application change
# Manually clicks "Sync" in UI
```

### 5. **Notifications & Alerts**

Configure notifications for:
- Sync success/failure
- Health status changes
- Deployment rollbacks

**Via Slack:**
```bash
argocd notification trigger on-deployed \
  --recipient slack:devops-channel
```

### 6. **High Availability**

For production:
```bash
# Install ArgoCD in HA mode
kubectl apply -n argocd -f \
  https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/ha/install.yaml
```

Features:
- 3 API server replicas
- 3 Repository server replicas
- 3 Application controller replicas
- Redis high availability

---

## Common ArgoCD Operations

### View Applications
```bash
# Via CLI
argocd app list

# Via kubectl
kubectl get applications -n argocd
```

### Sync Application
```bash
# Manual sync
argocd app sync memos

# With specific revision
argocd app sync memos --revision main

# Dry run (preview changes)
argocd app sync memos --dry-run
```

### Check Application Status
```bash
argocd app get memos
kubectl describe application memos -n argocd
```

### Edit Application
```bash
# Via UI (easiest)
# Go to memos app → Click "Edit"

# Via CLI
kubectl edit application memos -n argocd

# Via argocd CLI
argocd app set memos --sync-policy=automatic
```

### Rollback
```bash
# Rollback to previous sync
argocd app rollback memos

# Or just git revert
git revert HEAD
git push origin main
# ArgoCD automatically syncs
```

### Delete Application
```bash
argocd app delete memos
kubectl delete application memos -n argocd
```

---

## Troubleshooting

### Application shows "OutOfSync"

**Cause:** Git differs from cluster

**Solution:**
```bash
# Manual sync
argocd app sync memos

# Or auto-sync enabled in syncPolicy
```

### Application shows "Degraded"

**Cause:** Pod not ready, image pull failed, etc.

**Solution:**
```bash
# Check pod status
kubectl get pods -n memos
kubectl describe pod memos-xxx -n memos
kubectl logs memos-xxx -n memos

# Check deployment
kubectl describe deployment memos -n memos
```

### ArgoCD can't access Git repository

**Cause:** Invalid credentials or SSH key

**Solution:**
```bash
# Re-add repository with correct credentials
argocd repo rm https://github.com/Ike-DevCloudIQ/memos-deployment
argocd repo add https://github.com/Ike-DevCloudIQ/memos-deployment \
  --username <user> \
  --password <token>
```

### Application stuck in "Syncing"

**Cause:** Long-running sync, networking issue, or deadlock

**Solution:**
```bash
# Abort sync
argocd app terminate-op memos

# Or restart ArgoCD controller
kubectl rollout restart deployment argocd-application-controller -n argocd
```

---

## Summary

**GitOps with ArgoCD enables:**
- ✅ Git-driven deployments
- ✅ Automatic synchronization
- ✅ Easy rollbacks via Git history
- ✅ Audit trail of all changes
- ✅ Multi-environment management
- ✅ Disaster recovery (Git clone + apply)
- ✅ Team collaboration (pull requests for changes)
- ✅ Compliance & governance

**Next steps:**
- Install ArgoCD on EKS
- Create Memos Application manifest
- Push to Git and watch it deploy!

---

## Resources

- [ArgoCD Official Docs](https://argo-cd.readthedocs.io/)
- [GitOps Best Practices](https://www.gitops.tech/)
- [Kubernetes Deployment Patterns](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Kustomize Documentation](https://kustomize.io/)
