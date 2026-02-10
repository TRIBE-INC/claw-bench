#!/bin/bash
# =============================================================================
# benchmark-parallel.sh - Run benchmarks in parallel using TRIBE MUSE
# =============================================================================
# Usage:
#   ./benchmark-parallel.sh                      Benchmark all models (2 concurrent)
#   ./benchmark-parallel.sh -n 4                 Benchmark with 4 concurrent instances
#   ./benchmark-parallel.sh -m mistral,nova     Benchmark specific models
#   ./benchmark-parallel.sh --status             Show status of running benchmarks
#   ./benchmark-parallel.sh --collect            Collect results from completed benchmarks
#
# Requires: TRIBE CLI (tribe muse)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Load environment
if [ -f ".env" ]; then
  set -a
  source .env
  set +a
fi

MODELS_FILE="$SCRIPT_DIR/models-to-test.json"
REPORTS_DIR="$SCRIPT_DIR/reports"
PARALLEL="${PARALLEL_INSTANCES:-2}"
SELECTED_MODELS=""

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
benchmark-parallel.sh - Run benchmarks in parallel using TRIBE MUSE

Usage:
  ./benchmark-parallel.sh [options]

Options:
  -n, --parallel NUM    Number of concurrent benchmarks (default: 2)
  -m, --models LIST     Comma-separated list of model keys to benchmark
  --status              Show status of running benchmark agents
  --collect             Collect results from completed benchmarks
  --cleanup             Clean up all agents and terminate instances
  --help                Show this help

Examples:
  ./benchmark-parallel.sh                         # All models, 2 concurrent
  ./benchmark-parallel.sh -n 4                    # All models, 4 concurrent
  ./benchmark-parallel.sh -m mistral-large-3      # Single model
  ./benchmark-parallel.sh -m "mistral-large-3,nova-pro"  # Multiple specific models

Prerequisites:
  1. TRIBE CLI installed: https://tribecode.ai/install
  2. .env configured with AWS credentials
  3. MUSE leader running (auto-started if not)

