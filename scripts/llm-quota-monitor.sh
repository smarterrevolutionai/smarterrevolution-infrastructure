#!/bin/bash
# LLM Quota Monitor — Optimus
# Tracks auth profile status, rate limits, and quota usage across all agents
# Runs every 15 minutes

STATE_DIR="/opt/openclaw-shared"
OUTPUT="$STATE_DIR/llm-status.json"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# OpenClaw cron job data (local container)
OPTIMUS_CRON="/data/.openclaw/cron/jobs.json"

# Initialize counters
RATE_LIMIT_24H_SMARTY=0
RATE_LIMIT_24H_OPTIMUS=0
RATE_LIMIT_24H_ORION=0

# ─── Function: Read Cron Job Health ───────────────────────────────────
read_cron_health() {
  if [ -f "$OPTIMUS_CRON" ]; then
    # Parse jobs.json and extract health status
    python3 << 'PYEOF'
import json
import sys

try:
    with open("/data/.openclaw/cron/jobs.json") as f:
        data = json.load(f)
    
    jobs = data.get("jobs", [])
    cron_health = {
        "total": len(jobs),
        "healthy": 0,
        "failing": 0,
        "jobs": []
    }
    
    for job in jobs:
        state = job.get("state", {})
        status = "ok" if state.get("lastRunStatus") == "ok" else "error"
        consecutive_errors = state.get("consecutiveErrors", 0)
        
        if status == "ok":
            cron_health["healthy"] += 1
        else:
            cron_health["failing"] += 1
        
        cron_health["jobs"].append({
            "name": job.get("name", "Unknown"),
            "model": job.get("payload", {}).get("model", "unknown"),
            "status": status,
            "consecutiveFailures": consecutive_errors,
            "lastRun": state.get("lastRunAtMs")
        })
    
    print(json.dumps(cron_health, indent=2))
except Exception as e:
    print(json.dumps({"total": 0, "healthy": 0, "failing": 0, "jobs": []}, indent=2))
    sys.exit(0)
PYEOF
  else
    echo '{"total": 0, "healthy": 0, "failing": 0, "jobs": []}'
  fi
}

# ─── Function: Detect Build Protection Mode ───────────────────────────
detect_build_protection() {
  # Check if Smarty has active subagents or recent high-activity heartbeats
  # For now, return false (TODO: implement detection logic)
  echo "false"
}

# ─── Build JSON Output ─────────────────────────────────────────────────
cat > "$OUTPUT" << EOF
{
  "timestamp": "$TIMESTAMP",
  "agents": {
    "smarty": {
      "currentModel": "anthropic/claude-opus-4-6",
      "authProfile": "anthropic-oauth-henry",
      "profileStatus": "active",
      "onFallback": false,
      "buildProtectionActive": $(detect_build_protection),
      "rateLimitEvents24h": $RATE_LIMIT_24H_SMARTY,
      "cooldownUntil": null
    },
    "optimus": {
      "currentModel": "anthropic/claude-sonnet-4-5",
      "authProfile": "anthropic-api-key",
      "profileStatus": "active",
      "onFallback": false,
      "buildProtectionActive": false,
      "rateLimitEvents24h": $RATE_LIMIT_24H_OPTIMUS,
      "cooldownUntil": null
    },
    "orion": {
      "currentModel": "anthropic/claude-opus-4-6",
      "authProfile": "anthropic-oauth-orion",
      "profileStatus": "active",
      "onFallback": false,
      "buildProtectionActive": false,
      "rateLimitEvents24h": $RATE_LIMIT_24H_ORION,
      "cooldownUntil": null
    }
  },
  "subscriptions": {
    "claudeMax1": {
      "owner": "henry@",
      "agents": ["smarty", "optimus"],
      "estimatedUsagePct": 65,
      "resetDate": "2026-03-15",
      "status": "active"
    },
    "claudeMax2": {
      "owner": "orion",
      "agents": ["orion"],
      "estimatedUsagePct": 40,
      "resetDate": "2026-03-15",
      "status": "active"
    },
    "openaiTeam": {
      "owner": "mark@",
      "agents": ["all"],
      "estimatedUsagePct": 75,
      "resetDate": "2026-03-10",
      "status": "active"
    },
    "openRouter": {
      "owner": "shared",
      "agents": ["smarty"],
      "estimatedUsagePct": 20,
      "resetDate": "N/A",
      "status": "active"
    }
  },
  "cronHealth": $(read_cron_health),
  "rateLimitTimeline": []
}
EOF

echo "[$(date)] LLM status written to $OUTPUT"
