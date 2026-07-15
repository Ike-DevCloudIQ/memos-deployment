# Stage 5: CI/CD with GitHub Actions - QUICK REFERENCE

> **Automate Docker builds, ECR pushes, and deployments on every Git push**

---

## Part 1: Prerequisites

### Step 1.1: Verify bootstrap created the ECR repository and IAM role

```bash
cd ~/Desktop/Nouriva/memos-deployment

# Get ECR URL from bootstrap Terraform output
terraform -chdir=terraform/bootstrap output

# Expected output includes:
# ecr_repository_url = "123456789.dkr.ecr.eu-west-1.amazonaws.com/memos"
# github_actions_role_arn = "arn:aws:iam::123456789:role/memos-github-actions"
```

### Step 1.2: Save key values

```bash
# Run these and save the outputs
ECR_URL=$(terraform -chdir=terraform/bootstrap output -raw ecr_repository_url)
ROLE_ARN=$(terraform -chdir=terraform/bootstrap output -raw github_actions_role_arn)
AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)

echo "ECR URL: $ECR_URL"
echo "Role ARN: $ROLE_ARN"
echo "Account ID: $AWS_ACCOUNT"
```

---

## Part 2: Set Up GitHub Secrets

> GitHub Secrets store sensitive values safely. The workflow reads them as `${{ secrets.NAME }}`.

### Step 2.1: Open GitHub repository settings

```
Go to: https://github.com/Ike-DevCloudIQ/memos-deployment
→ Settings
→ Secrets and Variables
→ Actions
→ New repository secret
```

### Step 2.2: Add required secrets

Add these two secrets one at a time:

**Secret 1:**
- Name: `AWS_ROLE_ARN`
- Value: (paste the Role ARN from Step 1.2)
  - Example: `arn:aws:iam::123456789012:role/memos-github-actions`

**Secret 2 (optional but good to have):**
- Name: `AWS_ACCOUNT_ID`
- Value: (paste the Account ID from Step 1.2)
  - Example: `123456789012`

### Step 2.3: Verify secrets added

```
Go to:
  Settings → Secrets and Variables → Actions

Expected:
  Repository secrets:
  ✅ AWS_ROLE_ARN
  ✅ AWS_ACCOUNT_ID
```

---

## Part 3: Configure GitHub OIDC Trust Policy

The GitHub Actions workflow uses OIDC to authenticate with AWS — no long-lived keys needed.

### Step 3.1: Verify IAM role trust policy allows this repository

```bash
# Get the current trust policy
aws iam get-role --role-name memos-github-actions \
  --query 'Role.AssumeRolePolicyDocument' \
  --output json
```

**Expected trust policy should contain:**
```json
{
  "Condition": {
    "StringLike": {
      "token.actions.githubusercontent.com:sub": "repo:Ike-DevCloudIQ/memos-deployment:*"
    }
  }
}
```

### Step 3.2: If trust policy needs updating

```bash
# Create updated trust policy
cat > /tmp/trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:Ike-DevCloudIQ/memos-deployment:*"
        }
      }
    }
  ]
}
EOF

# Replace ACCOUNT_ID with your actual account ID
sed -i "s/ACCOUNT_ID/$AWS_ACCOUNT/" /tmp/trust-policy.json

# Update the IAM role
aws iam update-assume-role-policy \
  --role-name memos-github-actions \
  --policy-document file:///tmp/trust-policy.json

echo "Trust policy updated"
```

---

## Part 4: Verify the Workflow File

### Step 4.1: Check the workflow file exists

```bash
cat .github/workflows/deploy.yaml

# Expected: GitHub Actions workflow with build and update-manifests jobs
```

### Step 4.2: Confirm key values in the workflow

```bash
# Check AWS_REGION matches your setup
grep "AWS_REGION" .github/workflows/deploy.yaml
# Expected: eu-west-1

# Check ECR_REPOSITORY name
grep "ECR_REPOSITORY" .github/workflows/deploy.yaml
# Expected: memos

# Check path trigger
grep -A5 "paths:" .github/workflows/deploy.yaml
# Expected: - 'app/**'
```

