# Stage 3: Kubernetes Deployment - Comprehensive Guide

> **Deploy containerized Memos application to Amazon EKS Kubernetes cluster**

**Time required:** 2-3 hours  
**Prerequisites:** Stage 1 (Docker) ✅ and Stage 2 (Terraform/EKS) ✅ complete

---

## Part 1: Understanding Kubernetes for Deployment

### What is Kubernetes?

Kubernetes (K8s) is an **orchestration platform** that manages containerized applications across multiple machines.

**Key concepts:**

1. **Cluster** - Collection of machines (nodes) running containers
   - Control Plane: Manages the cluster (AWS handles this in EKS)
   - Worker Nodes: Run your containers (2x t3.medium in our case)

2. **Pods** - Smallest deployable unit
   - One or more containers sharing network namespace
   - Usually one container per pod
   - Ephemeral (can be created/destroyed)

3. **Deployment** - Manages pod replicas
   - Ensures desired number of pods always running
   - Handles rolling updates
   - Provides self-healing

4. **Service** - Network abstraction
   - LoadBalancer: Routes traffic to pods
   - Provides stable IP/DNS
   - Handles pod discovery

5. **ConfigMap** - Non-secret configuration
   - Store application settings
   - Mount as environment variables or files

6. **Secret** - Sensitive data storage
   - Passwords, API keys, tokens
   - Encoded (not encrypted by default)
   - Our case: Database credentials

---

## Part 2: Why Kubernetes for Memos?

### Benefits of Kubernetes Deployment

| Feature | Benefit |
|---------|---------|
| **Pod Replicas** | Multiple Memos instances for high availability |
| **LoadBalancer** | Automatic traffic distribution |
| **Self-healing** | Pod crashes → automatic restart |
| **Scaling** | Auto-scale based on CPU/memory |
| **Rolling Updates** | Zero-downtime deployments |
| **Health Checks** | Liveness & readiness probes |
| **Resource Limits** | Prevent resource exhaustion |
| **DNS Discovery** | Service endpoints auto-discovered |

### Compared to Docker Compose

```
Docker Compose (Local):
- Single machine
- No autoscaling
- No self-healing
- Manual container management
✗ Not production-ready

Kubernetes (Production):
- Multiple machines
- Automatic autoscaling
- Self-healing with restarts
- Declarative management
✅ Production-ready
```

---

## Part 3: Understanding Our Deployment

### Architecture

```
┌─────────────────────────────────────────┐
│      Kubernetes Cluster (EKS)           │
├─────────────────────────────────────────┤
│                                         │
│  ┌──────────────────────────────────┐  │
│  │   Deployment: memos              │  │
│  │   Replicas: 2 (min), 5 (max)    │  │
│  │   Strategy: RollingUpdate        │  │
│  │                                  │  │
│  │   ┌──────────────┐               │  │
│  │   │ Pod 1        │               │  │
│  │   │ memos:latest │               │  │
│  │   │ Port: 5230   │               │  │
│  │   └──────────────┘               │  │
│  │   ┌──────────────┐               │  │
│  │   │ Pod 2        │               │  │
│  │   │ memos:latest │               │  │
│  │   │ Port: 5230   │               │  │
│  │   └──────────────┘               │  │
│  │                                  │  │
│  └──────────────────────────────────┘  │
│                  ↓                      │
│  ┌──────────────────────────────────┐  │
│  │  Service: memos                  │  │
│  │  Type: LoadBalancer              │  │
│  │  Port: 80 → Pod:5230             │  │
│  │  External IP: a1b2c3d4.elb...    │  │
│  └──────────────────────────────────┘  │
│                                         │
└─────────────────────────────────────────┘
         ↓ (Network)
    ┌─────────────────┐
    │  RDS Database   │
    │  PostgreSQL     │
    │  Port: 5432     │
    └─────────────────┘
```

### Kubernetes Manifests We'll Use

**1. Namespace**
- Logical isolation: `memos` namespace
- Prevents name conflicts
- Access control boundary

**2. ConfigMap**
- Application settings (non-secret)
- Example: `MEMOS_PORT=5230`, `LOG_LEVEL=info`
- Mounted as environment variables

**3. Secret**
- Database credentials from Secrets Manager
- Connection string: `postgresql://user:pass@host:5432/db`
- Mounted as environment variables

**4. Deployment**
- Pod template: How to run Memos container
- Replicas: 2 pods initially
- Strategy: Rolling update (no downtime)
- Health checks: Liveness & readiness probes
- Resource limits: CPU/memory
- Security context: Non-root user

**5. ServiceAccount**
- Identity for pods
- Allows fine-grained RBAC (future use)

**6. Service**
- Type: LoadBalancer (AWS NLB)
- Routes traffic to pods
- Provides external URL

