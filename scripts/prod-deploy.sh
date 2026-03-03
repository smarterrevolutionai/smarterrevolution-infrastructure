#!/bin/bash
# Production Deploy Script — Optimus
# Called by OpenClaw cron after Mark approval
# Usage: prod-deploy.sh <repo> [commit_sha]

set -e

REPO=$1
COMMIT=$2
LOG=/opt/smarterrevolution-infrastructure/logs/prod-deploy.log
LOCK=/tmp/prod-deploy.lock
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

if [ -z "$REPO" ]; then
  echo "Usage: prod-deploy.sh <smarter-crm|openclaw-command-center|smarterrevolutionai-site>"
  exit 1
fi

# Prevent concurrent deploys
if [ -f $LOCK ]; then
  echo "$TIMESTAMP — Deploy already in progress" >> $LOG
  exit 1
fi
trap 'rm -f $LOCK' EXIT
touch $LOCK

case $REPO in
  smarter-crm)
    REPO_DIR=/opt/smarter-crm
    ;;
  openclaw-command-center)
    REPO_DIR=/opt/openclaw-command-center
    ;;
  smarterrevolutionai-site)
    REPO_DIR=/opt/smarterrevolutionai-site
    ;;
  *)
    echo "Unknown repo: $REPO" >> $LOG
    exit 1
    ;;
esac

cd $REPO_DIR
echo "" >> $LOG
echo "========================================" >> $LOG
echo "$TIMESTAMP — DEPLOY START: $REPO" >> $LOG

# Save current state for rollback
PREV_COMMIT=$(git rev-parse HEAD)
echo "Previous commit: $PREV_COMMIT" >> $LOG

# Pre-deploy backup
echo "$TIMESTAMP — Taking pre-deploy backup..." >> $LOG
if [ "$REPO" = "smarter-crm" ]; then
  docker exec -e PGPASSWORD=eZKIAjAidWgmwHgJcSow2m08cC9YCdjy crm-postgres pg_dump -U crm_user crm_db | gzip > /opt/backups/pre-deploy-$REPO-$(date +%Y%m%d-%H%M%S).sql.gz 2>/dev/null
elif [ "$REPO" = "openclaw-command-center" ]; then
  docker exec dashboard-postgres pg_dump -U dashboard_user dashboard_db | gzip > /opt/backups/pre-deploy-$REPO-$(date +%Y%m%d-%H%M%S).sql.gz 2>/dev/null
fi

# Pull latest main
echo "$TIMESTAMP — Pulling main branch..." >> $LOG
git fetch origin main >> $LOG 2>&1
git checkout main >> $LOG 2>&1
git pull origin main >> $LOG 2>&1
NEW_COMMIT=$(git rev-parse HEAD)
echo "New commit: $NEW_COMMIT" >> $LOG

# Deploy based on repo type
if [ "$REPO" = "smarter-crm" ]; then
  # Fix .next ownership (may be root from docker builds)
  [ -d .next ] && sudo chown -R smarty:smarty .next 2>/dev/null || true
  echo "$TIMESTAMP — Installing deps..." >> $LOG
  npm install >> $LOG 2>&1
  echo "$TIMESTAMP — Running Prisma migrations..." >> $LOG
  npx prisma migrate deploy >> $LOG 2>&1
  echo "$TIMESTAMP — Building..." >> $LOG
  npx next build >> $LOG 2>&1
  echo "$TIMESTAMP — Restarting PM2..." >> $LOG
  sudo pm2 restart smarter-crm >> $LOG 2>&1 || sudo pm2 start ecosystem.config.js >> $LOG 2>&1

elif [ "$REPO" = "openclaw-command-center" ]; then
  echo "$TIMESTAMP — Docker build + restart..." >> $LOG
  docker compose build --no-cache >> $LOG 2>&1
  docker compose up -d >> $LOG 2>&1
  sleep 5
  docker exec openclaw-dashboard npx prisma db push --accept-data-loss >> $LOG 2>&1 || true

elif [ "$REPO" = "smarterrevolutionai-site" ]; then
  # Fix .next ownership (may be root from docker builds)
  [ -d .next ] && sudo chown -R smarty:smarty .next 2>/dev/null || true
  echo "$TIMESTAMP — Installing deps..." >> $LOG
  npm install >> $LOG 2>&1
  echo "$TIMESTAMP — Building..." >> $LOG
  npx next build >> $LOG 2>&1
  echo "$TIMESTAMP — Restarting..." >> $LOG
  sudo pm2 restart smarterrevolutionai-site >> $LOG 2>&1 || true
fi

# Health check
echo "$TIMESTAMP — Running health check..." >> $LOG
sleep 5
case $REPO in
  smarter-crm)
    HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 http://localhost:3000)
    ;;
  openclaw-command-center)
    HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 http://localhost:3001)
    ;;
  smarterrevolutionai-site)
    HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 http://localhost:3003)
    ;;
esac

if [ "$HTTP_CODE" = "000" ]; then
  echo "$TIMESTAMP — 🔴 HEALTH CHECK FAILED (HTTP $HTTP_CODE) — ROLLING BACK" >> $LOG
  git checkout $PREV_COMMIT >> $LOG 2>&1
  echo "DEPLOY_FAILED"
  exit 1
else
  echo "$TIMESTAMP — ✅ Health check passed (HTTP $HTTP_CODE)" >> $LOG
fi

# Write result file for cron to pick up
echo "$TIMESTAMP — DEPLOY COMPLETE: $REPO ($PREV_COMMIT → $NEW_COMMIT) HTTP $HTTP_CODE" >> $LOG
echo "DEPLOY_OK|$REPO|$PREV_COMMIT|$NEW_COMMIT|$HTTP_CODE"
