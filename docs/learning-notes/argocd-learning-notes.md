# Argo CD — Learner Notes (GitOps Continuous Delivery)

These notes teach **GitOps and every Argo CD object in this repo**, mapped to the
real files under `argocd/`. Argo CD is what turns a `git push` into a running
change on the cluster — no `kubectl apply` by humans.

---

## 1. What GitOps is and why Argo CD exists

**GitOps** = Git is the single source of truth for *desired cluster state*. A
controller running *in* the cluster continuously compares Git to live state and
reconciles any difference.

```
        ┌─────────────── Git repo (desired state) ───────────────┐
        │  k8s/deployment.yaml, argocd/apps/*.yaml                │
        └────────────────────────┬───────────────────────────────┘
                                 │ Argo CD watches (polls/webhook)
                                 ▼
   compare desired (Git) vs live (cluster)  →  Sync  →  reconcile
                                 ▲
                                 │ self-heal / prune
                    ┌────────────┴────────────┐
                    │   EKS cluster (live)     │
                    └──────────────────────────┘
```

Why it's better than `kubectl apply` from a laptop or CI push:
- **Auditability**: every change is a Git commit (who/what/when, reviewable via PR).
- **Drift correction**: `selfHeal` reverts manual `kubectl edit` changes.
- **Rollback = git revert**.
- **No cluster creds in CI**: the pull-based model means CI never needs kube
  access; Argo pulls from Git instead.

---

## 2. Core Argo CD concepts

| Concept | Meaning in this repo |
|---|---|
| **Application** | A unit Argo manages = "sync this Git path to this namespace" |
| **App-of-Apps** | A root Application whose job is to create *other* Applications |
| **AppProject** | A security boundary: which repos/destinations/kinds an app may use |
| **Sync** | Apply Git's desired state to the cluster |
| **Sync status** | `Synced` (Git == live) or `OutOfSync` |
| **Health status** | `Healthy` / `Progressing` / `Degraded` (is the workload OK) |
| **Prune** | Delete live resources that were removed from Git |
| **Self-heal** | Revert out-of-band live changes back to Git |

---

## 3. This repo's structure — the App-of-Apps pattern

```
argocd/
├── argocd-project.yaml   # AppProject: restricted "memos-project"
├── root-app.yaml         # ROOT Application (app-of-apps)
└── apps/                 # child Applications (one tile each)
    ├── memos.yaml        # the real app  → syncs k8s/
    ├── cloudwatch.yaml   # scaffold       → syncs k8s-apps/cloudwatch/
    └── secrets.yaml      # scaffold       → syncs k8s-apps/secrets/
```

**How it works:** you sync the **root** app once. Root watches `argocd/apps/` and
creates one **child Application per file**. Each child then syncs its own Git path.
This is how you get a **tile per app** in the Argo UI and manage many apps from one
place.

```
        root (watches argocd/apps/)
          ├── creates ──► memos      ──► deploys k8s/
          ├── creates ──► cloudwatch ──► manages amazon-cloudwatch ns
          └── creates ──► secrets    ──► manages external-secrets ns
```

---

## 4. The ROOT Application (`root-app.yaml`)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/Ike-DevCloudIQ/memos-deployment
    targetRevision: HEAD
    path: argocd/apps          # ← the folder of child Applications
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated: { prune: true, selfHeal: true }
    syncOptions: [ CreateNamespace=false ]
```

Line-by-line teaching points:
- **`kind: Application`** — Argo's CRD; the whole app-of-apps trick is "an
  Application whose rendered manifests are *more Applications*."
- **`finalizers: resources-finalizer...`** — on delete, Argo **cascade-deletes**
  the child resources first (clean teardown) instead of orphaning them.
- **`source.path: argocd/apps`** — root renders every manifest in that folder.
- **`targetRevision: HEAD`** — track the default branch tip. (Prod often pins a
  tag/commit for control.)
- **`destination.server: https://kubernetes.default.svc`** — the in-cluster API
  (Argo manages its own cluster).
