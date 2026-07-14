# Stage 1: The Application - BEGINNER'S STEP-BY-STEP GUIDE

> **For Beginners**: This guide breaks down every single step. If you follow it exactly, you'll learn Docker while building a real application.

---

## Table of Contents
- [Part 1: Understand Memos (30 min)](#part-1-understand-memos)
- [Part 2: Create Dockerfile (1 hour)](#part-2-create-dockerfile)
- [Part 3: Create docker-compose.yaml (30 min)](#part-3-create-docker-composeyaml)
- [Part 4: Build & Run Locally (1 hour)](#part-4-build--run-locally)
- [Part 5: Test & Verify (30 min)](#part-5-test--verify)
- [Part 6: Document Learning (1 hour)](#part-6-document-learning)
- [Part 7: Commit to Git (15 min)](#part-7-commit-to-git)

---

# Part 1: Understand Memos

## Step 1.1: Open Terminal

**What to do:**
1. Open your Terminal application (or iTerm2 if you have it)
2. You'll see something like: `➜  ~ `

**Why?** Terminal is how we interact with our computer programmatically (using text commands instead of clicking).

---

## Step 1.2: Navigate to your project folder

**Type this command exactly** (then press Enter):
```bash
cd ~/Desktop/Nouriva/memos-deployment
```

**What should happen:**
- Your terminal changes to show: `➜  memos-deployment git:(main)`
- This means you're now inside your project folder

**If you get an error:**
```
cd: no such file or directory: ~/Desktop/Nouriva/memos-deployment
```
**Solution**: Create the folder first:
```bash
mkdir -p ~/Desktop/Nouriva/memos-deployment
cd ~/Desktop/Nouriva/memos-deployment
```

---

## Step 1.3: Clone the official Memos source code

**Type this command** (copy-paste it):
```bash
cd ~/Desktop/Nouriva && git clone https://github.com/usememos/memos.git memos-source
```

**What should happen:**
```
Cloning into 'memos-source'...
remote: Enumerating objects: 15832, done.
remote: Counting objects: 100% (1523/1523), done.
...
Receiving objects: 100% (15832/15832), ...
```
**This takes 1-2 minutes.** Wait for it to finish.

**What it did:** Downloaded the official Memos application code from GitHub into a folder called `memos-source`.

---

## Step 1.4: Navigate into Memos source folder

**Type:**
```bash
cd ~/Desktop/Nouriva/memos-source
```

**Verify you're there:**
```bash
pwd
```

**Expected output:**
```
/Users/[your-username]/Desktop/Nouriva/memos-source
```

---

## Step 1.5: See what's in the folder

**Type:**
```bash
ls -la
```

**What you should see:**
```
total 360
drwxr-xr-x  23 user  staff     736 Jul 14 10:00 .
drwxr-xr-x   5 user  staff     160 Jul 14 10:00 ..
-rw-r--r--   1 user  staff    1234 Jul 14 10:00 .gitignore
-rw-r--r--   1 user  staff    5678 Jul 14 10:00 go.mod
-rw-r--r--   1 user  staff    9999 Jul 14 10:00 go.sum
drwxr-xr-x   5 user  staff     160 Jul 14 10:00 cmd/              ← Backend entry points
drwxr-xr-x   8 user  staff     256 Jul 14 10:00 internal/         ← Core logic
drwxr-xr-x   3 user  staff      96 Jul 14 10:00 web/              ← Frontend code
drwxr-xr-x   2 user  staff      64 Jul 14 10:00 docs/
drwxr-xr-x   2 user  staff      64 Jul 14 10:00 proto/
-rw-r--r--   1 user  staff   11234 Jul 14 10:00 README.md
```

**What this means:**
- `cmd/` = Where the Go backend starts
- `web/` = Where the React frontend is
- `go.mod` = Go dependencies (like package.json for Node)

---

## Step 1.6: Explore the backend

**Type:**
```bash
ls -la cmd/
```

**You should see:**
```
drwxr-xr-x  4 user  staff  128 Jul 14 10:00 memos/
```

**Type:**
```bash
ls -la cmd/memos/
```

**You should see:**
```
-rw-r--r--  1 user  staff  2345 Jul 14 10:00 main.go    ← Entry point!
```

**Why?** `main.go` is where the Go program starts. This is the backend server.

---

## Step 1.7: Explore the frontend

**Type:**
```bash
ls -la web/
```

**You should see:**
```
-rw-r--r--  1 user  staff  5678 Jul 14 10:00 package.json    ← Node dependencies
-rw-r--r--  1 user  staff  1234 Jul 14 10:00 vite.config.ts  ← Frontend build config
drwxr-xr-x  3 user  staff    96 Jul 14 10:00 src/            ← React source code
```

**Why?** This is the React web UI that users see in their browser.

---

## Step 1.8: Look at the README

**Type:**
```bash
head -50 README.md
```

**You'll see:**
```
# Memos
A privacy-first, lightweight note-taking service. Easily capture and share your great thoughts...

## Features
- Privacy-first and open source...
- ...
```

**Key things to understand:**
- ✅ Memos is a **note-taking app** (like Notion)
- ✅ It's **open source** (free, anyone can see the code)
- ✅ Has **backend (Go)** + **frontend (React)**

---

## Step 1.9: Check Go and Node versions required

**Type:**
```bash
cat go.mod | head -5
```

**You'll see something like:**
```
module github.com/usememos/memos

go 1.21
```

**What this means:** The backend needs Go version 1.21 or higher.

**Type:**
```bash
cat web/package.json | head -10
```

**You'll see:**
```json
{
  "name": "memos",
  "version": "0.16.0",
  "type": "module",
  "scripts": {
    "build": "vite build",
    ...
```

**What this means:** Frontend needs Node.js to build.

---

## ✅ Part 1 Complete!

**What you learned:**
- ✅ Memos has a **Go backend** (server)
- ✅ Memos has a **React frontend** (web UI)
- ✅ Uses **PostgreSQL** for database (we'll see this in docker-compose)
- ✅ Backend runs on **port 5230**

**Next:** Go back to your project and create a Dockerfile!

```bash
cd ~/Desktop/Nouriva/memos-deployment
pwd
```

Should show: `/Users/[username]/Desktop/Nouriva/memos-deployment`

---

---

# Part 2: Create Dockerfile

## What is a Dockerfile?

**Simple explanation:**
```
Dockerfile = Recipe for creating a Docker image
Docker image = Package with app + all dependencies
Docker container = Running instance of that image
```

**Think of it like:**
- **Recipe** (Dockerfile) → **Cake** (Docker image) → **Eating the cake** (Docker container)

---

## Step 2.1: Create the app folder

**Type:**
```bash
mkdir -p app
```

**Verify:**
```bash
ls -la
```

**You should see:**
```
drwxr-xr-x  app
```

---

## Step 2.2: Create the Dockerfile

**Type:**
```bash
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

**Press Enter** when you're done pasting.

**Verify the file was created:**
```bash
ls -la app/
```

**You should see:**
```
-rw-r--r--  app/Dockerfile
```

---

## Step 2.3: Understand what the Dockerfile does

Let me break it down line by line:

### **Stage 1: Frontend Builder**
```dockerfile
FROM node:18-alpine AS web-builder
```
- **FROM** = Start with Node.js version 18 (small version)
- **AS web-builder** = Name this stage "web-builder" (we'll reference it later)
- **Why?** We need Node to compile React code

```dockerfile
WORKDIR /app
```
- **WORKDIR** = Set the working directory (like `cd /app` in terminal)
- **Why?** All future commands run from `/app` inside the container

```dockerfile
COPY web/package*.json ./web/
```
- **COPY** = Copy files from your computer → inside container
- `web/package*.json` = Copy package.json and package-lock.json
- `./web/` = Paste them in /app/web/ inside container
- **Why?** Node needs to know which packages to install

```dockerfile
RUN cd web && npm ci --legacy-peer-deps
```
- **RUN** = Execute a command (like in terminal)
- `npm ci` = Install packages from package-lock.json
- `--legacy-peer-deps` = Handle older package compatibility
- **Why?** Download all Node dependencies before building

```dockerfile
COPY web .
RUN npm run build
```
- **COPY** the entire web folder
- **RUN** the build script (compiles React into HTML/JS/CSS)
- **Why?** Creates the static files users will see in browser

### **Stage 2: Backend Builder**
```dockerfile
FROM golang:1.21-alpine AS backend-builder
```
- Start with Go compiler
- **Why?** We need Go to compile the backend code

```dockerfile
COPY go.mod go.sum ./
RUN go mod download
```
- Copy Go dependency files
- Download dependencies (like npm install)
- **Why?** Prepare to build the Go binary

```dockerfile
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o memos ./cmd/memos
```
- Copy entire source code
- Build Go program → creates `memos` binary
- `-o memos` = Output file is called "memos"
- `./cmd/memos` = Build from this directory
- **Why?** Compiles Go source → executable binary

### **Stage 3: Runtime (Final)**
```dockerfile
FROM alpine:3.18
```
- Start fresh with minimal Alpine Linux (5MB, not 1GB)
- **Why?** Only keep what's needed to RUN the app, not build it

```dockerfile
RUN apk add --no-cache ca-certificates tzdata
```
- Add SSL certificates (for HTTPS) and timezone data
- **Why?** The app might need these at runtime

```dockerfile
RUN addgroup -g 1000 memos && adduser -D -u 1000 -G memos memos
```
- Create a user called "memos" (not root!)
- **Why?** Security: don't run apps as root

```dockerfile
COPY --from=backend-builder /app/memos ./
COPY --from=web-builder /app/dist ./dist
```
- **COPY --from=backend-builder** = Copy file from Stage 2
- Copy the compiled `memos` binary (small!)
- Copy frontend files from Stage 1
- **Why?** We have everything needed to run, nothing extra

```dockerfile
USER memos
EXPOSE 5230
```
- **USER** = Run the app as "memos" user (not root)
- **EXPOSE** = Document that app uses port 5230
- **Why?** Security + documentation

```dockerfile
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost:5230/api/v1/ping || exit 1
```
- Check every 30 seconds if app is healthy
- Try to reach `http://localhost:5230/api/v1/ping`
- If it fails 3 times, mark container as unhealthy
- **Why?** Kubernetes uses this to auto-restart dead containers

```dockerfile
CMD ["./memos"]
```
- **CMD** = Default command when container starts
- Run the `memos` binary
- **Why?** This is what actually starts your app

---

## ✅ Part 2 Complete!

**What you created:**
- ✅ A production-grade Dockerfile
- ✅ Multi-stage build (3 stages: frontend, backend, runtime)
- ✅ Final image will be ~200-300MB (not 1GB!)

---

---

# Part 3: Create docker-compose.yaml

## What is docker-compose?

**Simple explanation:**
```
docker-compose = Way to run multiple containers together
With one command, start: app + database
```

**Why?** In production, Memos needs PostgreSQL. We can't just run the Memos container alone.

---

## Step 3.1: Create the docker-compose file

**Type:**
```bash
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

**Verify it was created:**
```bash
ls -la app/
```

**You should see:**
```
-rw-r--r--  app/Dockerfile
-rw-r--r--  app/docker-compose.yaml
```

---

## Step 3.2: Understand the docker-compose file

```yaml
version: '3.8'
```
- **version** = docker-compose file format version
- **Why?** Tells Docker which syntax to use

```yaml
services:
  postgres:
```
- **services** = List of containers to run
- **postgres** = Name of the database service

```yaml
    image: postgres:15-alpine
```
- **image** = Use official PostgreSQL version 15
- **alpine** = Small version (like Alpine Linux)
- **Why?** PostgreSQL is already made, we just use it

```yaml
    container_name: memos-db
```
- **container_name** = Call this container "memos-db"
- **Why?** Easy to identify in Docker commands

```yaml
    environment:
      POSTGRES_USER: memos
      POSTGRES_PASSWORD: memos_local_dev
      POSTGRES_DB: memos
```
- **environment** = Variables passed to the container
- **POSTGRES_USER** = Database username
- **POSTGRES_PASSWORD** = Database password (⚠️ NOT for production!)
- **POSTGRES_DB** = Default database name
- **Why?** PostgreSQL needs these to initialize

```yaml
    ports:
      - "5432:5432"
```
- **ports** = "host_port:container_port"
- **5432:5432** = Port 5432 on your machine → Port 5432 in container
- **Why?** You can connect to database at `localhost:5432`

```yaml
    volumes:
      - postgres_data:/var/lib/postgresql/data
```
- **volumes** = Persistent storage that survives container restarts
- **postgres_data** = Name of the storage volume
- `/var/lib/postgresql/data` = Where PostgreSQL stores data inside container
- **Why?** When you stop the container, data doesn't get deleted

```yaml
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U memos"]
      interval: 10s
      timeout: 5s
      retries: 5
```
- **healthcheck** = Check if database is healthy
- `pg_isready` = Command to test if PostgreSQL is ready
- **interval: 10s** = Check every 10 seconds
- **retries: 5** = If fails 5 times, mark unhealthy
- **Why?** Memos won't start until database is healthy

---

## **The Memos Service**

```yaml
  memos:
    build:
      context: ..
      dockerfile: app/Dockerfile
```
- **build** = Build the image using a Dockerfile
- **context: ..** = Build from parent directory (where we are now)
- **dockerfile: app/Dockerfile** = Use the Dockerfile we created
- **Why?** Docker will run the build steps we wrote

```yaml
    depends_on:
      postgres:
        condition: service_healthy
```
- **depends_on** = Wait for another service
- **postgres:condition: service_healthy** = Don't start Memos until PostgreSQL is healthy
- **Why?** Memos needs database connection, so database must be ready first

```yaml
    environment:
      DSN: postgres://memos:memos_local_dev@postgres:5432/memos
```
- **DSN** = Database connection string
- `postgres://` = Protocol (PostgreSQL)
- `memos:memos_local_dev` = username:password
- `@postgres` = Connect to the `postgres` service (Docker DNS)
- `:5432/memos` = Port and database name
- **Why?** Tells Memos how to connect to PostgreSQL

```yaml
    ports:
      - "5230:5230"
```
- Port 5230 on your machine → Port 5230 in container
- **Why?** You can access Memos at `http://localhost:5230`

```yaml
    volumes:
      - memos_data:/app/data
```
- Persistent storage for Memos (attachments, etc.)
- **Why?** Data survives container restarts

---

## **Volumes section**

```yaml
volumes:
  postgres_data:
  memos_data:
```
- **volumes** = Define the volumes referenced above
- These create persistent storage on your computer
- **Why?** Docker needs to know where to store data

---

## ✅ Part 3 Complete!

**What you created:**
- ✅ PostgreSQL service (database)
- ✅ Memos service (app)
- ✅ They're connected and will start together
- ✅ PostgreSQL starts first, Memos waits for it
- ✅ Data persists even after stopping containers

---

---

# Part 4: Build & Run Locally

## Step 4.1: Navigate to project folder

**Type:**
```bash
cd ~/Desktop/Nouriva/memos-deployment
```

**Verify:**
```bash
pwd
```

**Should show:**
```
/Users/[username]/Desktop/Nouriva/memos-deployment
```

---

## Step 4.2: Build the Docker image

**Type:**
```bash
docker-compose -f app/docker-compose.yaml build
```

**What should happen:**
```
[+] Building 45.3s (25/25) FINISHED
 => [web-builder 1/4] FROM node:18-alpine@sha256:abc...
 => [web-builder 2/4] WORKDIR /app
 => [web-builder 3/4] COPY web/package*.json ./web/
 => [web-builder 4/4] RUN cd web && npm ci --legacy-peer-deps
 ...
 => [backend-builder 3/3] RUN CGO_ENABLED=0 GOOS=linux go build...
 ...
 => [stage-3 2/4] COPY --from=backend-builder /app/memos ./
 => exporting to image
 => => naming to memos-deployment-memos:latest
```

**This takes 3-5 minutes.** ☕ Grab coffee!

**What it did:**
1. Downloaded Node.js image
2. Downloaded Go image
3. Downloaded Alpine image
4. Ran Stage 1: Built React frontend
5. Ran Stage 2: Built Go backend
6. Ran Stage 3: Created final small image
7. Created Docker image called `memos-deployment-memos`

**If you get an error:** Don't worry, copy the error and paste it in a terminal.

---

## Step 4.3: Start the containers

**Type:**
```bash
docker-compose -f app/docker-compose.yaml up -d
```

**The `-d` flag** = "detached" = Run in background

**What should happen:**
```
[+] Running 3/3
 ✓ Network memos-deployment_default  Created
 ✓ Container memos-db                 Started
 ✓ Container memos-app                Started
```

---

## Step 4.4: Check if containers are running

**Type:**
```bash
docker-compose -f app/docker-compose.yaml ps
```

**You should see:**
```
NAME             COMMAND                  SERVICE     STATUS
memos-db         "docker-entrypoint..."   postgres    Up 20 seconds (healthy)
memos-app        "./memos"                memos       Up 10 seconds (healthy)
```

**What this means:**
- ✅ Both containers are running
- ✅ Both are marked as "healthy"
- ✅ App has been running for 10 seconds

**If you see "unhealthy":** Wait 30 seconds and check again. Containers need time to start.

---

## Step 4.5: Check the logs

**Type:**
```bash
docker-compose -f app/docker-compose.yaml logs -f memos
```

**You should see something like:**
```
memos-app  | 2026/07/14 10:30:45 [INFO] memos server is running at http://127.0.0.1:5230
memos-app  | 2026/07/14 10:30:45 [INFO] database connection succeeded
```

**What this means:**
- ✅ Backend started successfully
- ✅ Connected to database
- ✅ Listening on port 5230

**To stop seeing logs:** Press `Ctrl+C`

---

## ✅ Part 4 Complete!

**What you did:**
- ✅ Built Docker image from Dockerfile
- ✅ Started PostgreSQL container
- ✅ Started Memos container
- ✅ Both are healthy and running

---

---

# Part 5: Test & Verify

## Step 5.1: Test the API

**Type:**
```bash
curl http://localhost:5230/api/v1/ping
```

**You should see:**
```json
{"data":"OK"}
```

**What this means:**
- ✅ App is running
- ✅ API is responding
- ✅ Database is connected

---

## Step 5.2: Open the web UI in browser

**Type:**
```bash
open http://localhost:5230
```

**What should happen:**
- Browser opens automatically
- You see the Memos login page

**If browser doesn't open:**
- Manually open browser
- Go to: `http://localhost:5230`

---

## Step 5.3: Create an account

**On the login page:**
1. Click "Sign Up"
2. Fill in:
   - Email: `test@example.com`
   - Password: `Test@123!`
   - Confirm password: `Test@123!`
3. Click "Sign Up"

**What should happen:**
- You're logged in
- Redirected to dashboard
- Empty notes list

---

## Step 5.4: Create a test note

**On the dashboard:**
1. Click **New Memo** button
2. Type: `This is my first note created in Docker!`
3. Click **Save**

**What should happen:**
- Note appears in the list
- You see it has content

---

## Step 5.5: Test persistence

**In browser:**
1. Refresh the page (Cmd+R)

**What should happen:**
- ✅ Note is still there!
- ✅ Database persisted your data

---

## Step 5.6: Stop containers (test data survival)

**In terminal:**
```bash
docker-compose -f app/docker-compose.yaml down
```

**What should happen:**
```
[+] Running 3/3
 ✓ Container memos-app          Removed
 ✓ Container memos-db           Removed
 ✓ Network memos-deployment...  Removed
```

**Note:** Containers are gone, but volumes (data) are still there!

---

## Step 5.7: Start containers again

**Type:**
```bash
docker-compose -f app/docker-compose.yaml up -d
```

**Wait 30 seconds**, then:

```bash
docker-compose -f app/docker-compose.yaml ps
```

**Verify both say "healthy"**

---

## Step 5.8: Check if data persisted

**Open browser:**
```bash
open http://localhost:5230
```

**Log in again** with same credentials:
- Email: `test@example.com`
- Password: `Test@123!`

**What should happen:**
- ✅ You see your note is still there!
- ✅ Database data survived the container restart

---

## Step 5.9: Check image size

**Type:**
```bash
docker image ls | grep memos
```

**You should see:**
```
memos-deployment-memos   latest   abc123def456   3 minutes   220MB
```

**What this means:**
- ✅ Image is ~220MB (not 1GB!)
- ✅ Multi-stage build worked
- ✅ Final image only has what's needed to run

---

## Step 5.10: Cleanup (optional)

**If you want to remove everything for testing:**

```bash
# Stop containers
docker-compose -f app/docker-compose.yaml down

# Remove volumes (deletes data)
docker-compose -f app/docker-compose.yaml down -v

# Remove image
docker image rm memos-deployment-memos
```

**Restart for final testing:**
```bash
docker-compose -f app/docker-compose.yaml up -d
```

---

## ✅ Part 5 Complete!

**What you verified:**
- ✅ App runs at http://localhost:5230
- ✅ Can create notes and save
- ✅ Notes persist after refresh
- ✅ Data survives container restarts
- ✅ Image size is reasonable (~200-300MB)

---

---

# Part 6: Document Your Learning

## Step 6.1: Create learning document

**Type:**
```bash
cat > docs/STAGE1_LEARNINGS.md << 'EOF'
# Stage 1: Application - What I Learned

## Docker Concepts

### What is Docker?
Docker is a tool to package applications with all their dependencies into containers.
Instead of "install Go, install Node, install PostgreSQL", you just run `docker run`.

### Key Concepts

#### Image vs Container
- **Image**: Blueprint (like a recipe or class)
- **Container**: Running instance (like actual food or object)
- **Registry**: Storage for images (like GitHub for code)

Example:
- **Image** = Instructions to make a cake
- **Container** = Actual cake you can eat
- **Registry** = Where you download recipes

#### Multi-Stage Build
Why we used 3 stages:

Stage 1: Build frontend (Node.js needed, big compiler)
- Downloads npm packages
- Compiles React code
- Output: HTML/JS/CSS files

Stage 2: Build backend (Go compiler needed, big compiler)
- Downloads Go packages
- Compiles Go code
- Output: Binary executable

Stage 3: Runtime (nothing needed but binaries, tiny)
- Copy the output from Stage 1
- Copy the output from Stage 2
- Alpine Linux (5MB base)
- Final image: ~200MB (not 1GB)

#### Dockerfile Commands
- **FROM** = Start with a base image
- **WORKDIR** = Set directory (like cd)
- **COPY** = Copy files from computer → container
- **RUN** = Execute command (like terminal)
- **ENV** = Set environment variable
- **EXPOSE** = Document which port the app uses
- **HEALTHCHECK** = Define how to check if app is healthy
- **CMD** = Default command when container starts
- **USER** = Run as a user (not root = security!)

### Multi-Container Setup

#### What is docker-compose?
Tool to run multiple containers together with one command.

Instead of:
```bash
docker run -d postgres:15
docker run -d my-app
# manually make sure postgres is healthy
# manually connect my-app to postgres
```

You do:
```bash
docker-compose up -d
# It handles everything!
```

#### Services We Defined

**PostgreSQL Service:**
- Image: postgres:15-alpine
- Port: 5432
- Data stored in: postgres_data volume
- Healthcheck: pg_isready

**Memos Service:**
- Build from: app/Dockerfile
- Port: 5230
- Depends on: postgres (waits for it to be healthy)
- Data stored in: memos_data volume
- Healthcheck: curl /api/v1/ping

### Persistence with Volumes

**Problem:** Containers are temporary
- Stop container → data is lost

**Solution:** Volumes
- Persistent storage outside the container
- Data survives container restarts
- Can be shared between containers

Our volumes:
- `postgres_data` = Database files
- `memos_data` = Memos attachments/data

---

## Application Architecture

### What is Memos?
Open-source note-taking app (like Notion, Evernote).

### Components

**Backend (Go)**
- Location: cmd/memos/main.go
- Port: 5230
- Language: Go (compiled, fast, efficient)
- Database: PostgreSQL
- Purpose: REST API server for create/read/update notes

**Frontend (React)**
- Location: web/
- Language: JavaScript/TypeScript
- Framework: React (modern UI)
- Build tool: Vite
- Purpose: Web UI that users interact with in browser

**Database (PostgreSQL)**
- Language: SQL
- Port: 5432
- Purpose: Store users, notes, relationships persistently

### How they talk to each other

```
Browser (http://localhost:5230)
    ↓
Frontend React App (served from /dist folder)
    ↓ (HTTP requests)
Backend Go API (REST endpoints)
    ↓ (SQL queries)
PostgreSQL Database
```

---

## Best Practices Applied

### Security
- ✅ Non-root user (memos) - don't run as root
- ✅ Alpine Linux - minimal attack surface
- ✅ No hardcoded passwords in image

### Performance
- ✅ Multi-stage build - smaller final image
- ✅ Layer caching - faster rebuilds
- ✅ Alpine Linux - small base image

### Reliability
- ✅ Healthchecks - detect unhealthy containers
- ✅ depends_on - ensure startup order
- ✅ Volumes - persistent data

### Maintainability
- ✅ Clear Dockerfile - easy to understand
- ✅ docker-compose - easy to manage multiple containers
- ✅ Comments in code

---

## Challenges I Encountered

### Challenge 1: [Your challenge here]
**Problem:** [What went wrong]
**Solution:** [How you fixed it]
**Learning:** [What you learned]

### Challenge 2: [Your challenge here]
**Problem:** [What went wrong]
**Solution:** [How you fixed it]
**Learning:** [What you learned]

---

## Key Takeaways

1. **Containerization solves "works on my machine"**
   - Same image runs on laptop, server, cloud
   - No more "install Go on Windows", "install Node on Mac"

2. **Docker-compose for local development**
   - One command to start entire system
   - Easy to reproduce production setup locally

3. **Multi-stage builds = smaller production images**
   - Build tools not needed at runtime
   - Reduces security surface
   - Faster deployments

4. **Volumes = persistent data**
   - Containers are ephemeral, volumes are permanent
   - Database data survives container restarts

5. **Healthchecks = reliability**
   - Kubernetes uses healthchecks to restart dead pods
   - Better user experience

---

## Next Steps

Stage 2: Terraform
- Write infrastructure code to create AWS resources
- VPC, EKS cluster, RDS database
- Everything as code (easier to manage, version control)
EOF
```

**Verify file created:**
```bash
ls -la docs/STAGE1_LEARNINGS.md
```

---

## Step 6.2: Fill in your learnings

**Edit the file:**
```bash
nano docs/STAGE1_LEARNINGS.md
```

**Fill in:**
- Challenges you encountered
- How you solved them
- What you learned
- Any questions you have

**Save:** Press `Ctrl+X`, then `Y`, then `Enter`

---

## ✅ Part 6 Complete!

**What you documented:**
- ✅ Docker concepts you learned
- ✅ Architecture of Memos
- ✅ Best practices applied
- ✅ Your challenges and solutions

---

---

# Part 7: Commit to Git

## Step 7.1: Check git status

**Type:**
```bash
git status
```

**You should see:**
```
On branch main

Untracked files:
  (use "git add <file>..." to include in what will be committed)
    app/
    docs/STAGE1_LEARNINGS.md

nothing added to commit but untracked files present (working tree dirty)
```

**What this means:**
- You have new files that aren't in git yet
- Ready to commit

---

## Step 7.2: Stage all files

**Type:**
```bash
git add .
```

**Verify:**
```bash
git status
```

**You should see:**
```
On branch main

Changes to be committed:
  (new file):   app/Dockerfile
  (new file):   app/docker-compose.yaml
  (new file):   docs/STAGE1_LEARNINGS.md
```

---

## Step 7.3: Commit with a message

**Type:**
```bash
git commit -m "Stage 1: Complete - Containerized Memos app with Docker

- Create multi-stage Dockerfile for Memos backend + frontend
- Build frontend (React) in Node.js
- Build backend (Go) for Linux
- Runtime Alpine Linux with only needed files
- Add docker-compose.yaml for PostgreSQL + Memos
- Non-root user for security
- Healthchecks for container health monitoring
- App runs on localhost:5230 with persistent database
- Tested: Create note, refresh, restart containers - data persists
- Document Docker concepts and learning

Next: Stage 2 - Terraform infrastructure as code"
```

**What should happen:**
```
[main 3f5a8c9] Stage 1: Complete - Containerized Memos app with Docker
 3 files changed, 250 insertions(+)
 create mode 100644 app/Dockerfile
 create mode 100644 app/docker-compose.yaml
 create mode 100644 docs/STAGE1_LEARNINGS.md
```

---

## Step 7.4: Push to GitHub

**Type:**
```bash
git push origin main
```

**What should happen:**
```
Enumerating objects: 5, done.
Counting objects: 100% (5/5), done.
Delta compression using 3 threads
Compressing objects: 100% (3/3), done.
Writing objects: 100% (5/5), 2.34 KiB | 2.34 MiB/s
To github.com:Ike-DevCloudIQ/memos-deployment.git
   7b0ac12..3f5a8c9  main -> main
```

---

## Step 7.5: Verify on GitHub

**Open browser:**
```bash
open https://github.com/Ike-DevCloudIQ/memos-deployment
```

**You should see:**
- ✅ Two commits (Stage 1 foundation + Stage 1 complete)
- ✅ Files: `app/`, `docs/`
- ✅ Recent commits show your work

---

## ✅ Part 7 Complete!

**What you did:**
- ✅ Staged all files
- ✅ Committed with meaningful message
- ✅ Pushed to GitHub
- ✅ Your work is backed up and visible

---

---

# 🎉 Stage 1: COMPLETE!

## Summary of What You Built

```
┌─────────────────────────────────────────────────────┐
│           Stage 1: The Application                   │
├─────────────────────────────────────────────────────┤
│ ✅ Analyzed Memos source code                       │
│ ✅ Created multi-stage Dockerfile                   │
│    - Frontend build (React + Node.js)               │
│    - Backend build (Go compiler)                    │
│    - Runtime (Alpine Linux minimal)                 │
│ ✅ Created docker-compose.yaml                      │
│    - PostgreSQL service                             │
│    - Memos service                                  │
│    - Networking and dependencies                    │
│ ✅ Built Docker image                               │
│ ✅ Started containers                               │
│ ✅ Tested app at http://localhost:5230              │
│ ✅ Verified data persistence                        │
│ ✅ Documented all learnings                         │
│ ✅ Committed to GitHub                              │
└─────────────────────────────────────────────────────┘
```

## What You Learned

**Docker Skills:**
- ✅ Image vs Container vs Registry
- ✅ Multi-stage builds (3 stages explained)
- ✅ Dockerfile best practices
- ✅ docker-compose for multi-container setup
- ✅ Persistent volumes
- ✅ Healthchecks
- ✅ Port mapping
- ✅ Environment variables

**Application Knowledge:**
- ✅ Memos architecture (Go + React + PostgreSQL)
- ✅ How backend and frontend communicate
- ✅ Database layer and persistence

**DevOps Practices:**
- ✅ Running apps in containers
- ✅ Local development with docker-compose
- ✅ Security (non-root user)
- ✅ Reliability (healthchecks)
- ✅ Git and GitHub workflows

## Your Deliverables

```
memos-deployment/
├── app/
│   ├── Dockerfile                 ← Multi-stage build
│   └── docker-compose.yaml        ← Local dev setup
├── docs/
│   ├── ARCHITECTURE.md            ← System design
│   ├── STAGE1_APP.md              ← This guide
│   └── STAGE1_LEARNINGS.md        ← Your learnings
├── LEARNING_GUIDE.md              ← Overview
└── README.md                       ← Project docs
```

## Ready for Stage 2?

You've mastered **containerization**! 🎓

Next stage: **Terraform - Infrastructure as Code**

You'll learn:
- AWS fundamentals (VPC, EKS, RDS)
- Terraform (IaC tool)
- Modular infrastructure
- State management
- Creating cloud resources

---

## Troubleshooting Common Issues

### Docker not installed?
```bash
# Check if Docker is installed
docker --version

# If not, download Docker Desktop from https://www.docker.com/products/docker-desktop
```

### Port 5230 already in use?
```bash
# Find what's using port 5230
lsof -i :5230

# Kill the process (if you want)
kill -9 <PID>
```

### Database won't connect?
```bash
# Check PostgreSQL logs
docker-compose -f app/docker-compose.yaml logs postgres

# Recreate from scratch
docker-compose -f app/docker-compose.yaml down -v
docker-compose -f app/docker-compose.yaml up -d
```

### Image build failed?
```bash
# Check full output
docker-compose -f app/docker-compose.yaml build --no-cache

# Check logs
docker-compose -f app/docker-compose.yaml logs memos
```

---

## Questions?

- **Docker docs**: https://docs.docker.com/
- **Memos repo**: https://github.com/usememos/memos
- **docker-compose**: https://docs.docker.com/compose/

---

## Celebrate! 🎉

You've completed Stage 1 and understand:
- Docker fundamentals
- Container orchestration
- Multi-container applications
- Data persistence

You're on your way to DevOps mastery!

**Next:** Stage 2 - Terraform & Cloud Infrastructure 🚀
