# k8s-apps — Learner Notes (GitOps Landing Zones / Platform Add-ons)

These notes explain the **`k8s-apps/` folder**: what it is, why it exists, and the
platform-engineering concepts it teaches. Unlike `k8s/` (the application), this
folder holds **platform add-on scaffolds** that Argo CD manages as separate tiles.

---

## 1. What this folder is

```
k8s-apps/
├── cloudwatch/
│   └── namespace.yaml      # creates the `amazon-cloudwatch` namespace
└── secrets/
    └── namespace.yaml      # creates the `external-secrets` namespace
```

Each subfolder is the **Git source path for one Argo CD child Application**
(defined in `argocd/apps/cloudwatch.yaml` and `argocd/apps/secrets.yaml`). Right
now each contains only a `Namespace` — they are **landing zones / scaffolds**: real,
`Healthy` Argo tiles that reserve a place to grow a platform capability later.

```
argocd/apps/cloudwatch.yaml ──points at──► k8s-apps/cloudwatch/ ──creates──► ns amazon-cloudwatch
argocd/apps/secrets.yaml    ──points at──► k8s-apps/secrets/    ──creates──► ns external-secrets
```

---

## 2. Why "scaffold" apps are a real pattern (not filler)

This is a genuine platform-engineering technique, not busywork:

1. **Stand up the GitOps structure first.** Create the Application + namespace so the
   tile is `Synced/Healthy` and the ownership boundary exists.
2. **Grow it by committing manifests** into the path later (a Helm chart, operator,
   or raw YAML). No UI clicks, no new wiring — just `git push`.
3. **Separation of concerns.** Each platform capability (observability, secrets)
   gets its **own Application, namespace, and lifecycle**, so it can be synced,
   pruned, or rolled back independently of the app and of each other.

This mirrors how mature platform teams onboard cluster add-ons: declare the slot,
then fill it.

---

## 3. `k8s-apps/cloudwatch/` — observability landing zone

- **Namespace:** `amazon-cloudwatch`
- **Intended tenant:** the **CloudWatch Agent** and/or **Fluent Bit** for **Container
  Insights** — shipping pod/node **metrics and logs** to Amazon CloudWatch.
- **Why a dedicated namespace:** agents run as a **DaemonSet** (one pod per node)
  with elevated node access; isolating them keeps their RBAC and workloads separate
  from apps.
- **How you'd grow it:** drop the CloudWatch agent + Fluent Bit manifests (or Helm
  chart) into this folder; Argo syncs them into `amazon-cloudwatch`. Node/pod IAM for
  CloudWatch is granted via **IRSA** (same mechanism as the app's pod role in the
  EKS module).

This connects to Stage 6 monitoring: Prometheus/Grafana cover in-cluster metrics,
while CloudWatch covers AWS-native logs/metrics and control-plane logging (the EKS
module already ships control-plane logs to a CloudWatch log group).

---

## 4. `k8s-apps/secrets/` — secrets-management landing zone

- **Namespace:** `external-secrets`
- **Intended tenant:** the **External Secrets Operator (ESO)** or **Sealed Secrets** —
  the fix for the plaintext `CHANGE_ME` Secret in `k8s/deployment.yaml`.
- **The problem it solves:** committing real secrets to Git is unsafe. ESO lets you
  commit only a **reference** (an `ExternalSecret`) while the real value stays in
  **AWS Secrets Manager** (where Terraform's RDS module already stores the DB
  password) and is materialised into a K8s Secret at runtime.
- **How you'd grow it:** install ESO here, create a `SecretStore` pointing at AWS
  Secrets Manager (auth via **IRSA**), and add an `ExternalSecret` that generates
  `memos-db-secret` — closing the loop between the Terraform-created secret and the
  running pod without any plaintext in Git.

```
AWS Secrets Manager (RDS creds, from Terraform)
        ▲                         │ ESO pulls at runtime
        │ referenced by           ▼
   ExternalSecret (in Git) ─► K8s Secret memos-db-secret ─► memos pod
```

---

## 5. How this folder ties the whole project together

| Layer | Where | Connection to k8s-apps |
|---|---|---|
| Cloud | `terraform/` | Secrets Manager holds RDS creds → `secrets` app consumes them; CloudWatch log group exists → `cloudwatch` app extends it |
| Delivery | `argocd/apps/` | Two child Applications point at these folders |
| App | `k8s/` | Its placeholder Secret is what the `secrets` add-on will replace |
| Platform | `k8s-apps/` | The add-on landing zones themselves |

It shows the difference between **application delivery** (`k8s/`) and **platform
delivery** (`k8s-apps/`) — a distinction senior engineers are expected to make.

---

## 6. Senior-level interview Q&A (15)

**Q1. What's the difference between application manifests and platform/add-on
manifests, and why separate them?**
Application manifests (`k8s/`) deliver the business workload; platform manifests
(`k8s-apps/`) deliver cluster capabilities (observability, secrets, ingress) that
apps depend on. Separating them gives each an independent lifecycle, RBAC boundary,
and ownership (often different teams), so upgrading the logging agent never risks the
app and vice versa.

**Q2. Explain the "scaffold/landing-zone" pattern and its benefits.**
You first commit a minimal Application + namespace so the GitOps tile exists and is
Healthy, then grow it by adding manifests to its path. Benefits: the ownership
boundary and namespace exist up front, onboarding a capability is a pure `git push`,
and each add-on is independently syncable/prunable/rollback-able. It's how platform
teams reserve and fill slots declaratively.

