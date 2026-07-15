# Stage 5: CI/CD with GitHub Actions - Conceptual Guide

> **Automate Docker builds, ECR pushes, and ArgoCD deployments on every Git push**

---

## What is CI/CD?

**CI = Continuous Integration**  
**CD = Continuous Deployment / Continuous Delivery**

### Continuous Integration (CI)
Every time code is pushed:
1. Run tests automatically
2. Build Docker image
3. Check for errors early
4. Give developer fast feedback

### Continuous Deployment (CD)
After CI passes:
1. Push Docker image to registry (ECR)
2. Update Kubernetes manifests
3. ArgoCD deploys to cluster
4. App is live with new version

### Why CI/CD?

| Manual Process | CI/CD Automated |
|---------------|-----------------|
| Developer manually builds image | GitHub Actions builds on push |
| Developer manually pushes to ECR | Automated push to ECR |
| DevOps manually applies manifests | ArgoCD auto-syncs |
| Errors caught in production | Errors caught in pipeline |
| 30 minutes per deployment | 5 minutes, no human needed |
| No audit trail | Full pipeline history |

---

## What is GitHub Actions?

**GitHub Actions = Automated workflows triggered by Git events**

You write YAML files that tell GitHub:
- **When** to run (on: push, pull_request, schedule)
- **What** to run (jobs: build, test, deploy)
- **Where** to run (runs-on: ubuntu-latest)

```yaml
# Example workflow structure
on:
  push:
    branches: [main]     # Trigger: Push to main branch

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest    # Where to run
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        
      - name: Build Docker image
        run: docker build -t memos:latest .
        
      - name: Push to ECR
        run: docker push <ecr-url>/memos:latest
```

---

## CI/CD Architecture

```
Developer pushes code
         ↓
   GitHub Repository
         ↓
  GitHub Actions trigger
         ↓
    ┌────────────────────────────┐
    │     GitHub Actions         │
    │    (ubuntu-latest VM)      │
    │                            │
    │  1. Checkout code          │
    │  2. Login to AWS ECR       │
    │  3. Build Docker image     │
    │  4. Tag with commit SHA    │
    │  5. Push to ECR            │
    │  6. Update image tag in    │
    │     k8s/deployment.yaml    │
    │  7. Push changes to Git    │
    └────────────────────────────┘
         ↓
   Git push (manifest update)
         ↓
    ArgoCD detects change
         ↓
  EKS cluster pulls new image
         ↓
   Memos app updated! ✅
```

---

## GitHub Actions Key Concepts

### 1. Workflow
A YAML file in `.github/workflows/` that defines the pipeline.

```
.github/
└── workflows/
    ├── deploy.yaml    ← Main CI/CD pipeline
    └── lint.yaml      ← Optional: code quality checks
```

### 2. Trigger (on:)
What events start the workflow:

```yaml
on:
  push:
    branches: [main]          # Runs on push to main
    paths:
      - 'app/**'              # Only when app code changes
  pull_request:
    branches: [main]          # Runs on PRs
  workflow_dispatch:          # Manual trigger (button in UI)
  schedule:
    - cron: '0 2 * * *'      # Run at 2am daily
```

### 3. Jobs
A job is a set of steps that runs on one machine:

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - ...

  deploy:
    runs-on: ubuntu-latest
    needs: build              # Only runs after 'build' succeeds
    steps:
      - ...
```

### 4. Steps
Each step is a command or reusable action:

```yaml
steps:
  # Reusable action
  - uses: actions/checkout@v4

  # Custom command
  - name: Build image
    run: docker build -t memos:latest .

  # Multi-line command
  - name: Configure AWS
    run: |
      aws configure set region eu-west-1
      aws configure set output json
```

### 5. Secrets
Sensitive values stored in GitHub, not in code:

```yaml
# In GitHub Settings → Secrets → Repository secrets:
# AWS_ACCESS_KEY_ID
# AWS_SECRET_ACCESS_KEY
# AWS_ACCOUNT_ID

# In workflow, access via ${{ secrets.NAME }}:
- name: Login to ECR
  env:
    AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
    AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
  run: aws ecr get-login-password ...
```

### 6. GitHub OIDC (More Secure Alternative)
Instead of long-lived AWS keys, use GitHub's OIDC to get temporary credentials:

```yaml
permissions:
  id-token: write    # Required for OIDC
  contents: read

steps:
  - name: Configure AWS Credentials
    uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: arn:aws:iam::ACCOUNT_ID:role/memos-github-actions
      aws-region: eu-west-1
```

This is safer because:
- No long-lived credentials
- Automatically rotated
- Scoped per repository

---

## Complete CI/CD Pipeline Flow

### Trigger
```
Developer: git push origin main
```

### Job 1: Build & Push (CI)
```
1. Checkout code from GitHub
2. Configure AWS credentials (OIDC or access keys)
3. Login to Amazon ECR
4. Build Docker image from app/Dockerfile
5. Tag with:
   - commit SHA (e.g., memos:abc1234)
   - "latest" (e.g., memos:latest)
6. Push both tags to ECR
```

### Job 2: Update Manifests (CD)
```
7. Update k8s/deployment.yaml with new image tag
8. Commit the change to Git
9. Push to main branch
10. ArgoCD detects new commit
11. ArgoCD syncs cluster with new image
12. Memos pods roll updated one by one (RollingUpdate)
```

### Result
```
Developer pushed code → App live with new version in ~5 minutes
No manual intervention needed!
```

---

## Security Best Practices

### 1. Use OIDC Instead of Access Keys

**Bad (avoid):**
```yaml
env:
  AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}  # Long-lived, risky
