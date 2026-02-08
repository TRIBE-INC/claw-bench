#!/bin/bash
# claw-bench/lib/common.sh
# Common functions for clawdbot benchmarking

# Colors (disabled if not a tty)
if [ -t 1 ]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  BLUE='\033[0;34m'
  BOLD='\033[1m'
  NC='\033[0m'
else
  RED=''
  GREEN=''
  YELLOW=''
  BLUE=''
  BOLD=''
  NC=''
fi

# Counters
CLAW_PASSED=0
CLAW_FAILED=0
CLAW_CRITICAL=0
CLAW_TOTAL=0

# Results array for JSON output
declare -a CLAW_RESULTS

#=============================================================================
# Configuration
#=============================================================================

claw_init() {
  # Load config file if exists
  if [ -f "${CLAW_BENCH_DIR}/config.sh" ]; then
    # shellcheck source=/dev/null
    source "${CLAW_BENCH_DIR}/config.sh"
  fi

  # Defaults
  CLAW_TIMEOUT="${CLAW_TIMEOUT:-90}"
  CLAW_SESSION="${CLAW_SESSION:-bench-$$-$(date +%s)}"
  CLAW_SSH_KEY="${CLAW_SSH_KEY:-$HOME/.ssh/id_rsa}"
  CLAW_SSH_OPTS="${CLAW_SSH_OPTS:--o StrictHostKeyChecking=no -o ConnectTimeout=10}"

  # Validate mode
  case "${CLAW_MODE:-}" in
    local|ssh|api)
      ;;
    *)
      echo "Error: CLAW_MODE must be 'local', 'ssh', or 'api'" >&2
      exit 3
      ;;
  esac
}

#=============================================================================
# Agent Communication
#=============================================================================

# Send a message to the agent and get response
# Usage: claw_ask "Your message here"
# Note: Uses unique session per call to avoid context accumulation issues
claw_ask() {
  local message="$1"
  local json_result
  local result
  # Use unique session ID per call to prevent context overflow
  local call_session="${CLAW_SESSION}-$(date +%s%N | cut -c1-13)"

  case "$CLAW_MODE" in
    local)
      json_result=$(timeout "$CLAW_TIMEOUT" clawdbot agent \
        --session-id "$call_session" \
        --message "$message" \
        --json 2>/dev/null) || json_result='{"error":"timeout"}'
      ;;

    ssh)
      # Use base64 encoding for reliable message transmission through SSH
      local encoded_message
      encoded_message=$(echo -n "$message" | base64)
      json_result=$(ssh -n -i "$CLAW_SSH_KEY" $CLAW_SSH_OPTS "$CLAW_HOST" \
        "timeout $CLAW_TIMEOUT clawdbot agent --session-id '$call_session' --message \"\$(echo '$encoded_message' | base64 -d)\" --json 2>/dev/null" \
        2>/dev/null) || json_result='{"error":"timeout"}'
      ;;

    api)
      # WebSocket-based gateway doesn't have REST API
      # This is a placeholder for future REST API support
      echo "Error: API mode not yet implemented for clawdbot gateway" >&2
      echo "CLAW_NOT_IMPLEMENTED"
      return
      ;;
  esac

  # Extract text from JSON payload
  # Try multiple paths since response format varies
  result=$(echo "$json_result" | jq -r '
    .result.payloads[0].text //
    .result.payloads[].text //
    .response //
    .text //
    .error //
    "CLAW_EMPTY_RESPONSE"
  ' 2>/dev/null) || result="CLAW_JSON_PARSE_ERROR"

  # Handle timeout/error cases
  if [ -z "$result" ] || [ "$result" = "null" ]; then
    result="CLAW_EMPTY_RESPONSE"
  fi

  echo "$result"
}

