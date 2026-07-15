# Stage 4: GitOps with ArgoCD - COMPLETION GUIDE

> **You're now ready to automate deployments from Git!**

---

## 📊 What You'll Have After Stage 4

```
GitHub Repository (memos-deployment)
         ↓
    Git Push (commit to main)
         ↓
  ArgoCD watches Git
         ↓
  Detects changes
         ↓
  Automatically applies to EKS
         ↓
  Memos app updated in cluster
         ↓
  No manual commands needed!
```

---

## 🎯 Stage 4 Roadmap

| Part | Task | Time | Status |
|------|------|------|--------|
| 1 | Prerequisites check | 5 min | ⏳ Next |
| 2 | Install ArgoCD on EKS | 15 min | ⏳ Next |
| 3 | Connect Git repository | 5 min | ⏳ Next |
| 4 | Create ArgoCD Application | 5 min | ⏳ Next |
| 5 | Sync and verify | 10 min | ⏳ Next |
| 6 | Test GitOps workflow | 10 min | ⏳ Next |
| 7 | Rollback via Git | 5 min | ⏳ Next |
| 8 | Monitor & dashboard | 5 min | ⏳ Next |
| | **Total** | **~60 min** | |

---

## 📚 Learning Materials

### Conceptual Guide (30 min read)
**[docs/STAGE4_GITOPS.md](docs/STAGE4_GITOPS.md)**
- What is GitOps?
- How ArgoCD works
- Key concepts
- Installation guide
- Best practices
- Troubleshooting

### Quick Reference (60 min execution)
**[STAGE4_QUICK_REFERENCE.md](STAGE4_QUICK_REFERENCE.md)**
- Copy-paste commands
- Step-by-step instructions
- Expected outputs at each step
- Multiple environments (advanced)

### Kubernetes Manifests
**[k8s/argocd-application.yaml](k8s/argocd-application.yaml)**
- ArgoCD Application resource
- Sync policy configuration
- Automated deployment settings

---

## ✨ Key Features You'll Enable

### 1. **Automated Deployments**
```bash
# Just push to Git
git push origin main

# ArgoCD automatically:
# - Detects changes
# - Applies manifests
# - Updates pods
# - Verifies health
```

### 2. **Easy Rollbacks**
```bash
# Rollback via Git history
git revert HEAD
git push origin main

# Cluster automatically reverts to previous state
```

### 3. **Git as Source of Truth**
```bash
# Everything in Git
# No manual kubectl commands
# No secrets in cluster
# Full audit trail
```

### 4. **Multi-Environment Support**
```
dev/     → Auto-deployed on every push
staging/ → Manual approval required
prod/    → Manual approval required
```

---

## 🚀 Start Here

### Step 1: Read the Guide
```bash
# Understand concepts first
cat docs/STAGE4_GITOPS.md | head -200
```

### Step 2: Check Prerequisites
```bash
# Verify everything is ready
aws eks update-kubeconfig --name memos-eks --region us-west-1
kubectl get nodes
```

### Step 3: Follow Quick Reference
```bash
# Execute commands in order
# STAGE4_QUICK_REFERENCE.md Parts 1-8
```

### Step 4: Verify It Works
```bash
# Check ArgoCD status
argocd app list
kubectl get applications -n argocd
```

---

## 📋 Stage 4 Checklist

**Prerequisites:**
- [ ] EKS cluster running (`kubectl get nodes` shows 2 nodes)
- [ ] kubectl configured (`kubectl cluster-info` works)
- [ ] Git repository cloned (`git remote -v` shows origin)
- [ ] ArgoCD CLI installed (`argocd version` works)

**Installation:**
- [ ] ArgoCD namespace created
- [ ] ArgoCD pods running (`kubectl get pods -n argocd`)
- [ ] ArgoCD LoadBalancer has external IP
- [ ] Can access ArgoCD UI (username: admin)

**Configuration:**
- [ ] Git repository connected (`argocd repo list`)
- [ ] Memos Application created (`argocd app list`)
- [ ] Application shows "Synced" status
- [ ] Memos pods running in `memos` namespace

**Verification:**
- [ ] Can access Memos at LoadBalancer URL
- [ ] Made Git change and ArgoCD auto-synced
- [ ] Rolled back via Git revert
- [ ] Monitored in ArgoCD UI dashboard

---

## 💡 Key Takeaways

**After Stage 4, you'll understand:**

✅ **GitOps principles** - Git as source of truth  
✅ **ArgoCD architecture** - How it watches and syncs  
✅ **Deployment automation** - Push → Deploy workflow  
✅ **Rollback strategies** - Git history for rollbacks  
✅ **Multi-environment** - Dev/staging/prod patterns  
✅ **Monitoring** - ArgoCD UI and CLI  
✅ **Best practices** - Secrets, approvals, notifications  

