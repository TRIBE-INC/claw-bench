#!/bin/bash
# Test: Clawdbot Verification
# Verifies that we're actually testing against clawdbot (openclaw)
#
# Pass: clawdbot is installed and responding
# Fail: clawdbot not found or not responding

test_clawdbot_verify() {
  claw_header "TEST 0: Clawdbot Verification"

  local start_s end_s duration
  start_s=$(date +%s)

  local version gateway_status

  case "$CLAW_MODE" in
    local)
      version=$(clawdbot --version 2>&1)
      gateway_status=$(curl -sf http://localhost:18789/ 2>&1 && echo "OK" || echo "FAIL")
      ;;
    ssh)
      version=$(ssh -i "$CLAW_SSH_KEY" $CLAW_SSH_OPTS "$CLAW_HOST" \
        "clawdbot --version 2>&1")
      gateway_status=$(ssh -i "$CLAW_SSH_KEY" $CLAW_SSH_OPTS "$CLAW_HOST" \
        "curl -sf http://localhost:18789/ >/dev/null 2>&1 && echo 'OK' || echo 'FAIL'")
      ;;
    api)
      version="API_MODE"
      gateway_status="OK"
      ;;
  esac

  end_s=$(date +%s)
  duration=$(( (end_s - start_s) * 1000 ))

  if [[ -z "$version" ]] || [[ "$version" == *"not found"* ]]; then
    claw_critical "clawdbot not installed" "clawdbot_verify" "$duration"
    return
  fi

  if [[ "$gateway_status" != "OK" ]]; then
    claw_fail "clawdbot gateway not responding" "clawdbot_verify" "$duration"
    return
  fi

  # Export for other tests
  export CLAW_VERSION="$version"

  echo -e "  ${GREEN}INFO${NC}: clawdbot version: $version"
  echo -e "  ${GREEN}INFO${NC}: Gateway: responding"
  claw_pass "clawdbot verified: $version" "clawdbot_verify" "$duration"
}
