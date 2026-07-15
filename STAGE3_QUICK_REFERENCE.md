# Stage 3: Kubernetes Deployment - QUICK REFERENCE

> **Deploy Memos app to EKS Kubernetes cluster**

---

## Part 1: Prerequisites

### Step 1.1: Verify Kubernetes access

```bash
# Update kubeconfig
aws eks update-kubeconfig --name memos-eks --region us-west-1

# Verify cluster access
kubectl get nodes

# Should show 2 nodes with STATUS=Ready
```

**Expected output:**
```
NAME                           STATUS   ROLES    AGE   VERSION
ip-10-0-11-xxx.ec2.internal   Ready    <none>   5m    v1.31.0
ip-10-0-12-xxx.ec2.internal   Ready    <none>   5m    v1.31.0
```

### Step 1.2: Get database credentials from Secrets Manager

```bash
# Works from either repo root or terraform/ directory
if [[ -d terraform ]]; then
  TF_CHDIR='-chdir=terraform'
else
  TF_CHDIR=''
fi

# Get RDS secret
SECRET_ARN=$(terraform ${TF_CHDIR} output -raw rds_secret_arn)
SECRET=$(aws secretsmanager get-secret-value \
  --secret-id "$SECRET_ARN" \
  --region us-west-1 \
  --query 'SecretString' \
  --output text)

# Parse credentials
DB_HOST=$(echo "$SECRET" | jq -r '.host')
DB_PORT=$(echo "$SECRET" | jq -r '.port')
DB_NAME=$(echo "$SECRET" | jq -r '.dbname')
DB_USER=$(echo "$SECRET" | jq -r '.username')
DB_PASS=$(echo "$SECRET" | jq -r '.password')

# Print for use in next step
echo "DB_HOST=$DB_HOST"
echo "DB_PORT=$DB_PORT"
echo "DB_NAME=$DB_NAME"
echo "DB_USER=$DB_USER"
echo "DB_PASS=$DB_PASS"
```

### Step 1.3: Verify ECR registry

```bash
# Get ECR repository URL
ECR_URL=$(terraform -chdir=terraform/bootstrap output -raw ecr_repository_url)
ECR_REGISTRY=${ECR_URL%/*}
ECR_REGION=$(echo "$ECR_REGISTRY" | cut -d'.' -f4)
echo "ECR URL: $ECR_URL"

# Login to ECR (optional, for pushing images later)
aws ecr get-login-password --region "$ECR_REGION" | \
  docker login --username AWS --password-stdin "$ECR_REGISTRY"
```

---

## Part 2: Deploy Memos to Kubernetes

### Step 2.1: Create namespace and secrets

```bash
# Create namespace
kubectl create namespace memos

# Verify namespace created
kubectl get namespaces

# Create database secret
if [[ -d terraform ]]; then
  TF_CHDIR='-chdir=terraform'
else
  TF_CHDIR=''
fi

SECRET_ARN=$(terraform ${TF_CHDIR} output -raw rds_secret_arn)
SECRET=$(aws secretsmanager get-secret-value \
  --secret-id "$SECRET_ARN" \
  --region us-west-1 \
  --query 'SecretString' \
  --output text)

DB_HOST=$(echo "$SECRET" | jq -r '.host')
DB_PORT=$(echo "$SECRET" | jq -r '.port')
DB_NAME=$(echo "$SECRET" | jq -r '.dbname')
DB_USER=$(echo "$SECRET" | jq -r '.username')
DB_PASS=$(echo "$SECRET" | jq -r '.password')
DSN="postgresql://$DB_USER:$DB_PASS@$DB_HOST:$DB_PORT/$DB_NAME?sslmode=disable"

# Create Kubernetes secret from database credentials
kubectl create secret generic memos-db-secret \
  --from-literal=DB_HOST=$DB_HOST \
  --from-literal=DB_PORT=$DB_PORT \
  --from-literal=DB_NAME=$DB_NAME \
  --from-literal=DB_USER=$DB_USER \
  --from-literal=DB_PASSWORD=$DB_PASS \
  --from-literal=DSN=$DSN \
  -n memos

# Verify secret created
kubectl get secrets -n memos
kubectl describe secret memos-db-secret -n memos
```

### Step 2.2: Apply Kubernetes manifests

```bash
# Apply deployment (includes namespace, configmap, deployment, service, HPA)
kubectl apply -f k8s/deployment.yaml

# Wait for deployment to be ready (2-3 minutes)
kubectl rollout status deployment/memos -n memos

# Verify all resources created
kubectl get all -n memos
```

