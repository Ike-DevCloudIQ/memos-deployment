# Stage 6: UI Workflow Guide - Grafana & CloudWatch

> **Exact clicks and queries for manual UI steps**

---

## Part 1: Grafana Dashboard Creation

### 1.1 Access Grafana

```bash
# Get Grafana URL
GRAFANA_URL=$(kubectl get svc prometheus-grafana -n monitoring \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "Open in browser: http://$GRAFANA_URL:3000"
```

**Login:**
- Username: `admin`
- Password: `admin`

---

## Part 2: Create "Memos Application Metrics" Dashboard

### 2.1 Create New Dashboard

**Step 1:** Click **"Dashboards"** in left sidebar  
**Step 2:** Click **"New"** (top right button, or + icon)  
**Step 3:** Click **"New Dashboard"**  

**Expected screen:** Blank dashboard with "Add a new panel" button

### 2.2 Add Panel 1: Requests Per Second

**Step 1:** Click **"Add a new panel"**

**Step 2:** In the panel editor:
- **Data source:** Select "Prometheus"
- **Metric:** Paste this query:
  ```
  rate(http_requests_total[5m])
  ```
- **Legend:** `{{ method }} {{ path }}`

**Step 3:** Click **"Refresh"** to preview

**Step 4:** Configure panel:
- Title: "Requests Per Second"
- Unit: "requests/sec" (or "short")
- Decimals: 0

**Step 5:** Click **"Apply"** (bottom right)

**Expected result:** Graph showing request rate over time

### 2.3 Add Panel 2: Error Rate

**Step 1:** Click **"Add a new panel"**

**Step 2:** In the panel editor:
- **Data source:** Prometheus
- **Metric:** Paste this query:
  ```
  rate(http_requests_total{status=~"5.."}[5m])
  ```
- **Legend:** `Error Rate`

**Step 3:** Configure panel:
- Title: "Error Rate (5xx)"
- Unit: "percentunit" (converts to %)
- Threshold: 0.01 (1%) = yellow, 0.05 (5%) = red
- Color scheme: Red (critical)

**Step 4:** Click **"Apply"**

### 2.4 Add Panel 3: Request Latency p95

**Step 1:** Click **"Add a new panel"**

**Step 2:** In the panel editor:
- **Data source:** Prometheus
- **Metric:** Paste this query:
  ```
  histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
  ```
- **Legend:** `p95 latency`

**Step 3:** Configure panel:
- Title: "Latency p95"
- Unit: "s" (seconds)
- Decimals: 3
- Threshold: 1 (second)

**Step 4:** Click **"Apply"**

### 2.5 Add Panel 4: Pod Memory Usage

**Step 1:** Click **"Add a new panel"**

**Step 2:** In the panel editor:
- **Data source:** Prometheus
- **Metric:** Paste this query:
  ```
  container_memory_usage_bytes{pod=~"memos-.*"} / 1024 / 1024
  ```
- **Legend:** `{{ pod }}`

**Step 3:** Configure panel:
- Title: "Memory Usage (MB)"
- Unit: "short"
- Max: 1024 (1GB limit)
- Threshold: 800 (warning), 950 (critical)

**Step 4:** Click **"Apply"**

### 2.6 Add Panel 5: Pod CPU Usage

**Step 1:** Click **"Add a new panel"**

**Step 2:** In the panel editor:
- **Data source:** Prometheus
- **Metric:** Paste this query:
  ```
  rate(container_cpu_usage_seconds_total{pod=~"memos-.*"}[5m]) * 100
  ```
- **Legend:** `{{ pod }}`

**Step 3:** Configure panel:
- Title: "CPU Usage (%)"
- Unit: "percent"
- Max: 100
- Threshold: 50 (warning), 80 (critical)

**Step 4:** Click **"Apply"**

### 2.7 Add Panel 6: EKS Node CPU

