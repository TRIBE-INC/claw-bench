#!/bin/bash
# =============================================================================
# terminate-instance.sh - Terminate a benchmark EC2 instance
# =============================================================================
# Usage: ./infra/terminate-instance.sh <instance-id>
#        ./infra/terminate-instance.sh --all  (terminate all benchmark instances)
#
# Safety: Only terminates instances tagged with ManagedBy=claw-bench

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

log() {
  echo "[$(date '+%H:%M:%S')] $*" >&2
}

terminate_instance() {
  local INSTANCE_ID="$1"

  # Safety check: Verify instance is managed by claw-bench
  MANAGED_BY=$(aws ec2 describe-instances --region "$AWS_REGION" \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].Tags[?Key==`ManagedBy`].Value' \
    --output text 2>/dev/null || echo "")

  if [ "$MANAGED_BY" != "claw-bench" ]; then
    log "WARNING: Instance $INSTANCE_ID is not managed by claw-bench (ManagedBy=$MANAGED_BY)"
    log "Skipping termination for safety"
    return 1
  fi

  log "Terminating instance $INSTANCE_ID..."
  aws ec2 terminate-instances --region "$AWS_REGION" \
    --instance-ids "$INSTANCE_ID" \
    --query 'TerminatingInstances[0].CurrentState.Name' \
    --output text

  # Remove local metadata
  rm -f "$BENCH_DIR/.instances/$INSTANCE_ID.json" 2>/dev/null || true

  log "Instance $INSTANCE_ID terminated"
}

# Handle --all flag
if [ "${1:-}" = "--all" ]; then
  log "Finding all claw-bench instances..."

  INSTANCES=$(aws ec2 describe-instances --region "$AWS_REGION" \
    --filters "Name=tag:ManagedBy,Values=claw-bench" \
              "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query 'Reservations[].Instances[].InstanceId' \
    --output text 2>/dev/null || echo "")

  if [ -z "$INSTANCES" ]; then
    log "No benchmark instances found"
    exit 0
  fi

  COUNT=$(echo "$INSTANCES" | wc -w | tr -d ' ')
  log "Found $COUNT benchmark instance(s)"

  for INSTANCE_ID in $INSTANCES; do
    terminate_instance "$INSTANCE_ID" || true
  done

  # Clean up all local metadata
  rm -rf "$BENCH_DIR/.instances"/*.json 2>/dev/null || true

  log "All benchmark instances terminated"
  exit 0
fi

# Single instance termination
INSTANCE_ID="${1:?Error: Instance ID required (or use --all)}"
terminate_instance "$INSTANCE_ID"
