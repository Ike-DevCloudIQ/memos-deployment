# Terraform — Learner Notes (Infrastructure as Code)

These notes explain **every Terraform concept used in this repo**, mapped to the
actual files under `terraform/`. Read this alongside the code — each section
points at the real resource so you learn the *why*, not just the *what*.

---

## 1. What Terraform is and why it is here

Terraform is a **declarative Infrastructure-as-Code (IaC)** tool. You describe the
*desired end state* of your cloud (VPCs, EKS, RDS, IAM) in `.tf` files, and
Terraform figures out the **plan** (create/update/destroy) to reach that state.

Key mental model:

```
Desired state (.tf files)  ─┐
                            ├─►  terraform plan  ─►  diff  ─►  terraform apply
Real state (.tfstate)      ─┘
```

- **Declarative, not imperative**: you never write "create then attach"; you
  declare resources and Terraform builds a **dependency graph** and orders them.
- **Idempotent**: running `apply` twice with no code change makes no changes.
- **Provider-based**: the `aws`, `kubernetes`, and `helm` providers translate HCL
  into API calls.

### The core workflow
```bash
terraform init      # download providers + configure backend
terraform validate  # static correctness
terraform plan      # preview changes (dry run)
terraform apply     # make real changes
terraform destroy   # tear everything down
```

---

## 2. How THIS repo is structured

```
terraform/
├── provider.tf     # providers, versions, S3 backend, auth wiring
├── variables.tf    # all input variables (region, sizes, versions)
├── main.tf         # root module: wires vpc → eks → rds together
├── outputs.tf      # values exported after apply (endpoints, ARNs)
├── modules/
│   ├── vpc/        # network: VPC, subnets, NAT, routing
│   ├── eks/        # Kubernetes control plane + node group + IRSA
│   └── rds/        # PostgreSQL, Secrets Manager, enhanced monitoring
└── bootstrap/      # one-time: S3 state bucket, ECR, GitHub OIDC role
```

This is the **root-module + child-modules** pattern. `main.tf` is the root; it
calls three reusable modules and passes outputs of one as inputs to the next.

### Module wiring (from `main.tf`)
```hcl
module "vpc" { source = "./modules/vpc"  ... }

module "eks" {
  source             = "./modules/eks"
  vpc_id             = module.vpc.vpc_id            # ← output of vpc feeds eks
  private_subnet_ids = module.vpc.private_subnet_ids
  ...
}

module "rds" {
  source             = "./modules/rds"
  private_subnet_ids = module.vpc.private_subnet_ids
  ...
}
```
`module.vpc.vpc_id` is an **implicit dependency** — Terraform sees the reference
and automatically builds VPC before EKS/RDS. You rarely need `depends_on`.

---

## 3. Providers, versions & the backend (`provider.tf`)

```hcl
terraform {
  required_version = ">= 1.15"
  required_providers {
    aws        = { source = "hashicorp/aws",        version = "~> 5.0"  }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.23" }
    helm       = { source = "hashicorp/helm",       version = "~> 2.11" }
  }
  backend "s3" {}   # remote state, configured at init time
}
```

Concepts:
- **`required_version` / version pinning** with `~>` (pessimistic operator):
  `~> 5.0` means `>= 5.0, < 6.0`. Protects you from breaking major upgrades.
- **`.terraform.lock.hcl`** locks exact provider versions + checksums for
  reproducible builds across the team/CI. Commit it.
- **Remote backend (S3)**: state is stored in S3 (see `bootstrap/`), *not* on your
  laptop, so the whole team shares one source of truth.

### Cross-provider auth chaining (advanced but important)
```hcl
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
  token                  = data.aws_eks_cluster_auth.main.token
}
```
The Kubernetes/Helm providers are **configured from EKS outputs**. This is the
classic "provider depends on a resource created in the same apply" situation —
handle with care (see Q&A on the chicken-and-egg problem).

---

## 4. Variables, types & defaults (`variables.tf`)

```hcl
variable "eks_desired_capacity" {
  description = "Desired EKS node capacity"
  type        = number
  default     = 2
}
```
- **Typed inputs**: `string`, `number`, `bool`, plus complex `list`, `map`,
  `object`. Types catch mistakes at plan time.
- **Defaults** make a variable optional. No default = required input.
- Everything is parameterised: `aws_region`, `vpc_cidr`, `kubernetes_version`,
  instance sizes. That is what makes the module reusable per environment.

---

## 5. The VPC module — the network foundation (`modules/vpc/main.tf`)

This builds a **highly-available 2-AZ network**:

