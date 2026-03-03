#!/bin/bash
# Resource monitor — runs every 5 minutes

STATE_DIR="/opt/smarterrevolution-infrastructure/logs"
LOG="$STATE_DIR/resource-monitor.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

DISK_PCT=$(df / | awk 'NR==2{print $5}' | tr -d '%')
MEM_TOTAL=$(free -m | awk '/Mem/{print $2}')
MEM_USED=$(free -m | awk '/Mem/{print $3}')
MEM_PCT=$((MEM_USED * 100 / MEM_TOTAL))
LOAD=$(cat /proc/loadavg | awk '{print $1}')

ALERTS=""

if [ "$DISK_PCT" -gt 90 ]; then
  ALERTS="$ALERTS\n🚨 CRITICAL: Disk at ${DISK_PCT}%"
elif [ "$DISK_PCT" -gt 80 ]; then
  ALERTS="$ALERTS\n⚠️ WARNING: Disk at ${DISK_PCT}%"
fi

if [ "$MEM_PCT" -gt 95 ]; then
  ALERTS="$ALERTS\n🚨 CRITICAL: Memory at ${MEM_PCT}% (${MEM_USED}MB/${MEM_TOTAL}MB)"
elif [ "$MEM_PCT" -gt 85 ]; then
  ALERTS="$ALERTS\n⚠️ WARNING: Memory at ${MEM_PCT}% (${MEM_USED}MB/${MEM_TOTAL}MB)"
fi

echo "[$TIMESTAMP] disk=${DISK_PCT}% mem=${MEM_PCT}% load=${LOAD}" >> "$LOG"

if [ -n "$ALERTS" ]; then
  echo -e "[$TIMESTAMP] ALERT:$ALERTS" >> "$LOG"
  echo -e "[OPTIMUS] Resource Alert:$ALERTS"
fi

# Rotate log if > 1MB
if [ -f "$LOG" ] && [ $(stat -c%s "$LOG" 2>/dev/null) -gt 1048576 ]; then
  mv "$LOG" "${LOG}.old"
fi
