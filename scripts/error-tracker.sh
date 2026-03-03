#!/bin/bash
# Error Tracker — Optimus
# Aggregates errors from all services and logs them centrally

TRACK_DIR=/opt/smarterrevolution-infrastructure/logs
ERROR_LOG=$TRACK_DIR/error-tracker.log
ALERT_FILE=$TRACK_DIR/error-alerts.json
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Initialize JSON array if needed
[ -f $ALERT_FILE ] || echo '[]' > $ALERT_FILE

NEW_ERRORS=0

# Check CRM Postgres for errors
PG_ERRORS=$(docker logs crm-postgres --since 5m 2>&1 | grep -ciE 'ERROR|FATAL|PANIC' 2>/dev/null)
if [ "$PG_ERRORS" -gt 0 ]; then
  PG_DETAIL=$(docker logs crm-postgres --since 5m 2>&1 | grep -iE 'ERROR|FATAL|PANIC' | tail -3)
  echo "$TIMESTAMP [CRM-POSTGRES] $PG_ERRORS errors: $PG_DETAIL" >> $ERROR_LOG
  NEW_ERRORS=$((NEW_ERRORS + PG_ERRORS))
fi

# Check slow queries (>500ms)
SLOW_QUERIES=$(docker logs crm-postgres --since 5m 2>&1 | grep -c 'duration:' 2>/dev/null)
if [ "$SLOW_QUERIES" -gt 0 ]; then
  SLOW_DETAIL=$(docker logs crm-postgres --since 5m 2>&1 | grep 'duration:' | tail -3)
  echo "$TIMESTAMP [SLOW-QUERY] $SLOW_QUERIES slow queries: $SLOW_DETAIL" >> $ERROR_LOG
fi

# Check Docker container restart events
for CONTAINER in crm-postgres dashboard-postgres openclaw-dashboard crm-redis crm-qdrant; do
  STATUS=$(docker inspect $CONTAINER --format '{{.State.Status}}' 2>/dev/null)
  RESTARTS=$(docker inspect $CONTAINER --format '{{.RestartCount}}' 2>/dev/null)
  if [ "$STATUS" != "running" ]; then
    echo "$TIMESTAMP [CONTAINER-DOWN] $CONTAINER is $STATUS" >> $ERROR_LOG
    NEW_ERRORS=$((NEW_ERRORS + 1))
  fi
  if [ "$RESTARTS" -gt 0 ]; then
    echo "$TIMESTAMP [CONTAINER-RESTART] $CONTAINER has restarted $RESTARTS times" >> $ERROR_LOG
  fi
done

# Check service HTTP codes
for SVC in CRM:3000 CMDCTR:3001 Website:3003 ExecDash:3006; do
  NAME=${SVC%%:*}
  PORT=${SVC##*:}
  HTTP=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://localhost:$PORT)
  if [ "$HTTP" = "000" ] || [ "$HTTP" = "500" ] || [ "$HTTP" = "502" ] || [ "$HTTP" = "503" ]; then
    echo "$TIMESTAMP [SERVICE-ERROR] $NAME returned HTTP $HTTP" >> $ERROR_LOG
    NEW_ERRORS=$((NEW_ERRORS + 1))
  fi
done

# Check disk space
DISK_PCT=$(df / | tail -1 | awk '{print $5}' | tr -d '%')
if [ "$DISK_PCT" -gt 85 ]; then
  echo "$TIMESTAMP [DISK-WARNING] Disk usage at ${DISK_PCT}%" >> $ERROR_LOG
  NEW_ERRORS=$((NEW_ERRORS + 1))
fi

# Check memory
MEM_PCT=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100}')
if [ "$MEM_PCT" -gt 85 ]; then
  echo "$TIMESTAMP [MEMORY-WARNING] Memory usage at ${MEM_PCT}%" >> $ERROR_LOG
  NEW_ERRORS=$((NEW_ERRORS + 1))
fi

if [ "$NEW_ERRORS" -gt 0 ]; then
  echo "$TIMESTAMP — $NEW_ERRORS new errors detected" >> $ERROR_LOG
fi

# Rotate log (keep last 10000 lines)
if [ -f $ERROR_LOG ] && [ $(wc -l < $ERROR_LOG) -gt 10000 ]; then
  tail -5000 $ERROR_LOG > $ERROR_LOG.tmp && mv $ERROR_LOG.tmp $ERROR_LOG
fi
