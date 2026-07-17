# CI/CD — Learner Notes (GitHub Actions Pipeline)

These notes teach **continuous integration/delivery and every part of the workflow
in this repo**, mapped to `.github/workflows/deploy.yaml`. This pipeline is the
bridge between a code push and the GitOps deploy that Argo CD finishes.

---

## 1. What CI/CD is and where the line sits here

- **CI (Continuous Integration)**: on every change, automatically build and validate
  the artifact (here: build + push the Docker image).
- **CD (Continuous Delivery/Deployment)**: get that artifact to the environment.
  This repo uses a **GitOps hand-off**: the pipeline doesn't deploy directly — it
  **updates a manifest in Git**, and **Argo CD** performs the actual cluster deploy.

```
git push (app/**)
   │
   ▼
GitHub Actions
   ├─ Job 1 build:  Docker build ─► push image to ECR (tag = short SHA)
   └─ Job 2 update: rewrite k8s/deployment.yaml image tag ─► commit to Git
                                                              │
                                                     Argo CD detects commit
                                                              ▼
                                                        deploy to EKS
```

The key architectural idea: **CI pushes to a registry + Git, never to the cluster.**
That's what makes it a *pull-based* GitOps pipeline.

---

## 2. Triggers & permissions (top of `deploy.yaml`)

```yaml
on:
  push:
    branches: [main]
    paths:
      - 'app/**'          # only build when app code changes
  workflow_dispatch:      # manual "Run workflow" button

permissions:
  id-token: write         # REQUIRED for OIDC federation to AWS
  contents: write         # REQUIRED to push the manifest commit
```
Teaching points:
- **Path filter (`paths: app/**`)** — avoids rebuilding when only docs/manifests
  change. Efficient CI.
- **`workflow_dispatch`** — lets you trigger manually from the UI (useful for
  re-runs).
- **`permissions` (least privilege for `GITHUB_TOKEN`)** — grants only what's
  needed:
  - `id-token: write` mints the **OIDC token** used to assume the AWS role.
  - `contents: write` lets Job 2 commit the manifest change.
  Everything else defaults to no access — a security best practice.

```yaml
env:
  AWS_REGION: eu-west-1
  ECR_REPOSITORY: memos
```
Global env vars keep region/repo DRY across steps.

---

## 3. Job 1 — build & push (the CI half)

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      image-tag: ${{ steps.meta.outputs.tag }}   # exported to Job 2
    steps:
      - uses: actions/checkout@v4
        with: { submodules: recursive }          # pull vendored Memos source

      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}   # OIDC, no static keys
          aws-region: ${{ env.AWS_REGION }}

      - id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2

      - id: buildx
        uses: docker/setup-buildx-action@v3
        with: { driver: docker-container }        # enables build cache backend

      - id: meta
        run: |
          SHORT_SHA=$(echo "${{ github.sha }}" | cut -c1-7)
          echo "tag=$SHORT_SHA" >> $GITHUB_OUTPUT # commit SHA = image tag

      - uses: docker/build-push-action@v5
        with:
          builder: ${{ steps.buildx.outputs.name }}
          context: src/memos                      # vendored source
          file: app/Dockerfile
          push: true
          tags: |
            ${{ steps.login-ecr.outputs.registry }}/${{ env.ECR_REPOSITORY }}:${{ steps.meta.outputs.tag }}
            ${{ steps.login-ecr.outputs.registry }}/${{ env.ECR_REPOSITORY }}:latest
```

The senior-relevant concepts here:

### (a) OIDC keyless auth — the security highlight
`configure-aws-credentials` uses **`id-token: write`** to get a short-lived OIDC
token from GitHub, which AWS trusts (the trust + role were created in
`terraform/bootstrap`). The role's trust policy pins `sub` to
`repo:Ike-DevCloudIQ/memos-deployment:*`, so **only this repo** can assume it.
**No long-lived `AWS_ACCESS_KEY_ID` secret exists** — nothing to leak or rotate.

### (b) Job outputs pass data between jobs
`outputs.image-tag` publishes the computed SHA so Job 2 (a *separate* runner) can
reuse it. Jobs are isolated; `outputs` is the contract between them.

### (c) Buildx `docker-container` driver
The default driver can't use the advanced cache backends; `docker-container` enables
layer caching across CI runs (pairs with the Dockerfile's cache-friendly ordering).

### (d) Immutable SHA tags
Tagging with `github.sha[0:7]` gives **traceability** (image ↔ commit) and works
with ECR's `IMMUTABLE` setting. `latest` is also pushed as a convenience pointer.

---

## 4. Job 2 — update manifests (the GitOps hand-off)

```yaml
  update-manifests:
    runs-on: ubuntu-latest
    needs: build                    # gate: only after build succeeds
    steps:
      - uses: actions/checkout@v4
        with: { token: ${{ secrets.GITHUB_TOKEN }} }

      - name: Update image tag
        env:
          IMAGE_TAG: ${{ needs.build.outputs.image-tag }}
          ECR_REGISTRY: ${{ secrets.AWS_ACCOUNT_ID }}.dkr.ecr.${{ env.AWS_REGION }}.amazonaws.com
        run: |
          NEW_IMAGE="$ECR_REGISTRY/${{ env.ECR_REPOSITORY }}:$IMAGE_TAG"
          sed -i "s|image: .*memos:.*|image: $NEW_IMAGE|" k8s/deployment.yaml

      - name: Commit and push
        run: |
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git config user.name  "github-actions[bot]"
          git add k8s/deployment.yaml
          if git diff --staged --quiet; then
            echo "No changes"
          else
            git commit -m "chore: update memos image to $IMAGE_TAG [skip ci]"
            git push origin main
          fi
