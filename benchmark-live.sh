#!/bin/bash
# =============================================================================
# benchmark-live.sh - Run benchmarks on a live AWS EC2 instance
# =============================================================================
# Usage:
#   ./benchmark-live.sh [model-key]              Run single model benchmark
#   ./benchmark-live.sh --all                    Run all models sequentially
#   ./benchmark-live.sh --parallel [n]           Run n models in parallel via MUSE
#
# Examples:
#   ./benchmark-live.sh mistral-large-3          Benchmark Mistral Large 3
#   ./benchmark-live.sh --all                    Benchmark all models in models-to-test.json
#   ./benchmark-live.sh --parallel 3             Run 3 benchmarks in parallel
#
# Prerequisites:
#   1. Copy .env.example to .env and configure
#   2. Ensure AWS CLI is configured with appropriate permissions
#   3. For parallel mode, ensure TRIBE CLI is installed (tribe muse)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Load environment
if [ -f ".env" ]; then
  set -a
  source .env
  set +a
else
  echo -e "${RED}Error: .env file not found${NC}"
  echo "Copy .env.example to .env and configure it"
  exit 1
fi

# Configuration
AUTO_TERMINATE="${AUTO_TERMINATE:-true}"
KEEP_ON_FAILURE="${KEEP_ON_FAILURE:-false}"
MODELS_FILE="$SCRIPT_DIR/models-to-test.json"
REPORTS_DIR="$SCRIPT_DIR/reports"

log() {
  echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $*"
}

error() {
  echo -e "${RED}[$(date '+%H:%M:%S')] ERROR:${NC} $*" >&2
}

success() {
  echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $*"
}

usage() {
  cat <<EOF
benchmark-live.sh - Run benchmarks on live AWS EC2 instances

Usage:
  ./benchmark-live.sh [model-key]              Run single model benchmark
  ./benchmark-live.sh --all                    Run all models sequentially
  ./benchmark-live.sh --parallel [n]           Run n models in parallel via MUSE
  ./benchmark-live.sh --list                   List available models
  ./benchmark-live.sh --cleanup                Terminate all benchmark instances
  ./benchmark-live.sh --help                   Show this help

Available models:
$(jq -r '.models[] | "  \(.key) - \(.name)"' "$MODELS_FILE" 2>/dev/null || echo "  (models-to-test.json not found)")

Environment variables (set in .env):
  CLAWGO_AMI_ID              AMI ID for clawdbot instances
  CLAWGO_SECURITY_GROUP_ID   Security group ID
  CLAWGO_KEY_PAIR_NAME       EC2 key pair name
  CLAW_SSH_KEY               Path to SSH private key
  AUTO_TERMINATE             Terminate instance after benchmark (default: true)
  KEEP_ON_FAILURE            Keep instance running on failure (default: false)
EOF
  exit 0
}

# Ensure dependencies
check_dependencies() {
  if ! command -v aws &>/dev/null; then
    error "AWS CLI not found. Install with: brew install awscli"
    exit 1
  fi

  if ! command -v jq &>/dev/null; then
    error "jq not found. Install with: brew install jq"
    exit 1
  fi

  if [ ! -f "$MODELS_FILE" ]; then
    error "models-to-test.json not found"
    exit 1
  fi
}

