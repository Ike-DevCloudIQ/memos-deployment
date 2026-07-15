# Stage 6: Monitoring & Observability - Conceptual Guide

> **See what's happening: metrics, logs, traces, and alerts for production**

---

## What is Observability?

**Observability = Ability to understand system behavior from external outputs**

Three pillars:
1. **Metrics** - Numbers over time (CPU %, memory, requests/sec)
2. **Logs** - Events & errors (what happened and when)
3. **Traces** - Request flow (path through system)

### Why Observability Matters

```
Before (No Observability):
App crashes → Users angry → You get paged at 3am → "What's wrong?" → Panic

With Observability:
Alert triggers → Dashboard shows CPU 95% → "Need more replicas" → Autoscale
```

### Observability vs Monitoring

| Monitoring | Observability |
|-----------|---------------|
| Pre-defined dashboards | Ad-hoc queries on any metric |
| Alerts on known problems | Find unknown unknowns |
| Reactive | Proactive |
| Example: "Alert if CPU > 80%" | Example: "Why did latency spike at 2:15pm?" |

---

## Architecture: Full Observability Stack

```
┌─────────────────────────────────────────────┐
│         Memos Application (EKS)             │
│                                             │
│  Emit metrics:                              │
│  - HTTP requests/latency                    │
│  - DB queries/latency                       │
│  - Memory/CPU usage                         │
│  - Errors/exceptions                        │
└─────────────────────────────────────────────┘
  ↓ metrics         ↓ logs           ↓ traces
  
  Prometheus     CloudWatch Logs    Jaeger
  (time-series)   (centralized)     (tracing)
  
  ↓                ↓                 ↓
  
  ┌─────────────────────────────────────────────┐
  │    Grafana Dashboards                       │
  │                                             │
  │  - System Health                            │
  │  - Application Performance                  │
  │  - Business Metrics                         │
  └─────────────────────────────────────────────┘
  
  ↓
  
  ┌─────────────────────────────────────────────┐
  │    Alert Rules                              │
  │                                             │
  │  IF CPU > 80% THEN Slack/email              │
  │  IF error_rate > 5% THEN PagerDuty          │
  │  IF latency > 1s THEN notify                │
  └─────────────────────────────────────────────┘
```

---

## Component 1: Metrics (Prometheus)

**What:** Collects time-series data points (timestamps + values)

**Example metrics:**
```
http_requests_total{method="GET", path="/api/notes"} = 1523 (counter)
http_request_duration_seconds{endpoint="/api/notes"} = 0.045 (histogram)
memos_db_query_duration_seconds = 0.12 (gauge)
go_memory_bytes_alloc = 52428800 (gauge)
```

### How Prometheus Works

```
1. App exposes metrics at /metrics endpoint
   GET http://memos:5230/metrics
   
   Response:
   # HELP http_requests_total Total HTTP requests
   # TYPE http_requests_total counter
   http_requests_total{method="GET"} 1523
   http_requests_total{method="POST"} 234

2. Prometheus scrapes every 15 seconds
   (Prometheus) → GET :5230/metrics → (Memos)
   
3. Stores in time-series database
   [timestamp, value, labels] format
   
4. Queries via PromQL language
   rate(http_requests_total[5m])  # requests per second over last 5 min
   quantile(0.95, latency)        # 95th percentile latency
```

### Key Metric Types

**Counter:**
- Only increases or resets
- Example: total requests, total errors
- Query: `rate(http_requests_total[5m])` = requests/sec

**Gauge:**
- Can go up or down
- Example: current memory, active connections
- Query: `memory_bytes / 1024 / 1024` = GB

**Histogram:**
- Buckets of values
- Example: request latencies (0.1s, 0.5s, 1s, 5s buckets)
- Query: `histogram_quantile(0.95, latency)` = 95th percentile

---

## Component 2: Logs (CloudWatch)

**What:** Centralized log collection and search

**Log sources:**
- EKS cluster logs (`kubectl logs`)
- Application logs (stdout/stderr)
- AWS API logs
- Security logs

### CloudWatch Log Groups

Each app has a log group:
```
/aws/eks/memos-eks/cluster       ← EKS control plane
/memos/app                        ← Application stdout
/aws/rds/postgresql               ← RDS database logs
```

### Log Queries (CloudWatch Insights)

```
# Find all errors in last hour
fields @timestamp, @message
| filter @message like /ERROR/
| stats count() by @message

# Request latency p95
fields @duration
| stats pct(@duration, 95)

# Top 10 endpoints by traffic
fields @request_path
| stats count() as requests by @request_path
| sort requests desc
| limit 10
```

---

## Component 3: Alerts & Notifications

**What:** Automated notifications when something goes wrong

### CloudWatch Alarms

