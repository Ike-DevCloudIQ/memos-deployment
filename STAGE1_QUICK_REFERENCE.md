# Stage 1: Quick Reference Card

> **Print this or keep it open!** Commands in the exact order to run them.

---

## Part 1: Understand Memos (30 min)

```bash
# Step 1: Navigate to project
cd ~/Desktop/Nouriva/memos-deployment

# Step 2: Clone Memos source
cd ~/Desktop/Nouriva
git clone https://github.com/usememos/memos.git memos-source

# Step 3: Explore the app
cd ~/Desktop/Nouriva/memos-source
ls -la                    # See directory structure
ls -la cmd/               # Backend entry point
ls -la web/               # Frontend code
cat go.mod | head -5      # Check Go version (should be 1.21+)
cat web/package.json      # Check Node dependencies
```

**✅ Completion:** You understand Memos is Go backend + React frontend + PostgreSQL

---

## Part 2: Create Dockerfile (1 hour)

```bash
# Step 1: Go back to project
cd ~/Desktop/Nouriva/memos-deployment

# Step 2: Create app folder
mkdir -p app

# Step 3: Copy-paste this entire block to create Dockerfile:
cat > app/Dockerfile << 'EOF'
# Stage 1: Build the frontend (React)
FROM node:18-alpine AS web-builder
WORKDIR /app
COPY web/package*.json ./web/
RUN cd web && npm ci --legacy-peer-deps

COPY web .
RUN npm run build

# Stage 2: Build the backend (Go)
FROM golang:1.21-alpine AS backend-builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o memos ./cmd/memos

# Stage 3: Runtime (minimal Alpine Linux)
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
EOF
```

**Step 4: Verify**
```bash
ls -la app/Dockerfile
```

**✅ Completion:** `app/Dockerfile` exists with 3 stages

---

## Part 3: Create docker-compose.yaml (30 min)

```bash
# Copy-paste this entire block to create docker-compose.yaml:
cat > app/docker-compose.yaml << 'EOF'
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    container_name: memos-db
    environment:
      POSTGRES_USER: memos
      POSTGRES_PASSWORD: memos_local_dev
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
      context: ..
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
EOF
```

**Verify**
```bash
ls -la app/docker-compose.yaml
```

**✅ Completion:** Both `app/Dockerfile` and `app/docker-compose.yaml` exist

---

## Part 4: Build & Run Locally (1 hour)

```bash
# Make sure you're in the project directory
cd ~/Desktop/Nouriva/memos-deployment

# Step 1: Build the Docker image (5-10 minutes)
docker-compose -f app/docker-compose.yaml build

# Step 2: Start containers in background
docker-compose -f app/docker-compose.yaml up -d

# Step 3: Wait 30 seconds, then check status
sleep 30
docker-compose -f app/docker-compose.yaml ps

# Expected output:
# NAME             COMMAND                  SERVICE     STATUS
# memos-db         "docker-entrypoint..."   postgres    Up 30 seconds (healthy)
# memos-app        "./memos"                memos       Up 25 seconds (healthy)

# Step 4: Check logs (press Ctrl+C to exit)
docker-compose -f app/docker-compose.yaml logs -f memos
```

**✅ Completion:** 
- Both containers are running and healthy
- Logs show "memos server is running at http://127.0.0.1:5230"

---

## Part 5: Test & Verify (30 min)

```bash
# Step 1: Test API endpoint
curl http://localhost:5230/api/v1/ping

# Expected: {"data":"OK"}

# Step 2: Open in browser
open http://localhost:5230

# Step 3: In browser, create account
# - Email: test@example.com
# - Password: Test@123!
# - Click Sign Up

# Step 4: Create a test note
# - Click "New Memo"
# - Type: "This is my first note in Docker!"
# - Click Save

# Step 5: Refresh browser (Cmd+R)
# Expected: Note is still there!

# Step 6: Stop containers (test if data persists)
docker-compose -f app/docker-compose.yaml down

# Step 7: Wait 5 seconds, then start again
sleep 5
docker-compose -f app/docker-compose.yaml up -d

# Step 8: Wait 30 seconds for startup
sleep 30

# Step 9: Open browser again
open http://localhost:5230

# Step 10: Log in with same credentials
# Expected: Your note is still there! ✅

# Step 11: Check image size
docker image ls | grep memos
# Expected: Size should be ~200-300MB
```

