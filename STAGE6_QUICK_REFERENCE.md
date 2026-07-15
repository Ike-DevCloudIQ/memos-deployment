# Stage 6: Monitoring & Observability - QUICK REFERENCE

> **Copy-paste commands to set up CloudWatch, Prometheus, and Grafana dashboards**

---

## Part 1: Prerequisites

### Step 1.1: Verify EKS cluster running

```bash
# Update kubeconfig
aws eks update-kubeconfig --name memos-eks --region us-west-1

# Verify cluster access
kubectl get nodes

# Expected: 2 nodes with STATUS=Ready
```

### Step 1.2: Install monitoring tools (Mac)

```bash
# Install helm
brew install helm

# Verify
helm version
```

---

## Part 2: CloudWatch Dashboard (AWS Infrastructure)

### Step 2.1: Create CloudWatch Namespace & Dashboards

```bash
# Create dashboard for EKS cluster
aws cloudwatch put-dashboard \
  --dashboard-name "Memos-EKS-Cluster" \
  --dashboard-body '{
    "widgets": [
      {
        "type": "metric",
        "properties": {
          "metrics": [
            ["AWS/EKS", "cluster_node_count", {"stat": "Average"}],
            ["AWS/EKS", "cluster_requests_count", {"stat": "Sum"}]
          ],
          "period": 300,
          "stat": "Average",
          "region": "us-west-1",
          "title": "EKS Cluster Health"
        }
      }
    ]
  }'

echo "CloudWatch dashboard created: Memos-EKS-Cluster"
```

### Step 2.2: Create CloudWatch Alarms

```bash
# Alert if CPU too high
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

# Alert if memory too high
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

# Alert if error rate too high
aws cloudwatch put-metric-alarm \
  --alarm-name memos-high-errors \
  --alarm-description "Alert when error rate > 5%" \
  --metric-name HTTPCode_ELB_5XX_Count \
  --namespace AWS/ApplicationELB \
  --statistic Sum \
  --period 60 \
  --threshold 5 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 1

echo "CloudWatch alarms created"
```

### Step 2.3: View CloudWatch Dashboards

```bash
# Go to AWS Console
echo "Open: https://console.aws.amazon.com/cloudwatch"
echo "Navigate to: Dashboards → Memos-EKS-Cluster"

# Or view via CLI
aws cloudwatch get-dashboard --region us-west-1 --dashboard-name Memos-EKS-Cluster
```

---

## Part 3: Enable EKS Control Plane Logging

### Step 3.1: Enable CloudWatch Logs for EKS

```bash
# Update EKS cluster to log to CloudWatch
aws eks update-cluster-config \
  --name memos-eks \
  --logging '{
    "clusterLogging": [
      {
        "types": ["api", "audit", "authenticator", "controllerManager", "scheduler"],
        "enabled": true
      }
    ]
  }' \
  --region us-west-1

echo "EKS control plane logging enabled"
```

### Step 3.2: Verify logs appearing in CloudWatch

```bash
# Wait 2-3 minutes for logs to appear
sleep 120

# Check log groups
aws logs describe-log-groups --region us-west-1

# Expected:
# /aws/eks/memos-eks/cluster

# Query the logs
aws logs tail /aws/eks/memos-eks/cluster --region us-west-1 --follow
```

---

## Part 4: Install Prometheus on EKS

### Step 4.1: Add Helm Repository

```bash
# Add Prometheus Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

# Add Grafana Helm repo
helm repo add grafana https://grafana.github.io/helm-charts

# Update repos
helm repo update

# Ensure EBS CSI addon exists for Prometheus PVC provisioning
eksctl utils associate-iam-oidc-provider --cluster memos-eks --region us-west-1 --approve
aws eks create-addon \
  --cluster-name memos-eks \
  --addon-name aws-ebs-csi-driver \
  --region us-west-1 \
  --resolve-conflicts OVERWRITE || true
```

### Step 4.2: Install Prometheus Stack (Prometheus + Grafana)