**7. HorizontalPodAutoscaler (HPA)**
- Auto-scale based on metrics
- Min 2, max 5 replicas
- CPU > 70% → scale up
- Memory > 80% → scale up

**8. PodDisruptionBudget (PDB)**
- Ensures minimum availability
- Min 1 pod always running
- Protects during cluster updates

---

## Part 4: Deployment Manifest Explained

### Deployment Spec

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: memos              # Deployment name
  namespace: memos         # Kubernetes namespace
spec:
  replicas: 2              # Start with 2 pods
  strategy:
    type: RollingUpdate    # No downtime updates
    rollingUpdate:
      maxSurge: 1          # 1 extra pod during update
      maxUnavailable: 0    # 0 pods down during update
```

**What this means:**
- Start 2 Memos pods (high availability)
- Update strategy: Create new pod, then terminate old pod (zero downtime)
- Max 1 extra pod during update (cost control)
- Never have 0 pods (always available)

### Pod Spec

```yaml
containers:
- name: memos
  image: ghcr.io/usememos/memos:latest
  ports:
  - name: http
    containerPort: 5230
  
  # Configuration from ConfigMap
  envFrom:
  - configMapRef:
      name: memos-config
  
  # Secrets from Kubernetes Secret
  env:
  - name: DB_HOST
    valueFrom:
      secretKeyRef:
        name: memos-db-secret
        key: DB_HOST
  # ... more environment variables
```

**What this means:**
- Pull image from GitHub container registry
- Expose port 5230
- Load app settings from ConfigMap
- Load database credentials from Secret
- Pod has access to both

### Health Checks

```yaml
livenessProbe:
  httpGet:
    path: /api/v1/ping
    port: http
  initialDelaySeconds: 30    # Wait 30s before first check
  periodSeconds: 10          # Check every 10s
  failureThreshold: 3        # Restart after 3 failures

readinessProbe:
  httpGet:
    path: /api/v1/ping
    port: http
  initialDelaySeconds: 10    # Wait 10s before first check
  periodSeconds: 5           # Check every 5s
  failureThreshold: 2        # Mark unready after 2 failures
```

**What this means:**
- **Liveness probe**: Is pod running? (restart if not)
- **Readiness probe**: Can pod handle traffic? (remove from LB if not)
- Checks `/api/v1/ping` endpoint
- Pod gets 30 seconds to start
- 3 failures in a row → pod restart
- 2 failures in a row → remove from load balancer

### Resource Limits

```yaml
resources:
  requests:                  # Minimum guaranteed
    cpu: 100m               # 100 millicores = 0.1 CPU
    memory: 128Mi           # 128 megabytes
  limits:                   # Maximum allowed
    cpu: 500m               # 500 millicores = 0.5 CPU
    memory: 512Mi           # 512 megabytes
```

**What this means:**
- Each pod needs minimum 0.1 CPU and 128MB RAM
- Max 0.5 CPU and 512MB RAM per pod
- If exceeded: pod terminated and restarted
- 2 pods × 512MB = 1GB total for 2 replicas
- 2 pods × 0.5 CPU = 1 CPU total for 2 replicas

### Security Context

```yaml
securityContext:
  runAsNonRoot: true        # Cannot run as root
  runAsUser: 1000           # Run as UID 1000
  allowPrivilegeEscalation: false  # No privilege escalation
  readOnlyRootFilesystem: false    # Can write to temp dirs
  capabilities:
    drop:
    - ALL                   # Drop all Linux capabilities
```

**What this means:**
- Container runs as non-root user (security best practice)
- No special privileges
- Prevents privilege escalation attacks
- Can still write to `/var/opt/memos` (our volume)

### Pod Anti-Affinity

```yaml
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchExpressions:
          - key: app
            operator: In
            values:
            - memos
        topologyKey: kubernetes.io/hostname
```

**What this means:**
- Try to place Memos pods on different nodes
- Weight: 100 = strong preference
- Topology key: different hostnames
- Improves availability (one node failure = at least 1 pod survives)

---

## Part 5: Service and LoadBalancer

### LoadBalancer Service

```yaml
kind: Service
metadata:
  name: memos
  namespace: memos
spec:
  type: LoadBalancer        # AWS NLB (Network Load Balancer)
  selector:
    app: memos              # Route to pods with this label
  ports:
  - name: http
    port: 80                # Listen on port 80
    targetPort: http        # Forward to pod port 5230
    protocol: TCP
```

**What this means:**
- Create AWS Network Load Balancer (NLB)
- Route external traffic to pods
- `80` → pod's `5230` port
- Auto-discovers pods with `app: memos` label
- If pod dies, automatically removed from LB

### External Access

```
Internet
  ↓
AWS NLB (a1b2c3d4.elb.us-west-1.amazonaws.com:80)
  ↓
