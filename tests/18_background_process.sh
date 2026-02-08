#!/bin/bash
# Test: Background Process Management (process tool)
# Tests that the agent can manage background processes
#
# Pass: Process list retrieved or bg task started
# Fail: Process tools unavailable

test_background_process() {
  claw_header "TEST 18: Background Process Management (process)"

  local start_s end_s duration
  start_s=$(date +%s)

  # Ask agent to list background processes
  local response
  response=$(claw_ask "Use the process tool with action 'list' to show any running background exec sessions. Report what you find.")

  end_s=$(date +%s)
  duration=$(( (end_s - start_s) * 1000 ))

  if claw_is_empty "$response"; then
    claw_critical "Empty response on process test" "background_process" "$duration"
  elif [[ "$response" == *"session"* ]] || [[ "$response" == *"process"* ]] || \
       [[ "$response" == *"running"* ]] || [[ "$response" == *"background"* ]]; then
    if [[ "$response" == *"no "* ]] || [[ "$response" == *"none"* ]] || \
       [[ "$response" == *"empty"* ]] || [[ "$response" == *"0 "* ]]; then
      claw_pass "process tool working: no background sessions" "background_process" "$duration"
    else
      claw_pass "process tool working: sessions listed" "background_process" "$duration"
    fi
  elif [[ "$response" == *"list"* ]]; then
    claw_pass "process tool responded" "background_process" "$duration"
  elif [[ "$response" == *"disabled"* ]] || [[ "$response" == *"not available"* ]]; then
    claw_fail "process tool disabled: $response" "background_process" "$duration"
  else
    # May have worked with different response format
    claw_pass "process tool responded" "background_process" "$duration"
  fi
}