```bash
# Create namespace
kubectl create namespace monitoring || true

# Install Prometheus stack (includes Prometheus, Grafana, AlertManager)
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.retention=15d \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=10Gi \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName=gp2 \
  --set grafana.adminPassword=admin

echo "Prometheus stack installing..."
```

### Step 4.3: Wait for all pods to be ready

```bash
# Wait for pods
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/instance=prometheus \
  -n monitoring \
  --timeout=300s

# Verify all running
kubectl get pods -n monitoring

# Expected:
# prometheus-operator-xxx     Running
# prometheus-0                Running
# grafana-xxx                 Running
# alertmanager-0              Running
# node-exporter-xxx           Running (on each node)
# kube-state-metrics-xxx      Running
```

### Step 4.4: Expose Prometheus and Grafana

```bash
# Make Prometheus accessible
kubectl patch svc prometheus-kube-prometheus-prometheus \
  -n monitoring \
  -p '{"spec": {"type": "LoadBalancer"}}'

# Make Grafana accessible
kubectl patch svc prometheus-grafana \
  -n monitoring \
  -p '{"spec": {"type": "LoadBalancer"}}'

# Get external IPs
echo "Waiting for LoadBalancers to get external IPs..."
sleep 30

PROMETHEUS_URL=$(kubectl get svc prometheus-kube-prometheus-prometheus -n monitoring \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
GRAFANA_URL=$(kubectl get svc prometheus-grafana -n monitoring \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "Prometheus: http://$PROMETHEUS_URL:9090"
echo "Grafana: http://$GRAFANA_URL:80"
```

### Step 4.5: Access Prometheus

```bash
# Get Prometheus URL
PROMETHEUS_URL=$(kubectl get svc prometheus-kube-prometheus-prometheus -n monitoring \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "Open Prometheus: http://$PROMETHEUS_URL:9090"
echo "Try a query: up (shows which targets are scraping)"
```

---

## Part 5: Access Grafana Dashboards

### Step 5.1: Get Grafana login credentials

```bash
# Username: admin
# Password: admin (from helm install above)
# Or retrieve from secret:
kubectl get secret --namespace monitoring prometheus-grafana \
  -o jsonpath="{.data.admin-password}" | base64 --decode; echo
```

### Step 5.2: Access Grafana

```bash
# Get Grafana URL
GRAFANA_URL=$(kubectl get svc prometheus-grafana -n monitoring \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "Open Grafana: http://$GRAFANA_URL:80"
echo "Username: admin"
echo "Password: admin"
```

### Step 5.3: View Pre-built Dashboards

In Grafana UI:
1. Click "Dashboards"
2. Browse these pre-installed dashboards:
   - **Kubernetes / Compute Resources / Namespace**
   - **Kubernetes / Compute Resources / Pod**
   - **Kubernetes / Networking / Namespace (Pods)**
   - **Kubernetes / System / Cluster**
   - **Node Exporter for Prometheus**

---

## Part 6: Create Custom Memos Dashboard

### Step 6.1: Add Prometheus as Data Source in Grafana

In Grafana UI:
1. Go to: **Configuration** → **Data Sources**
2. Click: **Add data source**
3. Select: **Prometheus**
4. URL: `http://prometheus-kube-prometheus-prometheus:9090`
5. Click: **Save & Test**

### Step 6.2: Create Dashboard for Memos Metrics

In Grafana UI:
1. Go to: **Dashboards** → **New Dashboard**
2. Click: **Add a new panel**
3. Add these panels:

**Panel 1: Request Rate**
- Metric: `rate(http_requests_total[5m])`
- Title: "Requests Per Second"

**Panel 2: Error Rate**
- Metric: `rate(http_requests_total{status=~"5.."}[5m])`
- Title: "Error Rate"

**Panel 3: Request Latency**
- Metric: `histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))`
- Title: "Latency p95"

**Panel 4: Pod Memory**
- Metric: `container_memory_usage_bytes{pod="memos"}`
- Title: "Memory Usage"