Monitor Progress:
  tribe muse status                    # Overall status
  tribe muse output bench-<model>      # View specific agent output
  tail -f reports/*-results-raw.txt    # Watch results as they come in
EOF
  exit 0
}

check_dependencies() {
  if ! command -v tribe &>/dev/null; then
    error "TRIBE CLI not found"
    echo ""
    echo "Install with:"
    echo "  curl -fsSL https://tribecode.ai/install.sh | bash"
    echo ""
    echo "Or run benchmarks sequentially:"
    echo "  ./benchmark-live.sh --all"
    exit 1
  fi

  if ! command -v jq &>/dev/null; then
    error "jq not found. Install with: brew install jq"
    exit 1
  fi
}

# Ensure MUSE leader is running
ensure_muse() {
  local STATUS
  STATUS=$(tribe muse status 2>&1 | grep -c "RUNNING" || echo "0")

  if [ "$STATUS" = "0" ]; then
    log "Starting MUSE leader..."
    tribe muse start >/dev/null 2>&1 &
    sleep 3
  fi
}

# Get list of models to benchmark
get_models() {
  if [ -n "$SELECTED_MODELS" ]; then
    echo "$SELECTED_MODELS" | tr ',' '\n'
  else
    jq -r '.models[].key' "$MODELS_FILE"
  fi
}

# Show status of running benchmarks
show_status() {
  echo ""
  echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║              PARALLEL BENCHMARK STATUS                           ║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
  echo ""

  # MUSE agent status
  tribe muse status 2>&1 | grep -E "(bench-|Complete:|Working:)" || echo "No benchmark agents running"

  echo ""
  echo -e "${YELLOW}Active EC2 Instances:${NC}"
  aws ec2 describe-instances --region "${AWS_REGION:-us-east-2}" \
    --filters "Name=tag:ManagedBy,Values=claw-bench" \
              "Name=instance-state-name,Values=pending,running" \
    --query 'Reservations[].Instances[].[InstanceId,PublicIpAddress,Tags[?Key==`Model`].Value|[0],LaunchTime]' \
    --output table 2>/dev/null || echo "  (Unable to query EC2)"

  echo ""
  echo -e "${YELLOW}Recent Reports:${NC}"
  ls -lt "$REPORTS_DIR"/*-report.md 2>/dev/null | head -5 | awk '{print "  " $NF " (" $6 " " $7 " " $8 ")"}' || echo "  No reports yet"
}

# Collect results from completed agents
collect_results() {
  echo ""
  log "Collecting results from completed benchmark agents..."

  local COMPLETED=0
  local FAILED=0

  # Check each model's status
  for MODEL_KEY in $(get_models); do
    local AGENT_NAME="bench-$MODEL_KEY"
    local REPORT_FILE="$REPORTS_DIR/${MODEL_KEY}-report.md"

    if [ -f "$REPORT_FILE" ]; then
      local PASS_RATE
      PASS_RATE=$(grep -E "Pass Rate \|" "$REPORT_FILE" | grep -oE "[0-9]+%" | head -1 || echo "?")
      echo -e "  ${GREEN}✓${NC} $MODEL_KEY: $PASS_RATE"
      COMPLETED=$((COMPLETED + 1))
    else
      # Check if agent is still running
      local STATUS
      STATUS=$(tribe muse status 2>&1 | grep "$AGENT_NAME" | grep -c "working" || echo "0")
      if [ "$STATUS" = "1" ]; then
        echo -e "  ${YELLOW}⋯${NC} $MODEL_KEY: running..."
      else
        echo -e "  ${RED}✗${NC} $MODEL_KEY: no report"
        FAILED=$((FAILED + 1))
      fi
    fi
  done

  echo ""
  echo "Summary: $COMPLETED completed, $FAILED failed/pending"
}

# Clean up all benchmark resources
cleanup_all() {
  log "Cleaning up benchmark resources..."

  # Clean up MUSE agents
  log "Cleaning MUSE agents..."
  tribe muse clean --force --all 2>/dev/null || true

  # Terminate EC2 instances
  log "Terminating EC2 instances..."
  ./infra/terminate-instance.sh --all 2>/dev/null || true

  success "Cleanup complete"
}

# Launch parallel benchmarks
launch_parallel() {
  local MODELS
  MODELS=$(get_models)
  local MODEL_COUNT=$(echo "$MODELS" | wc -l | tr -d ' ')

  echo ""
  echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║              PARALLEL BENCHMARK LAUNCHER                         ║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  log "Models to benchmark: $MODEL_COUNT"
  log "Concurrent instances: $PARALLEL"
  echo ""

  ensure_muse

  local LAUNCHED=0
  local RUNNING=0

  for MODEL_KEY in $MODELS; do
    # Wait if we've hit the parallel limit
    while [ $RUNNING -ge $PARALLEL ]; do
      sleep 5
      RUNNING=$(tribe muse status 2>&1 | grep -c "bench-.*working" || echo "0")
    done

    local AGENT_NAME="bench-$MODEL_KEY"

    # Check if already running or completed
    if tribe muse status 2>&1 | grep -q "$AGENT_NAME"; then
      log "Agent $AGENT_NAME already exists, skipping"
      continue
    fi

    if [ -f "$REPORTS_DIR/${MODEL_KEY}-report.md" ]; then
      log "Report for $MODEL_KEY already exists, skipping"
      continue
    fi

    log "Spawning benchmark agent for $MODEL_KEY..."

    # Spawn MUSE agent
    tribe muse spawn "Benchmark model: $MODEL_KEY

Your task:
1. Change to the benchmark directory: cd $SCRIPT_DIR
2. Run the benchmark: ./benchmark-live.sh $MODEL_KEY
3. Wait for completion
4. Report the pass rate and any critical failures

Important:
- The script handles instance launch/termination automatically
- Check reports/${MODEL_KEY}-report.md for results
- If benchmark fails, check reports/${MODEL_KEY}-results-raw.txt for errors

Output AWAITING_REVIEW when complete." "$AGENT_NAME" 2>/dev/null || {
      error "Failed to spawn agent for $MODEL_KEY"
      continue
    }

    LAUNCHED=$((LAUNCHED + 1))
    RUNNING=$((RUNNING + 1))

    # Brief delay between launches to avoid AWS rate limits
    sleep 2
  done

  echo ""
  success "Launched $LAUNCHED benchmark agents"
  echo ""
  echo "Monitor progress:"
  echo "  ./benchmark-parallel.sh --status"
  echo "  tribe muse status"
  echo ""
  echo "Collect results when complete:"
  echo "  ./benchmark-parallel.sh --collect"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -n|--parallel)
      PARALLEL="$2"
      shift 2
      ;;
    -m|--models)
      SELECTED_MODELS="$2"
      shift 2
      ;;
    --status)
      check_dependencies
      show_status
      exit 0
      ;;
    --collect)
      check_dependencies
      collect_results
      exit 0
      ;;
    --cleanup)
      check_dependencies
      cleanup_all
      exit 0
      ;;
    --help|-h)
      usage
      ;;
    *)
      error "Unknown option: $1"
      usage
      ;;
  esac
done

# Main execution
check_dependencies
launch_parallel