| Resource | Purpose |
|---|---|
| `aws_vpc.main` | The private network (`10.0.0.0/16`), DNS enabled |
| `aws_subnet.public` × 2 | Host NAT gateways + load balancers (internet-facing) |
| `aws_subnet.private` × 2 | Host EKS worker nodes + RDS (no public IPs) |
| `aws_internet_gateway` | Gives public subnets internet access |
| `aws_nat_gateway` × 2 | Lets private subnets reach *out* without being reachable *in* |
| `aws_eip.nat` × 2 | Static IPs for the NAT gateways |
| route tables + associations | Wire subnets to IGW (public) / NAT (private) |

Key techniques used:
- **`count` + `count.index`** to create 2 of everything (one per AZ).
- **`cidrsubnet(var.vpc_cidr, 8, count.index + 1)`** — programmatic subnet math.
  `cidrsubnet("10.0.0.0/16", 8, 1)` → `10.0.1.0/24`. No hard-coded CIDRs.
- **`data "aws_availability_zones"`** — dynamically discover AZs instead of
  hard-coding `us-west-1a`.
- **Public vs private subnet design**: the defense-in-depth pattern — anything
  holding data or compute lives in private subnets; only NAT/LB sit in public.

**Why two NAT gateways?** One per AZ = no cross-AZ dependency and no single point
of failure (a single NAT in one AZ would break the other AZ's egress if that AZ
failed). Trade-off: NAT gateways cost money — for dev you *could* use one.

---

## 6. The EKS module — managed Kubernetes (`modules/eks/main.tf`)

This is the densest module. It creates four things:

### (a) The control plane
- `aws_iam_role.eks_cluster_role` with `AmazonEKSClusterPolicy` — the role EKS
  itself assumes to manage AWS resources on your behalf.
- `aws_eks_cluster.main` with `endpoint_private_access = true` and
  `endpoint_public_access = true` (hybrid API access).
- `aws_cloudwatch_log_group` with 7-day retention for control-plane logs.

### (b) The worker node group
- `aws_iam_role.eks_node_role` with the **three mandatory node policies**:
  - `AmazonEKSWorkerNodePolicy` (join the cluster)
  - `AmazonEKS_CNI_Policy` (pod networking / IP allocation)
  - `AmazonEC2ContainerRegistryReadOnly` (pull images from ECR)
- `aws_eks_node_group.main` with a `scaling_config` (desired/min/max).

### (c) IRSA — IAM Roles for Service Accounts (the important one)
```hcl
resource "aws_iam_role" "pod_execution_role" {
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = "...oidc-provider/${issuer}" }
      Condition = { StringEquals = {
        "${issuer}:sub" = "system:serviceaccount:default:memos"
      }}
    }]
  })
}
```
This is **the** modern EKS security pattern. Instead of giving *nodes* broad IAM
permissions (which every pod would inherit), a specific **Kubernetes service
account** (`default:memos`) is federated to a specific IAM role via the cluster's
**OIDC provider**. Pods get *scoped, least-privilege* AWS credentials with **no
static keys**.

### (d) Security groups
- Cluster SG allows worker→control-plane on 443.
- Node SG allows intra-VPC traffic and all egress.

---

## 7. The RDS module — managed PostgreSQL (`modules/rds/main.tf`)

| Resource | What it teaches |
|---|---|
| `aws_db_subnet_group` | RDS must live in ≥2 AZs' subnets — HA requirement |
| `aws_security_group.rds` | Only allows 5432 **from the private subnets** — DB never public |
| `aws_db_parameter_group` | Engine tuning (`pg_stat_statements`, connection logging) |
| `aws_db_instance.main` | The database: `gp3`, `storage_encrypted=true`, backups, Multi-AZ toggle, `deletion_protection=true` |
| `random_password.db_password` | Generates a 32-char secret — never hard-code passwords |
| `aws_secretsmanager_secret[_version]` | Stores creds as JSON for apps to fetch at runtime |
| `aws_iam_role.rds_monitoring` | Enables **Enhanced Monitoring** (OS-level metrics) |

Security lessons baked in here:
- **`publicly_accessible = false`** + SG scoped to private CIDRs = DB unreachable
  from the internet.
- **`storage_encrypted = true`** — encryption at rest by default.
- **Secrets in Secrets Manager**, not in Terraform variables. The generated
  password never appears in code.
- **`deletion_protection = true`** + `skip_final_snapshot = false` — production
  guardrails so nobody accidentally nukes the DB.

⚠️ Note: `random_password` and the final password *do* land in **state**, which is
why the S3 backend must be encrypted + access-controlled (see Q&A).

---