Kubernetes Service (memos:80)
  ↓
Deployment Selector (app: memos)
  ↓
Pods (2 replicas on different nodes)
  ↓
Memos App (listening on :5230)
```

---

## Part 6: Auto-scaling

### HorizontalPodAutoscaler (HPA)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: memos
spec:
  scaleTargetRef:
    kind: Deployment
    name: memos
  minReplicas: 2            # Minimum 2 pods
  maxReplicas: 5            # Maximum 5 pods
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        averageUtilization: 70  # Scale up if CPU > 70%
  - type: Resource
    resource:
      name: memory
      target:
        averageUtilization: 80  # Scale up if memory > 80%
```

**What this means:**
- Automatically scale based on metrics
- If CPU/memory exceeds thresholds → add pods
- Minimum 2 pods (high availability)
- Maximum 5 pods (cost control)
- Scale up quickly, scale down slowly

**Scaling behavior:**

```
Initial: 2 pods
CPU usage: 50% → No change

Traffic increases:
CPU usage: 75% (> 70%) → Scale to 3 pods
CPU usage: 75% → Scale to 4 pods
CPU usage: 75% → Scale to 5 pods (max reached)

Traffic decreases:
CPU usage: 30% → Wait 5 minutes
CPU usage: 30% (stable) → Scale to 4 pods
CPU usage: 30% (stable) → Scale to 3 pods
CPU usage: 30% (stable) → Scale to 2 pods (min reached)
```

---

## Part 7: Deployment Workflow

### Step 1: Create Namespace

```bash
kubectl create namespace memos
```

Creates logical isolation for Memos resources.

### Step 2: Create Secrets

```bash
kubectl create secret generic memos-db-secret \
  --from-literal=DB_HOST=... \
  --from-literal=DB_PASSWORD=... \
  -n memos
```

Stores database credentials in Kubernetes Secret.

### Step 3: Apply Manifests

```bash
kubectl apply -f k8s/deployment.yaml
```

Creates:
- Namespace (if not exists)
- ConfigMap
- Secret
- ServiceAccount
- Deployment (2 replicas)
- Service (LoadBalancer)
- HPA
- PDB

### Step 4: Wait for Rollout

```bash
kubectl rollout status deployment/memos -n memos
```

Kubernetes:
1. Schedules 2 pods on nodes
2. Pulls Docker image
3. Creates containers
4. Waits for liveness probe to pass
5. Waits for readiness probe to pass
6. Routes traffic to pod

Timeline: ~1-3 minutes

### Step 5: Get External URL

```bash
kubectl get svc memos -n memos
```

Returns LoadBalancer external IP/hostname:

```
NAME    TYPE           EXTERNAL-IP                              PORT(S)
memos   LoadBalancer   a1b2c3d4e5f6.elb.us-west-1.amazonaws.com 80:30123/TCP
```

### Step 6: Access Application

```
http://a1b2c3d4e5f6.elb.us-west-1.amazonaws.com
```

Traffic flow:
1. Browser → AWS NLB (DNS resolved)
2. NLB → Kubernetes Service
3. Service → Pod 1 or Pod 2 (load balanced)
4. Pod → Memos app (port 5230)
5. Memos → Database (PostgreSQL)

---

## Part 8: Monitoring Deployment

### Check Pod Status

```bash
kubectl get pods -n memos

# Output:
NAME                     READY   STATUS    RESTARTS   AGE
memos-abc123-def456      1/1     Running   0          2m
memos-abc123-ghi789      1/1     Running   0          2m
```

**READY 1/1:** 1 container ready out of 1 expected
**STATUS Running:** Pod is running
**RESTARTS 0:** Pod hasn't crashed
**AGE 2m:** Pod running for 2 minutes

### Check Health Probes

```bash
kubectl describe pod memos-abc123-def456 -n memos

# Look for "Conditions:"
Conditions:
  Type              Status
  Initialized       True
  Ready             True
  ContainersReady   True
  PodScheduled      True
```

All should be **True** if pod is healthy.

### Check Logs

```bash
kubectl logs memos-abc123-def456 -n memos

# Output:
Starting memos server on :5230
Database: postgresql://user:***@host:5432/memos
Server running...
```

No error messages = healthy startup.

### Check Resource Usage

```bash
kubectl top pods -n memos

# Output:
NAME                   CPU(cores)   MEMORY(bytes)
memos-abc123-def456    50m          256Mi
memos-abc123-ghi789    45m          250Mi
```

- CPU: 50m = 50 millicores (request: 100m, limit: 500m) ✓
- Memory: 256Mi (request: 128Mi, limit: 512Mi) ✓

Both within limits.

---

## Part 9: Common Issues and Fixes

### Issue 1: Pods not starting (CrashLoopBackOff)

**Symptoms:**
```
STATUS            CrashLoopBackOff
RESTARTS          5
```