```

Teaching points:
- **`needs: build`** — sequential dependency; Job 2 runs only if Job 1 passed and
  reads its output tag.
- **`sed` rewrites the image line** in `k8s/deployment.yaml` — the exact line the
  Kubernetes + Argo notes describe. This commit is the trigger Argo CD watches.
- **`[skip ci]`** in the commit message — prevents the bot's own commit from
  re-triggering the workflow → no infinite loop.
- **Idempotent commit** — `git diff --staged --quiet` avoids empty commits when the
  tag is unchanged.
- **Bot identity** — commits are attributed to `github-actions[bot]` for a clean
  audit trail.

This is the crucial **"CI writes desired state, CD (Argo) reconciles it"** boundary.

---

## 5. The end-to-end supply chain

```
Developer ──push app/**──► GitHub Actions
   Job 1: checkout(+submodule) → OIDC assume role → ECR login →
          buildx build app/Dockerfile (context src/memos) → push :SHA + :latest
   Job 2: rewrite k8s/deployment.yaml image:SHA → commit [skip ci] → push main
                                   │
                          Argo CD (memos app, path k8s/) detects commit
                                   ▼
                          Rolling update on EKS (zero downtime)
```
Every arrow is auditable: a commit, an immutable image, a manifest change, a sync.

---

## 6. Secrets & variables this workflow relies on

| Name | Type | Purpose |
|---|---|---|
| `AWS_ROLE_ARN` | secret | The IAM role Actions assumes via OIDC (from bootstrap) |
| `AWS_ACCOUNT_ID` | secret | Builds the ECR registry URL |
| `GITHUB_TOKEN` | auto | Built-in token; scoped by `permissions:` block |

Note there are **no AWS access keys** — the whole point of OIDC.

---

## 7. GitHub Actions Q&A (15)

**Q1. Explain OIDC-based auth to AWS and why it beats storing access keys.**
GitHub mints a short-lived, signed OIDC token describing the workflow; AWS trusts
GitHub's OIDC provider and exchanges it for temporary STS credentials via
`AssumeRoleWithWebIdentity`. There are no long-lived keys to store, leak, or rotate,
and the role's trust policy scopes access to a specific repo (and can scope to
branch/environment), so a stolen token is far less useful than static keys.

**Q2. This pipeline never runs `kubectl`. Why is that a deliberate design?**
It's pull-based GitOps: CI's job is to produce an artifact (image) and update desired
state in Git; Argo CD running in-cluster does the deploy. This keeps cluster
credentials out of CI (smaller attack surface), centralises change control in Git
review, gives automatic drift correction, and decouples build reliability from
deploy reliability.

**Q3. Why tag images with the commit SHA, and how does it interact with ECR
settings?**
The SHA uniquely and immutably ties an image to the exact source commit, enabling
deterministic deploys, precise rollbacks, and traceability. ECR is configured
`IMMUTABLE`, so a given SHA tag can never be overwritten — guaranteeing the artifact
that passed CI is the one that runs. `latest` is a mutable convenience pointer, not
used for deploys.

**Q4. What prevents the manifest-update commit from triggering an infinite build
loop?**
Two guards: the `paths: app/**` filter means a `k8s/` change wouldn't trigger the
build anyway, and the bot commit includes `[skip ci]`, which GitHub honours to skip
workflow runs. Together they ensure the automated manifest commit can't recursively
retrigger the pipeline.

**Q5. How do the two jobs share data, and why not do it all in one job?**
`build` declares `outputs.image-tag`, and `update-manifests` reads it via
`needs.build.outputs.image-tag`. Splitting jobs isolates concerns (build vs Git
write), lets them use different permissions/checkouts, and makes the pipeline
readable and independently retryable. Jobs run on separate runners, so `outputs` is
the explicit contract between them.

**Q6. Walk through the least-privilege choices in this workflow.**
Top-level `permissions` grants only `id-token: write` (OIDC) and `contents: write`
(commit) — everything else is none. The AWS role's inline policy (from bootstrap)
allows only ECR push/read scoped to the single repo ARN. The OIDC trust pins `aud`
and `sub` to this repo. Path filters limit when it runs. Each layer grants the
minimum needed.

**Q7. Why the `docker-container` Buildx driver instead of the default?**
The default `docker` driver can't export/import to the advanced cache backends
(gha/registry) or do multi-platform builds. `docker-container` runs BuildKit in a
container, enabling cross-run layer caching (big CI speedup) and richer build
features. It pairs with the Dockerfile's dependency-first layer ordering.

**Q8. How would you add testing/quality gates before the image is built or pushed?**
Insert a `test` job that runs unit/integration tests and linting, and make `build`
`needs: test`. Add image scanning (Trivy/Docker Scout) after build and fail on high
CVEs, plus SBOM generation and image signing (cosign). For manifests, add
`kubeconform`/`kubectl --dry-run` validation before the commit. Gate merges with
required status checks.

**Q9. The workflow uses `AWS_REGION: eu-west-1` but the cluster is in us-west-1.
Why can that be fine, and when is it a problem?**
ECR is regional; the build only needs to push to the ECR repo, which can live in
`eu-west-1` as long as the role and repo are there and EKS nodes can pull
cross-region. It becomes a problem if the ECR repo isn't in that region (auth/URL
mismatch) or if cross-region pulls add latency/egress cost — you'd normally colocate
ECR with the cluster region.

**Q10. How do you secure the `GITHUB_TOKEN` that pushes to main?**
Scope it via the `permissions` block to `contents: write` only; never grant broad
scopes. Protect `main` with branch protection and restrict who/what can push, or
route changes through a PR with a bot. Prefer a dedicated deploy key or fine-grained
token if pushing to a different repo. Keep the token out of logs (Actions masks
secrets automatically).

**Q11. What are supply-chain risks in this pipeline and how do you harden them?**
Risks: compromised third-party actions, a poisoned base image, tampered artifacts.
Hardening: pin actions to commit SHAs (not just tags), pin base images by digest,
enable ECR `scan_on_push` (done) plus in-pipeline scanning, generate an SBOM, sign
images (cosign) and verify signatures at admission, and use OIDC (done) to avoid
static creds. Enforce least-privilege `permissions` (done).

**Q12. Why check `git diff --staged --quiet` before committing?**
To keep the pipeline idempotent — if the computed image line already matches (e.g., a
re-run on the same SHA), there's nothing to commit, and forcing an empty commit would
add noise and could re-trigger downstream tooling. It's a guard for clean,
meaningful Git history.

**Q13. How would you promote a build through dev → staging → prod with this design?**
Keep CI producing one immutable image per commit, then promote by *updating Git
references*, not rebuilding: separate Argo apps/paths (or overlays) per environment,
and promote by bumping the image tag in the next environment's manifest (via PR or a
promotion workflow with environment protection rules/approvals). The same artifact
flows forward — build once, deploy many.

**Q14. A build succeeds but Argo never deploys the new image. How do you triage?**
Confirm Job 2 actually committed (check for the `[skip ci]` commit and the changed
`image:` line), verify Argo's `memos` app is `Synced`/auto-sync enabled and pointing
at `path: k8s`/`HEAD`, check Argo detected the commit (poll interval or webhook), and
ensure the pushed tag exists in ECR and nodes can pull it (IRSA/ECR read). Sync
status vs health in Argo narrows it quickly.

**Q15. What are the trade-offs of the "CI commits to the same repo" GitOps style vs
a separate config repo?**
Same-repo (this setup) is simple and keeps app + manifests together, but mixes app
history with deploy commits and can complicate branch protection. A separate config
repo cleanly isolates desired-state, lets you apply different review/access controls
to deploys, and avoids CI writing back to the app repo — at the cost of more moving
parts and cross-repo coordination. Larger orgs usually prefer the split.

---

### TL;DR for a learner
`.github/workflows/deploy.yaml` is a **two-job, pull-based GitOps pipeline**: Job 1
builds and pushes an **immutable SHA-tagged image to ECR using keyless OIDC auth**;
Job 2 **rewrites the manifest image tag and commits it**, which **Argo CD** then
deploys. The senior themes are **OIDC over static keys, least-privilege permissions,
immutable artifacts, CI-never-touches-the-cluster, and loop-safe automation
(`[skip ci]`, path filters, idempotent commits)**.