## 8. Outputs (`outputs.tf`)

Outputs expose values *after* apply — for humans, for CI, or for other Terraform:
```hcl
output "eks_cluster_endpoint" { value = module.eks.cluster_endpoint }
output "rds_password" {
  value     = module.rds.database_password
  sensitive = true   # redacted in CLI output & logs
}
```
- **`sensitive = true`** stops secrets printing to the console/logs (they still
  exist in state).
- Outputs are how you get `kubectl`/app config after provisioning
  (endpoint, secret ARN, OIDC issuer URL).

---

## 9. The bootstrap module — solving chicken-and-egg (`bootstrap/`)

The S3 backend must exist **before** you can use it. `bootstrap/` is a tiny,
**locally-stateful** Terraform run that creates the prerequisites:

- `aws_s3_bucket.terraform_state` — versioned + encrypted + public access blocked
  → the remote state store for the *main* config.
- `aws_ecr_repository.memos` — `IMMUTABLE` tags + `scan_on_push` (image security).
- `aws_iam_openid_connect_provider.github` + `aws_iam_role.github_actions` —
  the **OIDC trust** that lets GitHub Actions assume an AWS role with **no
  long-lived keys** (see the `.github/` notes).
- `aws_iam_role_policy.github_actions_ecr` — **least-privilege** push access
  scoped to *this one ECR repo* ARN (except `GetAuthorizationToken`, which is
  account-wide by API design).

You run `bootstrap/` **once**, then the main config uses the bucket it created.

---

## 10. State — the concept people underestimate

- **State (`terraform.tfstate`)** is Terraform's record of *what it created* and
  the mapping from your code to real resource IDs.
- It is the **source of truth for diffs**. `plan` = compare code vs state vs real.
- **Remote state** (S3 here) enables teamwork and CI. Local state = one person only.
- **State locking** (usually via DynamoDB) prevents two applies clobbering each
  other. If two engineers `apply` at once without a lock, state can corrupt.
- **Never edit state by hand.** Use `terraform state mv/rm/import` and
  `terraform taint`/`-replace`.

---

## 11. Everyday commands cheat-sheet

```bash
terraform init -backend-config=...     # set up backend + providers
terraform fmt -recursive               # canonical formatting
terraform validate                     # syntax/type checks
terraform plan -out=tf.plan            # save a plan
terraform apply tf.plan                # apply exactly that plan
terraform output rds_endpoint          # read an output
terraform state list                   # what's tracked
terraform state show module.eks...     # inspect one resource
terraform import aws_s3_bucket.x name  # adopt an existing resource
terraform apply -replace=<addr>        # recreate one resource (was 'taint')
terraform destroy -target=module.rds   # scoped destroy (careful!)
```

---

## 12. Q&A (15)

**Q1. Explain Terraform state and why remote state matters.**
State is Terraform's mapping between declared resources and real infrastructure
IDs; it's how `plan` computes diffs. Remote state (S3 here) centralises it so a
team and CI share one truth, enables locking to prevent concurrent-apply
corruption, and keeps secrets out of individual laptops. Local state doesn't scale
past one person and is easily lost.