```

**Good (use this):**
```yaml
uses: aws-actions/configure-aws-credentials@v4
with:
  role-to-assume: ${{ secrets.AWS_ROLE_ARN }}  # Temporary, scoped
```

### 2. Pin Action Versions

**Bad:**
```yaml
uses: actions/checkout@main  # Can change unexpectedly
```

**Good:**
```yaml
uses: actions/checkout@v4    # Pinned version
```

### 3. Minimal Permissions

**Bad:**
```yaml
permissions:
  write-all   # Too broad
```

**Good:**
```yaml
permissions:
  id-token: write      # OIDC only
  contents: write      # For updating manifests
```

### 4. Only Deploy from Protected Branch

```yaml
on:
  push:
    branches: [main]   # Only deploy when code merges to main
                       # NOT feature branches
```

### 5. Validate Before Deploying

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: go test ./...      # Run tests first

  deploy:
    needs: test                  # Only deploy if tests pass
```

---

## Docker Image Tagging Strategy

### Using Commit SHA (Recommended)
```bash
# Tag with short commit SHA
IMAGE_TAG=$(git rev-parse --short HEAD)

docker build -t $ECR_URL/memos:$IMAGE_TAG .
docker build -t $ECR_URL/memos:latest .

docker push $ECR_URL/memos:$IMAGE_TAG
docker push $ECR_URL/memos:latest
```

Benefits:
- **Immutable** - Each commit = unique image tag
- **Traceable** - Know exactly what code is running
- **Rollback** - Know what tag to rollback to

### Using Semantic Version
```bash
# Tag with version from git tag
VERSION=$(git describe --tags)  # e.g., v1.2.3

docker build -t $ECR_URL/memos:$VERSION .
docker build -t $ECR_URL/memos:latest .
```

---

## Updating Kubernetes Manifests Automatically

After building the image, the pipeline updates the deployment.yaml with the new image tag:

```bash
# Old deployment.yaml:
# image: 123456789.dkr.ecr.eu-west-1.amazonaws.com/memos:abc1234

# New deployment.yaml (after pipeline runs):
# image: 123456789.dkr.ecr.eu-west-1.amazonaws.com/memos:def5678

# Command to update:
sed -i "s|image: .*/memos:.*|image: $ECR_URL/memos:$IMAGE_TAG|" k8s/deployment.yaml
```

Then:
```bash
git config user.email "actions@github.com"
git config user.name "GitHub Actions"
git add k8s/deployment.yaml
git commit -m "chore: update image to $IMAGE_TAG [ci skip]"
git push origin main
```

The `[ci skip]` in the commit message prevents an infinite loop (the pipeline updating manifests → triggering pipeline → updating manifests...).

---

## Monitoring CI/CD Pipeline

### GitHub Actions UI
1. Go to your repository on GitHub
2. Click "Actions" tab
3. View all workflow runs
4. Click a run to see step logs
5. Debug failures

### ArgoCD UI
1. After pipeline pushes manifest update
2. ArgoCD detects change in 3 minutes
3. Sync status changes from "Synced" to "OutOfSync" to "Synced"
4. New pods roll out

### Combined Pipeline View
```
GitHub Push
    ↓
GitHub Actions (build.yaml)
    ↓ runs 5 min
ECR (new image: memos:abc1234)
    ↓ manifest update pushed
ArgoCD detects (3 min)
    ↓ auto-sync
EKS new pods
    ↓ rolling update
Memos app live!
```

---

## Troubleshooting CI/CD

### Build fails - Docker build error

**Check:**
```bash
# Run locally first
cd memos-deployment
docker build -t memos:test app/

# Check app/Dockerfile for errors
cat app/Dockerfile
```

### AWS authentication fails

**Check:**
- GitHub OIDC role ARN is correct
- IAM role trust policy includes GitHub Actions
- Repository name matches trust condition

```bash
# Verify IAM role exists
aws iam get-role --role-name github-actions

# Verify trust policy
aws iam get-role --role-name github-actions \
  --query 'Role.AssumeRolePolicyDocument'
```

### ECR push fails

**Check:**
```bash
# Verify ECR repository exists
aws ecr describe-repositories --repository-names memos

# Verify IAM role has ECR permissions
aws iam list-role-policies --role-name github-actions
```

### Manifest update not triggering ArgoCD

**Check:**
```bash
# Verify commit was pushed
git log --oneline -5

# Force ArgoCD sync
argocd app sync memos

# Check ArgoCD diff
argocd app diff memos
```

### Pipeline loops infinitely

**Fix:** Add `[ci skip]` to manifest update commits:
```bash
git commit -m "chore: update image tag [ci skip]"
```

Or restrict trigger to `app/**` paths:
```yaml
on:
  push:
    paths:
      - 'app/**'        # Only trigger when app code changes
      - '!k8s/**'       # NOT when manifests update
```

---

## Summary

**Stage 5 gives you:**
- ✅ Automated Docker builds on every push
- ✅ Automatic ECR image pushes
- ✅ Manifest auto-update with new image tag
- ✅ ArgoCD auto-deploys updated image
- ✅ Full audit trail in GitHub Actions UI
- ✅ Fast feedback on build failures
- ✅ Zero-downtime rolling deployments
- ✅ Complete automation - zero manual steps

**Full Pipeline:**
```
Git Push → Build → Test → ECR Push → Manifest Update → ArgoCD Deploy → Live!
```

---

## Resources

- [GitHub Actions Docs](https://docs.github.com/en/actions)
- [AWS ECR Actions](https://github.com/aws-actions/amazon-ecr-login)
- [Configure AWS Credentials](https://github.com/aws-actions/configure-aws-credentials)
- [Docker Build Push Action](https://github.com/docker/build-push-action)
