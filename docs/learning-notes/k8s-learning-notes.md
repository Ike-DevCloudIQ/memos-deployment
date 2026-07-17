# Kubernetes — Learner Notes (Workload Orchestration)

These notes teach **every Kubernetes object and concept used in this repo**,
mapped to the real manifest `k8s/deployment.yaml`. This single file is what Argo
CD deploys, so understanding it deeply = understanding the running app.

---

## 1. What Kubernetes is (the 60-second model)

Kubernetes (K8s) is a **container orchestrator**. You declare the *desired state*
of your workloads as YAML objects; K8s **controllers** continuously reconcile
reality toward that desired state.

```
You declare:   "I want 2 healthy memos pods, reachable on port 80"
K8s ensures:    schedules pods, restarts crashes, replaces dead nodes,
                load-balances traffic, scales on CPU — forever.
```

Core loop = **reconciliation**: `observe → diff desired vs actual → act → repeat`.
This is the same idea Terraform and Argo CD use, applied to running containers.

### The object hierarchy you'll meet here
```
Namespace
 └── Deployment ──manages──► ReplicaSet ──manages──► Pods ──run──► Containers
 └── Service (stable network endpoint + LoadBalancer)
 └── ConfigMap / Secret (configuration & credentials)
 └── ServiceAccount (pod identity)
 └── HorizontalPodAutoscaler (scaling)
 └── PodDisruptionBudget (availability during disruptions)
```

---

## 2. What THIS repo's manifest contains

`k8s/deployment.yaml` is a **multi-document YAML** (objects separated by `---`).
In order, it defines:

1. `Namespace` — `memos`
2. `ConfigMap` — non-secret app config
3. `Secret` — DB connection details
4. `Deployment` — the app itself (2 replicas)
5. `ServiceAccount` — pod identity (ties to IRSA)
6. `Service` — LoadBalancer (NLB) exposing the app
7. `PodDisruptionBudget` — availability guarantee
8. `HorizontalPodAutoscaler` — CPU/memory autoscaling

Let's go object by object.

---

## 3. Namespace — logical isolation

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: memos
  labels:
    name: memos
```
A **namespace** is a virtual cluster boundary for grouping resources, applying
quotas, RBAC, and network policies. Everything the app owns lives in `memos`,
keeping it isolated from `argocd`, `monitoring`, etc.

---

## 4. ConfigMap — non-secret configuration

```yaml
kind: ConfigMap
metadata: { name: memos-config, namespace: memos }
data:
  MEMOS_PORT: "5230"
  MEMOS_MODE: "prod"
  DRIVER: "postgres"
  LOG_LEVEL: "info"
```
- **ConfigMaps** externalise configuration from the image (12-factor app). The
  same image runs in dev/prod with different ConfigMaps.
- Injected into the pod via `envFrom.configMapRef` (all keys become env vars).
- **Never** put secrets here — ConfigMaps are stored/readable in plaintext.

---

## 5. Secret — sensitive configuration

```yaml
kind: Secret
type: Opaque
stringData:
  DB_HOST: "...rds.amazonaws.com"
  DB_PASSWORD: "CHANGE_ME_FROM_SECRETS_MANAGER"
  DSN: "postgresql://...sslmode=disable"
```
- **Secrets** hold sensitive data. `stringData` lets you write plaintext that K8s
  base64-encodes on store (vs `data`, which you must pre-encode).
- ⚠️ **Base64 is encoding, not encryption.** Native Secrets are only as safe as
  etcd encryption + RBAC. The placeholder `CHANGE_ME` signals these should be
  injected from **AWS Secrets Manager** (that's what the `secrets` scaffold app is
  a landing zone for — see `k8s-apps/` notes).
- Consumed individually via `secretKeyRef` so each env var maps to one key.

**Senior note:** committing a Secret manifest (even placeholder) to Git is an
anti-pattern for real secrets. Production pattern = External Secrets Operator or
Sealed Secrets so Git never holds plaintext.

---

## 6. Deployment — the heart of the app

The `Deployment` declares desired pod state and manages rollouts. Walk the key
sections:

### Replicas + rollout strategy
```yaml
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1        # at most 1 extra pod during rollout
      maxUnavailable: 0  # never drop below desired count → zero downtime
```
`maxUnavailable: 0` + `maxSurge: 1` = **zero-downtime rolling deploy**: spin up a
new pod, wait for it healthy, then retire an old one.

### Selector + template
The `selector.matchLabels` (`app: memos`) tells the Deployment which pods it owns;
`template.metadata.labels` must match. This label linkage is how Deployment →
ReplicaSet → Pod → Service all find each other.

### Prometheus scrape annotations
```yaml
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "5230"
  prometheus.io/path: "/api/v1/metrics"
