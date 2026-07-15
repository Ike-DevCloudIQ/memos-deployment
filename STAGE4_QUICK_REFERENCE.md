# Stage 4: GitOps with ArgoCD - QUICK REFERENCE

> **Copy-paste commands to install ArgoCD and deploy Memos with GitOps**

---

## Part 1: Prerequisites

### Step 1.1: Verify EKS cluster is running

```bash
# Update kubeconfig
aws eks update-kubeconfig --name memos-eks --region us-west-1

# Verify cluster access
kubectl get nodes

# Expected: 2 nodes with STATUS=Ready
```

### Step 1.2: Verify Git repository is configured

```bash
# Go to memos-deployment directory
cd ~/Desktop/Nouriva/memos-deployment

# Verify remote is set
git remote -v

# Expected:
# origin  https://github.com/Ike-DevCloudIQ/memos-deployment (fetch)
# origin  https://github.com/Ike-DevCloudIQ/memos-deployment (push)
```

### Step 1.3: Install ArgoCD CLI (optional but recommended)

```bash
# macOS
brew install argocd

# Verify
argocd version
```

---

## Part 2: Install ArgoCD on EKS

### Step 2.1: Create ArgoCD namespace

```bash
kubectl create namespace argocd
```

### Step 2.2: Install ArgoCD manifests

```bash
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

**Expected output:**
```
customresourcedefinition.apiextensions.k8s.io/applications.argoproj.io created
customresourcedefinition.apiextensions.k8s.io/applicationsets.argoproj.io created
...
serviceaccount/argocd-server created
clusterrole.rbac.authorization.k8s.io/argocd-server created
clusterrolebinding.rbac.authorization.k8s.io/argocd-server created
...
```

### Step 2.3: Wait for ArgoCD pods to be ready

```bash
# Wait up to 5 minutes
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/part-of=argocd \
  -n argocd \
  --timeout=300s

# Verify all pods are running
kubectl get pods -n argocd
```

**Expected output:**
```
NAME                                            READY   STATUS    RESTARTS   AGE
argocd-application-controller-0                 1/1     Running   0          2m
argocd-dex-server-xxx                           1/1     Running   0          2m
argocd-notifications-controller-xxx             1/1     Running   0          2m
argocd-redis-xxx                                1/1     Running   0          2m
argocd-repo-server-xxx                          1/1     Running   0          2m
argocd-server-xxx                               1/1     Running   0          2m
```

### Step 2.4: Change ArgoCD server to LoadBalancer

```bash
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# Wait for external IP (takes ~1 minute)
kubectl get svc -n argocd argocd-server

# Expected:
# NAME            TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)
# argocd-server   LoadBalancer   10.100.xxx.xxx  xxxxxx.elb...   443:31417/TCP
```

### Step 2.5: Get admin password

```bash
# Decode the initial admin secret
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo

# Save the password somewhere safe
# You can change it later
```

### Step 2.6: Access ArgoCD UI

```bash
# Get the external IP
ARGOCD_IP=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "Access ArgoCD at: https://$ARGOCD_IP"
echo "Username: admin"
echo "Password: (from Step 2.5)"

# Or use port forwarding
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Access at: https://localhost:8080
```

---

## Part 3: Connect Git Repository

### Step 3.1: Add repository via CLI (easier)

```bash
# If using SSH (requires SSH key in GitHub):
argocd repo add git@github.com:Ike-DevCloudIQ/memos-deployment.git \
  --ssh-private-key-path ~/.ssh/id_rsa

# Or using HTTPS:
argocd repo add https://github.com/Ike-DevCloudIQ/memos-deployment \
  --username Ike-DevCloudIQ \
  --password <your-github-personal-access-token>
```

### Step 3.2: Verify repository connected

```bash
argocd repo list