```yaml
# Alert if CPU > 80%
Metric: pod_cpu_usage
Threshold: 80%
Condition: GreaterThanThreshold
Duration: 2 minutes (to avoid false alarms)
Action: Send Slack message + PagerDuty
```

### Prometheus Alerting Rules

```yaml
# Alert if error rate > 5%
alert: HighErrorRate
expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.05
for: 5m
annotations:
  summary: "High error rate detected"
  value: "{{ $value | humanizePercentage }}"
```

---

## Full Observability Setup for Memos

### 1. CloudWatch for AWS Infrastructure

**What to monitor:**
- EKS cluster health (nodes, control plane)
- RDS database (CPU, connections, replication lag)
- Load balancer (requests, latency, errors)
- EC2 node metrics (disk, network)

**Dashboards:**
```
EKS Cluster Status
├─ Active nodes: 2/2
├─ Control plane CPU: 15%
├─ API requests/sec: 234
├─ Pod memory: 2.5 GB / 4 GB

RDS Database
├─ Connections: 15/100
├─ CPU: 25%
├─ Read latency: 5ms
├─ Write latency: 12ms

Network
├─ Load balancer requests: 1,234/sec
├─ Response time p95: 234ms
├─ Error rate: 0.1%
```

### 2. Prometheus for Application Metrics

**What to monitor:**
- HTTP request rate, latency, errors
- Database query latency
- Memory/CPU per pod
- Business metrics (notes created, etc)

**Install Prometheus on EKS:**
```bash
# Via Helm
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace
```

**App instrumentation:**
```go
// In Go code
import "github.com/prometheus/client_golang/prometheus"

// Define metrics
requestsTotal := prometheus.NewCounterVec(
    prometheus.CounterOpts{
        Name: "http_requests_total",
        Help: "Total HTTP requests",
    },
    []string{"method", "endpoint"},
)

// Increment on request
requestsTotal.WithLabelValues("GET", "/api/notes").Inc()

// Expose at /metrics
http.Handle("/metrics", promhttp.Handler())
```

### 3. Grafana for Dashboards

**What is Grafana:**
- Beautiful dashboards for metrics
- Connect to Prometheus, CloudWatch, etc
- Share with team
- Set alerts

**Example Dashboards:**
1. **System Health** - CPU, memory, disk, network
2. **Application Performance** - Request rate, latency, errors
3. **Database** - Query latency, connections, replication
4. **Business Metrics** - Revenue, user count, content created

---

## Four Golden Signals

Google's recommended metrics to monitor:

### 1. Latency
- How long requests take
- Alert if p95 latency > 1 second

### 2. Traffic
- How many requests per second
- Alert if traffic drops suddenly (possible outage)

### 3. Errors
- What percentage fail
- Alert if error rate > 1%

### 4. Saturation
- How "full" are resources
- Alert if CPU > 80%, memory > 85%

```
Metrics dashboard:
┌──────────────────────────────────────┐
│ Latency: 234ms (p95)  ✅             │
│ Traffic: 1,234 req/s  ✅             │
│ Errors: 0.05%  ✅                    │
│ CPU: 45%  ✅                         │
│ Memory: 62%  ✅                      │
└──────────────────────────────────────┘
```

---

## Sample Monitoring Setup

### Phase 1: Baseline (CloudWatch)
- Monitor EKS cluster via CloudWatch
- Monitor RDS database
- CloudWatch dashboards
- Basic alarms (CPU, memory)

### Phase 2: Application Metrics (Prometheus)
- Install Prometheus on EKS
- Add Prometheus annotations to pods
- Create Grafana dashboards
- Add app-specific metrics

### Phase 3: Advanced (Tracing)
- Jaeger for request tracing
- Understand request flow
- Find bottlenecks
- Trace distributed requests

---

## Logging Strategy

### Application Logs

**Structured logs (JSON):**
```json
{
  "timestamp": "2026-07-15T10:30:45Z",
  "level": "ERROR",
  "service": "memos-api",
  "pod": "memos-abc123",
  "request_id": "req-12345",
  "user_id": "user-456",
  "message": "Failed to create note",
  "error": "database connection timeout",
  "duration_ms": 5000
}
```

**Why JSON:**
- Searchable fields
- Parse and aggregate
- Query in CloudWatch Insights

### Log Levels

```
DEBUG   - Detailed info for developers
INFO    - General app events (requests, user actions)
WARN    - Warning conditions (slow query, retries)
ERROR   - Error conditions (failed request, exception)
FATAL   - App shutting down
```

### Log Retention

```
DEBUG:   3 days   (verbose, lots of data)
INFO:    30 days  (normal events)
ERROR:   90 days  (troubleshooting)
AUDIT:   1 year   (compliance, security)
```

---

## Alerting Strategy

### Alert Severity

**Critical (page ops immediately):**
- App down (error rate > 10%)
- Database unreachable
- No healthy pods