```
These tell Prometheus to scrape metrics from each pod (Stage 6 monitoring).

### Pod anti-affinity (spread for HA)
```yaml
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector: { matchExpressions: [{ key: app, operator: In, values: [memos] }] }
        topologyKey: kubernetes.io/hostname
```
**"Prefer to place memos pods on different nodes."** If a node dies you don't lose
both replicas. `preferred` (soft) not `required` (hard) so scheduling still
succeeds on a single-node dev cluster.

### Container image (GitOps target)
```yaml
image: 184353012435.dkr.ecr.eu-west-1.amazonaws.com/memos:54c6025
```
The tag is a **git short-SHA**, not `latest`. CI rewrites this line and Argo CD
deploys the change — the core of the GitOps flow (see `.github/` and `argocd/`
notes). Immutable SHA tags = reproducible, rollback-able deploys.

### Config injection
```yaml
envFrom:
  - configMapRef: { name: memos-config }   # bulk env from ConfigMap
env:
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef: { name: memos-db-secret, key: DB_PASSWORD }  # per-key from Secret
```

### Health probes — the three-probe model
```yaml
livenessProbe:   # is it alive? fail → restart the container
readinessProbe:  # is it ready for traffic? fail → remove from Service endpoints
startupProbe:    # still booting? gates the other probes until app has started
```
- **Liveness** restarts a hung container.
- **Readiness** gates traffic — pod stays in the Service only when ready.
- **Startup** (`failureThreshold: 30 × periodSeconds: 10` = up to 5 min) protects
  slow-starting apps so liveness doesn't kill them mid-boot.

### Resource requests & limits
```yaml
resources:
  requests: { cpu: 100m, memory: 128Mi }   # scheduler reserves this
  limits:   { cpu: 500m, memory: 512Mi }   # hard ceiling
```
- **Requests** = what the scheduler guarantees (used for bin-packing + HPA math).
- **Limits** = the ceiling. Exceed memory → **OOMKilled**; exceed CPU → throttled.
- Requests==limits would make it **Guaranteed** QoS; here requests<limits =
  **Burstable** QoS.

### Security context (hardening)
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  allowPrivilegeEscalation: false
  capabilities: { drop: [ALL] }
# pod-level:
  fsGroup: 1000
  seccompProfile: { type: RuntimeDefault }
automountServiceAccountToken: false
```
This is a **hardened pod**: non-root, no privilege escalation, all Linux
capabilities dropped, seccomp on, and the SA token not auto-mounted (reduces
blast radius if the pod is compromised). Textbook least privilege.