# Expected output:
# REPO                                                     INSECURE  OCI  LFS  TYPE
# https://github.com/Ike-DevCloudIQ/memos-deployment      false     false false git
# git@github.com:Ike-DevCloudIQ/memos-deployment.git      false     false false git
```

---

## Part 4: Create ArgoCD Application

### Step 4.1: Create Application manifest

```bash
cat > k8s/argocd-application.yaml << 'EOF'
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
      - PruneLast=true
EOF
```

### Step 4.2: Create the Application in ArgoCD

```bash
# Apply the Application manifest
kubectl apply -f k8s/argocd-application.yaml

# Or via CLI:
argocd app create memos \
  --repo https://github.com/Ike-DevCloudIQ/memos-deployment \
  --path k8s \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace memos \
  --auto-prune \
  --self-heal
```

### Step 4.3: Verify Application created

```bash
# Via CLI
argocd app list

# Via kubectl
kubectl get applications -n argocd

# Expected:
# NAME    SYNC STATUS   HEALTH STATUS
# memos   OutOfSync     Progressing
```

---

## Part 5: Sync Application

### Step 5.1: Check Application status

```bash
argocd app get memos

# Or detailed view:
argocd app get memos --refresh
```

**Expected output:**
```
Name:               memos
Project:            default
Sync Policy:        Automated
Sync Status:        OutOfSync
Health Status:      Progressing

Repository:         https://github.com/Ike-DevCloudIQ/memos-deployment
Target Revision:    HEAD
Path:               k8s
...
```

### Step 5.2: Manually sync (if not automatic)

```bash
# Sync to cluster
argocd app sync memos

# Or via kubectl
kubectl patch application memos -n argocd \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/sync-now":"true"}}}' \
  --type merge
```

### Step 5.3: Wait for sync to complete

```bash
# Watch sync progress
argocd app wait memos --sync

# Or monitor in real-time:
kubectl get application memos -n argocd --watch
```

**Expected final status:**
```
SYNC STATUS: Synced
HEALTH STATUS: Healthy
```

### Step 5.4: Verify Memos is deployed

```bash
# Check pods
kubectl get pods -n memos

# Expected: 2 memos pods running
# NAME                     READY   STATUS    RESTARTS   AGE
# memos-xxx                1/1     Running   0          1m
# memos-yyy                1/1     Running   0          1m

# Check service
kubectl get svc -n memos

# Expected: memos service with LoadBalancer
# NAME    TYPE           CLUSTER-IP      EXTERNAL-IP
# memos   LoadBalancer   10.100.xxx.xxx  xxxxxx.elb...

