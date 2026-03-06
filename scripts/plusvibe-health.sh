#!/bin/bash
# PlusVibe Health Monitor — Optimus
# Checks: API health, bounce rates, campaign stats

API="https://api.plusvibe.ai/api/v1"
KEY="928fd41c-ca0ebf02-beec065e-c7062e63"
OUT="/opt/openclaw-shared/plusvibe-health.json"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# 1. API Health Check
API_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 -H "x-api-key: $KEY" "$API/unibox/campaign-emails?workspace_id=692307182213832a0e2cf618")
API_LATENCY=$(curl -s -o /dev/null -w "%{time_total}" --max-time 10 -H "x-api-key: $KEY" "$API/unibox/campaign-emails?workspace_id=692307182213832a0e2cf618")

# 2. Read latest report for bounce data
REPORT="/opt/openclaw-shared/plusvibe-latest-report.json"
if [ -f "$REPORT" ]; then
  BOUNCE_DATA=$(python3 << 'PYEOF'
import json
with open("/opt/openclaw-shared/plusvibe-latest-report.json") as f:
    d = json.load(f)
t = d.get("totals", {})
sent = t.get("grandContacted",0) + t.get("grandCompleted",0)
bounced = t.get("grandBounced",0)
rate = bounced/max(sent,1)*100
campaigns_over = []
for c in d.get("campaigns",[]):
    cs = c.get("contacted",0)+c.get("completed",0)
    if cs > 0:
        cr = c.get("bounced",0)/cs*100
        if cr > 3:
            campaigns_over.append({"name":c["name"],"rate":round(cr,1),"bounced":c.get("bounced",0)})
print(json.dumps({"overall_bounce_rate":round(rate,1),"total_sent":sent,"total_bounced":bounced,"campaigns_over_threshold":campaigns_over,"report_timestamp":d.get("timestamp","")}))
PYEOF
)
else
  BOUNCE_DATA='{"overall_bounce_rate":null,"error":"no report file"}'
fi

# 3. Write health output
echo "{
  \"timestamp\": \"$TIMESTAMP\",
  \"api_status\": $API_STATUS,
  \"api_latency_s\": $API_LATENCY,
  \"api_healthy\": $([ "$API_STATUS" = "200" ] && echo "true" || echo "false"),
  \"bounce_data\": $BOUNCE_DATA
}" > "$OUT"

# 4. Console output for cron log
echo "[$TIMESTAMP] API: HTTP $API_STATUS (${API_LATENCY}s) | Bounce data: $BOUNCE_DATA"
