#!/bin/bash
# Test: Basic Chat (No Tools)
# Tests LLM connectivity and basic reasoning without tool use.
#
# Pass: Correct math answer returned
# Fail: Wrong answer or empty response

test_basic_chat() {
  claw_header "TEST 1: Basic Chat (No Tools)"

  local start_s
  local end_s
  local duration
  start_s=$(date +%s)

  local response
  response=$(claw_ask "What is 15 + 27? Reply with just the number, nothing else.")

  end_s=$(date +%s)
  duration=$(( (end_s - start_s) * 1000 ))

  if claw_is_empty "$response"; then
    claw_critical "Empty response - LLM not responding" "basic_chat" "$duration"
  elif [[ "$response" == *"42"* ]]; then
    claw_pass "Math correct: 15+27=42" "basic_chat" "$duration"
  else
    claw_fail "Expected 42, got: $response" "basic_chat" "$duration"
  fi
}