**Causes & Fixes:**
```bash
# Check logs
kubectl logs <POD_NAME> -n memos

# Common errors:
# - "connection refused": Database not accessible
#   → Check RDS security group
#   → Verify database credentials in secret
#
# - "image not found": Container image not available
#   → Check image name and tag
#   → Verify ECR permissions
#
# - "insufficient resources": Node ran out of CPU/memory
#   → Reduce resource requests
#   → Add more nodes to cluster
```

### Issue 2: LoadBalancer stuck on pending

**Symptoms:**
```
EXTERNAL-IP   <pending>
```

**Causes & Fixes:**
```bash
# Check service events
kubectl describe svc memos -n memos

# Common issues:
# - EKS doesn't have public subnets tagged correctly
# - Security groups blocking traffic
# - Insufficient IAM permissions

# Solution: Verify EKS setup
aws eks describe-cluster --name memos-eks --region us-west-1
```

### Issue 3: Cannot access application

**Symptoms:**
```
curl http://<EXTERNAL-IP>
Connection timeout
```

**Causes & Fixes:**
```bash
# Check if pods are ready
kubectl get pods -n memos

# Check if service has endpoints
kubectl get endpoints -n memos

# Check if pod port is correct
kubectl describe pod <POD_NAME> -n memos | grep -A 2 "Ports:"

# Test from node
kubectl exec -it <POD_NAME> -n memos -- curl localhost:5230/api/v1/ping
```

### Issue 4: Database connection failed

**Symptoms:**
```
error: connection refused
database host unreachable
```

**Causes & Fixes:**
```bash
# Verify secret
kubectl get secret memos-db-secret -n memos -o yaml

# Verify pod has secret mounted
kubectl exec -it <POD_NAME> -n memos -- env | grep DB_

# Verify database is reachable
# From pod:
kubectl exec -it <POD_NAME> -n memos -- \
  nc -zv $DB_HOST $DB_PORT

# Check RDS security group
aws ec2 describe-security-groups \
  --group-ids <RDS_SG_ID> --region us-west-1
```

---

## Part 10: Updates and Rollbacks

### Rolling Update (New Version)

```bash
# Update to new image version
kubectl set image deployment/memos \
  memos=ghcr.io/usememos/memos:v0.21.0 \
  -n memos

# Watch the rollout
kubectl rollout status deployment/memos -n memos

# Timeline:
# 1. Create new pod with new image
# 2. Wait for liveness/readiness probes
# 3. Add to load balancer
# 4. Remove old pod from load balancer
# 5. Terminate old pod
# 6. Repeat for each replica
# Result: Zero downtime update
```

### Rollback (If Update Fails)

```bash
# View rollout history
kubectl rollout history deployment/memos -n memos

# Rollback to previous version
kubectl rollout undo deployment/memos -n memos

# Verify rollback
kubectl rollout status deployment/memos -n memos
```

---

## Part 11: Cost Considerations

### Resource Usage

```
2 pods (minimum):
├─ CPU: 2 × 100m request = 200m = 0.2 CPU
├─ Memory: 2 × 128Mi = 256Mi
└─ Monthly: Included in t3.medium node

5 pods (maximum):
├─ CPU: 5 × 100m request = 500m = 0.5 CPU
├─ Memory: 5 × 128Mi = 640Mi
└─ Monthly: Included in t3.medium node
```

**Cost Impact:**
- Pods don't cost directly (included in node cost)
- More pods = higher CPU/memory utilization
- Auto-scaling helps: only pay for what you use

### LoadBalancer Cost

```
Network Load Balancer (NLB):
├─ Fixed cost: $18-32/month
├─ Processing units: ~$0.006/hour per million requests
└─ Total: ~$20-40/month depending on usage
```

---

## Summary

**Stage 3 teaches you:**
- ✅ Kubernetes deployment concepts
- ✅ Writing Kubernetes manifests (YAML)
- ✅ Deploying containerized apps to Kubernetes
- ✅ Managing replicas and availability
- ✅ Auto-scaling based on metrics
- ✅ Health checks and self-healing
- ✅ Load balancing with services
- ✅ Debugging Kubernetes deployments

**After Stage 3, you have:**
- ✅ Memos app running on EKS
- ✅ High availability (2 replicas)
- ✅ Auto-scaling to 5 pods
- ✅ Load balanced with external URL
- ✅ Database connectivity
- ✅ Health checks and monitoring

**Ready for Stage 4:**
- GitOps with ArgoCD (automated deployments from Git)
- Continuous synchronization of desired state
- Zero-downtime updates

---

## Next: Stage 3 Deployment

Follow [STAGE3_QUICK_REFERENCE.md](../STAGE3_QUICK_REFERENCE.md) for step-by-step deployment commands.