**✅ Completion:** 
- App loads at localhost:5230
- Can create and save notes
- Notes persist after refresh
- Notes persist after container restart
- Image size is reasonable

---

## Part 6: Document Your Learning (1 hour)

```bash
# Make sure you're in project directory
cd ~/Desktop/Nouriva/memos-deployment

# Create your learning document (with your observations)
cat > docs/STAGE1_LEARNINGS.md << 'EOF'
# Stage 1: Application - What I Learned

## Docker Concepts Understood

### What is Docker?
[Write your understanding here]

### Image vs Container
[Write your understanding here]

### Multi-Stage Build
[Write why we used 3 stages and what each does]

### Persistence with Volumes
[Write how volumes keep data after container restarts]

## Application Architecture

### Memos Components
- Backend: [What you learned about Go backend]
- Frontend: [What you learned about React frontend]
- Database: [What you learned about PostgreSQL]

## Best Practices Applied
[List which best practices we applied and why]

## Challenges I Encountered
[Write any issues you hit and how you solved them]

## Key Takeaways
[Write 3-5 main learnings from Stage 1]
EOF
```

**✅ Completion:** `docs/STAGE1_LEARNINGS.md` exists with your notes

---

## Part 7: Commit to Git (15 min)

```bash
# Make sure you're in project directory
cd ~/Desktop/Nouriva/memos-deployment

# Step 1: Check what changed
git status

# Step 2: Stage all files
git add .

# Step 3: Commit with message
git commit -m "Stage 1 Complete: Containerize Memos with Docker

- Create multi-stage Dockerfile (Node.js → React, Go → binary, Alpine runtime)
- Create docker-compose.yaml with PostgreSQL and Memos services
- Build Docker image (~200MB with multi-stage optimization)
- Start containers and verify health
- Test app at localhost:5230
- Create note, verify persistence after refresh and container restart
- Document Docker concepts and learnings"

# Step 4: Push to GitHub
git push origin main

# Step 5: Verify on GitHub
open https://github.com/Ike-DevCloudIQ/memos-deployment
```

**✅ Completion:** 
- All files committed
- Visible on GitHub
- Clear commit message explaining what you built

---

## ✅ Stage 1 Complete!

### Verify All Success Criteria

```bash
# 1. Files exist
ls -la app/Dockerfile
ls -la app/docker-compose.yaml
ls -la docs/STAGE1_LEARNINGS.md

# 2. Containers running and healthy
docker-compose -f app/docker-compose.yaml ps

# 3. App accessible
curl http://localhost:5230/api/v1/ping

# 4. Git is up to date
git status
# Should show: "On branch main" and "nothing to commit"

# 5. Check GitHub
open https://github.com/Ike-DevCloudIQ/memos-deployment
```

---

## Troubleshooting

### Build fails?
```bash
# Rebuild from scratch
docker-compose -f app/docker-compose.yaml build --no-cache
```

### Port already in use?
```bash
# See what's using 5230
lsof -i :5230

# Or kill and restart containers
docker-compose -f app/docker-compose.yaml down
docker-compose -f app/docker-compose.yaml up -d
```

### Database won't connect?
```bash
# Check PostgreSQL logs
docker-compose -f app/docker-compose.yaml logs postgres

# Restart everything
docker-compose -f app/docker-compose.yaml down -v
docker-compose -f app/docker-compose.yaml up -d
sleep 30
```

### Can't push to GitHub?
```bash
# Check remote
git remote -v

# Fix SSH auth (if needed)
git remote set-url origin git@github.com:Ike-DevCloudIQ/memos-deployment.git

# Try push again
git push origin main
```

---

## What's Next?

Once you finish Stage 1 (all ✅ above), come back and we'll start:

### **Stage 2: Terraform - Infrastructure as Code**

You'll learn:
- AWS account setup
- VPC (networking)
- EKS (Kubernetes cluster)
- RDS (managed database)
- IAM (permissions)
- All written in Terraform (not point-and-click AWS console)

---

## 📚 Resources

- **Full Guide**: `docs/STAGE1_BEGINNER_GUIDE.md` (detailed explanations)
- **Quick Reference**: This file
- **Architecture**: `docs/ARCHITECTURE.md` (system design)
- **Overview**: `LEARNING_GUIDE.md` (all 6 stages)

---

## 🎓 You've Got This!

Every step is detailed above. Follow them in order, and you'll master Docker containerization by the end of today! 

**Questions?** Check the full guide or ask for clarification.

**Ready?** Start with Part 1! 🚀