**Panel 5: Pod CPU**
- Metric: `rate(container_cpu_usage_seconds_total{pod="memos"}[5m])`
- Title: "CPU Usage"

4. Click: **Save** as "Memos Application Metrics"

---

## Part 7: Set Up Prometheus Alerts

### Step 7.1: Create AlertManager Configuration

```bash
# Create AlertManager config with Slack integration (optional)
cat > /tmp/alertmanager-config.yaml << 'EOF'
global:
  resolve_timeout: 5m

route:
  group_by: ['alertname', 'cluster', 'service']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h
  receiver: 'null'
  
  routes:
    - match:
        severity: critical
      receiver: 'pagerduty'
    - match:
        severity: warning
      receiver: 'slack'

receivers:
  - name: 'null'
  
  - name: 'slack'
    slack_configs:
      - api_url: 'YOUR_SLACK_WEBHOOK_URL'
        channel: '#alerts'
        title: '{{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
  
  - name: 'pagerduty'
    pagerduty_configs:
      - service_key: 'YOUR_PAGERDUTY_KEY'
EOF

# Update AlertManager (if using Slack)
# kubectl create secret generic alertmanager-secrets \
#   --from-file=/tmp/alertmanager-config.yaml \
#   -n monitoring \
#   --dry-run=client -o yaml | kubectl apply -f -
```

### Step 7.2: Create Alert Rules

```bash
# Create Prometheus rules for Memos
cat > /tmp/memos-rules.yaml << 'EOF'
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: memos-alerts
  namespace: monitoring
spec:
  groups:
    - name: memos.rules
      interval: 30s
      rules:
        # Alert: High Error Rate
        - alert: HighErrorRate
          expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.05
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "High error rate detected"
            description: "Error rate is {{ $value | humanizePercentage }}"

        # Alert: High Latency
        - alert: HighLatency
          expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 1
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "High request latency"
            description: "p95 latency is {{ $value }}s"

        # Alert: High Memory
        - alert: PodHighMemory
          expr: container_memory_usage_bytes{pod="memos"} / 1024 / 1024 > 500
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Pod memory usage high"
            description: "Memory is {{ $value | humanize }}MB"

        # Alert: High CPU
        - alert: PodHighCPU
          expr: rate(container_cpu_usage_seconds_total{pod="memos"}[5m]) > 0.8
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Pod CPU usage high"
            description: "CPU is {{ $value | humanizePercentage }}"
EOF

# Apply the rules
kubectl apply -f /tmp/memos-rules.yaml

echo "Alert rules created"
```

### Step 7.3: View Alerts

In Prometheus UI:
```bash
# Get Prometheus URL
PROMETHEUS_URL=$(kubectl get svc prometheus-kube-prometheus-prometheus -n monitoring \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "Open: http://$PROMETHEUS_URL:9090"
echo "Go to: Alerts tab"
echo "See all defined alerts and their status"
```

---

## Part 8: Create Application Metrics (Optional)

### Step 8.1: Add Prometheus Metrics to Memos App

In your Go code (`app/server/main.go`):

```go
import (
    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promauto"
    "github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
    httpRequestsTotal = promauto.NewCounterVec(
        prometheus.CounterOpts{
            Name: "http_requests_total",
            Help: "Total HTTP requests",
        },
        []string{"method", "endpoint", "status"},
    )
    
    httpRequestDuration = promauto.NewHistogramVec(
        prometheus.HistogramOpts{
            Name:    "http_request_duration_seconds",
            Help:    "HTTP request duration",
            Buckets: []float64{0.01, 0.05, 0.1, 0.5, 1},
        },
        []string{"method", "endpoint"},
    )
)

// In your HTTP handler:
// Track metrics
httpRequestsTotal.WithLabelValues(r.Method, r.URL.Path, "200").Inc()
httpRequestDuration.WithLabelValues(r.Method, r.URL.Path).Observe(elapsed)

// Expose metrics endpoint
http.Handle("/metrics", promhttp.Handler())
```

### Step 8.2: Annotate Deployment for Scraping

