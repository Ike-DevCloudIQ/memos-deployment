# Stage 6: Complete Execution Checklist

> **Step-by-step guide to go from zero to full observability**

---

## 🎯 Overview

This checklist guides you through Stage 6 in two phases:

**Phase 1: Automated Setup** (terminal commands)  
**Phase 2: Manual UI Work** (Grafana + CloudWatch)

Total time: 2-3 hours

---

## PHASE 1: Automated Setup (Terminal)

### ✅ Check Prerequisites

```bash
# 1. Verify AWS credentials
aws sts get-caller-identity

# Expected output:
# {
#   "Account": "123456789",
#   "UserId": "AIDAI...",
#   "Arn": "arn:aws:iam::123456789:root"
# }

# 2. Verify EKS cluster
aws eks update-kubeconfig --name memos-eks --region us-west-1
kubectl get nodes

# Expected: 2 nodes with STATUS=Ready
```

### ✅ Enable CloudWatch Logging

```bash
# Enable EKS control plane logging to CloudWatch
aws eks update-cluster-config \
  --name memos-eks \
  --logging-config '{
    "clusterLogging": [
      {
        "types": ["api", "audit", "authenticator", "controllerManager", "scheduler"],
        "enabled": true,
        "logRetentionInDays": 7
      }
    ]
  }' \
  --region us-west-1

# ⏳ Wait 2-3 minutes for logs to appear

# Verify logs
aws logs tail /aws/eks/memos-eks/cluster --region us-west-1 --follow
```

### ✅ Install Prometheus Stack

```bash
# 1. Add Helm repos
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# 2. Create monitoring namespace
kubectl create namespace monitoring

# 3. Install Prometheus stack
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.retention=15d \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=10Gi \
  --set grafana.adminPassword=admin

# ⏳ Wait ~2-3 minutes

# 4. Wait for all pods
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/part-of=kube-prometheus-stack \
  -n monitoring \
  --timeout=300s

# Verify
kubectl get pods -n monitoring
# Expected: prometheus, grafana, alertmanager, node-exporter all Running
```

### ✅ Expose Prometheus & Grafana

```bash
# 1. Expose Prometheus
kubectl patch svc prometheus-kube-prom-prometheus \
  -n monitoring \
  -p '{"spec": {"type": "LoadBalancer"}}'

# 2. Expose Grafana
kubectl patch svc prometheus-grafana \
  -n monitoring \
  -p '{"spec": {"type": "LoadBalancer"}}'

# ⏳ Wait ~1 minute for external IPs

# 3. Get URLs
PROMETHEUS_URL=$(kubectl get svc prometheus-kube-prom-prometheus -n monitoring \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
GRAFANA_URL=$(kubectl get svc prometheus-grafana -n monitoring \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "Prometheus: http://$PROMETHEUS_URL:9090"
echo "Grafana: http://$GRAFANA_URL:3000"
echo ""
echo "Grafana login:"
echo "  Username: admin"
echo "  Password: admin"
```

### ✅ Create CloudWatch Alarms

```bash
# 1. High CPU alarm
aws cloudwatch put-metric-alarm \
  --alarm-name memos-high-cpu \
  --alarm-description "Alert when node CPU > 80%" \
  --metric-name CPUUtilization \
  --namespace AWS/EC2 \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2

# 2. High memory alarm
aws cloudwatch put-metric-alarm \
  --alarm-name memos-high-memory \
  --alarm-description "Alert when pod memory > 85%" \
  --metric-name MemoryUtilization \
  --namespace AWS/ECS \
  --statistic Average \
  --period 300 \
  --threshold 85 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2

# 3. High error rate alarm
aws cloudwatch put-metric-alarm \
  --alarm-name memos-high-errors \
  --alarm-description "Alert when error rate > 5%" \
  --metric-name HTTPErrorCount \
  --namespace AWS/ApplicationELB \
  --statistic Sum \
  --period 60 \
  --threshold 5 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 1

echo "✅ CloudWatch alarms created"
```