**Expected output:**
```
NAME                         READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/memos       2/2     2            2           1m

NAME                            READY   STATUS    RESTARTS   AGE
pod/memos-abc123-def456         1/1     Running   0          1m
pod/memos-abc123-ghi789         1/1     Running   0          1m

NAME            TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)         AGE
service/memos   LoadBalancer   10.100.1.1      a1b2c3d4...   80:30123/TCP    1m
```

### Step 2.3: Get load balancer endpoint

```bash
# Get the load balancer URL
kubectl get service memos -n memos

# Or with more detail
kubectl get svc memos -n memos -o wide

# Get just the external IP
EXTERNAL_IP=$(kubectl get svc memos -n memos -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Memos URL: http://$EXTERNAL_IP"
```

**Expected output:**
```
NAME    TYPE           CLUSTER-IP      EXTERNAL-IP                                            PORT(S)         AGE
memos   LoadBalancer   10.100.1.1      a1b2c3d4e5f6g7.elb.us-west-1.amazonaws.com            80:30123/TCP    2m
```

### Step 2.4: Access the application

```bash
# Open in browser
EXTERNAL_IP=$(kubectl get svc memos -n memos -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
open http://$EXTERNAL_IP

# Or use curl to test
curl -I http://$EXTERNAL_IP

# Should return 200 OK
```

**Expected output:**
```
HTTP/1.1 200 OK
Content-Type: text/html; charset=utf-8
...
```

---

## Part 3: Verify Deployment

### Step 3.1: Check pod logs

```bash
# Get pod names
kubectl get pods -n memos

# Check logs for first pod
POD_NAME=$(kubectl get pods -n memos -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n memos $POD_NAME

# Follow logs
kubectl logs -n memos $POD_NAME -f

# Check logs for errors
kubectl logs -n memos $POD_NAME | grep -i error
```

### Step 3.2: Check pod events

```bash
# Describe pod to see events
POD_NAME=$(kubectl get pods -n memos -o jsonpath='{.items[0].metadata.name}')
kubectl describe pod $POD_NAME -n memos

# Check for readiness/liveness probe status
kubectl get pod $POD_NAME -n memos -o yaml | grep -A 10 "conditions:"
```

### Step 3.3: Test database connectivity

```bash
# Get pod name
POD_NAME=$(kubectl get pods -n memos -o jsonpath='{.items[0].metadata.name}')

# Execute shell in pod
kubectl exec -it $POD_NAME -n memos -- /bin/sh

# Inside pod, test database connection
# (Memos should handle this internally)
# Check environment variables
env | grep DB_
exit
```

### Step 3.4: Check horizontal autoscaling

```bash
# Get HPA status
kubectl get hpa -n memos
kubectl describe hpa memos -n memos

# Should show current/desired replicas
# Example: current: 2, desired: 2-5 based on CPU/memory
```

---

## Part 4: Application Testing

### Step 4.1: Test API endpoint

```bash
# Get load balancer URL
EXTERNAL_IP=$(kubectl get svc memos -n memos -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Test app health endpoint
curl -I http://$EXTERNAL_IP/

# Create a note via API
curl -X POST http://$EXTERNAL_IP/api/v1/memos \
  -H "Content-Type: application/json" \
  -d '{"content": "Test note from Kubernetes"}' | jq .
```

### Step 4.2: Test via UI

```bash
# Get load balancer URL
EXTERNAL_IP=$(kubectl get svc memos -n memos -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Open in browser
open http://$EXTERNAL_IP

# Sign up / Login
# Create a note
# Verify it persists after refresh
# Stop pod and verify it recreates
```

### Step 4.3: Test pod recreation

```bash
# Delete a pod (should be recreated automatically)
POD_NAME=$(kubectl get pods -n memos -o jsonpath='{.items[0].metadata.name}')
kubectl delete pod $POD_NAME -n memos

# Watch it recreate
kubectl get pods -n memos -w

# After ~30 seconds, pod should be Running again
```

---

## Part 5: Scaling and Auto-scaling

### Step 5.1: Manual scaling

```bash
# Scale to 3 replicas
kubectl scale deployment memos --replicas=3 -n memos

# Watch pods spin up
kubectl get pods -n memos -w

# Scale back to 2
kubectl scale deployment memos --replicas=2 -n memos
```

### Step 5.2: Monitor autoscaling

```bash
# Generate load to trigger autoscaling (optional)
kubectl run -it --rm load-generator --image=busybox:1.28 -- /bin/sh

# Inside load generator:
# while sleep 0.01; do wget -q -O- http://memos.memos.svc.cluster.local; done

# In another terminal, watch HPA
kubectl get hpa -n memos -w

# Should scale up as CPU/memory increases
```

