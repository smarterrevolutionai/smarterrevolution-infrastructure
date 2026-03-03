#!/bin/bash
# Health check — runs every 60 seconds
# Alerts after 3 consecutive failures per service

STATE_DIR="/opt/smarterrevolution-infrastructure/logs"
LOG="$STATE_DIR/health-check.log"

SERVICES=(
  "CRM|http://localhost:3000|critical"
  "CommandCenter|http://localhost:3001|critical"
  "Website|http://localhost:3003|high"
  "ExecDashboard|http://localhost:3006|medium"
)

FAILURES=""
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

for service_entry in "${SERVICES[@]}"; do
  IFS='|' read -r name url priority <<< "$service_entry"
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$url" 2>/dev/null || echo "000")
  STATE_FILE="$STATE_DIR/${name}.failures"
  
  # Accept 200 and 307 (redirects) as healthy
  if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "307" ]; then
    # Reset failure counter
    echo "0" > "$STATE_FILE"
  else
    # Increment failure counter
    PREV=$(cat "$STATE_FILE" 2>/dev/null || echo "0")
    COUNT=$((PREV + 1))
    echo "$COUNT" > "$STATE_FILE"
    
    if [ "$COUNT" -ge 3 ]; then
      FAILURES="$FAILURES\n🔴 $name ($url) — HTTP $HTTP_CODE — $COUNT consecutive failures [$priority]"
    fi
  fi
done

if [ -n "$FAILURES" ]; then
  echo -e "[$TIMESTAMP] ALERT:$FAILURES" >> "$LOG"
  echo -e "[OPTIMUS] ⚠️ Health Check Failures:\n$FAILURES"
fi

# Log healthy check (compact, rotate daily)
if [ -z "$FAILURES" ]; then
  echo "[$TIMESTAMP] OK" >> "$LOG"
fi

# Rotate log if > 1MB
if [ -f "$LOG" ] && [ $(stat -f%z "$LOG" 2>/dev/null || stat -c%s "$LOG" 2>/dev/null) -gt 1048576 ]; then
  mv "$LOG" "${LOG}.old"
fi