### ✅ Verify Everything Running

```bash
# Check all components
kubectl get pods -n monitoring

echo ""
echo "Checking Prometheus targets..."
kubectl port-forward svc/prometheus-kube-prom-prometheus -n monitoring 9090:9090 &

# Wait 2 seconds
sleep 2

# Open: http://localhost:9090/targets
# Should show 50+ targets being scraped

echo ""
echo "✅ Phase 1 Complete!"
```

---

## PHASE 2: Manual UI Work

### Time: 60-90 minutes

---

## STEP 1: Access Grafana Dashboard

### 1.1 Get Grafana URL

```bash
# From terminal:
GRAFANA_URL=$(kubectl get svc prometheus-grafana -n monitoring \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "Grafana URL: http://$GRAFANA_URL:3000"
```

### 1.2 Open in Browser

1. Copy the URL from above
2. Paste in browser: `http://<url>:3000`
3. Login with:
   - Username: `admin`
   - Password: `admin`

### 1.3 First Time Setup (Change Password)

1. You'll see "Welcome to Grafana"
2. Click **Settings** (gear icon, bottom left)
3. Click **Admin** → **Users**
4. Click **admin** user
5. Click **"Change password"**
6. Enter new password (recommend: `YourSecurePassword123`)
7. Click **"Update"**

---

## STEP 2: Create Memos Application Dashboard

### 2.1 Create New Dashboard

1. Click **"Dashboards"** in left sidebar
2. Click **"New"** (top right)
3. Click **"New Dashboard"**

**Expected:** Blank dashboard screen

### 2.2 Add Panel 1: Requests Per Second

1. Click **"Add a new panel"**
2. In the metric field, paste:
   ```
   rate(http_requests_total[5m])
   ```
3. Click **"Run query"** (blue button)
4. Set:
   - **Title:** "Requests Per Second"
   - **Unit:** "short"
   - **Decimals:** 0
5. Click **"Apply"** (bottom right)

### 2.3 Add Panel 2: Error Rate

1. Click **"Add a new panel"**
2. Paste query:
   ```
   rate(http_requests_total{status=~"5.."}[5m]) * 100
   ```
3. Set:
   - **Title:** "Error Rate (%)"
   - **Unit:** "percent"
   - **Color scheme:** "Red (critical)"
   - **Thresholds:** 1 (yellow), 5 (red)
4. Click **"Apply"**

### 2.4 Add Panel 3: Latency p95

1. Click **"Add a new panel"**
2. Paste query:
   ```
   histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
   ```
3. Set:
   - **Title:** "Latency p95 (seconds)"
   - **Unit:** "s"
   - **Decimals:** 3
   - **Thresholds:** 0.5 (yellow), 1 (red)
4. Click **"Apply"**

### 2.5 Add Panel 4: Pod Memory

1. Click **"Add a new panel"**
2. Paste query:
   ```
   container_memory_usage_bytes{pod=~"memos-.*"} / 1024 / 1024
   ```
3. Set:
   - **Title:** "Memory Usage (MB)"
   - **Unit:** "short"
   - **Max value:** 1024
4. Click **"Apply"**

### 2.6 Add Panel 5: Pod CPU

1. Click **"Add a new panel"**
2. Paste query:
   ```
   rate(container_cpu_usage_seconds_total{pod=~"memos-.*"}[5m]) * 100
   ```
3. Set:
   - **Title:** "CPU Usage (%)"
   - **Unit:** "percent"
   - **Max value:** 100
4. Click **"Apply"**

### 2.7 Add Panel 6: Node CPU

1. Click **"Add a new panel"**
2. Paste query:
   ```
   (1 - avg(rate(node_cpu_seconds_total{mode="idle"}[5m]))) * 100
   ```
3. Set:
   - **Title:** "Node CPU (%)"
   - **Unit:** "percent"
4. Click **"Apply"**

