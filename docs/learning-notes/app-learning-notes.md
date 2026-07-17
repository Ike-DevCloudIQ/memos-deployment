# App / Docker — Learner Notes (Containerization)

These notes teach **container fundamentals and every Docker concept in this repo**,
mapped to `app/Dockerfile` and `app/docker-compose.yaml`. This is where source code
becomes the immutable artifact that Kubernetes runs.

---

## 1. Why containers (the problem they solve)

"It works on my machine" happens because environments differ. A **container**
packages the app **with** its runtime, libraries, and OS userland into one
immutable image, so it runs identically on a laptop, in CI, and on EKS.

```
Source code + deps + runtime  ──build──►  Image (immutable, tagged)
                                              │ run
                                              ▼
                                          Container (a running instance)
```

- **Image** = the read-only template (layers).
- **Container** = a running instance of an image.
- Containers share the host kernel (unlike VMs) → lightweight, fast to start.

---

## 2. The multi-stage Dockerfile (`app/Dockerfile`)

This Dockerfile uses **three stages** to build a tiny, secure runtime image. This is
the single most important Docker technique to understand.

### Stage 1 — build the frontend
```dockerfile
FROM node:24-alpine AS web-builder
WORKDIR /frontend-build/web
RUN corepack enable && corepack prepare pnpm@11.0.1 --activate
COPY web/package.json web/pnpm-lock.yaml web/pnpm-workspace.yaml ./
RUN pnpm install --frozen-lockfile     # ← deps layer, cached
COPY web/ ./
RUN pnpm release                       # ← build static assets
```
- **`AS web-builder`** names the stage so later stages can copy from it.
- **Copy manifests first, then `install`, then copy source.** This is **layer-cache
  optimization**: dependencies only re-install when `package.json`/lockfile change,
  not on every source edit.
- **`--frozen-lockfile`** = reproducible installs (fails if lockfile is stale).
- **`corepack`** pins the exact pnpm version — deterministic tooling.

### Stage 2 — build the Go backend
```dockerfile
FROM golang:1.26.2-alpine AS backend-builder
WORKDIR /backend-build
COPY go.mod go.sum ./
RUN go mod download                    # ← cached dep layer
COPY . ./
COPY --from=web-builder /frontend-build/server/router/frontend/dist ./server/router/frontend/dist
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -tags netgo,osusergo -o memos ./cmd/memos
```
- **`COPY --from=web-builder`** pulls the built frontend into the backend build —
  stages compose.
- **`CGO_ENABLED=0`** → a **fully static binary** (no libc dependency), so it can
  run on a minimal base image.
- **`-ldflags="-s -w"`** strips debug info → smaller binary.
- **`-trimpath`** removes local filesystem paths → reproducible + no info leak.
- **`netgo,osusergo`** use pure-Go network/user resolution (no glibc needed).

### Stage 3 — the minimal runtime
```dockerfile
FROM alpine:3.21
RUN apk add --no-cache ca-certificates tzdata su-exec && \
    addgroup -g 10001 -S memos && \
    adduser  -u 10001 -S -G memos -h /var/opt/memos memos && \
    mkdir -p /var/opt/memos && chown -R memos:memos /var/opt/memos
WORKDIR /var/opt/memos
COPY --from=backend-builder /backend-build/memos /usr/local/bin/memos
USER memos                              # ← run as non-root
EXPOSE 5230
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost:5230/api/v1/ping || exit 1
CMD ["/usr/local/bin/memos"]
```
- **The final image contains only Alpine + the static binary** — none of Node, Go,
  npm, or source. This is the payoff of multi-stage: a **small attack surface** and
  fast pulls.
- **Non-root user (`USER memos`, uid 10001)** — matches the K8s `runAsNonRoot`
  hardening. Defense in depth.
- **`HEALTHCHECK`** lets Docker/K8s know if the app is actually serving (hits
  `/api/v1/ping`).
- **`CMD` (exec form)** — the process runs as PID 1 directly (proper signal
  handling for graceful shutdown).

**Why multi-stage matters (senior takeaway):** build tools are the biggest source
of image bloat and CVEs. Multi-stage keeps them out of the shipped artifact — you
get a small, reproducible, low-CVE image without a separate build server.

---

## 3. Local dev with Compose (`app/docker-compose.yaml`)

