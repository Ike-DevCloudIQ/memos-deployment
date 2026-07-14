# Stage 1: The Application - Complete Guide

## 📖 Overview

In Stage 1, you'll learn how to **understand, containerize, and run the Memos application locally**.

This stage teaches you:
- **Docker fundamentals**: Images, containers, building, running
- **Application architecture**: What is Memos, how does it work
- **Development workflow**: Local testing before cloud deployment
- **Best practices**: Security, multi-stage builds, health checks

---

## 🎯 Part 1: Understanding the Memos Application

### What is Memos?

Memos is an **open-source, self-hosted note-taking application** similar to Notion or Evernote.

**Key Components**:
- **Backend**: Go-based REST API server
- **Frontend**: React-based web UI
- **Database**: PostgreSQL for persistence
- **Storage**: Local filesystem or cloud storage for attachments

**Architecture**:
```
┌─────────────────────────────────────────┐
│         User Browser                    │
│      (Memos Web UI - React)             │
└──────────────┬──────────────────────────┘
               │ HTTP/REST
┌──────────────▼──────────────────────────┐
│      Memos API Server (Go)              │
│  - Authentication                       │
│  - Memo CRUD operations                 │
│  - Resource management                  │
└──────────────┬──────────────────────────┘
               │ SQL
┌──────────────▼──────────────────────────┐
│        PostgreSQL Database              │
│  - User accounts                        │
│  - Memos/notes                          │
│  - Relationships                        │
└─────────────────────────────────────────┘
```

### Why Containerize Memos?

**Problem**: 
- Installing Go, Node.js, PostgreSQL on each machine is tedious
- Different machines have different environments ("works on my machine" problem)
- Deployment consistency is hard

**Solution (Docker)**:
- Package app + all dependencies into a **container**
- Same container runs everywhere: your laptop, staging, production
- Reproducible, portable, scalable

---

## 🐳 Part 2: Docker Fundamentals (5-minute primer)

### Key Concepts

**Image**: Blueprint for a container (like a class in OOP)
```
Think of it as: "Here's how to build the app"
```

**Container**: Running instance of an image (like an object)
```
Think of it as: "The app is running right now"
```

**Dockerfile**: Recipe that defines how to build an image
```dockerfile
FROM golang:1.21              # Start from Go image
COPY . /app                   # Copy source code
WORKDIR /app                  # Set working directory
RUN go build -o memos .      # Build the binary
CMD ["./memos"]               # Run the binary
```

**Registry**: Store for images (like GitHub for Docker)
```
- Docker Hub (public, free)
- AWS ECR (Elastic Container Registry - what we'll use)
- GitHub Container Registry (ghcr.io)
```

### Docker Workflow

```
1. Write Dockerfile     → defines how to build
2. Build image          → docker build → creates .tar-like file
3. Run container        → docker run → starts the app
4. Push to registry     → docker push → share with others
5. Deploy anywhere      → docker run → same app everywhere
```

---

## 📝 Part 3: Task 1.1 - Understand Memos Source

### Objective
Understand the Memos codebase structure and dependencies.

### Steps

#### Step 1: Clone the official Memos repository

```bash
cd /Users/emekaezedozie/Desktop/Nouriva
git clone https://github.com/usememos/memos.git memos-app
cd memos-app
```

#### Step 2: Explore the structure

```bash
# See the main directories
ls -la

# Go backend
ls -la cmd/                    # Entry points
ls -la internal/               # Core logic
ls -la store/                  # Database layer

# Frontend
ls -la web/                    # React app

# Configuration
cat go.mod | head -20          # Go dependencies
cat package.json | head -20    # Node.js dependencies
```

#### Step 3: Read key documentation

```bash
cat README.md                  # Project overview
cat docs/ARCHITECTURE.md       # (if exists)
```

#### Step 4: Document what you learned

Create a file: `docs/STAGE1_APP.md`

```markdown
# Stage 1: Application Understanding

## Memos Overview
- **Type**: Self-hosted note-taking app
- **Language**: Go (backend), React (frontend)
- **Database**: PostgreSQL
- **License**: Open source

## Architecture
[Describe what you learned]

## Key Components
1. Backend (Go)
   - Location: cmd/memos/, internal/
   - Port: 5230
   - Key dependencies: PostgreSQL, ...

2. Frontend (React)
   - Location: web/
   - Port: 3000
   - Built with: Vite, React, ...

3. Database
   - PostgreSQL 13+
   - Port: 5432
   - Stores: Users, memos, attachments, ...

## System Requirements
- Go 1.21+
- Node.js 18+
- PostgreSQL 13+
- Docker (for containerization)
```

---

## 🐳 Part 4: Task 1.2 - Create Production Dockerfile

### Why Multi-Stage Builds?

**Problem**: A Dockerfile that builds + runs everything is huge (~1GB)
```
- Go compiler (big)
- Node.js toolchain (big)
- build artifacts
```

**Solution**: Multi-stage build
```
Stage 1 (builder)  → compile code        → keep compiler output
Stage 2 (final)    → copy only binary    → discard compiler
Result: Final image ~50-100MB instead of 1GB+
```

### Creating the Dockerfile

Create: `app/Dockerfile`

```dockerfile
# Stage 1: Frontend build
FROM node:18-alpine AS web-builder
WORKDIR /app
COPY web/package*.json ./web/
RUN cd web && npm ci --legacy-peer-deps

COPY web .
RUN npm run build

# Stage 2: Backend build
FROM golang:1.21-alpine AS backend-builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o memos ./cmd/memos

# Stage 3: Runtime (minimal)
FROM alpine:3.18
RUN apk add --no-cache ca-certificates tzdata
RUN addgroup -g 1000 memos && adduser -D -u 1000 -G memos memos

WORKDIR /app
COPY --from=backend-builder /app/memos ./
COPY --from=web-builder /app/dist ./dist

USER memos
EXPOSE 5230
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost:5230/api/v1/ping || exit 1

CMD ["./memos"]
```

