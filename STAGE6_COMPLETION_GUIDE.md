# Stage 6: Monitoring & Observability - COMPLETION GUIDE

> **See everything that's happening in your production system**

---

## 📊 What You'll Have After Stage 6

```
Complete Observability Stack:

CloudWatch          Prometheus         Grafana
├─ Alarms           ├─ Metrics         └─ Dashboards
├─ Dashboards       ├─ Queries         └─ Alerts
├─ Logs Insights    └─ AlertManager
└─ Log Groups
```

---

## 🎯 Stage 6 Roadmap

| Part | Task | Time | Status |
|------|------|------|--------|
| 1 | Prerequisites check | 5 min | ⏳ Next |
| 2 | CloudWatch dashboard & alarms | 10 min | ⏳ Next |
| 3 | EKS control plane logging | 5 min | ⏳ Next |
| 4 | Install Prometheus stack | 15 min | ⏳ Next |
| 5 | Access Grafana dashboards | 10 min | ⏳ Next |
| 6 | Create custom Memos dashboard | 15 min | ⏳ Next |
| 7 | Set up Prometheus alerts | 10 min | ⏳ Next |
| 8 | Application metrics (optional) | 20 min | ⏳ Next |
| 9 | CloudWatch Logs Insights | 10 min | ⏳ Next |
| 10 | Commit to Git | 5 min | ⏳ Next |
| | **Total** | **~105 min** | |

---

## 📚 Learning Materials

### Conceptual Guide (45 min read)
**[docs/STAGE6_MONITORING.md](docs/STAGE6_MONITORING.md)**
- What is observability
- Three pillars: metrics, logs, traces
- Architecture overview
- Prometheus & Grafana
- CloudWatch integration
- Four golden signals
- Best practices
- Common mistakes

### Quick Reference (90 min execution)
**[STAGE6_QUICK_REFERENCE.md](STAGE6_QUICK_REFERENCE.md)**
- Copy-paste commands
- CloudWatch setup
- Prometheus installation
- Grafana access
- Custom dashboards
- Alert rules
- Log queries
- Troubleshooting

---

## ✨ Key Features You'll Enable

### 1. **Real-time Dashboards**
```
In Grafana:
- System Health (CPU, memory, disk, network)
- Application Metrics (requests, latency, errors)
- Database Performance (connections, query latency)
- Business Metrics (notes created, active users)
```

### 2. **Alerting**
```
Automatic alerts when:
- CPU > 80% for 5 minutes
- Error rate > 1%
- Request latency > 1 second
- Database connection pool exhausted
- Pod crashes repeatedly
```

### 3. **Log Aggregation**
```
All logs in one place:
- EKS cluster logs
- Application logs
- Database logs
- Security logs

Query with CloudWatch Insights:
- Find errors by type
- Identify slow requests
- Track user actions
```

### 4. **Troubleshooting**
```
When issues occur:
- Look at dashboard → see what's wrong
- Check logs → find root cause
- View traces → understand request flow
- Review alerts → see what triggered
```

---

## 🚀 Start Here

### Step 1: Read the Guide
```bash
# Understand observability concepts
cat docs/STAGE6_MONITORING.md | head -300
```

### Step 2: Check Prerequisites
```bash
# Verify cluster is ready
aws eks update-kubeconfig --name memos-eks --region us-west-1
kubectl get nodes
```

### Step 3: Follow Quick Reference
```bash
# Execute commands in order
# STAGE6_QUICK_REFERENCE.md Parts 1-10
```

### Step 4: Access Dashboards
```bash
# Get Grafana URL
GRAFANA_URL=$(kubectl get svc prometheus-grafana -n monitoring \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "Open Grafana: http://$GRAFANA_URL:3000"
echo "Username: admin, Password: admin"
```

---

## 📋 Stage 6 Checklist

**Prerequisites:**
- [ ] EKS cluster running (`kubectl get nodes` shows 2 nodes)
- [ ] kubectl configured
- [ ] helm installed (`helm version` works)
- [ ] AWS CLI access

**CloudWatch Setup:**
- [ ] CloudWatch dashboard created
- [ ] Alarms created (CPU, memory, errors)
- [ ] Can view in AWS console

**Prometheus & Grafana:**
- [ ] Prometheus stack installed (`kubectl get pods -n monitoring`)
- [ ] Prometheus LoadBalancer has external IP
- [ ] Grafana LoadBalancer has external IP
- [ ] Can access Grafana UI
- [ ] Can access Prometheus UI

**Dashboards:**
- [ ] Pre-built Kubernetes dashboards visible
- [ ] Created custom Memos dashboard
- [ ] Dashboard shows metrics (requests, latency, errors)