---

## Part 6: Update Deployment

### Step 6.1: Update image version

```bash
# Update image (e.g., to a specific version)
kubectl set image deployment/memos \
  memos=ghcr.io/usememos/memos:v0.XX.X \
  -n memos

# Watch rollout
kubectl rollout status deployment/memos -n memos

# Verify new pods are running
kubectl get pods -n memos
```

### Step 6.2: Rollback if needed

```bash
# View rollout history
kubectl rollout history deployment/memos -n memos

# Rollback to previous version
kubectl rollout undo deployment/memos -n memos

# Verify rollback
kubectl rollout status deployment/memos -n memos
```

---

## Part 7: Monitoring and Debugging

### Step 7.1: Get deployment metrics

```bash
# Install Metrics Server once (required for kubectl top and HPA resource metrics)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# EKS often needs this TLS setting for kubelet certs
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

# Wait until metrics-server is ready
kubectl rollout status deployment/metrics-server -n kube-system

# Check resources used
kubectl top nodes

# Check pod resource usage
kubectl top pods -n memos

# Get deployment status
kubectl get deployment memos -n memos -o yaml | head -50
```

### Step 7.2: Check events

```bash
# Get cluster events
kubectl get events -n memos --sort-by='.lastTimestamp'

# Watch for new events
kubectl get events -n memos -w
```

### Step 7.3: Describe service

```bash
# Get service details
kubectl describe svc memos -n memos

# Get endpoints (backend pods)
kubectl get endpoints memos -n memos
```

---

## Part 8: Cleanup (Optional)

### Step 8.1: Delete deployment

```bash
# Delete everything in memos namespace
kubectl delete namespace memos

# Verify namespace deleted
kubectl get namespaces
```

### Step 8.2: Delete load balancer

```bash
# Load balancer automatically deleted with service
# Verify in AWS console
aws elbv2 describe-load-balancers --region us-west-1
```

---

## ✅ Verification Checklist

- [ ] Kubernetes cluster accessible (2 nodes Ready)
- [ ] Database credentials retrieved from Secrets Manager
- [ ] Memos namespace created
- [ ] Database secret created in Kubernetes
- [ ] Deployment applied (pods running)
- [ ] Load balancer service running
- [ ] External IP/hostname assigned
- [ ] Application accessible via URL
- [ ] Root endpoint (`/`) responding
- [ ] Can create notes in UI
- [ ] Notes persist after pod restart
- [ ] HPA configured and monitoring
- [ ] Pod logs show no errors

---

## 🐛 Troubleshooting

### Pods not starting

```bash
# Check pod status
kubectl describe pod <POD_NAME> -n memos

# Check logs
kubectl logs <POD_NAME> -n memos

# Common issues:
# - Database not accessible: Check security group
# - Image pull errors: Check ECR permissions
# - Insufficient resources: Check node capacity
```

### LoadBalancer pending

```bash
# Check service status
kubectl describe svc memos -n memos

# If stuck on "pending", check:
# - EKS cluster has public subnets
# - Security groups allow traffic
# - AWS account has NLB permissions
# - service sessionAffinity is set to None (ClientIP is unsupported with this NLB setup)
```

### Database connection failures

```bash
# Verify secret exists
kubectl get secret memos-db-secret -n memos

# Verify database is accessible
# From node:
# telnet <DB_HOST> 5432

# Check RDS security group
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=memos-rds-sg" \
  --region us-west-1
```

---

## 📊 Next Steps

After successful deployment:

1. **Stage 4: GitOps with ArgoCD**
   - Install ArgoCD on EKS
   - Create ArgoCD Application
   - Automate deployments from Git

2. **Stage 5: CI/CD with GitHub Actions**
   - Build Docker image
   - Push to ECR
   - Trigger ArgoCD deployment

3. **Stage 6: Monitoring**
   - CloudWatch dashboards
   - Prometheus metrics
   - Grafana visualization

---

## Summary

```
Stage 3 Accomplished:
✅ Deployed Memos app to EKS
✅ Created LoadBalancer service
✅ Accessed app via load balancer URL
✅ Verified database connectivity
✅ Tested pod autoscaling
✅ Confirmed high availability

Infrastructure:
2 Memos pods running
1 LoadBalancer service
1 Horizontal Pod Autoscaler
Database connection pooling enabled
Health checks configured

Ready for: Stage 4 (GitOps with ArgoCD)
```