```yaml
services:
  postgres:
    image: postgres:15-alpine
    environment: { POSTGRES_USER: memos, POSTGRES_PASSWORD: memos_local_dev, POSTGRES_DB: memos }
    healthcheck: { test: ["CMD-SHELL", "pg_isready -U memos"], ... }

  memos:
    build:
      context: ../../memos-source
      dockerfile: ../memos-deployment/app/Dockerfile
    depends_on:
      postgres: { condition: service_healthy }
    environment:
      DSN: postgres://memos:memos_local_dev@postgres:5432/memos
    ports: [ "5230:8081" ]
    volumes: [ "memos_data:/var/opt/memos" ]
```
Concepts Compose teaches:
- **Local prod-parity**: mirrors the real topology (app + PostgreSQL) so you test
  the same wiring you deploy — the cloud version just swaps local Postgres for RDS.
- **`depends_on` + `condition: service_healthy`** — memos waits until Postgres
  passes its healthcheck, not merely until it starts. Avoids race-on-boot.
- **Service DNS**: memos reaches the DB at hostname `postgres` (Compose network
  DNS) — same pattern as K8s Service DNS.
- **`build.context`** points at the sibling `memos-source` checkout while reusing
  this repo's Dockerfile.
- **Named volume `memos_data`** persists across `docker compose up/down` (unlike
  the pod's ephemeral `emptyDir`).
- **Port mapping `5230:8081`** = host:container.

⚠️ Note `POSTGRES_PASSWORD: memos_local_dev` is a **local-only dev secret** — fine
for a laptop, never for production (prod uses RDS + Secrets Manager).

---

## 4. How this connects to the rest of the pipeline

```
app/Dockerfile ──built by──► GitHub Actions ──push──► ECR (SHA tag)
                                                        │
k8s/deployment.yaml image: ...:<SHA>  ◄── CI rewrites ──┘
                                                        │ Argo CD syncs
                                                        ▼
                                                   EKS runs the image
```
The Dockerfile is the **start** of the supply chain; the image SHA is the currency
that flows through ECR → manifest → Argo CD → cluster.

---

## 5. Image & container command cheat-sheet

```bash
docker build -f app/Dockerfile -t memos:dev ../../memos-source  # build
docker images                          # list images + sizes
docker history memos:dev               # inspect layers (find bloat)
docker run --rm -p 5230:5230 memos:dev # run locally
docker compose up --build              # bring up app + postgres
docker compose logs -f memos           # stream logs
docker scout cves memos:dev            # scan for vulnerabilities
docker exec -it <container> sh         # shell into a running container
docker compose down -v                 # stop + remove named volumes
```

---

## 6. Docker Q&A (15)

**Q1. What is a multi-stage build and what problems does it solve?**
It's a Dockerfile with multiple `FROM` stages where later stages copy only needed
artifacts from earlier ones. It solves image bloat and security exposure: heavy
build tooling (Node, Go compiler) stays in build stages, and the final image ships
only the static binary on a minimal base. Result: smaller images, faster pulls,
fewer CVEs, no separate build infrastructure.

**Q2. Explain Docker layer caching and how this Dockerfile exploits it.**
Each instruction creates a cached layer keyed by its inputs; a change invalidates it
and everything after. This file copies dependency manifests and runs
`install`/`go mod download` *before* copying source, so dependency layers stay
cached across source-only changes — dramatically faster rebuilds. Reordering (source
first) would bust the cache on every edit.

**Q3. Why `CGO_ENABLED=0` and a static binary here?**
It compiles Go without linking against C libraries (glibc), producing a fully static
binary. That means the runtime image needs no libc, so it can run on a tiny Alpine
(or even scratch/distroless) base, shrinking size and attack surface and avoiding
glibc/musl mismatch issues. The `netgo,osusergo` tags do the same for DNS/user
lookups.

**Q4. Why run the container as a non-root user, and how does it relate to K8s?**
Running as root inside a container means a container escape or app RCE starts with
root on that namespace — a bigger blast radius. `USER memos` (uid 10001) drops that.
It pairs with the pod's `runAsNonRoot: true` in `k8s/deployment.yaml`: the image
supports non-root and the cluster enforces it — defense in depth, aligned with
restricted Pod Security Standards.

**Q5. What's the difference between a Docker HEALTHCHECK and a Kubernetes probe?**
Both check liveness, but the HEALTHCHECK is baked into the image for Docker/Compose
runtimes, while K8s ignores the image HEALTHCHECK and uses its own liveness/
readiness/startup probes for finer control (traffic gating, restart policy, startup
grace). Having both means the image self-describes health locally and K8s controls
orchestration in the cluster.

**Q6. `CMD` vs `ENTRYPOINT`, and exec vs shell form — why does it matter?**
ENTRYPOINT sets the fixed executable; CMD sets default args (or the command if no
ENTRYPOINT). Exec form (`["bin","arg"]`) runs the binary directly as PID 1 so it
receives SIGTERM for graceful shutdown; shell form (`bin arg`) wraps it in
`/bin/sh -c`, making the shell PID 1 and often swallowing signals. This file uses
exec form for clean termination.

**Q7. How would you make this image even smaller/more secure?**
Switch the final stage to `scratch` or a distroless base (the static binary needs
no shell/package manager), drop `su-exec`/shell to remove exec-into-container
attack paths, add SBOM generation and image signing (cosign), scan in CI (Trivy/
Docker Scout), and pin the base by digest. ECR here already enforces `scan_on_push`
and immutable tags.

**Q8. Why tag images with a git SHA instead of `latest`?**
Immutable, unique tags make deployments deterministic and auditable — you know
exactly which commit runs, rollback is a tag change, and the kubelet won't silently
pull a changed `latest`. ECR is configured `IMMUTABLE` so a tag can never be
overwritten, guaranteeing artifact integrity across the pipeline.

**Q9. Explain `depends_on` with `condition: service_healthy` in Compose.**
Plain `depends_on` only waits for the container to *start*, not to be *ready*. With
`condition: service_healthy` the memos service waits until Postgres passes its
`pg_isready` healthcheck, preventing the app from starting before the DB accepts
connections — eliminating a classic boot race. K8s solves the same problem with
readiness probes + retries.

**Q10. What are the security implications of the local Compose password, and how
does prod differ?**
`memos_local_dev` is a hardcoded convenience secret acceptable only on a developer
laptop with a throwaway DB. In prod the password is generated by Terraform
(`random_password`), stored in AWS Secrets Manager, and injected via K8s Secret/
External Secrets — never committed. Never promote Compose creds; environment parity
should not extend to secrets.

**Q11. How does layer caching interact with CI, and how do you speed CI builds?**
CI often starts cold, losing local cache. You restore it with a remote cache backend
(e.g., Buildx `--cache-to/--cache-from` gha or a registry cache), which this project
enables via the `docker-container` Buildx driver. Combined with dependency-first
ordering, CI reuses unchanged layers and only rebuilds what changed.

**Q12. What does `docker history` / image layer inspection tell you, and why care?**
It shows each layer's size and originating instruction, exposing bloat (a forgotten
build tool, a large COPY, a cache dir left in a layer) and accidental secret leakage
(a secret added then "removed" still lives in an earlier layer). Reviewing it is how
you keep images lean and confirm nothing sensitive is baked in.