**Q2. How do you handle secrets that end up in state, like the RDS password?**
Treat state as sensitive. Encrypt the S3 bucket (SSE), block public access, and
lock down IAM to it (this repo's bootstrap does all three). Mark outputs
`sensitive = true`. Prefer generating secrets with `random_password` and storing
them in Secrets Manager (as done here) so apps fetch at runtime rather than
reading Terraform outputs. For stronger guarantees, use a backend with encryption
+ short-lived access and audit logging, and never commit `*.tfstate`.

**Q3. `count` vs `for_each` — when do you use each?**
`count` gives index-addressed resources (`res[0]`, `res[1]`) — great for N
identical things like the 2 subnets/NAT gateways here. Its weakness: removing a
middle item reindexes everything and forces recreation. `for_each` keys resources
by a stable map/set key, so adding/removing one item doesn't disturb the others.
Use `for_each` when the collection changes over time or items have identity;
`count` for simple fixed replication.

**Q4. Walk me through the IRSA setup in the EKS module.**
An OIDC identity provider is associated with the cluster. The `pod_execution_role`
trust policy allows `sts:AssumeRoleWithWebIdentity` federated to that OIDC issuer,
with a `sub` condition pinned to `system:serviceaccount:default:memos`. So only
pods running under that specific service account can assume the role and get
scoped, temporary AWS credentials — no node-wide permissions and no static keys.
It's least privilege at the pod level.

**Q5. The Kubernetes provider is configured from EKS outputs created in the same
apply. What's the risk and how do you manage it?**
It's the provider-depends-on-resource problem. On first apply the cluster may not
exist when the provider initialises, and destroy ordering can break. Best practice
is to **split** cluster creation from in-cluster resources into separate
configs/state (or separate apply stages), or use `-target` for bootstrap. Keeping
raw K8s objects out of the same config that builds the cluster avoids fragile
runs.

**Q6. How does Terraform decide resource ordering? When do you need `depends_on`?**
It builds a DAG from **implicit references** — `module.vpc.vpc_id` used in the eks
module makes VPC a prerequisite automatically. You only add explicit `depends_on`
when there's a dependency Terraform can't see (e.g., an IAM policy that must exist
before an action, or side-effects), like the `depends_on` on the EKS cluster
waiting for its IAM policy attachments here.

**Q7. Explain the version pinning strategy in this repo.**
`required_version = ">= 1.15"` sets a Terraform floor; providers use `~> 5.0`
(pessimistic) meaning `>=5.0,<6.0` to allow patches/minors but block breaking
majors. The `.terraform.lock.hcl` pins exact versions + checksums so every teammate
and CI run resolves identical providers — reproducible and supply-chain safe.

**Q8. Why two NAT gateways and two private route tables?**
High availability. Each AZ gets its own NAT gateway and route table so egress in
AZ-A doesn't depend on AZ-B. A single shared NAT would be both a SPOF and a
cross-AZ data-charge path. The trade-off is cost (NAT gateways are billed
hourly + per-GB), so in dev you might collapse to one.

**Q9. How would you promote this from dev to prod safely?**
Separate state per environment (workspaces or, better, separate state keys/dirs),
parameterise via `*.tfvars`, flip `multi_az = true`, use larger `instance_class`,
raise `backup_retention_days`, keep `deletion_protection`, add DynamoDB state
locking, enforce `plan` review in CI with required approvals, and use immutable
tagged images. Never share one state between environments.

**Q10. What's `terraform import` for and when have you used it?**
It brings pre-existing, manually-created resources under Terraform management by
writing them into state (you still write matching HCL). Used when adopting
click-ops infrastructure or recovering after state loss. Modern Terraform also
supports `import` blocks for plan-time, reviewable imports.

**Q11. `-replace` (formerly taint) vs changing config — when do you force a
replace?**
When a resource is in a bad runtime state that config doesn't capture (corrupted
instance, drifted secret) you use `terraform apply -replace=<addr>` to recreate it
without editing code. Changing config is for *intended* desired-state changes.
Replace is a surgical, out-of-band recreate.

**Q12. How do you detect and handle drift?**
`terraform plan` (or `terraform plan -refresh-only`) compares real state to code
and shows drift from out-of-band changes. Handle it by either reverting the manual
change, updating code to match intent, or importing new resources. In mature
setups, scheduled CI drift-detection plans alert the team.

**Q13. How is least privilege implemented for the CI/CD role here?**
The `github_actions` role trusts GitHub's OIDC provider with conditions on `aud`
(`sts.amazonaws.com`) and `sub` (`repo:org/repo:*`), so only workflows from that
repo can assume it. Its inline policy grants only ECR push/read actions, and the
layer/image actions are scoped to the single repo ARN — not `*`. Only
`ecr:GetAuthorizationToken` is account-wide because the API requires it.

**Q14. Why put S3 bucket, ECR, and OIDC in a separate `bootstrap` config?**
Chicken-and-egg: the S3 backend must exist before the main config can store state
in it, so bootstrap runs with local state to create the bucket (plus ECR and the
CI OIDC role, which are also global prerequisites). Splitting lifecycle concerns
keeps the frequently-changing app infra separate from rarely-changing foundational
resources.

**Q15. What are the trade-offs of managing Helm releases through the Terraform
Helm provider (as wired here)?**
Pros: one tool/plan for infra + platform add-ons, single dependency graph. Cons:
Terraform state now tracks release state that Helm/K8s also mutate, causing drift
and noisy diffs; upgrades can be awkward; and it couples cluster lifecycle to
add-on lifecycle. Many teams prefer GitOps (Argo CD, as this repo also uses) for
in-cluster workloads and keep Terraform for cloud primitives.

---

### TL;DR for a learner
Terraform here builds the **cloud foundation**: network (VPC module) → Kubernetes
(EKS module) → database (RDS module), with a **bootstrap** for state/ECR/CI trust.
The recurring senior themes are **least privilege (IRSA, scoped OIDC), HA (multi-AZ),
secret hygiene (Secrets Manager + encrypted state), and reproducibility (version
pinning + remote state)**.
