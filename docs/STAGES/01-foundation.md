# Stage 1: Foundation & Project Setup

## 📚 Learning Objectives

By the end of this stage, you will:
1. ✅ Understand git workflow and branching strategy
2. ✅ Set up local project structure correctly
3. ✅ Configure git as the sole project contributor
4. ✅ Create first commit and push to GitHub
5. ✅ Document decisions and learnings

---

## 🎯 What We're Building

A clean, well-organized project repository with:
- Professional directory structure
- Clear documentation
- Git configuration with you as contributor
- Ready for Terraform (Stage 3) and Kubernetes (Stage 5)

---

## 📝 Key Concepts to Understand

### Git Branching Strategy
We'll use a **stage-based branching model**:
- `main` - Production-ready code (merged after each stage completion)
- `stage/XX-name` - Working branch for each stage
- `feature/` - Feature-specific branches within a stage (optional)

**Why?** This keeps history clean and allows you to see exactly what changed at each stage.

### Project Structure
```
terraform/          # Infrastructure as Code
kubernetes/         # Container orchestration configs
docker/             # Application containerization
docs/               # All documentation
.github/            # GitHub-specific configs (CI/CD, templates)
```

**Why?** Separates concerns and makes the project navigable as it grows.

---

## 🛠 Step-by-Step Setup

### Step 1: Initialize Local Repository

```bash
cd /Users/emekaezedozie/Desktop/Nouriva/memos-deployment

# Initialize git
git init

# Add origin remote pointing to GitHub repo
git remote add origin https://github.com/Ike-DevCloudIQ/memos-deployment.git

# Verify configuration
git remote -v
```

**What this does:**
- `git init` - Creates .git directory to track changes
- `git remote add origin` - Connects to your GitHub repository
- `git remote -v` - Shows that origin is properly configured

---

### Step 2: Configure Git User (Stage-Specific)

```bash
# Set your name and email for THIS project
git config user.name "Your Name"
git config user.email "your-email@example.com"

# Verify
git config --list | grep user
```

**Why?** Every commit needs an author. This ensures you're the sole contributor.

---

### Step 3: Create Working Branch for Stage 1

```bash
git checkout -b stage/01-foundation
```

**What this does:**
- Creates new branch `stage/01-foundation`
- Switches to that branch
- All commits go here until you merge to `main`

---

### Step 4: Add Initial Files

```bash
# Check what's untracked
git status

# Add all files
git add .

# See what's staged
git status

# Create first commit
git commit -m "Stage 1: Project foundation with structure and documentation"
```

**Commit message format:**
```
Stage X: Brief description of what was done

- Bullet point with more details
- Another detail if needed
```

---

### Step 5: Push to GitHub

```bash
# Push to remote (first time includes -u to set upstream)
git push -u origin stage/01-foundation

# Verify on GitHub
# Visit: https://github.com/Ike-DevCloudIQ/memos-deployment/tree/stage/01-foundation
```

**What this does:**
- Sends your commits to GitHub
- `-u` sets this branch as the upstream (future pushes only need `git push`)

---

### Step 6: Create Pull Request (Optional but Recommended)

1. Go to GitHub repo: `https://github.com/Ike-DevCloudIQ/memos-deployment`
2. Click **Compare & pull request**
3. Add description:
   ```
   # Stage 1: Foundation & Project Setup

   ## Changes
   - Created project directory structure
   - Added documentation and learning roadmap
   - Set up git configuration
   - Created initial file structure

   ## What I Learned
   - Importance of clean project organization
   - Git branching strategy for team workflows
   - How to structure documentation for learning projects
   ```
4. Click **Create Pull Request**
5. Merge PR to `main`: Click **Merge pull request**

---

### Step 7: Update Local Main Branch

```bash
git checkout main
git pull origin main

# Verify Stage 1 files are present
ls -la
```

---

## ✅ Validation Checklist

Before moving to Stage 2, verify:

- [ ] Repository cloned locally
- [ ] Git configured with your name/email
- [ ] `.gitignore` file exists
- [ ] `README.md` created with full roadmap
- [ ] `docs/STAGES/01-foundation.md` exists
- [ ] First commit made on `stage/01-foundation` branch
- [ ] Branch pushed to GitHub
- [ ] Pull request created and merged to `main`
- [ ] `git log --oneline` shows only YOUR commits
- [ ] GitHub shows 1 contributor (you)

---

## 🔍 Key Learning Points

### Git Concepts
1. **Repository**: Local `.git` folder tracks all changes
2. **Remote**: GitHub repo is your "backup" and collaboration tool
3. **Branch**: Isolated workspace for changes; `main` is production
4. **Commit**: Snapshot of code with a message explaining why
5. **Push**: Upload commits from local to GitHub

### Why This Structure?
- **Separate directories**: Makes project scalable (100+ files manageable)
- **Documentation folder**: Future self will thank you for clear docs
- **`.gitignore`**: Prevents accidental commits of secrets, build artifacts
- **Stage-based commits**: Git history tells a learning story

### Git Hygiene
- ✅ Clear commit messages explaining WHY, not just WHAT
- ✅ Logical commits (one feature per commit)
- ✅ Regular pushes (don't let local diverge from GitHub)
- ✅ Meaningful branch names (not `branch1`, `fix`, `temp`)

---

## 📚 Next Steps

Once you complete all checklist items, **you're ready for Stage 2: Infrastructure Planning**!

In Stage 2, we'll:
- Draw an architecture diagram
- Document AWS services we'll use
- Plan resource provisioning strategy
- Set up AWS CLI configuration

---

## 🆘 Troubleshooting

### "fatal: not a git repository"
```bash
# Solution: Run git init first
git init
```

### "fatal: 'origin' does not appear to be a 'git' repository"
```bash
# Solution: Add origin remote
git remote add origin https://github.com/Ike-DevCloudIQ/memos-deployment.git
```

### "error: src refspec main does not match any"
```bash
# Solution: Rename branch to main
git branch -M main
# Then push with -u flag
git push -u origin main
```

### "fatal: the current branch has no upstream tracking information"
```bash
# Solution: Use -u flag when pushing
git push -u origin stage/01-foundation
```

---

**Questions? Let's discuss before moving forward! 🚀**
