#!/bin/bash
# =============================================================================
# wait-for-ready.sh - Wait for a benchmark instance to be ready
# =============================================================================
# Usage: ./infra/wait-for-ready.sh <instance-id>
#
# Outputs public IP when ready, or exits with error
# Returns: 0 on success, 1 on timeout, 2 on instance error

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BENCH_DIR="$(dirname "$SCRIPT_DIR")"

# Load environment
if [ -f "$BENCH_DIR/.env" ]; then
  set -a
  source "$BENCH_DIR/.env"
  set +a
fi

AWS_REGION="${AWS_REGION:-us-east-2}"
CLAW_SSH_KEY="${CLAW_SSH_KEY:-~/.ssh/id_rsa}"
CLAW_SSH_KEY="${CLAW_SSH_KEY/#\~/$HOME}"

INSTANCE_ID="${1:?Error: Instance ID required}"
MAX_WAIT="${2:-300}"  # 5 minutes default

log() {
  echo "[$(date '+%H:%M:%S')] $*" >&2
}

log "Waiting for instance $INSTANCE_ID to be ready (max ${MAX_WAIT}s)..."

# Phase 1: Wait for instance to be running with public IP
START_TIME=$(date +%s)
PUBLIC_IP=""

while true; do
  ELAPSED=$(($(date +%s) - START_TIME))
  if [ $ELAPSED -gt $MAX_WAIT ]; then
    log "ERROR: Timeout waiting for instance to start"
    exit 1
  fi

  STATE=$(aws ec2 describe-instances --region "$AWS_REGION" \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].State.Name' \
    --output text 2>/dev/null || echo "pending")

  case "$STATE" in
    running)
      PUBLIC_IP=$(aws ec2 describe-instances --region "$AWS_REGION" \
        --instance-ids "$INSTANCE_ID" \
        --query 'Reservations[0].Instances[0].PublicIpAddress' \
        --output text 2>/dev/null || echo "")

      if [ -n "$PUBLIC_IP" ] && [ "$PUBLIC_IP" != "None" ]; then
        log "Instance running with IP: $PUBLIC_IP"
        break
      fi
      ;;
    terminated|shutting-down|stopping|stopped)
      log "ERROR: Instance in unexpected state: $STATE"
      exit 2
      ;;
  esac

  log "Instance state: $STATE (${ELAPSED}s elapsed)"
  sleep 5
done

# Update instance metadata with IP
if [ -f "$BENCH_DIR/.instances/$INSTANCE_ID.json" ]; then
  TMP_FILE=$(mktemp)
  jq --arg ip "$PUBLIC_IP" '. + {publicIp: $ip}' "$BENCH_DIR/.instances/$INSTANCE_ID.json" > "$TMP_FILE"
  mv "$TMP_FILE" "$BENCH_DIR/.instances/$INSTANCE_ID.json"
fi

# Phase 2: Wait for SSH to be available
log "Waiting for SSH to be available..."
SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=5 -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"

while true; do
  ELAPSED=$(($(date +%s) - START_TIME))
  if [ $ELAPSED -gt $MAX_WAIT ]; then
    log "ERROR: Timeout waiting for SSH"
    exit 1
  fi

  if ssh -i "$CLAW_SSH_KEY" $SSH_OPTS ubuntu@"$PUBLIC_IP" "echo ok" >/dev/null 2>&1; then
    log "SSH available"
    break
  fi

  sleep 5
done

# Phase 3: Wait for clawdbot gateway to be ready
log "Waiting for clawdbot gateway..."

while true; do
  ELAPSED=$(($(date +%s) - START_TIME))
  if [ $ELAPSED -gt $MAX_WAIT ]; then
    log "ERROR: Timeout waiting for gateway"
    # Try to get boot logs for debugging
    ssh -i "$CLAW_SSH_KEY" $SSH_OPTS ubuntu@"$PUBLIC_IP" \
      "cat /opt/claw-bench/boot.log 2>/dev/null || journalctl -u clawdbot --no-pager -n 50" >&2 || true
    exit 1
  fi

  GATEWAY_STATUS=$(ssh -i "$CLAW_SSH_KEY" $SSH_OPTS ubuntu@"$PUBLIC_IP" \
    "curl -sf http://localhost:18789/ >/dev/null 2>&1 && echo 'ready' || echo 'waiting'" 2>/dev/null || echo "ssh_error")

  if [ "$GATEWAY_STATUS" = "ready" ]; then
    log "Gateway ready!"
    break
  fi

  log "Gateway status: $GATEWAY_STATUS (${ELAPSED}s elapsed)"
  sleep 5
done

# Phase 4: Verify clawdbot can respond
log "Verifying clawdbot..."
VERIFY=$(ssh -i "$CLAW_SSH_KEY" $SSH_OPTS ubuntu@"$PUBLIC_IP" \
  "clawdbot --version 2>&1" 2>/dev/null || echo "unknown")

log "Clawdbot version: $VERIFY"

# Get configured model
MODEL=$(ssh -i "$CLAW_SSH_KEY" $SSH_OPTS ubuntu@"$PUBLIC_IP" \
  "jq -r '.agents.defaults.model.primary' ~/.clawdbot/clawdbot.json 2>/dev/null" 2>/dev/null || echo "unknown")

log "Configured model: $MODEL"

# Update metadata with ready status
if [ -f "$BENCH_DIR/.instances/$INSTANCE_ID.json" ]; then
  TMP_FILE=$(mktemp)
  jq --arg model "$MODEL" --arg version "$VERIFY" \
    '. + {status: "ready", model: $model, clawdbotVersion: $version, readyTime: now | todate}' \
    "$BENCH_DIR/.instances/$INSTANCE_ID.json" > "$TMP_FILE"
  mv "$TMP_FILE" "$BENCH_DIR/.instances/$INSTANCE_ID.json"
fi

# Output IP for scripting
echo "$PUBLIC_IP"