---

## Part 5: Trigger the Pipeline

### Step 5.1: Make a change in the app directory

```bash
cd ~/Desktop/Nouriva/memos-deployment

# Make a trivial change to trigger the pipeline
echo "# CI/CD trigger test" >> app/README.md
```

### Step 5.2: Commit and push

```bash
git add app/README.md

git commit -m "test: trigger CI/CD pipeline

Testing GitHub Actions workflow:
- Build Docker image
- Push to ECR
- Update deployment manifest"

git push origin main
```

### Step 5.3: Watch the pipeline in GitHub

```
1. Go to: https://github.com/Ike-DevCloudIQ/memos-deployment
2. Click "Actions" tab
3. Click the running workflow "Build and Deploy Memos"
4. Watch each step in real-time
```

**Expected steps:**
```
✅ Checkout code
✅ Configure AWS Credentials
✅ Login to Amazon ECR
✅ Set image metadata
✅ Build and push Docker image
```

**Then in update-manifests job:**
```
✅ Checkout code
✅ Update image tag in deployment.yaml
✅ Commit and push manifest update
```

---

## Part 6: Verify the Pipeline Ran

### Step 6.1: Check ECR for the new image

```bash
# List images in ECR
aws ecr describe-images \
  --repository-name memos \
  --region eu-west-1 \
  --query 'imageDetails[*].{tag:imageTags[0], pushed:imagePushedAt}' \
  --output table
```

**Expected output:**
```
----------------------------------
|       DescribeImages           |
+----------+---------------------+
|  tag     |  pushed             |
+----------+---------------------+
|  abc1234 |  2026-07-15T10:30   |
|  latest  |  2026-07-15T10:30   |
+----------+---------------------+
```

### Step 6.2: Check that deployment.yaml was updated

```bash
# Check git log
git log --oneline -5

# Expected to see:
# abc1234 chore: update memos image to abc1234 [skip ci]
# def5678 test: trigger CI/CD pipeline

# Check the updated image tag in deployment.yaml
grep "image:" k8s/deployment.yaml

# Expected:
# image: 123456789.dkr.ecr.eu-west-1.amazonaws.com/memos:abc1234
```

### Step 6.3: Check ArgoCD deployed the new version

```bash
# Check ArgoCD Application status
argocd app get memos

# Expected:
# Sync Status: Synced
# Health Status: Healthy

# Check pods are running with new image
kubectl get pods -n memos

# Check which image the pods are running
kubectl get deployment memos -n memos \
  -o jsonpath='{.spec.template.spec.containers[0].image}'

# Expected:
# 123456789.dkr.ecr.eu-west-1.amazonaws.com/memos:abc1234
```

---

## Part 7: Test a Real Code Change

### Step 7.1: Simulate a real app change

```bash
cd ~/Desktop/Nouriva/memos-deployment

# Make a change in the app directory
# (In a real project this would be code changes)
touch app/test-change.txt
echo "Test change to trigger pipeline" > app/test-change.txt
```

### Step 7.2: Push and watch full pipeline

```bash
git add app/test-change.txt

git commit -m "feat: test full CI/CD pipeline

This should:
1. Trigger GitHub Actions
2. Build new Docker image
3. Push to ECR with new tag
4. Update deployment.yaml
5. ArgoCD deploy to EKS"

git push origin main
```

### Step 7.3: Watch full deployment

```bash
# Terminal 1: Watch GitHub Actions (go to browser)
# https://github.com/Ike-DevCloudIQ/memos-deployment/actions

# Terminal 2: Watch pods roll over
kubectl get pods -n memos --watch

# Expected: Old pods terminate, new pods start
# memos-old-pod   Terminating
# memos-new-pod   ContainerCreating
# memos-new-pod   Running
```

---

## Part 8: Manual Pipeline Trigger

You can trigger the pipeline without a code push:

```bash
# Via CLI
gh workflow run deploy.yaml

# Or via GitHub UI:
# Go to Actions → Build and Deploy Memos → Run workflow
```