---

## 🔄 GitOps Workflow

### Scenario 1: Update Replica Count
```bash
# Developer
vim k8s/deployment.yaml          # Change replicas: 2 → 3
git add k8s/deployment.yaml
git commit -m "Scale to 3 replicas"
git push origin main

# ArgoCD (automatic)
# → Detects change
# → Compares with cluster
# → Creates new pod
# → Updates load balancer
# → Verifies health

# Result: 3 replicas running in ~1 minute
```

### Scenario 2: Emergency Rollback
```bash
# Previous version had a bug

# In Git
git revert HEAD                  # Revert bad commit
git push origin main

# ArgoCD (automatic)
# → Detects revert
# → Applies old version
# → Rolls back pods

# Result: Working version restored in ~1 minute
```

### Scenario 3: Production Approval
```bash
# Want to require approval for prod changes

# Config
syncPolicy:
  # Remove "automated" section
  # Manual sync only for prod

# Then
# → Developer pushes code
# → ArgoCD shows "OutOfSync"
# → Manager reviews in UI
# → Manager clicks "Sync"
# → Change applied
```

---

## 🛠️ After Stage 4

**You can:**
- Deploy to Kubernetes without `kubectl apply`
- Rollback instantly with Git history
- Have full audit trail of all changes
- Require approvals for production
- Manage multiple environments easily
- Monitor deployments in one dashboard
- Integrate with GitHub, GitLab, Bitbucket

**Your infrastructure now:**
- Has automatic failover (if pod crashes, ArgoCD restarts)
- Prevents cluster drift (manual changes auto-corrected)
- Scales easily (change replicas in Git)
- Recovers from disasters (Git clone + apply)

---

## ⏳ Time Estimate

| Task | Time |
|------|------|
| Read conceptual guide | 30 min |
| Install ArgoCD | 15 min |
| Configure Git & Application | 10 min |
| Test GitOps workflow | 10 min |
| Monitor & troubleshoot | 5 min |
| **Total** | **~70 min** |

---

## 🎯 Success Criteria

**Stage 4 is complete when:**

✅ ArgoCD is running on EKS  
✅ Git repository is connected  
✅ Memos Application is synced  
✅ Can access Memos at LoadBalancer URL  
✅ Made a Git change and ArgoCD auto-deployed  
✅ Successfully rolled back via Git  
✅ Understood GitOps workflow  
✅ All code committed to GitHub  

---

## 📞 If Something Goes Wrong

**ArgoCD pods not running:**
```bash
kubectl describe pod -n argocd <pod-name>
kubectl logs -n argocd <pod-name>
```

**Can't access UI:**
```bash
# Verify LoadBalancer has external IP
kubectl get svc -n argocd

# Use port forwarding if needed
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

**Application stuck syncing:**
```bash
argocd app terminate-op memos
```

**Git changes not syncing:**
```bash
# Force sync
argocd app sync memos --force
```

---

## 🎓 Learning Resources

- **[ArgoCD Docs](https://argo-cd.readthedocs.io/)**
- **[GitOps Best Practices](https://www.gitops.tech/)**
- **[Kubernetes Docs](https://kubernetes.io/docs/)**

---

## 📝 Git Commit Template

When Stage 4 is complete:

```bash
git add -A

git commit -m "Stage 4: GitOps with ArgoCD - COMPLETE

Installed and configured ArgoCD:
✅ ArgoCD deployed to argocd namespace
✅ All core components running
✅ LoadBalancer service for UI access
✅ GitHub repository connected
✅ Memos Application created with auto-sync
✅ Tested GitOps workflow (Git push → Auto-deploy)
✅ Tested rollback via Git revert

Documentation:
✅ docs/STAGE4_GITOPS.md - Conceptual guide (2000+ lines)
✅ STAGE4_QUICK_REFERENCE.md - Copy-paste commands
✅ k8s/argocd-application.yaml - Application manifest

Capabilities enabled:
✅ Git-driven deployments
✅ Automatic cluster sync
✅ Easy rollbacks via Git history
✅ Full audit trail in Git
✅ Multi-environment support
✅ ArgoCD UI monitoring
✅ No manual kubectl apply needed

Status: Stage 4 COMPLETE
Ready for: Stage 5 (CI/CD with GitHub Actions)"

git push origin main
```

---

## 🚀 Next: Stage 5 - CI/CD with GitHub Actions

**Coming next:**
- Automated Docker builds on Git push
- Push to ECR automatically
- Trigger ArgoCD sync
- Full CI/CD pipeline

See you in Stage 5! 🎉
