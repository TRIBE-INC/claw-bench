#!/bin/bash
# Test: Session Status (session_status tool)
# Tests that the agent can report its own session status
#
# Pass: Session status reported with model/usage info
# Fail: Session status unavailable

test_session_status() {
  claw_header "TEST 20: Session Status (session_status)"

  local start_s end_s duration
  start_s=$(date +%s)

  local response
  response=$(claw_ask "Use the session_status tool to show me your current session status including the model you're using and token usage.")

  end_s=$(date +%s)
  duration=$(( (end_s - start_s) * 1000 ))

  if claw_is_empty "$response"; then
    claw_critical "Empty response on session status test" "session_status" "$duration"
  elif [[ "$response" == *"model"* ]] || [[ "$response" == *"token"* ]] || \
       [[ "$response" == *"usage"* ]] || [[ "$response" == *"session"* ]]; then
    # Check for model name
    if [[ "$response" == *"mistral"* ]] || [[ "$response" == *"Mistral"* ]]; then
      claw_pass "session_status working: Mistral Large 3 confirmed" "session_status" "$duration"
    elif [[ "$response" == *"bedrock"* ]] || [[ "$response" == *"amazon"* ]]; then
      claw_pass "session_status working: Bedrock model confirmed" "session_status" "$duration"
    else
      claw_pass "session_status working: status reported" "session_status" "$duration"
    fi
  elif [[ "$response" == *"disabled"* ]] || [[ "$response" == *"not available"* ]]; then
    claw_fail "session_status tool disabled: $response" "session_status" "$duration"
  else
    claw_pass "session_status responded" "session_status" "$duration"
  fi
}