### Storage
```yaml
volumes:
  - name: memos-data
    emptyDir: { sizeLimit: 1Gi }
```
`emptyDir` is **ephemeral** — wiped when the pod dies. Fine because real data
lives in **RDS PostgreSQL**, not on the pod. (If the app needed durable local
state you'd use a PersistentVolumeClaim instead.)

---

## 7. ServiceAccount — pod identity

```yaml
kind: ServiceAccount
metadata: { name: memos, namespace: memos }
```
The pod runs as this SA. Crucially, the Terraform EKS module's **IRSA** role trusts
exactly `system:serviceaccount:default:memos` — the SA is the bridge between
Kubernetes identity and AWS IAM permissions.

---

## 8. Service — stable networking + external exposure

```yaml
kind: Service
metadata:
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
spec:
  type: LoadBalancer
  selector: { app: memos }
  ports:
    - { name: http, port: 80,  targetPort: http }
    - { name: https, port: 443, targetPort: http }
```
- **Service** gives pods a **stable virtual IP + DNS name** even as pods come and
  go. It load-balances across pods matching the `selector`.
- **`type: LoadBalancer`** provisions a cloud LB. The annotation requests an AWS
  **NLB** (L4, high throughput) with cross-zone balancing.
- **`targetPort: http`** references the *named* container port (`5230`), decoupling
  the service port (80/443) from the container port.

Service types recap: `ClusterIP` (internal only) → `NodePort` (node port) →
`LoadBalancer` (cloud LB). This app uses LoadBalancer for public access.

---

## 9. PodDisruptionBudget — availability guarantee

```yaml
kind: PodDisruptionBudget
spec:
  minAvailable: 1
  selector: { matchLabels: { app: memos } }
```
A **PDB** limits *voluntary* disruptions (node drains, upgrades). It guarantees at
least 1 memos pod stays up during a `kubectl drain`, so cluster maintenance can't
take the app fully offline. (It does not protect against involuntary events like a
sudden node crash.)

---

## 10. HorizontalPodAutoscaler — elasticity

```yaml
kind: HorizontalPodAutoscaler
apiVersion: autoscaling/v2
spec:
  minReplicas: 2
  maxReplicas: 5
  metrics:
    - type: Resource
      resource: { name: cpu,    target: { type: Utilization, averageUtilization: 70 } }
    - type: Resource
      resource: { name: memory, target: { type: Utilization, averageUtilization: 80 } }
  behavior:
    scaleDown: { stabilizationWindowSeconds: 300, ... }  # slow, cautious
    scaleUp:   { stabilizationWindowSeconds: 0,  ... }    # fast, responsive
```
- The **HPA** scales replicas 2→5 based on CPU>70% or memory>80% of **requests**.
- Utilization is measured against the **request** value — that's why setting
  requests correctly matters.
- **`behavior`** tunes reactivity: scale **up fast** (0s window, +100%/30s) to
  absorb spikes, scale **down slowly** (300s window) to avoid flapping.
- Requires the **metrics-server** to be running to supply CPU/memory metrics.

---

## 11. How it all connects (request path)

```
Internet
  │
  ▼
AWS NLB  (from Service type=LoadBalancer)
  │  load-balances to ready pods only (readinessProbe)
  ▼
memos pods (2–5, spread across nodes via anti-affinity)
  │  env from ConfigMap + Secret
  ▼
RDS PostgreSQL (private subnet)   ← data persistence (not emptyDir)
```

---

## 12. Essential `kubectl` for a learner

```bash
kubectl get pods -n memos -o wide          # where are pods running
kubectl describe pod <pod> -n memos        # events, probe failures, image pulls
kubectl logs -f deploy/memos -n memos      # stream app logs
kubectl rollout status deploy/memos -n memos
kubectl rollout undo deploy/memos -n memos # rollback
kubectl get hpa -n memos                   # current vs target utilization
kubectl get endpoints memos -n memos       # which pod IPs the Service targets
kubectl get events -n memos --sort-by=.lastTimestamp
kubectl top pods -n memos                  # live CPU/mem (needs metrics-server)
```

---

## 13. Kubernetes Q&A (15)

**Q1. Deployment vs ReplicaSet vs Pod — who does what?**
A Pod is one or more co-located containers (smallest deployable unit). A ReplicaSet
keeps N identical pods running. A Deployment manages ReplicaSets to give you
declarative updates, rollout strategy, and rollback — each image change creates a
new ReplicaSet and shifts pods over. You almost always manage Deployments, not
ReplicaSets directly.

**Q2. Explain the three probe types and a failure mode of misconfiguring them.**
Liveness restarts a container that's alive-but-stuck; readiness gates traffic;
startup protects slow-booting apps from premature liveness kills. A classic
mistake: pointing liveness at a heavy endpoint or setting `initialDelaySeconds` too
low, so a slow-starting app gets killed in a restart loop (CrashLoopBackOff). The
startup probe here (up to 5 min) exists precisely to prevent that.

**Q3. requests vs limits, and what happens at each boundary?**
Requests are guaranteed reservations used for scheduling and HPA math; limits are
ceilings. Hitting the memory limit → the container is OOMKilled and restarted;
hitting the CPU limit → it's throttled (not killed). Setting requests too high
wastes capacity; too low causes noisy-neighbour and bad HPA behaviour. This pod is
Burstable QoS because requests < limits.

**Q4. How does this manifest achieve zero-downtime deploys?**
RollingUpdate with `maxUnavailable: 0` and `maxSurge: 1`: a new pod is created and
must pass readiness before an old one is removed, so capacity never dips below
desired. Combined with the readiness probe, the Service only routes to ready pods,
so users never hit a starting or dying pod.

**Q5. What's the difference between a ConfigMap and a Secret, really?**
Functionally both inject config; the difference is intent and handling. Secrets are
meant for sensitive data, can be encrypted at rest in etcd, are RBAC-restricted,
and are kept out of some logs/UIs. But base64 is not encryption — without etcd
encryption + tight RBAC (and ideally an external secrets manager) a Secret isn't
truly secret. ConfigMaps are plaintext by design.

**Q6. Why is committing this Secret to Git a problem, and what's the fix?**
Anyone with repo access sees the credentials, and they persist in git history
forever. The placeholder here hints at the fix: inject from AWS Secrets Manager via
External Secrets Operator (or use Sealed Secrets, which stores an *encrypted*
manifest that only the in-cluster controller can decrypt). Git should never hold
plaintext secrets. The `secrets` Argo scaffold app is the landing zone for exactly
this.

**Q7. Explain pod anti-affinity here and soft vs hard.**
`podAntiAffinity` with `topologyKey: kubernetes.io/hostname` asks the scheduler to
place memos replicas on different nodes so one node failure doesn't kill both. It's
`preferred` (soft) so scheduling still succeeds if only one node is available; a
`required` (hard) rule would leave pods Pending if the spread can't be satisfied —
riskier on small clusters.

**Q8. How does the Service know which pods to send traffic to, and how do probes
factor in?**
The Service's `selector` (`app: memos`) matches pod labels; matching, *ready* pods
are added to the Service's Endpoints. A pod failing its readiness probe is removed
from Endpoints (no traffic) without being restarted, which is how rolling updates
and transient overload stay graceful.

**Q9. What does the PodDisruptionBudget protect against and not protect against?**
It caps *voluntary* disruptions — node drains, cluster upgrades, autoscaler
scale-in — guaranteeing `minAvailable: 1`. It does not protect against
*involuntary* disruptions like a hardware/node crash or OOM. It's a maintenance
safety net, not an HA guarantee on its own.

**Q10. How does the HPA decide to scale, and what's required for it to work?**
It compares live CPU/memory utilization (as a percentage of pod *requests*) to the
70%/80% targets and adjusts replicas between 2 and 5. It needs metrics-server to
supply resource metrics. The `behavior` block makes scale-up aggressive and
scale-down conservative to prevent thrashing. If requests are unset/wrong, HPA math
is meaningless.

**Q11. `emptyDir` here is ephemeral — is that a bug? When would you use a PVC
instead?**
Not a bug: Memos persists to RDS, so the pod needs no durable local disk;
`emptyDir` is fine for scratch/cache and is wiped on pod restart. You'd switch to a
PersistentVolumeClaim (backed by EBS) only if the app itself required durable
node-local state, which would also constrain scheduling and complicate multi-replica
writes.

**Q12. Walk through this pod's security hardening.**
`runAsNonRoot` + `runAsUser: 1000` (no root), `allowPrivilegeEscalation: false`,
`capabilities.drop: [ALL]` (no Linux caps), `seccompProfile: RuntimeDefault`
(syscall filtering), `fsGroup` for volume ownership, and
`automountServiceAccountToken: false` to avoid handing every pod a usable API
token. Together they shrink the blast radius if the container is compromised —
aligned with Pod Security Standards "restricted".

**Q13. The image is tagged with a git SHA, not `latest`. Why does that matter?**
Immutable, unique tags make deployments deterministic and auditable: you know
exactly which commit is running, rollbacks are a tag change, and the kubelet won't
be confused by a mutable `latest` that changed underneath it. It's also what makes
the GitOps loop work — CI writes the SHA, Argo CD syncs that exact artifact.

**Q14. How would you expose this app more securely/cheaply than a per-Service
LoadBalancer?**
Replace multiple `type: LoadBalancer` Services with a single Ingress + Ingress
controller (e.g., AWS Load Balancer Controller using an ALB), terminating TLS at
the LB, adding WAF, and routing by host/path — one shared LB instead of one per
service. Note this manifest maps 443→the plaintext container port with no TLS, so
adding real TLS termination at an ALB/Ingress is the right hardening step.

**Q15. A pod is stuck in CrashLoopBackOff. Walk me through triage.**
`kubectl describe pod` for events (image pull? OOMKilled? probe failures?),
`kubectl logs --previous` for the crashed container's output, check resource limits
for OOM, verify env/Secret/ConfigMap values (e.g., a bad DSN), confirm the DB is
reachable from the pod's subnet/SG, and check the startup/liveness timing. Fix the
root cause rather than bumping restarts — most CrashLoops are config, dependency,
or resource issues.

---

### TL;DR for a learner
`k8s/deployment.yaml` is a **production-shaped** manifest: it isolates with a
Namespace, configures with ConfigMap/Secret, runs a **hardened, health-checked,
auto-scaling** Deployment, gives it an **AWS-NLB Service**, and guards availability
with a **PDB**. The senior themes are **zero-downtime rollouts, least-privilege
pods, correct probes/resources, and externalising state & secrets**.