---

## Part 9: Troubleshoot Failures

### Pipeline fails at "Configure AWS Credentials"

```bash
# Check that GitHub OIDC provider exists in AWS
aws iam list-open-id-connect-providers

# Should show:
# arn:aws:iam::ACCOUNT:oidc-provider/token.actions.githubusercontent.com

# Verify trust policy on the role
aws iam get-role --role-name memos-github-actions \
  --query 'Role.AssumeRolePolicyDocument'

# Common fix: ensure the repository name in condition matches exactly
```

### Pipeline fails at "Login to Amazon ECR"

```bash
# Verify ECR repository exists
aws ecr describe-repositories --repository-names memos

# Verify IAM role has ECR permissions
aws iam list-role-policies --role-name memos-github-actions
aws iam get-role-policy \
  --role-name memos-github-actions \
  --policy-name memos-github-actions-ecr
```

### Pipeline fails at "Build and push Docker image"

```bash
# Test Docker build locally first
docker build -f app/Dockerfile -t memos:test .

# Check Dockerfile exists and is valid
cat app/Dockerfile
```

### Manifest update triggers another pipeline run (infinite loop)

```bash
# Verify [skip ci] is in commit message
git log --oneline -3
# Should show: chore: update memos image to abc1234 [skip ci]

# If not, update the workflow step:
# git commit -m "... [skip ci]"
```

---

## Part 10: Commit Stage 5 to Git

```bash
cd ~/Desktop/Nouriva/memos-deployment

git add docs/STAGE5_CICD.md STAGE5_QUICK_REFERENCE.md .github/workflows/deploy.yaml terraform/bootstrap/main.tf terraform/bootstrap/outputs.tf

git commit -m "Stage 5: CI/CD with GitHub Actions - COMPLETE

Added GitHub Actions CI/CD pipeline:

Workflow (.github/workflows/deploy.yaml):
✅ Triggers on push to main (app/** paths)
✅ GitHub OIDC authentication (no long-lived keys)
✅ Docker multi-stage build
✅ Push to Amazon ECR with commit SHA tags
✅ Auto-update k8s/deployment.yaml with new tag
✅ ArgoCD detects change and deploys

Documentation:
✅ docs/STAGE5_CICD.md - Conceptual guide
✅ STAGE5_QUICK_REFERENCE.md - Step-by-step setup

Full pipeline:
  git push → GitHub Actions → ECR → manifest update → ArgoCD → EKS

Security:
✅ OIDC authentication (no AWS keys in GitHub Secrets)
✅ Minimal IAM permissions
✅ Pinned action versions
✅ [skip ci] to prevent infinite loops

Status: Stage 5 COMPLETE
Ready for: Stage 6 (Monitoring with CloudWatch + Prometheus)"

git push origin main
```

---

## ✅ Stage 5 Complete!

**What you now have:**

✅ GitHub Actions workflow (`.github/workflows/deploy.yaml`)  
✅ Automatic Docker builds on push  
✅ Images pushed to ECR with commit SHA tags  
✅ Deployment manifest auto-updated  
✅ ArgoCD auto-deploys new version  
✅ Zero manual steps needed  

**Full automated pipeline:**
```
git push origin main
      ↓ (5 min)
New Docker image in ECR
      ↓ (3 min)
ArgoCD deploys to EKS
      ↓
Memos app updated!
```

---

## Troubleshooting Reference

| Problem | Command |
|---------|---------|
| Check pipeline status | `gh run list` |
| View pipeline logs | `gh run view <run-id>` |
| Check ECR images | `aws ecr describe-images --repository-name memos` |
| Check ArgoCD status | `argocd app get memos` |
| Force ArgoCD sync | `argocd app sync memos` |
| Check pod image | `kubectl get deployment memos -n memos -o yaml \| grep image` |

---

## Next: Stage 6 - Monitoring & Observability

- CloudWatch dashboards and alarms
- Prometheus & Grafana on EKS
- Application metrics
- Log aggregation
- Alerting when things go wrong

See you in Stage 6! 🚀