**Q13. Why copy `go.mod`/`go.sum` and run `go mod download` before copying the rest?**
So the module-download layer is cached independently of source changes. Application
code changes far more often than dependencies; isolating dependency resolution means
day-to-day edits skip the (slow) download step entirely. Same principle as
copying `package.json` before the frontend source.

**Q14. A container exits immediately on start. How do you debug it?**
Check `docker logs <id>` for the crash reason, run it interactively
(`docker run -it --entrypoint sh image`) to inspect the filesystem/env, verify the
`CMD`/binary path and file permissions, confirm required env (like `DSN`) is set,
and ensure the process stays in the foreground (a backgrounded process makes PID 1
exit). For Compose, confirm dependencies are healthy.

**Q15. How do you achieve reproducible builds, and where does this Dockerfile do
that?**
Pin everything and remove nondeterminism: pinned base image tags (`node:24-alpine`,
`golang:1.26.2-alpine`, `alpine:3.21`), pinned tool versions via corepack/pnpm,
`--frozen-lockfile` and `go mod download` against committed lockfiles, and
`-trimpath` to strip machine-specific paths. For full reproducibility you'd also pin
base images by digest and record an SBOM.

---

### TL;DR for a learner
`app/Dockerfile` is a **three-stage build** that turns Node + Go source into a
**tiny, non-root, static-binary Alpine image** — small, reproducible, low-CVE.
`docker-compose.yaml` gives **prod-parity local dev** (app + Postgres with health-
gated startup). The senior themes are **multi-stage builds, layer-cache ordering,
static binaries, non-root/minimal runtime, and immutable SHA-tagged artifacts** that
feed the ECR → Argo CD → EKS pipeline.