### Understanding the Dockerfile

```dockerfile
# FROM image:version    ← Start with a base image
# WORKDIR path          ← Set working directory (like "cd")
# COPY src dst          ← Copy files from host → container
# RUN command           ← Execute command during build
# USER name             ← Switch to non-root user (security!)
# EXPOSE port           ← Document which ports the app uses
# HEALTHCHECK ...       ← Define how to check if app is healthy
# CMD command           ← Default command when container starts
```

### Key Best Practices Applied

✅ **Multi-stage build**: Only runtime dependencies in final image
✅ **Non-root user**: Run as `memos` user (not `root`)
✅ **Alpine Linux**: Minimal base image (~5MB vs ~100MB)
✅ **Healthcheck**: Kubernetes will use this to determine if app is healthy
✅ **Layer caching**: Go modules layer separate from source (faster rebuilds)

---

## 🐳 Part 5: Task 1.3 - Create docker-compose.yaml

Docker-compose is a tool to run **multiple containers together** locally.

Create: `app/docker-compose.yaml`

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    container_name: memos-db
    environment:
      POSTGRES_USER: memos
      POSTGRES_PASSWORD: memos_local_dev  # ⚠️ Not for production!
      POSTGRES_DB: memos
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U memos"]
      interval: 10s
      timeout: 5s
      retries: 5

  memos:
    build:
      context: ..                    # Build from parent directory
      dockerfile: app/Dockerfile
    container_name: memos-app
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      DSN: postgres://memos:memos_local_dev@postgres:5432/memos
    ports:
      - "5230:5230"
    volumes:
      - memos_data:/app/data
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:5230/api/v1/ping"]
      interval: 30s
      timeout: 5s
      retries: 3

volumes:
  postgres_data:
  memos_data:
```

### What Each Section Does

```yaml
services:               ← Containers to run
  postgres:             ← Database container
  memos:                ← App container

environment:            ← Pass variables to container
ports:                  ← "host:container" port mapping
volumes:                ← Persistent storage (survives container restart)
depends_on:             ← Start order dependency
healthcheck:            ← How Docker checks if service is healthy
```

---

## ▶️ Part 6: Task 1.4 - Run Locally & Test

### Step 1: Build and run

```bash
cd /Users/emekaezedozie/Desktop/Nouriva/memos-deployment

# Build the Docker image
docker-compose -f app/docker-compose.yaml build

# Start containers in background
docker-compose -f app/docker-compose.yaml up -d

# Check status
docker-compose -f app/docker-compose.yaml ps
```

### Step 2: Verify it's working

```bash
# Check logs
docker-compose -f app/docker-compose.yaml logs -f memos

# Test API
curl http://localhost:5230/api/v1/ping

# Expected response: {"data":"OK"}
```

### Step 3: Access the web UI

Open browser: `http://localhost:5230`

You should see the Memos login page!

### Step 4: Test functionality

1. Create an account (register)
2. Create a note
3. Verify it persists (refresh page)
4. Test attachments if applicable

### Step 5: Stop containers

```bash
docker-compose -f app/docker-compose.yaml down

# Keep data:
docker-compose -f app/docker-compose.yaml down -v  # removes volumes
```

---

## 📋 Part 7: Task 1.5 - Documentation

Create: `README.md` (update existing)

```markdown
# Memos Deployment Project

DevOps learning project: Deploy Memos app to AWS EKS with production-grade practices.

## Quick Start (Local Development)

### Prerequisites
- Docker Desktop installed
- 4GB RAM available

### Run locally
```bash
docker-compose -f app/docker-compose.yaml up -d
```

Access: http://localhost:5230

### Stop
```bash
docker-compose -f app/docker-compose.yaml down
```

## Project Structure
- `docs/` - Learning guides and architecture
- `app/` - Application (Dockerfile, docker-compose)
- `terraform/` - Infrastructure code (Stage 2)
- `k8s/` - Kubernetes manifests (Stage 3)
- `argocd/` - GitOps configuration (Stage 4)
- `.github/workflows/` - CI/CD pipelines (Stage 5)

## Stages
1. ✅ The App (current)
2. ⏳ Terraform modules
3. ⏳ Kubernetes deployment
4. ⏳ ArgoCD GitOps
5. ⏳ GitHub Actions CI/CD
6. ⏳ Monitoring & Observability

See [LEARNING_GUIDE.md](LEARNING_GUIDE.md) for detailed learning path.
```

---

## ✅ Stage 1 Completion Checklist

- [ ] Cloned Memos source code
- [ ] Understood application architecture
- [ ] Created `app/Dockerfile` with multi-stage build
- [ ] Created `app/docker-compose.yaml`
- [ ] Built Docker image successfully
- [ ] Started containers with `docker-compose up -d`
- [ ] Verified app running at http://localhost:5230
- [ ] Tested basic functionality (create note, verify persistence)
- [ ] Documented findings in `docs/STAGE1_APP.md`
- [ ] Updated `README.md`
- [ ] Committed all files to git

---

## 🚀 Next: Proceed to Implementation

Once you complete all tasks above, confirm:
- ✅ App runs on localhost:5230
- ✅ Database persists data
- ✅ All files committed to git

Then we move to **Stage 2: Terraform Infrastructure** 🎓
