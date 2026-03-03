#!/bin/bash
# Backup Verification Script — Optimus
# Runs daily at 4 AM EST, validates latest backups

FAILURES=

# Verify CRM backup
LATEST_CRM=$(ls -t /opt/backups/crm-db/crm-db-*.sql.gz 2>/dev/null | head -1)
if [ -z "$LATEST_CRM" ]; then
  FAILURES="$FAILURES\n🔴 No CRM backups found"
else
  AGE_HOURS=$(( ($(date +%s) - $(stat -c %Y "$LATEST_CRM")) / 3600 ))
  SIZE=$(stat -c %s "$LATEST_CRM")
  if [ "$AGE_HOURS" -gt 9 ]; then
    FAILURES="$FAILURES\n⚠️ CRM backup is ${AGE_HOURS}h old (expected <9h)"
  fi
  if [ "$SIZE" -lt 1000 ]; then
    FAILURES="$FAILURES\n🔴 CRM backup suspiciously small: ${SIZE} bytes"
  fi
  gzip -t "$LATEST_CRM" 2>/dev/null || FAILURES="$FAILURES\n🔴 CRM backup is CORRUPT"
fi

# Verify Dashboard backup
LATEST_DASH=$(ls -t /opt/backups/dashboard-db/dashboard-db-*.sql.gz 2>/dev/null | head -1)
if [ -z "$LATEST_DASH" ]; then
  FAILURES="$FAILURES\n🔴 No Dashboard backups found"
else
  AGE_HOURS=$(( ($(date +%s) - $(stat -c %Y "$LATEST_DASH")) / 3600 ))
  SIZE=$(stat -c %s "$LATEST_DASH")
  if [ "$AGE_HOURS" -gt 25 ]; then
    FAILURES="$FAILURES\n⚠️ Dashboard backup is ${AGE_HOURS}h old (expected <25h)"
  fi
  if [ "$SIZE" -lt 1000 ]; then
    FAILURES="$FAILURES\n🔴 Dashboard backup suspiciously small: ${SIZE} bytes"
  fi
  gzip -t "$LATEST_DASH" 2>/dev/null || FAILURES="$FAILURES\n🔴 Dashboard backup is CORRUPT"
fi

# Report
if [ -n "$FAILURES" ]; then
  echo -e "[OPTIMUS] ⚠️ Backup Verification FAILURES:$FAILURES"
  exit 1
else
  CRM_SIZE=$(ls -lh "$LATEST_CRM" 2>/dev/null | awk '{print $5}')
  DASH_SIZE=$(ls -lh "$LATEST_DASH" 2>/dev/null | awk '{print $5}')
  echo "[OPTIMUS] ✅ Backup verification passed. CRM: ${CRM_SIZE}, Dashboard: ${DASH_SIZE}"
fi