**Alerting:**
- [ ] Alert rules created
- [ ] Alerts showing in Prometheus UI
- [ ] AlertManager running

**Verification:**
- [ ] Can access all three dashboards
- [ ] Metrics being collected
- [ ] Logs appearing in CloudWatch
- [ ] Alerts functional

---

## 💡 Key Takeaways

**After Stage 6, you'll understand:**

✅ **Observability principles** - Metrics, logs, traces  
✅ **CloudWatch integration** - AWS infrastructure monitoring  
✅ **Prometheus** - Application metrics collection  
✅ **Grafana** - Beautiful dashboards  
✅ **Alerting** - Automated notifications  
✅ **Log queries** - Find issues in logs  
✅ **Four golden signals** - What to monitor  
✅ **Best practices** - Monitoring done right  

---

## 🔄 Dashboard Workflow

### Normal Day (Everything Good)
```
Grafana Dashboard
├─ ✅ Error rate: 0.1%
├─ ✅ Latency p95: 234ms
├─ ✅ CPU: 35%
├─ ✅ Memory: 62%
└─ ✅ All pods healthy

→ No alerts
→ Team is happy
→ Sleep well
```

### Something Goes Wrong
```
Alert fires: "High Error Rate"

→ Check Grafana dashboard
   Error rate jumped to 8%!

→ Check Prometheus
   Which endpoint has errors?

→ Check CloudWatch logs
   "Database connection timeout"

→ Check RDS
   Connection pool exhausted

→ Scale RDS
→ Error rate drops to 0.1%
→ Alert clears
```

---

## 🛠️ Four Golden Signals

### 1. Latency - How fast is it?
```
Dashboard panel:
- Request latency p50: 45ms
- Request latency p95: 234ms
- Request latency p99: 1200ms

Alert: p95 > 1s
```

### 2. Traffic - How many requests?
```
Dashboard panel:
- Requests per second: 1,234

Alert: Traffic drops suddenly (possible outage)
```

### 3. Errors - What percentage fail?
```
Dashboard panel:
- Error rate: 0.1% (blue = ok)
- 5xx errors: 1 per minute
- 4xx errors: 10 per minute

Alert: Error rate > 1%
```

### 4. Saturation - How "full" are resources?
```
Dashboard panel:
- CPU: 45%
- Memory: 62%
- Disk: 28%
- DB connections: 15/100

Alert: Any > 80%
```

---

## 📈 Dashboard Recommendations

**Dashboard 1: System Health (Top Level)**
- Node count (should be 2)
- Pod count (should be 3 for memos)
- CPU across all nodes
- Memory across all nodes
- Network in/out

**Dashboard 2: Application Performance**
- Requests per second
- Error rate
- Latency p95
- Database query latency
- Pod resource usage

**Dashboard 3: Database**
- Active connections
- Query latency
- CPU usage
- Disk usage
- Backup status

**Dashboard 4: Business Metrics (Optional)**
- Total notes created
- Active users today
- Revenue/tier distribution
- User retention

---

## 🎓 Practice Scenarios

### Scenario 1: Troubleshoot High Latency
```
1. Alert: "Latency p95 > 1s"
2. Open Grafana dashboard
3. See: Database queries slow (not app)
4. Check CloudWatch logs
5. Find: RDS CPU at 95%
6. Action: Scale RDS instance
7. Result: Latency drops, alert clears
```

### Scenario 2: Pod Keeps Crashing
```
1. Monitoring shows: memos pod restarting
2. Check pod logs: "Out of memory"
3. Grafana shows: Memory usage at 95%
4. Action: Increase pod memory request
5. Redeploy (via Git + ArgoCD)
6. Result: Pod stable
```

### Scenario 3: High Error Rate
```
1. Alert: "High Error Rate (8%)"
2. Dashboard shows: Errors spike at 2:15pm
3. CloudWatch Logs query: All errors are "Database timeout"
4. Check: RDS connection pool exhausted
5. Action: Increase connection pool
6. Result: Error rate drops to 0.1%
```

---

## ⏳ Time Estimate

| Task | Time |
|------|------|
| Read conceptual guide | 45 min |
| Install Prometheus stack | 15 min |
| Access dashboards | 10 min |
| Create custom dashboard | 15 min |
| Set up alerts | 10 min |
| Test queries | 10 min |
| Troubleshoot | 10 min |
| **Total** | **~115 min** |

---

## 🎯 Success Criteria

**Stage 6 is complete when:**

✅ CloudWatch dashboards show cluster metrics  
✅ Prometheus is scraping metrics  
✅ Grafana dashboards are visible  
✅ Custom Memos dashboard created  
✅ Alert rules are active  
✅ Can query logs in CloudWatch Insights  
✅ Understood four golden signals  
✅ All code committed to GitHub  