# Run benchmark on a single model
benchmark_model() {
  local MODEL_KEY="$1"
  local MODEL_INFO
  local MODEL_ID
  local MODEL_NAME
  local INSTANCE_ID
  local PUBLIC_IP
  local EXIT_CODE=0

  MODEL_INFO=$(jq -c ".models[] | select(.key == \"$MODEL_KEY\")" "$MODELS_FILE")

  if [ -z "$MODEL_INFO" ]; then
    error "Model '$MODEL_KEY' not found in $MODELS_FILE"
    return 1
  fi

  MODEL_ID=$(echo "$MODEL_INFO" | jq -r '.modelId')
  MODEL_NAME=$(echo "$MODEL_INFO" | jq -r '.name')

  echo ""
  echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║  BENCHMARK: ${MODEL_NAME}${NC}"
  echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════╝${NC}"
  echo ""

  # Phase 1: Launch instance
  log "Launching benchmark instance..."
  INSTANCE_ID=$(./infra/launch-instance.sh "$MODEL_ID")

  if [ -z "$INSTANCE_ID" ]; then
    error "Failed to launch instance"
    return 1
  fi

  log "Instance ID: $INSTANCE_ID"

  # Cleanup trap
  cleanup() {
    if [ "$AUTO_TERMINATE" = "true" ]; then
      if [ "$KEEP_ON_FAILURE" = "true" ] && [ "$EXIT_CODE" != "0" ]; then
        log "Keeping instance $INSTANCE_ID for debugging (KEEP_ON_FAILURE=true)"
        log "SSH: ssh -i $CLAW_SSH_KEY ubuntu@$PUBLIC_IP"
        log "Terminate manually: ./infra/terminate-instance.sh $INSTANCE_ID"
      else
        log "Terminating instance $INSTANCE_ID..."
        ./infra/terminate-instance.sh "$INSTANCE_ID" || true
      fi
    else
      log "Instance kept running (AUTO_TERMINATE=false): $INSTANCE_ID"
      log "SSH: ssh -i $CLAW_SSH_KEY ubuntu@$PUBLIC_IP"
    fi
  }
  trap cleanup EXIT

  # Phase 2: Wait for ready
  log "Waiting for instance to be ready..."
  PUBLIC_IP=$(./infra/wait-for-ready.sh "$INSTANCE_ID" 300)

  if [ -z "$PUBLIC_IP" ]; then
    error "Instance failed to become ready"
    EXIT_CODE=1
    return 1
  fi

  log "Instance ready at $PUBLIC_IP"

  # Phase 3: Run benchmark
  log "Running benchmark..."

  export CLAW_HOST="ubuntu@$PUBLIC_IP"
  export CLAW_SSH_KEY="${CLAW_SSH_KEY/#\~/$HOME}"
  export CLAW_MODEL="$MODEL_ID"

  mkdir -p "$REPORTS_DIR"

  local RAW_OUTPUT
  local JSON_OUTPUT
  local START_TIME
  local END_TIME

  START_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Run the benchmark
  RAW_OUTPUT=$(./run.sh --ssh 2>&1) || EXIT_CODE=$?
  JSON_OUTPUT=$(./run.sh --ssh --json 2>&1) || true

  END_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Save results
  echo "$RAW_OUTPUT" > "$REPORTS_DIR/${MODEL_KEY}-results-raw.txt"

  # Extract JSON from output
  local JSON_RESULT
  JSON_RESULT=$(echo "$JSON_OUTPUT" | sed -n '/^{$/,/^}$/p')
  echo "$JSON_RESULT" > "$REPORTS_DIR/${MODEL_KEY}-results.json"

  # Parse results
  local TOTAL PASSED FAILED CRITICAL
  TOTAL=$(echo "$JSON_RESULT" | jq -r '.results.total // 0' 2>/dev/null) || TOTAL=0
  PASSED=$(echo "$JSON_RESULT" | jq -r '.results.passed // 0' 2>/dev/null) || PASSED=0
  FAILED=$(echo "$JSON_RESULT" | jq -r '.results.failed // 0' 2>/dev/null) || FAILED=0
  CRITICAL=$(echo "$JSON_RESULT" | jq -r '.results.critical // 0' 2>/dev/null) || CRITICAL=0

  # Get pricing
  local INPUT_COST OUTPUT_COST
  INPUT_COST=$(echo "$MODEL_INFO" | jq -r '.inputCostPerMillion // 0')
  OUTPUT_COST=$(echo "$MODEL_INFO" | jq -r '.outputCostPerMillion // 0')

  # Generate report
  cat > "$REPORTS_DIR/${MODEL_KEY}-report.md" << EOF
# Benchmark Report: ${MODEL_NAME}

**Date:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")
**Model ID:** $MODEL_ID
**Provider:** $(echo "$MODEL_INFO" | jq -r '.provider')
**Instance:** $INSTANCE_ID ($PUBLIC_IP)

## Pricing

| Metric | Cost per 1M tokens |
|--------|-------------------|
| Input | \$${INPUT_COST} |
| Output | \$${OUTPUT_COST} |

## Results Summary

| Metric | Value |
|--------|-------|
| Total Tests | ${TOTAL} |
| Passed | ${PASSED} |
| Failed | ${FAILED} |
| Critical Failures | ${CRITICAL} |
| Pass Rate | $([ "$TOTAL" -gt 0 ] && echo "scale=1; $PASSED * 100 / $TOTAL" | bc || echo "0")% |

## Test Details

| Test | Status | Notes |
|------|--------|-------|
$(echo "$JSON_RESULT" | jq -r '.tests[] | "| \(.name) | \(if .status == "pass" then "✅ PASS" elif .status == "critical_fail" then "🔴 CRITICAL" else "❌ FAIL" end) | \(.reason // .message // "-") |"' 2>/dev/null || echo "| (parse error) | - | - |")

## Instance Details

| Property | Value |
|----------|-------|
| Instance ID | $INSTANCE_ID |
| Public IP | $PUBLIC_IP |
| Start Time | $START_TIME |
| End Time | $END_TIME |

## Notes

$(echo "$MODEL_INFO" | jq -r '.notes // "No notes"')

---
*Generated by claw-bench live benchmark - $(date -u +"%Y-%m-%d")*
EOF

  success "Report saved: $REPORTS_DIR/${MODEL_KEY}-report.md"

  # Print summary
  echo ""
  if [ "$CRITICAL" -gt 0 ]; then
    echo -e "  ${RED}Result: ${PASSED}/${TOTAL} passed, ${CRITICAL} CRITICAL failures${NC}"
    EXIT_CODE=2
  elif [ "$FAILED" -gt 0 ]; then
    echo -e "  ${YELLOW}Result: ${PASSED}/${TOTAL} passed${NC}"
    EXIT_CODE=1
  else
    echo -e "  ${GREEN}Result: ${PASSED}/${TOTAL} passed - ALL TESTS PASSED${NC}"
  fi

  return $EXIT_CODE
}