**Q3. Why does each add-on get its own namespace instead of sharing one?**
Isolation of RBAC, network policy, resource quotas, and blast radius. Observability
agents and secrets operators often need elevated, node-level, or cluster permissions;
confining each to its own namespace limits what a compromise or misconfiguration can
reach and keeps ownership/cost attribution clean.

**Q4. How would you turn the `secrets` scaffold into a production secrets flow?**
Install External Secrets Operator into `external-secrets`, grant it AWS access via
IRSA, define a `SecretStore` for AWS Secrets Manager, and add `ExternalSecret`
resources that materialise `memos-db-secret` from the Terraform-created secret. Git
holds only references; plaintext never lands in the repo, replacing the `CHANGE_ME`
placeholder.

**Q5. ESO vs Sealed Secrets — when would you pick each?**
ESO keeps the source of truth in an external manager (AWS Secrets Manager/Vault) and
syncs live values — great when secrets rotate or are managed outside K8s. Sealed
Secrets encrypts the secret into a manifest you *can* safely commit, with the source
of truth in Git — simpler, no external dependency, but rotation and central
management are manual. Choose based on where you want the source of truth.

**Q6. What is Container Insights and what would run in the `cloudwatch` namespace?**
Container Insights is AWS's managed observability for containers. You'd run the
CloudWatch Agent (metrics) and Fluent Bit (log forwarding) as DaemonSets in
`amazon-cloudwatch`, shipping node/pod metrics and container logs to CloudWatch. It
complements in-cluster Prometheus/Grafana with AWS-native dashboards, alarms, and log
insights.

**Q7. Why run observability/log agents as DaemonSets, and what are the
implications?**
A DaemonSet places one agent pod on every node so it can collect that node's logs and
metrics locally. Implications: agents scale automatically with the node group, need
node-level host mounts and elevated permissions (so isolate them), and consume
resources on every node — you must set requests/limits and tolerations so they run on
all nodes including tainted ones.

**Q8. How does IRSA make these add-ons secure, and how does it relate to the app's
pod role?**
Each add-on's service account federates to a scoped IAM role via the cluster OIDC
provider, granting only the AWS permissions it needs (CloudWatch put-metrics/logs, or
Secrets Manager read) with no static keys. It's the same mechanism as the app's
`pod_execution_role` in the EKS module — least privilege per workload, enforced by an
OIDC `sub` condition on the specific service account.

**Q9. If you `git rm` the `cloudwatch` namespace manifest, what happens, and what's
the risk?**
With the child app's `prune: true`, Argo deletes the `amazon-cloudwatch` namespace —
and namespace deletion cascades to *everything* inside it (agents, configs). That's
the danger of pruning namespaces: it's a wide blast radius. You'd stage such changes
carefully, possibly disabling auto-prune or using sync waves/finalizers to control
ordering.

**Q10. Why keep these as separate Argo Applications rather than folding them into the
app-of-apps root directly?**
Separate Applications give each add-on its own sync status, health, prune policy, and
(optionally) AppProject/RBAC. That independence means you can sync or roll back the
secrets operator without touching observability or the app, and you get a clear tile
per capability — the whole point of app-of-apps composition.

**Q11. These scaffolds use the `default` AppProject while the app uses a restricted
one. Is that acceptable?**
For empty scaffolds, yes, but as they grow to install operators with cluster-scoped
resources (CRDs, ClusterRoles), you'd move them under purpose-built AppProjects that
whitelist exactly those cluster resource kinds and destinations. Platform add-ons
legitimately need broader cluster permissions than the app, so their guardrails
differ — but should still be explicit, not `default`.

**Q12. How do platform add-ons here relate to the Terraform layer?**
Terraform provisions the AWS primitives (Secrets Manager entry with RDS creds, the
EKS control-plane CloudWatch log group, OIDC provider/IRSA roles). The `k8s-apps`
add-ons consume those primitives from inside the cluster (ESO reads Secrets Manager;
CloudWatch agents extend logging). It's the handoff from cloud IaC to in-cluster
platform delivery.

**Q13. What ordering problems arise when installing operators via GitOps, and how do
you solve them?**
Operators often ship CRDs that must exist before their custom resources can apply,
causing "resource not found" sync errors. Argo solves this with sync waves
(annotations to order resources), the `ServerSideApply`/`Replace` and
`SkipDryRunOnMissingResource` options for CRDs, and splitting CRD install from CR
usage into separate waves/apps so the CRDs land first.

**Q14. How would you add Prometheus/Grafana as a managed add-on in this structure?**
Create a new `k8s-apps/monitoring/` path and an `argocd/apps/monitoring.yaml` child
app that deploys the kube-prometheus-stack Helm chart (Argo supports Helm sources)
into a `monitoring` namespace. That converts the Stage 6 manual Helm install into a
declarative, version-pinned, GitOps-managed tile — consistent with the other add-ons.

**Q15. What makes a good landing-zone/scaffold vs an anti-pattern?**
Good: it creates a real, Healthy boundary (namespace + Application) with a clear
intended tenant and a documented growth path, and it's independently manageable.
Anti-pattern: empty apps with no purpose, scaffolds that never get filled (drift into
confusion), or over-broad permissions granted "just in case." Intent and least
privilege distinguish a deliberate landing zone from clutter.

---

### TL;DR for a learner
`k8s-apps/` holds **platform add-on landing zones** — currently just namespaces for
**observability (`amazon-cloudwatch`)** and **secrets management (`external-secrets`)**
— each managed by its own Argo CD child app. It teaches the distinction between
**application delivery and platform delivery**, the **scaffold/landing-zone pattern**,
and how in-cluster add-ons **consume the AWS primitives Terraform created** (Secrets
Manager, CloudWatch, IRSA) — all delivered declaratively via GitOps.