In `k8s/deployment.yaml`:

```yaml
spec:
  template:
    metadata:
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "5230"
        prometheus.io/path: "/metrics"
    spec:
      containers:
        - name: memos
          ports:
            - name: http
              containerPort: 5230
            - name: metrics
              containerPort: 5230
```

Prometheus will automatically scrape the `/metrics` endpoint every 15 seconds.

---

## Part 9: CloudWatch Logs Insights Queries

### Step 9.1: Search Application Logs

```bash
# Open CloudWatch Logs Insights
# https://console.aws.amazon.com/cloudwatch/logs/insights

# Query 1: Count errors by type in last hour
fields @timestamp, @message, error_type
| filter @message like /ERROR/
| stats count() by error_type

# Query 2: Find slow requests (> 1 second)
fields @timestamp, @duration, @request_path
| filter @duration > 1000
| sort @duration desc

# Query 3: Request rate per minute
fields @timestamp
| stats count() as requests by bin(5m)

# Query 4: Top 10 endpoints by request count
fields @request_path
| stats count() as requests by @request_path
| sort requests desc
| limit 10

# Query 5: Error rate per endpoint
fields @request_path, @status
| filter @status >= 400
| stats count() as errors by @request_path
```

---

## Part 10: Commit to Git

```bash
cd ~/Desktop/Nouriva/memos-deployment

git add docs/STAGE6_MONITORING.md STAGE6_QUICK_REFERENCE.md README.md

git commit -m "Stage 6: Monitoring & Observability - COMPLETE

Implemented full observability stack:

CloudWatch:
✅ EKS cluster dashboard
✅ CloudWatch alarms (CPU, memory, errors)
✅ CloudWatch Logs for control plane
✅ CloudWatch Logs Insights for querying

Prometheus + Grafana:
✅ Installed kube-prometheus-stack on EKS
✅ Prometheus metrics scraping
✅ Grafana dashboards
✅ Pre-built Kubernetes dashboards

Alerting:
✅ AlertManager configuration
✅ Alert rules (high error rate, latency, CPU)
✅ Slack/PagerDuty integration ready

Monitoring:
✅ Four golden signals (latency, traffic, errors, saturation)
✅ Custom application metrics ready
✅ Log aggregation and search

Status: Stage 6 COMPLETE - All 6 stages done!

Architecture complete:
Docker → Terraform → Kubernetes → GitOps → CI/CD → Monitoring"

git push origin main
```

---

## ✅ Stage 6 Complete - Project Finished!

**You now have:**

✅ **Infrastructure as Code** - Terraform for AWS VPC, EKS, RDS  
✅ **Containerization** - Docker multi-stage builds  
✅ **Kubernetes** - Deployed to EKS cluster  
✅ **GitOps** - ArgoCD auto-deploys from Git  
✅ **CI/CD** - GitHub Actions auto-builds and deploys  
✅ **Monitoring** - Full observability with CloudWatch, Prometheus, Grafana  

**Dashboard URLs:**
```
Grafana:     http://<grafana-lb>:3000
Prometheus:  http://<prometheus-lb>:9090
CloudWatch:  https://console.aws.amazon.com/cloudwatch
```

**Next Steps:**
- Monitor in production
- Set up on-call rotations
- Document runbooks
- Plan disaster recovery
- Scale to multi-region

---

## Learning Outcomes

After all 6 stages you can:

✅ Build containerized applications  
✅ Deploy infrastructure with Terraform  
✅ Run apps on Kubernetes  
✅ Automate deployments with GitOps  
✅ Build CI/CD pipelines  
✅ Monitor production systems  
✅ Troubleshoot issues quickly  
✅ Scale applications reliably  

**Total learning time:** 10-15 days  
**Total infrastructure resources:** 50+ AWS resources  
**Total code:** 1000+ lines of Terraform, 500+ lines of Kubernetes, 200+ lines of GitHub Actions  
**Total documentation:** 10,000+ lines

---

Congratulations! 🎉 You've completed a full DevOps learning project!