# Run benchmarks in parallel using MUSE
benchmark_parallel() {
  local NUM_PARALLEL="${1:-2}"
  local MODELS

  if ! command -v tribe &>/dev/null; then
    error "TRIBE CLI not found. Install from: https://tribecode.ai/install"
    error "Or run benchmarks sequentially with: ./benchmark-live.sh --all"
    exit 1
  fi

  MODELS=$(jq -r '.models[].key' "$MODELS_FILE")
  local MODEL_COUNT=$(echo "$MODELS" | wc -l | tr -d ' ')

  log "Starting parallel benchmark of $MODEL_COUNT models ($NUM_PARALLEL concurrent)"

  # Launch MUSE agents for each model
  local AGENTS=()
  local LAUNCHED=0

  for MODEL_KEY in $MODELS; do
    # Wait if we've hit the parallel limit
    while [ ${#AGENTS[@]} -ge $NUM_PARALLEL ]; do
      # Check for completed agents
      local NEW_AGENTS=()
      for AGENT in "${AGENTS[@]}"; do
        local STATUS
        STATUS=$(tribe muse status 2>/dev/null | grep "$AGENT" | grep -c "complete" || echo "0")
        if [ "$STATUS" = "0" ]; then
          NEW_AGENTS+=("$AGENT")
        else
          log "Agent $AGENT completed"
        fi
      done
      AGENTS=("${NEW_AGENTS[@]}")

      if [ ${#AGENTS[@]} -ge $NUM_PARALLEL ]; then
        sleep 10
      fi
    done

    # Spawn new agent
    log "Spawning benchmark agent for $MODEL_KEY..."
    local AGENT_NAME="bench-$MODEL_KEY"

    tribe muse spawn "Run benchmark for model $MODEL_KEY:
    1. cd $SCRIPT_DIR
    2. Run: ./benchmark-live.sh $MODEL_KEY
    3. Report results and any errors
    Wait for completion and output AWAITING_REVIEW when done." "$AGENT_NAME" 2>/dev/null || {
      error "Failed to spawn agent for $MODEL_KEY"
      continue
    }

    AGENTS+=("$AGENT_NAME")
    LAUNCHED=$((LAUNCHED + 1))
  done

  log "Launched $LAUNCHED benchmark agents"
  log "Monitor with: tribe muse status"
  log "View output: tribe muse output <agent-name>"
}

# Main
check_dependencies

case "${1:-}" in
  --help|-h)
    usage
    ;;
  --list)
    echo "Available models:"
    jq -r '.models[] | "  \(.key) - \(.name) (\(.provider))"' "$MODELS_FILE"
    ;;
  --cleanup)
    log "Terminating all benchmark instances..."
    ./infra/terminate-instance.sh --all
    ;;
  --all)
    log "Running all benchmarks sequentially..."
    MODELS=$(jq -r '.models[].key' "$MODELS_FILE")
    for MODEL_KEY in $MODELS; do
      benchmark_model "$MODEL_KEY" || true
    done
    ;;
  --parallel)
    benchmark_parallel "${2:-2}"
    ;;
  "")
    usage
    ;;
  *)
    benchmark_model "$1"
    ;;
esac