- **`automated.prune: true`** — if you delete `apps/foo.yaml`, Argo deletes app
  `foo`. **`selfHeal: true`** — reverts manual drift.

⚠️ **The famous foot-gun:** an App-of-Apps with `prune: true` + `selfHeal: true`
that also manages Argo CD itself can delete Argo's own control plane. Earlier in
this project a self-manage `argocd` child was removed for exactly that reason.

---

## 5. The AppProject (`argocd-project.yaml`)

```yaml
kind: AppProject
metadata: { name: memos-project, namespace: argocd }
spec:
  description: Restricted project for memos GitOps application
  sourceRepos:
    - https://github.com/Ike-DevCloudIQ/memos-deployment
  destinations:
    - namespace: memos
      server: https://kubernetes.default.svc
  clusterResourceWhitelist:
    - group: ""
      kind: Namespace
  orphanedResources:
    warn: true
```

An **AppProject** is a **guardrail / multi-tenancy boundary**. It restricts what
apps assigned to it may do:
- **`sourceRepos`** — apps may only deploy from this one repo (blocks a rogue app
  pulling arbitrary manifests).
- **`destinations`** — may only deploy into the `memos` namespace on this cluster.
- **`clusterResourceWhitelist`** — the only *cluster-scoped* kind allowed is
  `Namespace`; everything else must be namespaced. Prevents an app from creating
  ClusterRoles, CRDs, etc.
- **`orphanedResources.warn`** — flags resources in the namespace that Git doesn't
  track.

The `default` project (used by root/scaffolds) is permissive; `memos-project`
demonstrates **least privilege for a delivery pipeline**.

---

## 6. The child Application: memos (`apps/memos.yaml`)

```yaml
kind: Application
metadata: { name: memos, namespace: argocd, finalizers: [ ... ] }
spec:
  project: memos-project          # ← runs under the restricted project
  source:
    repoURL: https://github.com/Ike-DevCloudIQ/memos-deployment
    targetRevision: HEAD
    path: k8s                     # ← deploys everything in k8s/
  destination:
    server: https://kubernetes.default.svc
    namespace: memos
  syncPolicy:
    automated: { prune: true, selfHeal: true }
    syncOptions:
      - CreateNamespace=true
      - PruneLast=true
```

Teaching points:
- Assigned to **`memos-project`**, so it's constrained by the AppProject rules
  above — the child *can't* escape to another namespace or repo.
- **`path: k8s`** — this is the link to the Kubernetes notes: Argo applies
  `k8s/deployment.yaml`. When CI rewrites the image SHA there, Argo auto-syncs.
- **`CreateNamespace=true`** — Argo creates the `memos` namespace if missing.
- **`PruneLast=true`** — during a sync, prune deletions happen **after** the new
  resources are healthy, reducing downtime/ordering issues.

This is the **complete CI/CD → GitOps handoff**: GitHub Actions builds an image and
commits a new tag into `k8s/deployment.yaml`; Argo notices the commit and rolls it
out. CI never touches the cluster.

---

## 7. The scaffold children: cloudwatch & secrets (`apps/*.yaml`)

```yaml
# cloudwatch.yaml → path: k8s-apps/cloudwatch → namespace: amazon-cloudwatch
# secrets.yaml    → path: k8s-apps/secrets    → namespace: external-secrets
```

These are **landing-zone scaffolds**: real, `Healthy` Applications that currently
only manage an empty namespace. They exist so the app-of-apps has proper tiles and
a clear place to later drop:
- **cloudwatch** → CloudWatch agent / Fluent Bit (Container Insights) for
  logs+metrics.
- **secrets** → External Secrets Operator / Sealed Secrets to replace the plaintext
  K8s Secret with values pulled from AWS Secrets Manager.

