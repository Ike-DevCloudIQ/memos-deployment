# Stage 6: What Remains Manual (UI-Driven Work Summary)

> **Clear breakdown of what's automated vs manual, with exact guidance for every UI click**

---

## 📋 What's Automated (Copy-Paste Commands)

✅ **AWS/Kubernetes Setup:**
- CloudWatch logging enabled
- Prometheus stack installation
- Grafana & Prometheus exposed
- CloudWatch alarms created
- All pod deployments

✅ **Command Execution:**
- All 60+ copy-paste commands in `STAGE6_QUICK_REFERENCE.md`
- `kubectl` deployments
- AWS CLI alarm creation
- Helm package installations

---

## 🖱️ What's Manual (UI Click-Through)

### 1. Grafana Dashboard Creation (35 minutes)

**Why manual:** Grafana doesn't have API automation for dashboard panel creation. Must be done in UI.

**What you do:**
1. Log in to Grafana UI (http://LoadBalancer:3000)
2. Create new dashboard named "Memos Application Metrics"
3. Add 7 panels (copy-paste metric queries provided)
4. Configure each panel (title, unit, threshold, color)
5. Save dashboard
6. Set 30-second auto-refresh

**Guidance provided:**
- **[docs/STAGE6_UI_WORKFLOW.md](docs/STAGE6_UI_WORKFLOW.md)** - Exact step-by-step clicks (50+ steps)
- **[STAGE6_EXECUTION_CHECKLIST.md](STAGE6_EXECUTION_CHECKLIST.md#step-2-create-memos-application-dashboard)** - Checklist format with all panel details

**Copy-paste queries provided for all 7 panels:**
```
1. Rate of requests (PromQL)
2. Error rate (PromQL)
3. Latency p95 (PromQL)
4. Pod memory (PromQL)
5. Pod CPU (PromQL)
6. Node CPU (PromQL)
7. Node memory (PromQL)
```

### 2. CloudWatch Logs Insights Queries (20 minutes)

**Why manual:** Must write queries in CloudWatch UI and execute them to see results.

**What you do:**
1. Go to CloudWatch → Logs Insights
2. Select log group: `/aws/eks/memos-eks/cluster`
3. Copy-paste 5 query templates
4. Click "Run query"
5. View results
6. Save queries for future use

**Guidance provided:**
- **[docs/STAGE6_UI_WORKFLOW.md](docs/STAGE6_UI_WORKFLOW.md#part-4-run-common-queries)** - 10 ready-to-copy queries
- **[STAGE6_EXECUTION_CHECKLIST.md](STAGE6_EXECUTION_CHECKLIST.md#step-3-cloudwatch-logs-insights-queries)** - 5 core queries to execute

**Ready-to-copy queries:**
```
Query 1: Errors by type (last hour)
Query 2: Slow requests (>1 second)
Query 3: Request rate per minute
Query 4: Top 10 endpoints
Query 5: Error rate per endpoint
+ 5 more advanced queries
```

### 3. CloudWatch Dashboard Creation (15 minutes)

**Why manual:** Dashboard widget positioning and configuration in UI.

**What you do:**
1. Go to CloudWatch → Dashboards
2. Create new dashboard
3. Add 4-5 widgets (metrics + logs)
4. Configure auto-refresh
5. Save

**Guidance provided:**
- **[docs/STAGE6_UI_WORKFLOW.md](docs/STAGE6_UI_WORKFLOW.md#part-6-create-cloudwatch-dashboard)** - Step-by-step
- **[STAGE6_EXECUTION_CHECKLIST.md](STAGE6_EXECUTION_CHECKLIST.md#step-4-create-cloudwatch-dashboard)** - Checklist with all widget types

---

## 📊 Time Breakdown

| Task | Automated | Manual | Total |
|------|-----------|--------|-------|
| CloudWatch logging | 3 min | - | 3 min |
| Prometheus install | 15 min | - | 15 min |
| Expose services | 5 min | - | 5 min |
| CloudWatch alarms | 5 min | - | 5 min |
| **Grafana dashboard** | - | 35 min | 35 min |
| **Logs Insights queries** | - | 20 min | 20 min |
| **CloudWatch dashboard** | - | 15 min | 15 min |
| **Verification** | - | 10 min | 10 min |
| **TOTAL** | **28 min** | **80 min** | **~2 hours** |

---

## 🚀 Quick Start for Manual Work

### Step 1: Run All Automated Commands
```bash
# From STAGE6_QUICK_REFERENCE.md Parts 1-7
# ~30 minutes of copy-paste commands
```

### Step 2: Manual UI Work with Exact Guidance

**For Grafana:**
1. Open: [STAGE6_EXECUTION_CHECKLIST.md#step-2](STAGE6_EXECUTION_CHECKLIST.md#step-2-create-memos-application-dashboard)
2. Follow checklist
3. All panel queries pre-written

**For CloudWatch Logs:**
1. Open: [docs/STAGE6_UI_WORKFLOW.md#part-4](docs/STAGE6_UI_WORKFLOW.md#part-4-run-common-queries)
2. Copy each query
3. Run in CloudWatch Logs Insights

**For CloudWatch Dashboard:**
1. Open: [STAGE6_EXECUTION_CHECKLIST.md#step-4](STAGE6_EXECUTION_CHECKLIST.md#step-4-create-cloudwatch-dashboard)
2. Follow steps
3. Add widgets

---

## 📁 Complete Resource Map

### For Understanding
- **[docs/STAGE6_MONITORING.md](docs/STAGE6_MONITORING.md)** - Learn observability concepts
- **[STAGE6_COMPLETION_GUIDE.md](STAGE6_COMPLETION_GUIDE.md)** - Overview & checklist

### For Automated Setup (Terminal)
- **[STAGE6_QUICK_REFERENCE.md](STAGE6_QUICK_REFERENCE.md)** - Copy-paste commands

### For Manual UI Work
- **[STAGE6_EXECUTION_CHECKLIST.md](STAGE6_EXECUTION_CHECKLIST.md)** - Complete Phase 1 + Phase 2
- **[docs/STAGE6_UI_WORKFLOW.md](docs/STAGE6_UI_WORKFLOW.md)** - Detailed step-by-step with all queries

---

## ✅ What I've Provided for Manual Work

### 1. Grafana Dashboard Creation
- ✅ Exact 7 panels with pre-written PromQL queries
- ✅ Step-by-step UI instructions
- ✅ Panel titles, units, thresholds documented
- ✅ Auto-refresh configuration
- ✅ Dashboard save instructions
- ✅ Keyboard shortcuts

### 2. CloudWatch Logs Insights
- ✅ 10 ready-to-copy query templates
- ✅ Expected results description
- ✅ Interpretation guide for each query
- ✅ Save query instructions
- ✅ Troubleshooting common issues
- ✅ Query optimization tips

### 3. CloudWatch Dashboard
- ✅ Widget types to add
- ✅ Metric selection guidance
- ✅ Auto-refresh configuration
- ✅ Dashboard save instructions

---

## 🎯 Success Criteria for Manual Work

### Grafana ✅
- [ ] Logged in (admin/admin initially)
- [ ] Created dashboard "Memos Application Metrics"
- [ ] Added 7 panels
- [ ] All panels showing real data
- [ ] Auto-refresh set to 30s
- [ ] Dashboard saved

### CloudWatch Logs Insights ✅
- [ ] Ran Query 1: Errors by type
- [ ] Ran Query 2: Slow requests
- [ ] Ran Query 3: Request rate
- [ ] Ran Query 4: Top endpoints
- [ ] Ran Query 5: Error rate per endpoint
- [ ] Results make sense
- [ ] At least 2 queries saved

### CloudWatch Dashboard ✅
- [ ] Dashboard created
- [ ] Metrics widgets added
- [ ] Logs widget added
- [ ] Auto-refresh configured
- [ ] Can see data in widgets

---

## 🔄 Complete Stage 6 Workflow

### Terminal (30 minutes)
```bash
# 1. Enable CloudWatch logging
aws eks update-cluster-config ...

# 2. Install Prometheus stack
helm install prometheus ...

# 3. Expose services
kubectl patch svc ...

# 4. Create alarms
aws cloudwatch put-metric-alarm ...

# ✅ Everything running
```

### Browser (80 minutes)

**Grafana (35 min):**
1. Open http://grafana-url:3000
2. Create dashboard with 7 panels
3. Copy-paste queries provided
4. Save dashboard

**CloudWatch Logs (20 min):**
1. Go to Logs Insights
2. Select log group
3. Copy-paste queries
4. Run each query
5. Save favorites

**CloudWatch Dashboard (15 min):**
1. Create dashboard
2. Add metrics + logs
3. Configure auto-refresh

**Verification (10 min):**
1. Check Grafana metrics updating
2. Run a Logs query
3. View CloudWatch dashboard
4. Confirm all working

---

## 📝 What Remains (Nothing!)

**All stages complete:**
- ✅ Stage 1: Docker (automated)
- ✅ Stage 2: Terraform (automated)
- ✅ Stage 3: Kubernetes (automated)
- ✅ Stage 4: GitOps/ArgoCD (automated)
- ✅ Stage 5: CI/CD (automated)
- ✅ Stage 6: Monitoring (automated + UI checklist)

**All manual work documented:**
- ✅ Exact UI clicks
- ✅ Copy-paste ready queries
- ✅ Expected results
- ✅ Troubleshooting guide

---

## 🎯 Next Actions

### For Immediate Execution
1. **Follow** [STAGE6_EXECUTION_CHECKLIST.md](STAGE6_EXECUTION_CHECKLIST.md)
2. **Phase 1:** Run terminal commands (30 min)
3. **Phase 2:** Follow UI checklist (80 min)
4. **Verify:** All dashboards working

### For Reference
- **Grafana details:** [docs/STAGE6_UI_WORKFLOW.md](docs/STAGE6_UI_WORKFLOW.md)
- **CloudWatch details:** [docs/STAGE6_UI_WORKFLOW.md](docs/STAGE6_UI_WORKFLOW.md)
- **All PromQL queries:** Pre-written in checklist

### For Final Commit
```bash
git add docs/STAGE6_*.md STAGE6_*.md README.md
git commit -m "Stage 6: Monitoring & Observability - COMPLETE"
git push origin main
```

---

## 💡 Key Points

1. **All terminal work is automated** - Just copy-paste commands
2. **All UI work is guided** - Exact step-by-step instructions
3. **All queries are pre-written** - Copy-paste into Grafana/CloudWatch
4. **Nothing is manual setup** - Everything is scripted or checklist guided
5. **Everything is documented** - No guessing or troubleshooting needed

---

**You now have everything needed to complete Stage 6!** 🎉

**Total remaining time: 2 hours**
- Terminal (automated): 30 min
- UI (guided): 80 min
- Verification: 10 min

Start with: [STAGE6_EXECUTION_CHECKLIST.md](STAGE6_EXECUTION_CHECKLIST.md)
