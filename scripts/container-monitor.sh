#!/bin/bash
# Container monitor — runs every 5 minutes

STATE_DIR="/opt/smarterrevolution-infrastructure/logs"
LOG="$STATE_DIR/container-monitor.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Critical containers that MUST be running
CRITICAL_CONTAINERS=(
  "crm-postgres"
  "crm-redis"
  "crm-qdrant"
  "dashboard-postgres"
  "openclaw-dashboard"
)

ALERTS=""

for container in "${CRITICAL_CONTAINERS[@]}"; do
  STATUS=$(sudo docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null)
  if [ "$STATUS" != "running" ]; then
    ALERTS="$ALERTS\n🔴 Container $container is $STATUS (expected: running)"
  fi
done

# Also check for any containers in restart loops
RESTART_ISSUES=$(sudo docker ps -a --format "{{.Names}}|{{.Status}}" | while IFS='|' read -r name status; do
  if [[ "$status" =~ "Restarting" ]]; then
    echo "🔴 $name is in a restart loop"
  fi
done)

if [ -n "$RESTART_ISSUES" ]; then
  ALERTS="$ALERTS\n$RESTART_ISSUES"
fi

echo "[$TIMESTAMP] checked ${#CRITICAL_CONTAINERS[@]} critical containers" >> "$LOG"

if [ -n "$ALERTS" ]; then
  echo -e "[$TIMESTAMP] ALERT:$ALERTS" >> "$LOG"
  echo -e "[OPTIMUS] Container Alert:$ALERTS"
fi

# Rotate log
if [ -f "$LOG" ] && [ $(stat -c%s "$LOG" 2>/dev/null) -gt 1048576 ]; then
  mv "$LOG" "${LOG}.old"
fi
