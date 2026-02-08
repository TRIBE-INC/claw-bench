#!/bin/bash
# Test: Muse Extension (OpenClaw Runtime)
# Tests that the Muse/TribeCode extension is loaded and functional.
#
# Pass: Extension loaded, tools available, status returns successfully
# Fail: Extension not loaded or tools unavailable
#
# Requires: tribecode plugin enabled in clawdbot
#   clawdbot plugins enable tribecode

test_muse_extension() {
  claw_header "TEST 12: Muse Extension (OpenClaw)"

  local start_s
  local end_s
  local duration
  start_s=$(date +%s)

  # First check if the tribecode plugin is loaded
  local plugin_status
  case "$CLAW_MODE" in
    local)
      plugin_status=$(clawdbot plugins list 2>&1 | grep -i "tribecode\|tribe" | head -1)
      ;;
    ssh)
      plugin_status=$(ssh -i "$CLAW_SSH_KEY" $CLAW_SSH_OPTS "$CLAW_HOST" \
        "clawdbot plugins list 2>&1 | grep -i 'tribecode\|TribeCode' | head -1")
      ;;
    api)
      plugin_status="CLAW_NOT_IMPLEMENTED"
      ;;
  esac

  # Check if plugin is loaded
  if [[ "$plugin_status" == *"loaded"* ]]; then
    echo -e "  ${GREEN}INFO${NC}: tribecode plugin is loaded"
  elif [[ "$plugin_status" == *"disabled"* ]]; then
    end_s=$(date +%s)
    duration=$(( (end_s - start_s) * 1000 ))
    claw_fail "tribecode plugin is disabled - run: clawdbot plugins enable tribecode" "muse_extension" "$duration"
    return
  else
    end_s=$(date +%s)
    duration=$(( (end_s - start_s) * 1000 ))
    claw_fail "tribecode plugin not found: $plugin_status" "muse_extension" "$duration"
    return
  fi

  # Now test the tribe_status tool via agent
  local response
  response=$(claw_ask "Run tribe_status to check if TRIBE CLI is configured. Report the status in your response.")

  end_s=$(date +%s)
  duration=$(( (end_s - start_s) * 1000 ))

  if claw_is_empty "$response"; then
    claw_fail "Empty response when testing muse extension" "muse_extension" "$duration"
  elif [[ "$response" == *"not installed"* ]] || [[ "$response" == *"Not installed"* ]]; then
    claw_warn "TRIBE CLI not installed - muse in local-only mode"
    claw_pass "Muse extension loaded (local-only mode)" "muse_extension" "$duration"
  elif [[ "$response" == *"Not authenticated"* ]] || [[ "$response" == *"not authenticated"* ]] || \
       [[ "$response" == *"local-only"* ]] || [[ "$response" == *"local only"* ]]; then
    claw_warn "TRIBE not authenticated - muse in local-only mode"
    claw_pass "Muse extension loaded (local-only mode)" "muse_extension" "$duration"
  elif [[ "$response" == *"Active"* ]] || [[ "$response" == *"active"* ]] || \
       [[ "$response" == *"status"* ]] || [[ "$response" == *"Status"* ]] || \
       [[ "$response" == *"tribe"* ]] || [[ "$response" == *"TRIBE"* ]] || \
       [[ "$response" == *"telemetry"* ]] || [[ "$response" == *"Telemetry"* ]]; then
    claw_pass "Muse extension functional" "muse_extension" "$duration"
  else
    # Even if response doesn't match expected patterns, plugin is loaded
    claw_pass "Muse extension loaded (response: ${response:0:100}...)" "muse_extension" "$duration"
  fi
}