Pattern lesson: it's common to **stand up the GitOps structure first** (healthy
empty tiles), then grow each app by committing manifests into its path — no UI
clicks needed.

---

## 8. Sync & health, prune & self-heal (the daily concepts)

- **Sync status**: `Synced` = live matches Git; `OutOfSync` = drift or a new commit
  not yet applied.
- **Health**: derived per resource (a Deployment is `Healthy` when replicas are
  available, `Progressing` mid-rollout, `Degraded` on failure).
- **Prune**: removing a manifest from Git → Argo removes the live object. Powerful
  and dangerous (see the Argo self-manage incident).
- **Self-heal**: someone runs `kubectl scale`? Argo reverts it to Git's value.
  Enforces "Git is truth."

---

## 9. Useful Argo CD commands

```bash
# Access the UI (corporate network blocks the ELB, so port-forward):
kubectl port-forward svc/argocd-server -n argocd 8080:443
# admin password:
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo

argocd app list
argocd app get memos
argocd app sync memos              # manual sync
argocd app history memos           # rollout history
argocd app rollback memos <id>     # roll back to a previous synced revision
argocd app diff memos              # desired vs live diff
kubectl get applications -n argocd # raw CRD view of all tiles
```

---

## 10. ArgoCD Q&A (15)

**Q1. What is GitOps and how is it different from traditional CI/CD push
deployments?**
GitOps makes Git the single source of truth and uses an in-cluster controller to
*pull* and reconcile desired state continuously. Traditional CI *pushes* with
`kubectl apply` from a pipeline that holds cluster credentials. GitOps adds
continuous drift correction, a full Git audit trail, easy rollback via revert, and
removes cluster creds from CI (smaller attack surface).

**Q2. Explain the App-of-Apps pattern and when you'd use it.**
A root Application whose source path contains *other* Application manifests, so
syncing one app bootstraps many. You use it to manage a fleet of apps declaratively
from one repo/folder, get a tile per app, and onboard a new app by simply adding a
file. This repo's `root-app.yaml` watches `argocd/apps/` and creates memos,
cloudwatch, and secrets.

**Q3. What does an AppProject give you that a plain Application doesn't?**
Multi-tenancy guardrails: it whitelists allowed source repos, destination
clusters/namespaces, and cluster/namespace resource kinds, plus RBAC and orphaned-
resource policy. `memos-project` restricts the app to one repo, the `memos`
namespace, and only lets it create the `Namespace` cluster-scoped kind — least
privilege for delivery.

**Q4. `prune` and `selfHeal` are powerful. What's the risk and how do you mitigate
it?**
`prune` deletes live resources removed from Git; `selfHeal` reverts manual changes.
If misapplied — e.g., an app-of-apps that also manages Argo CD itself — a bad
render can delete the control plane (which happened here). Mitigate with restricted
AppProjects, never letting an automated app manage Argo's own resources, pinning
`targetRevision`, using sync windows, and reviewing diffs before enabling
auto-sync on sensitive apps.

