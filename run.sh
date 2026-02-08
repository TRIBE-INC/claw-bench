#!/bin/bash
# claw-bench - Clawdbot Agent Benchmark Suite
# https://github.com/anthropics/clawdbot
#
# Usage:
#   ./run.sh --local              Run against local clawdbot
#   ./run.sh --ssh                Run against remote instance via SSH
#   ./run.sh --api                Run against gateway API (not yet implemented)
#
# Options:
#   --json                        Output results as JSON
#   --tap                         Output results as TAP
#   --help                        Show this help

set -euo pipefail

CLAW_BENCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CLAW_BENCH_DIR

# Parse arguments
CLAW_MODE=""
CLAW_OUTPUT="human"

usage() {
  cat <<EOF
claw-bench - Clawdbot Agent Benchmark Suite

Usage:
  ./run.sh --local [options]      Run against local clawdbot
  ./run.sh --ssh [options]        Run against remote instance via SSH
  ./run.sh --api [options]        Run against gateway API

Options:
  --json          Output results as JSON
  --tap           Output results as TAP format
  --help          Show this help

Environment Variables:
  CLAW_HOST       SSH target (user@host) for --ssh mode
  CLAW_SSH_KEY    Path to SSH private key (default: ~/.ssh/id_rsa)
  CLAW_GATEWAY    Gateway URL for --api mode
  CLAW_TOKEN      Gateway auth token for --api mode
  CLAW_TIMEOUT    Request timeout in seconds (default: 90)

Examples:
  # Local clawdbot
  ./run.sh --local

  # Remote via SSH
  CLAW_HOST=ubuntu@192.168.1.100 CLAW_SSH_KEY=~/.ssh/mykey.pem ./run.sh --ssh

  # JSON output for CI
  ./run.sh --local --json > results.json

EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --local)
      CLAW_MODE="local"
      shift
      ;;
    --ssh)
      CLAW_MODE="ssh"
      shift
      ;;
    --api)
      CLAW_MODE="api"
      shift
      ;;
    --json)
      CLAW_OUTPUT="json"
      shift
      ;;
    --tap)
      CLAW_OUTPUT="tap"
      shift
      ;;
    --help|-h)
      usage
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Use --help for usage" >&2
      exit 3
      ;;
  esac
done

if [ -z "$CLAW_MODE" ]; then
  echo "Error: Must specify --local, --ssh, or --api" >&2
  echo "Use --help for usage" >&2
  exit 3
fi

export CLAW_MODE
export CLAW_OUTPUT

# Load common library
# shellcheck source=lib/common.sh
source "${CLAW_BENCH_DIR}/lib/common.sh"

# Initialize
claw_init

# Validate configuration
case "$CLAW_MODE" in
  ssh)
    if [ -z "${CLAW_HOST:-}" ]; then
      echo "Error: CLAW_HOST must be set for SSH mode (e.g., ubuntu@192.168.1.100)" >&2
      exit 3
    fi
    if [ ! -f "${CLAW_SSH_KEY/#\~/$HOME}" ]; then
      echo "Error: SSH key not found: $CLAW_SSH_KEY" >&2
      exit 3
    fi
    ;;
  api)
    if [ -z "${CLAW_GATEWAY:-}" ]; then
      echo "Error: CLAW_GATEWAY must be set for API mode" >&2
      exit 3
    fi
    ;;
esac

# Header (only for human output)
if [ "$CLAW_OUTPUT" = "human" ]; then
  echo ""
  echo "╔══════════════════════════════════════════════════════════════════╗"
  echo "║                    CLAW-BENCH v1.0                               ║"
  echo "║              Clawdbot Agent Benchmark Suite                      ║"
  echo "╠══════════════════════════════════════════════════════════════════╣"
  echo "║  Mode:    $CLAW_MODE"
  echo "║  Session: $CLAW_SESSION"
  echo "║  Time:    $(date '+%Y-%m-%d %H:%M:%S')"
  echo "╚══════════════════════════════════════════════════════════════════╝"

  # Pre-flight checks
  echo ""
  echo "Pre-flight checks..."

  case "$CLAW_MODE" in
    local)
      if ! command -v clawdbot &> /dev/null; then
        echo -e "  ${RED}clawdbot command not found${NC}"
        exit 3
      fi
      echo -e "  ${GREEN}clawdbot: found${NC}"
      ;;
    ssh)
      if ! ssh -i "$CLAW_SSH_KEY" $CLAW_SSH_OPTS "$CLAW_HOST" "echo ok" >/dev/null 2>&1; then
        echo -e "  ${RED}SSH connection failed to $CLAW_HOST${NC}"
        exit 3
      fi
      echo -e "  ${GREEN}SSH: connected to $CLAW_HOST${NC}"

      if ! ssh -i "$CLAW_SSH_KEY" $CLAW_SSH_OPTS "$CLAW_HOST" "command -v clawdbot" >/dev/null 2>&1; then
        echo -e "  ${RED}clawdbot not found on remote host${NC}"
        exit 3
      fi
      echo -e "  ${GREEN}clawdbot: found on remote${NC}"

      # Get model info
      CLAW_MODEL=$(ssh -i "$CLAW_SSH_KEY" $CLAW_SSH_OPTS "$CLAW_HOST" \
        "jq -r '.agents.defaults.model.primary' ~/.clawdbot/clawdbot.json 2>/dev/null" || echo "unknown")
      export CLAW_MODEL
      echo -e "  ${GREEN}Model: $CLAW_MODEL${NC}"
      ;;
  esac
fi

# Load and run all tests
for test_file in "${CLAW_BENCH_DIR}"/tests/*.sh; do
  if [ -f "$test_file" ]; then
    # shellcheck source=/dev/null
    source "$test_file"

    # Extract test function name from filename
    test_name=$(basename "$test_file" .sh | sed 's/^[0-9]*_//')
    test_func="test_${test_name}"

    # Run test if function exists
    if declare -f "$test_func" > /dev/null; then
      "$test_func"
    fi
  fi
done

# Output summary
case "$CLAW_OUTPUT" in
  human)
    claw_summary_human
    ;;
  json)
    claw_summary_json
    ;;
  tap)
    claw_summary_tap
    ;;
esac

# Exit with appropriate code
claw_exit