**Step 1:** Click **"Add a new panel"**

**Step 2:** In the panel editor:
- **Data source:** Prometheus
- **Metric:** Paste this query:
  ```
  (1 - avg(rate(node_cpu_seconds_total{mode="idle"}[5m]))) * 100
  ```
- **Legend:** `{{ node }}`

**Step 3:** Configure panel:
- Title: "Node CPU (%)"
- Unit: "percent"
- Threshold: 70 (warning), 90 (critical)

**Step 4:** Click **"Apply"**

### 2.8 Add Panel 7: EKS Node Memory

**Step 1:** Click **"Add a new panel"**

**Step 2:** In the panel editor:
- **Data source:** Prometheus
- **Metric:** Paste this query:
  ```
  (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100
  ```
- **Legend:** `{{ node }}`

**Step 3:** Configure panel:
- Title: "Node Memory (%)"
- Unit: "percent"
- Max: 100
- Threshold: 70 (warning), 85 (critical)

**Step 4:** Click **"Apply"**

### 2.9 Save Dashboard

**Step 1:** Click **"Save"** (top right, or Ctrl+S)

**Step 2:** Name: `Memos Application Metrics`

**Step 3:** Tags: `memos` `application` `monitoring`

**Step 4:** Click **"Save"**

**Expected result:** Dashboard saved and visible in Dashboards list

### 2.10 Set Auto-Refresh

**Step 1:** Click clock icon (top right) for refresh settings

**Step 2:** Select **"30s"** (updates every 30 seconds)

**Step 3:** Your dashboard now updates automatically!

---

## Part 3: CloudWatch Logs Insights Queries

### 3.1 Access CloudWatch Logs Insights

```
Go to: https://console.aws.amazon.com/cloudwatch
→ Logs
→ Logs Insights
```

Or click "CloudWatch" in AWS console, then "Logs Insights"

---

## Part 4: Run Common Queries

### Query 1: Count Errors by Type (Last Hour)

**In CloudWatch Logs Insights:**

**Step 1:** Select log group: `/aws/eks/memos-eks/cluster`

**Step 2:** Copy-paste this query:
```
fields @timestamp, @message, error_type
| filter @message like /ERROR/
| stats count() as errors by error_type
| sort errors desc
```

**Step 3:** Click **"Run query"** (or Ctrl+Enter)

**Expected result:** Table showing error count by type

**Interpretation:**
- Which error types occur most frequently?
- Prioritize fixing the most common errors

---

### Query 2: Find Slow Requests (> 1 Second)

**Copy-paste this query:**
```
fields @timestamp, @duration, @request_path, @status
| filter @duration > 1000
| stats count() as slow_requests, avg(@duration) as avg_duration by @request_path
| sort slow_requests desc
```

**Expected result:** Table with slow endpoints

**Interpretation:**
- Which endpoints are slow?
- Need to optimize database queries or caching?

---

### Query 3: Request Rate Per Minute

**Copy-paste this query:**
```
fields @timestamp
| stats count() as requests by bin(1m)
| sort @timestamp desc
```

**Expected result:** Time series showing requests per minute

**Interpretation:**
- Traffic pattern over time
- Detect traffic spikes or drops

---

### Query 4: Top 10 Endpoints by Request Count

**Copy-paste this query:**
```
fields @request_path
| stats count() as requests by @request_path
| sort requests desc
| limit 10
```

**Expected result:** List of top endpoints

**Interpretation:**
- Most used endpoints
- Where to focus optimization efforts

---

### Query 5: Error Rate Per Endpoint

**Copy-paste this query:**
```
fields @request_path, @status
| filter @status >= 400
| stats count() as errors by @request_path, @status
| sort errors desc
```

**Expected result:** Errors grouped by endpoint and status code

**Interpretation:**
- Which endpoints have the most errors?
- 4xx (client errors) vs 5xx (server errors)?

---