# Send a message and get JSON response
# Usage: claw_ask_json "Your message here"
claw_ask_json() {
  local message="$1"
  local result

  case "$CLAW_MODE" in
    local)
      result=$(timeout "$CLAW_TIMEOUT" clawdbot agent \
        --session-id "$CLAW_SESSION" \
        --message "$message" \
        --json 2>/dev/null)
      ;;

    ssh)
      # Use base64 encoding for reliable message transmission through SSH
      local encoded_message
      encoded_message=$(echo -n "$message" | base64)
      result=$(ssh -n -i "$CLAW_SSH_KEY" $CLAW_SSH_OPTS "$CLAW_HOST" \
        "timeout $CLAW_TIMEOUT clawdbot agent --session-id '$CLAW_SESSION' --message \"\$(echo '$encoded_message' | base64 -d)\" --json 2>/dev/null" \
        2>/dev/null)
      ;;

    api)
      result='{"error": "API mode not implemented"}'
      ;;
  esac

  echo "$result"
}

#=============================================================================
# Response Validation
#=============================================================================

# Check if response is empty or useless
# Usage: if claw_is_empty "$response"; then ...
claw_is_empty() {
  local response="$1"

  # Empty string
  [ -z "$response" ] && return 0

  # Common non-responses
  case "$response" in
    "completed"|"done"|"ok"|"null"|"CLAW_TIMEOUT"|"CLAW_NOT_IMPLEMENTED"|"CLAW_EMPTY_RESPONSE"|"CLAW_JSON_PARSE_ERROR")
      return 0
      ;;
  esac

  # Whitespace only
  [[ "$response" =~ ^[[:space:]]*$ ]] && return 0

  return 1
}

# Check if response contains reasoning tags
# Usage: if claw_has_reasoning_tags "$response"; then ...
claw_has_reasoning_tags() {
  local response="$1"

  [[ "$response" == *"<reasoning>"* ]] && return 0
  [[ "$response" == *"</reasoning>"* ]] && return 0
  [[ "$response" == *"<think>"* ]] && return 0
  [[ "$response" == *"</think>"* ]] && return 0

  return 1
}

# Check JSON response for empty payloads (tool-use bug detection)
# Usage: if claw_json_has_empty_payload "$json_response"; then ...
claw_json_has_empty_payload() {
  local json="$1"
  local payloads
  local output_tokens

  payloads=$(echo "$json" | jq -r '.result.payloads | length' 2>/dev/null || echo "0")
  output_tokens=$(echo "$json" | jq -r '.result.meta.agentMeta.usage.output' 2>/dev/null || echo "0")

  # Empty payloads AND very few output tokens = empty response bug
  [ "$payloads" = "0" ] && [ "$output_tokens" -lt 20 ] && return 0

  return 1
}

#=============================================================================
# Test Reporting
#=============================================================================

claw_header() {
  local name="$1"
  echo ""
  echo -e "${BLUE}━━━ $name ━━━${NC}"
}

claw_pass() {
  local message="$1"
  local test_name="${2:-unknown}"
  local duration="${3:-0}"

  echo -e "  ${GREEN}PASS${NC}: $message"
  CLAW_PASSED=$((CLAW_PASSED + 1))
  CLAW_TOTAL=$((CLAW_TOTAL + 1))

  CLAW_RESULTS+=("{\"name\":\"$test_name\",\"status\":\"pass\",\"message\":\"$message\",\"duration_ms\":$duration}")
}

claw_fail() {
  local message="$1"
  local test_name="${2:-unknown}"
  local duration="${3:-0}"

  echo -e "  ${RED}FAIL${NC}: $message"
  CLAW_FAILED=$((CLAW_FAILED + 1))
  CLAW_TOTAL=$((CLAW_TOTAL + 1))

  CLAW_RESULTS+=("{\"name\":\"$test_name\",\"status\":\"fail\",\"message\":\"$message\",\"duration_ms\":$duration}")
}