---

## 📞 If Something Goes Wrong

**Prometheus pods not running:**
```bash
kubectl describe pod -n monitoring <pod-name>
kubectl logs -n monitoring <pod-name>
```

**Can't access Grafana:**
```bash
# Verify LoadBalancer has external IP
kubectl get svc -n monitoring prometheus-grafana

# Use port forwarding if needed
kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80
# Access at: http://localhost:3000
```

**Metrics not appearing:**
```bash
# Check Prometheus targets
# Go to http://<prometheus-lb>:9090/targets
# Verify targets are scraping

# Force refresh
kubectl rollout restart deployment prometheus-operator -n monitoring
```

**Can't query logs:**
```bash
# Check CloudWatch has logs
aws logs describe-log-groups --region us-west-1

# Verify log group name
aws logs tail /aws/eks/memos-eks/cluster --region us-west-1
```

---

## 🎓 Learning Resources

- **[Prometheus Official Docs](https://prometheus.io/docs/)**
- **[Grafana Docs](https://grafana.com/docs/grafana/)**
- **[CloudWatch Docs](https://docs.aws.amazon.com/cloudwatch/)**
- **[Google SRE Book - Monitoring](https://sre.google/sre-book/monitoring-distributed-systems/)**
- **[Prometheus Best Practices](https://prometheus.io/docs/practices/naming/)**

---

## 🎉 ALL 6 STAGES COMPLETE!

You've built a complete production DevOps infrastructure:

```
┌─────────────────────────────────────────────┐
│  COMPLETE MEMOS DEPLOYMENT INFRASTRUCTURE  │
├─────────────────────────────────────────────┤
│ Stage 1: Docker Containerization        ✅  │
│ Stage 2: Terraform Infrastructure       ✅  │
│ Stage 3: Kubernetes Deployment          ✅  │
│ Stage 4: GitOps with ArgoCD             ✅  │
│ Stage 5: CI/CD with GitHub Actions      ✅  │
│ Stage 6: Monitoring & Observability     ✅  │
└─────────────────────────────────────────────┘

Total Infrastructure:
- 50+ AWS resources
- 100+ Kubernetes resources
- 5+ automated workflows
- 10,000+ lines documentation
- 100% GitOps driven
- 100% monitored
```

---

## 📝 Final Git Commit Template

```bash
git commit -m "Stage 6: Monitoring & Observability - PROJECT COMPLETE! 🎉

Implemented comprehensive observability:

CloudWatch:
✅ EKS cluster dashboard
✅ RDS database monitoring
✅ Load balancer metrics
✅ CloudWatch alarms (CPU, memory, errors)
✅ Control plane logs
✅ CloudWatch Logs Insights queries

Prometheus + Grafana:
✅ kube-prometheus-stack on EKS
✅ Prometheus metrics collection
✅ Grafana dashboards (system, app, database)
✅ AlertManager configuration

Monitoring Strategy:
✅ Four golden signals
✅ Alert rules (critical, warning, info)
✅ Log aggregation and search
✅ Custom application metrics

PROJECT COMPLETE - All 6 Stages Finished:
✅ Docker containerization
✅ Terraform infrastructure (50+ resources)
✅ Kubernetes deployment to EKS
✅ GitOps automation with ArgoCD
✅ CI/CD pipeline with GitHub Actions
✅ Full observability stack

Infrastructure:
- VPC: 10.0.0.0/16 with 2 AZs
- EKS: v1.31, 2 nodes, OIDC enabled
- RDS: PostgreSQL 15, encrypted, backups
- ECR: Image registry with scanning
- ArgoCD: Git-driven deployments
- GitHub Actions: Build & deploy automation
- Prometheus: Metrics collection
- Grafana: Beautiful dashboards
- CloudWatch: AWS infrastructure monitoring

Total Learning Time: ~10-15 days
Total Infrastructure Cost: ~$200-300/month

Ready for production! 🚀"

git push origin main
```

---

## 🚀 Next Steps (After Project)

**Maintenance:**
- Monitor dashboards daily
- Respond to alerts
- Update dependencies quarterly

**Enhancements:**
- Add distributed tracing (Jaeger)
- Implement cost allocation
- Set up disaster recovery
- Multi-region deployment

**Scaling:**
- Add more environments (staging, prod)
- Implement A/B testing
- Set up canary deployments
- Add service mesh (Istio)

**Compliance:**
- Add security scanning
- Implement audit logging
- Set up compliance dashboards
- Document runbooks

---

**Congratulations! You've completed a full production DevOps learning project!** 🎉

From containerization to monitoring, you've learned every step of modern cloud-native deployment. You're now equipped to build and operate production systems on AWS!