**Warning (notify but not urgent):**
- High latency (> 1s)
- CPU > 80%
- Memory > 85%

**Info (log for review):**
- Pod restarts
- Scaling events
- Deployment changes

### Alert Destinations

```
Critical → PagerDuty (wake people up)
Warning → Slack #alerts channel
Info → CloudWatch Logs only
```

---

## Best Practices

### 1. Metric Naming
```
✅ Good:
   http_requests_total
   db_query_duration_seconds
   memory_bytes_used

❌ Bad:
   requests     (ambiguous)
   duration     (what duration?)
   mem          (in what units?)
```

### 2. Labels (Dimensions)
```
✅ Good:
   http_requests_total{method="GET", path="/api/notes", status="200"}
   
❌ Bad:
   http_requests_GET_api_notes_200  (cardinality explosion)
```

### 3. Alert Thresholds
```
✅ Good:
   - Error rate > 1% (meaningful)
   - Latency p95 > 1s (user-noticeable)
   - CPU > 80% for 5 min (real sustained load)
   
❌ Bad:
   - CPU > 50% (too sensitive, false alarms)
   - "If anything weird happens" (too vague)
```

### 4. Dashboard Design
```
✅ Good:
   - One dashboard = one story
   - Auto-refresh every 30 seconds
   - Color: red (critical), yellow (warning), green (ok)
   - Show trends (last 1hr, 1day, 1week)

❌ Bad:
   - 50 metrics on one dashboard (overwhelming)
   - No color coding (hard to spot issues)
   - Static data (stale information)
```

### 5. Cost Optimization
```
Prometheus:
- Scrape interval: 15-30 seconds (not too frequent)
- Retention: 15 days (not forever)
- Drop unnecessary metrics

CloudWatch:
- Log retention: 30-90 days (not 1 year for app logs)
- Batch writes (not individual puts)
```

---

## Common Monitoring Mistakes

### Mistake 1: Monitor the Infrastructure, Not the App
```
❌ Wrong: Only monitor CPU, memory, disk
✅ Right: Also monitor app metrics (request rate, errors, latency)
```

### Mistake 2: Too Many Alerts
```
❌ Wrong: 100 alerts, ops ignores them all (alert fatigue)
✅ Right: 5-10 critical alerts that are always actionable
```

### Mistake 3: Alert on Noise
```
❌ Wrong: Alert if CPU > 50% (triggers constantly)
✅ Right: Alert if CPU > 80% for 5 minutes (sustained high load)
```

### Mistake 4: No Runbooks
```
❌ Wrong: "High error rate alert" — ops doesn't know what to do
✅ Right: Link to runbook: "Check RDS connection pool, restart pods"
```

### Mistake 5: Monitoring the Monitoring
```
❌ Wrong: Forget to monitor Prometheus/Grafana themselves
✅ Right: Alert if Prometheus scrape fails, if Grafana is down
```

---

## Tools Overview

| Tool | Purpose | Cost |
|------|---------|------|
| **CloudWatch** | AWS metrics/logs/alarms | $0.50/GB ingested logs |
| **Prometheus** | Time-series metrics | Free (OSS) |
| **Grafana** | Dashboards & visualization | Free (OSS) |
| **AlertManager** | Alert routing & deduplication | Free (part of Prometheus) |
| **Jaeger** | Distributed tracing | Free (OSS) |
| **ELK Stack** | Log aggregation | Free (OSS) but complex |
| **DataDog** | All-in-one platform | $15+/host/month |
| **New Relic** | APM + monitoring | $0.50+/GB ingested |

---

## Recommended Setup for Memos

**Tier 1 (Essential):**
- CloudWatch (automatic, included with AWS)
- Basic CloudWatch Alarms
- CloudWatch Dashboard

**Tier 2 (Recommended):**
- Prometheus on EKS
- Grafana dashboards
- Prometheus AlertManager

**Tier 3 (Advanced):**
- Jaeger for tracing
- Log aggregation (Loki)
- Cost analysis dashboards

---

## Summary

**After Stage 6:**
- ✅ CloudWatch dashboards for infrastructure
- ✅ Prometheus for application metrics
- ✅ Grafana for beautiful dashboards
- ✅ Alerts for critical issues
- ✅ Logs searchable and organized
- ✅ Understand system health at a glance
- ✅ Troubleshoot issues quickly
- ✅ Prevent problems before they become critical

---

## Resources

- [CloudWatch Docs](https://docs.aws.amazon.com/cloudwatch/)
- [Prometheus Official Docs](https://prometheus.io/docs/)
- [Grafana Docs](https://grafana.com/docs/grafana/)
- [Google SRE Book - Monitoring](https://sre.google/sre-book/monitoring-distributed-systems/)
- [Prometheus Best Practices](https://prometheus.io/docs/practices/naming/)