### 2.8 Add Panel 7: Node Memory

1. Click **"Add a new panel"**
2. Paste query:
   ```
   (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100
   ```
3. Set:
   - **Title:** "Node Memory (%)"
   - **Unit:** "percent"
   - **Max value:** 100
4. Click **"Apply"**

### 2.9 Save Dashboard

1. Click **"Save"** (top right, or Ctrl+S)
2. Dashboard name: `Memos Application Metrics`
3. Tags: `memos`, `application`, `production`
4. Click **"Save"**

### 2.10 Set Auto-Refresh

1. Click clock icon (top right)
2. Select **"30s"** (auto-refresh every 30 seconds)
3. Your dashboard now updates live!

**✅ Check:**
- [ ] Dashboard saved
- [ ] All 7 panels showing data
- [ ] Can see real-time metrics
- [ ] Auto-refresh working

---

## STEP 3: CloudWatch Logs Insights Queries

### 3.1 Access Logs Insights

1. Go to: https://console.aws.amazon.com/cloudwatch
2. Click **"Logs"** in left sidebar
3. Click **"Logs Insights"**

### 3.2 Run Query 1: Errors by Type

1. Select log group: `/aws/eks/memos-eks/cluster`
2. Copy-paste query:
   ```
   fields @timestamp, @message, error_type
   | filter @message like /ERROR/
   | stats count() as errors by error_type
   | sort errors desc
   ```
3. Click **"Run query"**
4. **Save** this query as `Errors by Type - Last Hour`

**Result:** Table showing error counts

### 3.3 Run Query 2: Slow Requests

1. Copy-paste query:
   ```
   fields @timestamp, @duration, @request_path, @status
   | filter @duration > 1000
   | stats count() as slow_requests, avg(@duration) as avg_duration by @request_path
   | sort slow_requests desc
   ```
2. Click **"Run query"**
3. **Save** as `Slow Requests`

**Result:** Endpoints taking > 1 second

### 3.4 Run Query 3: Request Rate

1. Copy-paste query:
   ```
   fields @timestamp
   | stats count() as requests by bin(1m)
   | sort @timestamp desc
   ```
2. Click **"Run query"**

**Result:** Traffic over time

### 3.5 Run Query 4: Top Endpoints

1. Copy-paste query:
   ```
   fields @request_path
   | stats count() as requests by @request_path
   | sort requests desc
   | limit 10
   ```
2. Click **"Run query"**

**Result:** Most popular endpoints

### 3.6 Run Query 5: Error Rate Per Endpoint

1. Copy-paste query:
   ```
   fields @request_path, @status
   | filter @status >= 400
   | stats count() as errors by @request_path, @status
   | sort errors desc
   ```
2. Click **"Run query"**

**Result:** Which endpoints have errors

**✅ Check:**
- [ ] All 5 queries returning results
- [ ] At least 2 queries saved
- [ ] Can modify and re-run queries

---

## STEP 4: Create CloudWatch Dashboard

### 4.1 Create Dashboard

1. Go to **CloudWatch** → **Dashboards**
2. Click **"Create dashboard"**
3. Name: `Memos Infrastructure`
4. Click **"Create dashboard"**

### 4.2 Add Metrics Widget

1. Click **"Add widget"** → **"Metrics"**
2. Add:
   - **EKS Node CPU**
   - **EKS Node Memory**
   - **Pod CPU**
   - **Pod Memory**

### 4.3 Add Logs Widget

1. Click **"Add widget"** → **"Logs"**
2. Paste one of the Logs Insights queries
3. Click **"Create widget"**

### 4.4 Set Auto-Refresh

1. Click **"Auto-refresh"** (top right)
2. Select **"1 minute"**

**✅ Check:**
- [ ] CloudWatch dashboard created
- [ ] Metrics visible
- [ ] Logs widget shows data

---

## STEP 5: View Pre-built Kubernetes Dashboards

