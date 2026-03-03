#!/bin/bash
# Shadow Review Script — Optimus
# Monitors dev branches for new commits, logs diffs for review

REVIEW_DIR=/opt/smarterrevolution-infrastructure/reviews
mkdir -p $REVIEW_DIR

for REPO_DIR in /opt/smarter-crm /opt/openclaw-command-center /opt/smarterrevolutionai-site; do
  REPO_NAME=$(basename $REPO_DIR)
  STATE_FILE=$REVIEW_DIR/${REPO_NAME}.last-commit

  cd $REPO_DIR 2>/dev/null || continue

  # Fetch latest from dev
  git fetch origin dev 2>/dev/null || continue

  REMOTE_HEAD=$(git rev-parse origin/dev 2>/dev/null)
  LAST_SEEN=$(cat $STATE_FILE 2>/dev/null)

  if [ "$REMOTE_HEAD" = "$LAST_SEEN" ]; then
    continue  # No new commits
  fi

  # New commits found
  if [ -n "$LAST_SEEN" ]; then
    COMMIT_LOG=$(git log --oneline $LAST_SEEN..$REMOTE_HEAD 2>/dev/null)
    DIFF_STAT=$(git diff --stat $LAST_SEEN..$REMOTE_HEAD 2>/dev/null)
    FILES_CHANGED=$(git diff --name-only $LAST_SEEN..$REMOTE_HEAD 2>/dev/null)
  else
    COMMIT_LOG=$(git log --oneline -5 origin/dev 2>/dev/null)
    DIFF_STAT="(First scan — showing last 5 commits)"
    FILES_CHANGED="(First scan)"
  fi

  # Save review data
  REVIEW_FILE=$REVIEW_DIR/${REPO_NAME}-$(date +%Y%m%d-%H%M%S).review
  echo "Repo: $REPO_NAME" > $REVIEW_FILE
  echo "Previous: $LAST_SEEN" >> $REVIEW_FILE
  echo "Current: $REMOTE_HEAD" >> $REVIEW_FILE
  echo "" >> $REVIEW_FILE
  echo "Commits:" >> $REVIEW_FILE
  echo "$COMMIT_LOG" >> $REVIEW_FILE
  echo "" >> $REVIEW_FILE
  echo "Diff stat:" >> $REVIEW_FILE
  echo "$DIFF_STAT" >> $REVIEW_FILE
  echo "" >> $REVIEW_FILE
  echo "Files changed:" >> $REVIEW_FILE
  echo "$FILES_CHANGED" >> $REVIEW_FILE

  # Update state
  echo "$REMOTE_HEAD" > $STATE_FILE

  echo "[REVIEW] $REPO_NAME: new commits detected — $REVIEW_FILE"
done