**Q5. How does the CI pipeline hand off to Argo CD in this repo?**
GitHub Actions builds/pushes the image to ECR, then commits the new image SHA into
`k8s/deployment.yaml` with `[skip ci]`. Argo's `memos` Application watches `path:
k8s`, detects the commit, and syncs the new tag to the cluster. CI has zero cluster
access — a clean pull-based separation.

**Q6. What do Sync status and Health status each tell you, and can they disagree?**
Sync status compares Git to live (Synced/OutOfSync); Health reflects whether the
workload is actually working (Healthy/Progressing/Degraded). They can absolutely
disagree: an app can be `Synced` but `Degraded` (correct manifest, crashing pods)
or `OutOfSync` but `Healthy` (running fine on an old revision). You need both to
reason about a deployment.

**Q7. How do you roll back a bad deployment under GitOps?**
Preferably `git revert` the offending commit so Git stays the source of truth and
Argo syncs the previous state. For speed you can `argocd app rollback` to a prior
synced revision, but then reconcile Git to match, otherwise self-heal/next sync
will reapply the bad version. The Git history is your rollback ledger.

**Q8. What are finalizers on the Applications here and why do they matter?**
`resources-finalizer.argocd.argoproj.io` makes deletion *cascading*: when you delete
the Application, Argo first deletes the child resources it created, then removes the
Application. Without it you can orphan live resources (or, for app-of-apps, leave
child Applications behind). During the recovery incident, a finalizer had to be
cleared to fully remove a stuck app.

**Q9. `targetRevision: HEAD` vs pinning a commit/tag — trade-offs?**
`HEAD` auto-tracks the branch tip, so every merge deploys — fast feedback, good for
dev. Pinning a tag/commit gives controlled, promotable releases and prevents an
unreviewed commit from auto-deploying to prod. Mature setups track branches in dev
and pin immutable refs in prod, promoting by updating the ref.

**Q10. How does Argo CD detect changes — polling or webhooks?**
By default it polls the repo (~3 min). For faster syncs you configure a Git webhook
so pushes notify Argo immediately. Health/live-state is watched continuously via
Kubernetes informers, independent of the Git poll.

**Q11. A resource is `OutOfSync` but you didn't change Git. What causes that and how
do you handle it?**
Drift — someone edited the live object (`kubectl edit`), a mutating webhook/defaulting
changed fields, or an HPA/controller owns a field Argo also manages. With
`selfHeal` on, Argo reverts it. For controller-owned fields (like replica count
under HPA) you use `ignoreDifferences` so Argo stops fighting the other controller.

**Q12. How would you evolve the `secrets` scaffold into a real secure secrets flow?**
Drop External Secrets Operator manifests into `k8s-apps/secrets/`, configure a
SecretStore pointing at AWS Secrets Manager (auth via IRSA), and define
ExternalSecrets that materialise the `memos-db-secret` from Secrets Manager. Git
then holds only references, never plaintext — replacing the `CHANGE_ME` placeholder
Secret. Argo syncs it like any other app because the tile already exists.

**Q13. Why shouldn't CI have direct kubectl access in a GitOps model?**
Because the reconciler pulls from Git, CI only needs to write to Git and a registry
— no kubeconfig/cluster admin in pipeline secrets. This shrinks the attack surface
(stolen CI creds can't reach the cluster), centralises change control in Git
review, and makes the cluster's state independent of pipeline reliability.

**Q14. How do you manage secrets that Argo CD itself must apply, given Git is
public/shared?**
Never commit plaintext. Use Sealed Secrets (commit an encrypted SealedSecret only
the in-cluster controller can decrypt) or External Secrets (commit references, pull
real values from a manager at runtime). Both keep Git safe while letting Argo apply
declaratively. Plain K8s Secrets in Git (like the placeholder here) are only
acceptable as non-secret scaffolding.

**Q15. Describe a real Argo CD incident and recovery.**
In this project an app-of-apps child was set to *self-manage Argo CD* with
prune+selfHeal, and a sync pruned Argo's own control-plane resources. Recovery:
reapply the upstream Argo install manifests (pinned version), restart the
repo-server/server/application-controller, clear the stuck app's finalizer, delete
the offending Application, and confirm remaining apps returned to Synced/Healthy.
Lesson: never let an automated pruning app manage the GitOps controller itself.

---

### TL;DR for a learner
Argo CD makes **Git the deploy button**. The **root** app (app-of-apps) spawns
child apps; **memos** deploys `k8s/` under a **restricted AppProject**; **scaffolds**
reserve tiles for CloudWatch and secrets tooling. The senior themes are
**pull-based delivery, drift correction (selfHeal), safe pruning, project-level
least privilege, and Git-as-rollback** — plus the hard-won lesson to never let an
auto-pruning app manage Argo itself.