# Get LoadBalancer URL
MEMOS_URL=$(kubectl get svc memos -n memos -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Access Memos at: http://$MEMOS_URL:5230"
```

---

## Part 6: GitOps Workflow - Make a Change

### Step 6.1: Modify deployment in Git

```bash
cd ~/Desktop/Nouriva/memos-deployment

# Edit deployment (change replicas from 2 to 3)
vim k8s/deployment.yaml

# Change this line:
# replicas: 2
# To:
# replicas: 3
```

### Step 6.2: Commit and push to Git

```bash
git add k8s/deployment.yaml

git commit -m "Scale Memos to 3 replicas via GitOps"

git push origin main
```

### Step 6.3: Watch ArgoCD sync automatically

```bash
# Check ArgoCD Application status
argocd app get memos

# Watch the sync happen (takes ~1 minute)
kubectl get pods -n memos --watch

# Expected: 3 pods running now
# memos-xxx   Running
# memos-yyy   Running
# memos-zzz   Running (new!)
```

**That's GitOps in action!** ✨

---

## Part 7: Rollback via Git

### Step 7.1: Revert the change

```bash
cd ~/Desktop/Nouriva/memos-deployment

# Revert last commit
git revert HEAD

git push origin main
```

### Step 7.2: Watch ArgoCD rollback automatically

```bash
# ArgoCD detects the revert
# Automatically syncs cluster back to 2 replicas

kubectl get pods -n memos --watch

# Expected: Back to 2 pods
# memos-xxx   Running
# memos-yyy   Running
```

---

## Part 8: Monitor ArgoCD

### Step 8.1: View ArgoCD UI dashboard

```bash
# Get ArgoCD URL
ARGOCD_URL=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "Open: https://$ARGOCD_URL"
echo "Username: admin"
echo "Password: (get with: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d)"
```

**In UI you can:**
- View application status
- See Git vs cluster diff
- Manually sync
- View deployment history
- Check pod logs

### Step 8.2: Monitor via CLI

```bash
# Watch application status
argocd app get memos --refresh

# Get detailed info
argocd app details memos

# Get sync history
argocd app history memos

# Get resource status
argocd app resources memos
```

---

## Part 9: Advanced - Multiple Environments

To deploy to dev, staging, and prod:

### Step 9.1: Create directory structure

```bash
mkdir -p k8s/{dev,staging,prod}

# Copy base manifests
cp k8s/deployment.yaml k8s/dev/
cp k8s/deployment.yaml k8s/staging/
cp k8s/deployment.yaml k8s/prod/

# Modify for each environment (different replicas, resources, etc)
```

### Step 9.2: Create separate Applications

```bash
# Dev environment
argocd app create memos-dev \
  --repo https://github.com/Ike-DevCloudIQ/memos-deployment \
  --path k8s/dev \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace memos-dev \
  --auto-prune --self-heal

# Staging environment
argocd app create memos-staging \
  --repo https://github.com/Ike-DevCloudIQ/memos-deployment \
  --path k8s/staging \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace memos-staging

# Production (manual sync for safety)
argocd app create memos-prod \
  --repo https://github.com/Ike-DevCloudIQ/memos-deployment \
  --path k8s/prod \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace memos-prod
```

---

## Part 10: Commit to Git

```bash
cd ~/Desktop/Nouriva/memos-deployment

git add docs/STAGE4_GITOPS.md STAGE4_QUICK_REFERENCE.md k8s/argocd-application.yaml

git commit -m "Stage 4: GitOps with ArgoCD

Installed ArgoCD on EKS cluster:
- ArgoCD namespace with all components
- LoadBalancer service for UI access
- Connected Git repository
- Created Memos Application
- Automated sync policy enabled

GitOps workflow:
- Git push triggers automatic cluster sync
- Changes applied within 3 minutes
- Rollback via git revert
- Full audit trail in Git history

Status: Stage 4 COMPLETE
Ready for: Stage 5 (CI/CD with GitHub Actions)"

git push origin main
```

---

## ✅ Stage 4 Complete!

**What you've accomplished:**

✅ Installed ArgoCD on EKS  
✅ Connected Git repository  
✅ Created Memos Application  
✅ Enabled automatic sync  
✅ Verified GitOps workflow  
✅ Tested rollback via Git  

**You now have:**
- Git-driven deployments
- Automatic cluster sync
- Easy rollbacks
- Full audit trail
- UI dashboard for monitoring

---

## Troubleshooting

### ArgoCD pods not running
```bash
kubectl describe pod -n argocd <pod-name>
kubectl logs -n argocd <pod-name>
```

### Application stuck in "Syncing"
```bash
argocd app terminate-op memos
kubectl rollout restart deployment argocd-application-controller -n argocd
```

### Can't access ArgoCD UI
```bash
# Verify LoadBalancer has external IP
kubectl get svc argocd-server -n argocd

# If stuck, use port forwarding:
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Access: https://localhost:8080
```

### Application shows OutOfSync
```bash
# Manually sync
argocd app sync memos

# Or check what's different
argocd app diff memos
```

---

## Next: Stage 5 - CI/CD with GitHub Actions

- Build Docker image on push
- Push to ECR
- Trigger ArgoCD sync
- Automated deployment pipeline

See you in Stage 5! 🚀