### Query 6: Database Connection Errors (Last Hour)

**Copy-paste this query:**
```
fields @timestamp, @message
| filter @message like /connection|timeout|pool|database/i
| stats count() as db_errors by @message
| sort db_errors desc
```

**Expected result:** Count of database-related errors

**Interpretation:**
- Database connectivity issues?
- Connection pool exhausted?

---

### Query 7: Slowest Requests (p95 latency)

**Copy-paste this query:**
```
fields @duration
| filter @duration > 0
| stats pct(@duration, 95) as p95_latency, 
        pct(@duration, 99) as p99_latency,
        max(@duration) as max_latency
```

**Expected result:** Single row with latency percentiles

**Interpretation:**
- 95% of requests are faster than p95_latency
- Max latency shows worst case

---

### Query 8: Pod Restart Events (Last 24 Hours)

**Copy-paste this query:**
```
fields @timestamp, @message, kubernetes.pod_name
| filter @message like /restart|CrashLoopBackOff|OOMKilled/
| stats count() as restarts by kubernetes.pod_name
| sort restarts desc
```

**Expected result:** Pods with restart count

**Interpretation:**
- Pods crashing frequently?
- Memory issues (OOMKilled)?
- Application stability issues?

---

### Query 9: Authentication Failures (Last Hour)

**Copy-paste this query:**
```
fields @timestamp, @user_id, @message
| filter @message like /authentication|forbidden|unauthorized|401|403/i
| stats count() as auth_failures by @user_id
| sort auth_failures desc
```

**Expected result:** Failed authentications by user

**Interpretation:**
- Brute force attacks?
- User account issues?

---

### Query 10: Application Startup Time

**Copy-paste this query:**
```
fields @timestamp, @message
| filter @message like /started|listening|ready/i
| stats min(@timestamp) as startup_time
```

**Expected result:** Time app started

**Interpretation:**
- When was application last redeployed?
- Startup latency (for debugging deployments)

---

## Part 5: Save Queries as Insights

### Step 1: After running a query, click **"Save"** (top right)

### Step 2: Name it: `Errors by Type - Last Hour`

### Step 3: Click **"Save"**

Now you can access saved queries from **"Saved queries"** in left sidebar

---

## Part 6: Create CloudWatch Dashboard

### 6.1 Add Logs Insights Widget to Dashboard

**Step 1:** Go to **CloudWatch → Dashboards**

**Step 2:** Click **"Create dashboard"**

**Step 3:** Name: `Memos Observability`

**Step 4:** Click **"Create dashboard"**

**Step 5:** Click **"Add widget"**

**Step 6:** Select **"Logs"** widget type

**Step 7:** Paste one of the queries (e.g., top 10 endpoints)

**Step 8:** Click **"Create widget"**

### 6.2 Add More Widgets

Repeat for:
- Error rate query
- Slow requests query
- Database errors query
- Pod restarts query

---

## Part 7: Troubleshooting Queries

### Query returns no results?

**Check:**
1. Correct log group selected?
2. Time range includes data? (Check calendar)
3. Field names spelled correctly?
4. Filters too restrictive?

**Solution:**
```
# Start with simple query
fields @timestamp, @message
| limit 10
```

### Query slow/timeout?

**Optimize:**
- Reduce time range (e.g., last 1 hour instead of 7 days)
- Add more specific filters
- Limit results

```
# Good: Specific time range + filter
fields @timestamp, @message
| filter @message like /ERROR/
| limit 1000
```

### @duration field not found?

**Check:** App is logging duration field
```
# Verify field exists
fields @duration
| limit 1

# If empty, app needs to log duration
```

---

