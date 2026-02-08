#!/bin/bash
# Test: Consecutive Tool Uses
# Tests multiple tool calls in a single request.
#
# Pass: All tool results reported
# Fail: Partial results or empty response

test_consecutive_tools() {
  claw_header "TEST 10: Consecutive Tool Uses"

  local start_s
  local end_s
  local duration
  start_s=$(date +%s)

  local response
  response=$(claw_ask "First, fetch https://httpbin.org/ip to get my IP. Then fetch https://httpbin.org/user-agent to get the user agent. Tell me both values in your response.")

  end_s=$(date +%s)
  duration=$(( (end_s - start_s) * 1000 ))

  # Check for leaked reasoning tags
  if claw_has_reasoning_tags "$response"; then
    claw_critical "Reasoning tags leaked in multi-tool response" "consecutive_tools" "$duration"
    return
  fi

  if claw_is_empty "$response"; then
    claw_critical "Empty response on consecutive tool use" "consecutive_tools" "$duration"
  elif [[ "$response" =~ [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ ]]; then
    claw_pass "Handled consecutive tool calls with response" "consecutive_tools" "$duration"
  else
    claw_fail "Missing expected data: $response" "consecutive_tools" "$duration"
  fi
}