claw_critical() {
  local message="$1"
  local test_name="${2:-unknown}"
  local duration="${3:-0}"

  echo -e "  ${RED}${BOLD}CRITICAL FAIL${NC}: $message"
  CLAW_FAILED=$((CLAW_FAILED + 1))
  CLAW_CRITICAL=$((CLAW_CRITICAL + 1))
  CLAW_TOTAL=$((CLAW_TOTAL + 1))

  CLAW_RESULTS+=("{\"name\":\"$test_name\",\"status\":\"critical_fail\",\"message\":\"$message\",\"duration_ms\":$duration}")
}

claw_warn() {
  local message="$1"
  echo -e "  ${YELLOW}WARN${NC}: $message"
}

claw_info() {
  local message="$1"
  echo -e "  ${BLUE}INFO${NC}: $message"
}

#=============================================================================
# Output Formatting
#=============================================================================

claw_summary_human() {
  echo ""
  echo "╔══════════════════════════════════════════════════════════════════╗"
  echo "║                         RESULTS                                  ║"
  echo "╠══════════════════════════════════════════════════════════════════╣"
  printf "║  Total Tests:      %-3d                                          ║\n" "$CLAW_TOTAL"
  printf "║  Passed:           ${GREEN}%-3d${NC}                                          ║\n" "$CLAW_PASSED"
  printf "║  Failed:           ${RED}%-3d${NC}                                          ║\n" "$CLAW_FAILED"
  if [ "$CLAW_CRITICAL" -gt 0 ]; then
    printf "║  ${RED}${BOLD}CRITICAL FAILURES: %-3d${NC}                                          ║\n" "$CLAW_CRITICAL"
  fi
  echo "╚══════════════════════════════════════════════════════════════════╝"
  echo ""

  if [ "$CLAW_CRITICAL" -gt 0 ]; then
    echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║  CRITICAL: Agent has blocking issues - DO NOT DEPLOY            ║${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════════════╝${NC}"
  elif [ "$CLAW_FAILED" -gt 0 ]; then
    echo -e "${YELLOW}Some tests failed - review above for details${NC}"
  else
    echo -e "${GREEN}${BOLD}ALL TESTS PASSED - Agent is ready${NC}"
  fi
}

claw_summary_json() {
  local model="${CLAW_MODEL:-unknown}"
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  echo "{"
  echo "  \"timestamp\": \"$timestamp\","
  echo "  \"model\": \"$model\","
  echo "  \"session\": \"$CLAW_SESSION\","
  echo "  \"results\": {"
  echo "    \"total\": $CLAW_TOTAL,"
  echo "    \"passed\": $CLAW_PASSED,"
  echo "    \"failed\": $CLAW_FAILED,"
  echo "    \"critical\": $CLAW_CRITICAL"
  echo "  },"
  echo "  \"tests\": ["

  local first=true
  for result in "${CLAW_RESULTS[@]}"; do
    if [ "$first" = true ]; then
      first=false
    else
      echo ","
    fi
    echo -n "    $result"
  done

  echo ""
  echo "  ]"
  echo "}"
}

claw_summary_tap() {
  echo "TAP version 14"
  echo "1..$CLAW_TOTAL"

  local i=1
  for result in "${CLAW_RESULTS[@]}"; do
    local name
    local status
    name=$(echo "$result" | jq -r '.name')
    status=$(echo "$result" | jq -r '.status')

    case "$status" in
      pass)
        echo "ok $i - $name"
        ;;
      fail)
        echo "not ok $i - $name"
        ;;
      critical_fail)
        local msg
        msg=$(echo "$result" | jq -r '.message')
        echo "not ok $i - $name # CRITICAL: $msg"
        ;;
    esac

    i=$((i + 1))
  done
}

#=============================================================================
# Exit Handling
#=============================================================================

claw_exit() {
  if [ "$CLAW_CRITICAL" -gt 0 ]; then
    exit 2
  elif [ "$CLAW_FAILED" -gt 0 ]; then
    exit 1
  else
    exit 0
  fi
}
