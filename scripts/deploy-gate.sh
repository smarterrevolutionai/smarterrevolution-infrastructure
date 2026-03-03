#!/bin/bash
# Deploy Gate — Monitors main branch for new merges
# Posts deploy requests to a file for OpenClaw cron to pick up

GATE_DIR=/opt/smarterrevolution-infrastructure/deploy-queue
mkdir -p $GATE_DIR

for REPO_DIR in /opt/smarter-crm /opt/openclaw-command-center /opt/smarterrevolutionai-site; do
  REPO_NAME=$(basename $REPO_DIR)
  STATE_FILE=$GATE_DIR/${REPO_NAME}.main-head

  cd $REPO_DIR 2>/dev/null || continue

  # Fetch main
  git fetch origin main 2>/dev/null || continue

  REMOTE_HEAD=$(git rev-parse origin/main 2>/dev/null)
  CURRENT_HEAD=$(git rev-parse HEAD 2>/dev/null)
  LAST_SEEN=$(cat $STATE_FILE 2>/dev/null)

  # Initialize state file on first run
  if [ -z "$LAST_SEEN" ]; then
    echo "$REMOTE_HEAD" > $STATE_FILE
    continue
  fi

  # Check if main has new commits we haven't deployed
  if [ "$REMOTE_HEAD" != "$LAST_SEEN" ] && [ "$REMOTE_HEAD" != "$CURRENT_HEAD" ]; then
    # New commits on main that aren't deployed yet
    COMMIT_LOG=$(git log --oneline $LAST_SEEN..$REMOTE_HEAD 2>/dev/null)
    DIFF_STAT=$(git diff --stat $LAST_SEEN..$REMOTE_HEAD 2>/dev/null | tail -1)

    # Create deploy request
    REQUEST_FILE=$GATE_DIR/${REPO_NAME}-$(date +%Y%m%d-%H%M%S).deploy-request
    echo "repo=$REPO_NAME" > $REQUEST_FILE
    echo "from=$LAST_SEEN" >> $REQUEST_FILE
    echo "to=$REMOTE_HEAD" >> $REQUEST_FILE
    echo "commits=$COMMIT_LOG" >> $REQUEST_FILE
    echo "stats=$DIFF_STAT" >> $REQUEST_FILE
    echo "status=pending_review" >> $REQUEST_FILE
    echo "$REMOTE_HEAD" > $STATE_FILE

    echo "[DEPLOY-GATE] New merge detected on $REPO_NAME main: $LAST_SEEN → $REMOTE_HEAD"
  fi
done