## Part 8: Grafana Tips & Tricks

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl+S` | Save dashboard |
| `D` + `N` | New dashboard |
| `T` | Time range selector |
| `R` | Refresh |
| `F` | Full screen |
| `ESC` | Exit full screen |

### Quick Time Ranges

Click time range (top right):
- **Last 5 minutes** - Real-time monitoring
- **Last 1 hour** - Current incidents
- **Last 24 hours** - Trends
- **Last 7 days** - Weekly patterns
- **Last 30 days** - Monthly trends

### Dashboard Variables

Create dynamic dashboards:

**Step 1:** Click **"Dashboard"** → **"Settings"**

**Step 2:** Click **"Variables"**

**Step 3:** Click **"New"**

**Step 4:** Create a variable:
- Name: `namespace`
- Type: Query
- Datasource: Prometheus
- Query: `label_values(kube_namespace_labels, namespace)`

**Step 5:** In panels, use `$namespace` in queries

---

## Part 9: Grafana Alerts

### Create Alert on Dashboard Panel

**Step 1:** Click panel title → **"Edit"**

**Step 2:** Click **"Alert"** tab

**Step 3:** Click **"Create alert"**

**Step 4:** Set threshold:
- **Condition:** When `A` is above 1000 (requests/sec)
- **Evaluate for:** 5 minutes
- **Pending period:** 1 minute

**Step 5:** Notification channel: (configure in Alerting settings)

**Step 6:** Click **"Save alert"**

---

## Part 10: CloudWatch Logs Dashboard

### Create CloudWatch Dashboard

**Step 1:** Go to CloudWatch → Dashboards

**Step 2:** Click **"Create dashboard"**

**Step 3:** Name: `Memos Infrastructure`

**Step 4:** Add widgets for:
- EKS node CPU
- EKS node memory
- RDS CPU
- RDS connections
- Load balancer requests
- Load balancer errors

**Step 5:** Set auto-refresh to 1 minute

---

## Part 11: Share Dashboards

### Share Grafana Dashboard

**Step 1:** Click dashboard title → **"Share"**

**Step 2:** Copy link from **"Link"** tab

**Step 3:** Share with team

### Make Dashboard Public (Optional)

**Step 1:** Organization settings → **"Preferences"**

**Step 2:** Enable **"Public dashboards"**

**Step 3:** Click dashboard → **"Share"** → **"Public dashboard"**

---

## Checklists

### UI Steps Checklist

**Grafana:**
- [ ] Logged in (admin/admin)
- [ ] Created "Memos Application Metrics" dashboard
- [ ] Added 7 panels (requests, errors, latency, memory, CPU, node CPU, node memory)
- [ ] Set auto-refresh to 30s
- [ ] Saved dashboard
- [ ] Can view live metrics

**CloudWatch Logs Insights:**
- [ ] Accessed Logs Insights console
- [ ] Ran Query 1: Errors by type
- [ ] Ran Query 2: Slow requests
- [ ] Ran Query 3: Request rate
- [ ] Ran Query 4: Top endpoints
- [ ] Ran Query 5: Error rate per endpoint
- [ ] Saved at least 2 queries

**CloudWatch Dashboards:**
- [ ] Created dashboard
- [ ] Added metrics widgets
- [ ] Added logs widget
- [ ] Set auto-refresh

---

## Success Criteria

✅ Grafana dashboard showing real-time metrics  
✅ All 7 panels populated with data  
✅ CloudWatch Logs queries returning results  
✅ Saved queries for quick access  
✅ CloudWatch dashboard created  
✅ Can access all 3 dashboards  
✅ Understand how to create custom queries  

---

## Next Steps

1. **Monitor daily** - Check dashboards each morning
2. **Set alerts** - Create alerts for critical thresholds
3. **Create runbooks** - Document how to respond to alerts
4. **Share dashboards** - Give team access
5. **Add more panels** - Database metrics, business metrics

---

## Resources

- [Grafana Dashboard Creation](https://grafana.com/docs/grafana/latest/dashboards/)
- [Prometheus Query Language](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [CloudWatch Logs Insights Query Syntax](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CWL_QuerySyntax.html)