1. Go back to **Grafana Dashboards**
2. You should see pre-installed dashboards:
   - **Kubernetes / System / Cluster**
   - **Kubernetes / Compute Resources / Namespace**
   - **Kubernetes / Compute Resources / Pod**
   - **Node Exporter for Prometheus**

3. Click on **"Kubernetes / System / Cluster"**

**See:**
- Cluster overview
- Node status
- Pod status
- Resource usage

---

## STEP 6: Verify Everything Works

### 6.1 Check Grafana

```bash
# In Grafana:
1. Click "Dashboards" → "Memos Application Metrics"
2. Verify all panels show data
3. Watch metrics update in real-time
```

### 6.2 Check CloudWatch

```bash
# In CloudWatch:
1. Go to Logs Insights
2. Run one of the saved queries
3. Should return results immediately
```

### 6.3 Check Prometheus

```bash
# Get Prometheus URL
PROMETHEUS_URL=$(kubectl get svc prometheus-kube-prom-prometheus -n monitoring \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Open: http://$PROMETHEUS_URL:9090
# Navigate to: Status → Targets
# Should show 50+ targets scraping successfully
```

---

## Final Checklist

### Phase 1: Automated ✅
- [ ] AWS credentials verified
- [ ] EKS cluster verified
- [ ] CloudWatch logging enabled
- [ ] Prometheus stack installed
- [ ] Grafana & Prometheus exposed
- [ ] CloudWatch alarms created

### Phase 2: Manual UI ✅
- [ ] Accessed Grafana at LoadBalancer URL
- [ ] Created "Memos Application Metrics" dashboard
- [ ] Added all 7 panels to dashboard
- [ ] Dashboard auto-refreshing every 30s
- [ ] Ran 5 CloudWatch Logs Insights queries
- [ ] Saved at least 2 queries
- [ ] Created CloudWatch dashboard
- [ ] Verified Prometheus targets

### Dashboards Working ✅
- [ ] Grafana dashboard shows live metrics
- [ ] CloudWatch dashboard shows infrastructure
- [ ] CloudWatch Logs Insights queries working
- [ ] Can create custom queries
- [ ] All components responding

---

## Success!

**You now have:**

✅ **Real-time Grafana dashboards** with 7 key metrics  
✅ **CloudWatch infrastructure monitoring** for AWS resources  
✅ **Logs Insights** for searching and troubleshooting  
✅ **Automated alarms** for critical conditions  
✅ **Pre-built Kubernetes dashboards** for cluster health  

**You can now:**
- See application performance in real-time
- Troubleshoot issues with logs
- Get alerts when problems occur
- Track infrastructure usage
- Create custom dashboards for any metric

---

## Commit All Work

```bash
cd ~/Desktop/Nouriva/memos-deployment

git add \
  docs/STAGE6_MONITORING.md \
  STAGE6_QUICK_REFERENCE.md \
  STAGE6_COMPLETION_GUIDE.md \
  docs/STAGE6_UI_WORKFLOW.md \
  README.md

git commit -m "Stage 6: Complete - All dashboards operational

Phase 1 (Automated):
✅ CloudWatch logging enabled
✅ Prometheus + Grafana installed
✅ CloudWatch alarms created
✅ All components running

Phase 2 (Manual UI):
✅ Grafana dashboard: Memos Application Metrics
✅ 7 real-time monitoring panels
✅ CloudWatch Logs Insights queries (5 templates)
✅ CloudWatch infrastructure dashboard
✅ Pre-built Kubernetes dashboards

Monitoring Active:
✅ Requests/sec
✅ Error rate (%)
✅ Latency p95
✅ Pod resources (CPU, memory)
✅ Node resources (CPU, memory)
✅ Log aggregation & search
✅ Automated alerting

PROJECT COMPLETE: Docker → Terraform → K8s → GitOps → CI/CD → Monitoring"

git push origin main
```

---

## 🎉 Project Complete!

All 6 stages finished with full production infrastructure!

Go celebrate! 🚀
