#!/bin/bash
# Test: Multi-Step Reasoning
# Tests calculation and logical reasoning without tools.
#
# Pass: Correct calculation with explanation
# Fail: Wrong answer or empty response

test_reasoning() {
  claw_header "TEST 6: Multi-Step Reasoning"

  local start_s
  local end_s
  local duration
  start_s=$(date +%s)

  local response
  response=$(claw_ask "A store sells apples for 2 dollars each and oranges for 3 dollars each. If I buy 4 apples and 5 oranges, what is my total cost? Show your calculation and give the final answer.")

  end_s=$(date +%s)
  duration=$(( (end_s - start_s) * 1000 ))

  if claw_is_empty "$response"; then
    claw_critical "Empty response on reasoning task" "reasoning" "$duration"
  elif [[ "$response" == *"23"* ]]; then
    claw_pass "Correct calculation: 4*2 + 5*3 = 23" "reasoning" "$duration"
  else
    claw_fail "Expected 23, got: $response" "reasoning" "$duration"
  fi
}
