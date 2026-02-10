#!/bin/bash
# Test: Multi-turn Context Retention
# Tests that the agent maintains context across multiple turns within a session
#
# Pass: Agent remembers and uses information from previous turn
# Fail: Agent loses context or gives inconsistent answers

test_multi_turn_context() {
  claw_header "TEST 22: Multi-turn Context Retention"

  local start_s end_s duration
  start_s=$(date +%s)

  # Generate unique identifiers for this test
  local secret_code="CONTEXT_${RANDOM}_$(date +%s)"
  local shared_session="context-test-$(date +%s)"

  # First turn: give the agent a secret code to remember
  local turn1_response
  turn1_response=$(claw_ask_session "$shared_session" "Remember this secret code for our conversation: $secret_code. Acknowledge that you have stored it.")

  # Brief pause to ensure turn completes
  sleep 1

  # Second turn: ask the agent to recall the code
  local turn2_response
  turn2_response=$(claw_ask_session "$shared_session" "What was the secret code I gave you in my previous message? Reply with ONLY the code, nothing else.")

  end_s=$(date +%s)
  duration=$(( (end_s - start_s) * 1000 ))

  if claw_is_empty "$turn2_response"; then
    claw_critical "Empty response on context recall" "multi_turn_context" "$duration"
  elif [[ "$turn2_response" == *"$secret_code"* ]]; then
    claw_pass "Context retained: secret code recalled correctly" "multi_turn_context" "$duration"
  elif [[ "$turn2_response" == *"CONTEXT_"* ]]; then
    claw_warn "Partial context retention (code format recognized)"
    claw_pass "Context partially retained" "multi_turn_context" "$duration"
  elif [[ "$turn2_response" == *"don't"* ]] || [[ "$turn2_response" == *"cannot"* ]] || \
       [[ "$turn2_response" == *"no code"* ]]; then
    claw_fail "Context lost: agent cannot recall previous turn" "multi_turn_context" "$duration"
  else
    claw_fail "Context test failed: expected '$secret_code', got: ${turn2_response:0:100}" "multi_turn_context" "$duration"
  fi
}

# Helper function for multi-turn with shared session
claw_ask_session() {
  local session_id="$1"
  local message="$2"
  local json_result result

  case "$CLAW_MODE" in
    local)
      json_result=$(timeout "$CLAW_TIMEOUT" clawdbot agent \
        --session-id "$session_id" \
        --message "$message" \
        --json 2>/dev/null) || json_result='{"error":"timeout"}'
      ;;
    ssh)
      local encoded_message
      encoded_message=$(echo -n "$message" | base64)
      json_result=$(ssh -n -i "$CLAW_SSH_KEY" $CLAW_SSH_OPTS "$CLAW_HOST" \
        "timeout $CLAW_TIMEOUT clawdbot agent --session-id '$session_id' --message \"\$(echo '$encoded_message' | base64 -d)\" --json 2>/dev/null" \
        2>/dev/null) || json_result='{"error":"timeout"}'
      ;;
    api)
      echo "CLAW_NOT_IMPLEMENTED"
      return
      ;;
  esac

  result=$(echo "$json_result" | jq -r '.result.payloads[0].text // .error // "CLAW_EMPTY_RESPONSE"' 2>/dev/null)
  echo "$result"
}
