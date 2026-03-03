#!/bin/bash
# Approve a pending deploy request
# Usage: approve-deploy.sh <repo>

REPO=$1
GATE_DIR=/opt/smarterrevolution-infrastructure/deploy-queue

if [ -z "$REPO" ]; then
  echo 'Usage: approve-deploy.sh <smarter-crm|openclaw-command-center|smarterrevolutionai-site>'
  exit 1
fi

# Find pending request
REQUEST=$(ls -t $GATE_DIR/${REPO}-*.deploy-request 2>/dev/null | head -1)
if [ -z "$REQUEST" ]; then
  echo "No pending deploy request for $REPO"
  exit 1
fi

# Mark as approved
sed -i 's/status=pending.*/status=approved/' "$REQUEST"
mv "$REQUEST" "${REQUEST%.deploy-request}.deploy-approved"
echo "Deploy approved for $REPO: $(basename $REQUEST)"
