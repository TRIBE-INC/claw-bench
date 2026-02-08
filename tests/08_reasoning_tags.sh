#!/bin/bash
# Test: Reasoning Tag Stripping
# Ensures internal reasoning tags are not visible to users.
#
# Pass: No tags in response
# Critical Fail: Tags leaked to output

test_reasoning_tags() {
  claw_header "TEST 8: No Reasoning Tag Leakage"

  local start_s
  local end_s
  local duration
  start_s=$(date +%s)

  local response
  response=$(claw_ask "What is 144 divided by 12? Give me just the answer.")

  end_s=$(date +%s)
  duration=$(( (end_s - start_s) * 1000 ))

  if claw_has_reasoning_tags "$response"; then
    claw_critical "Reasoning tags leaked to user: $response" "reasoning_tags" "$duration"
  elif claw_is_empty "$response"; then
    claw_fail "Empty response" "reasoning_tags" "$duration"
  elif [[ "$response" == *"12"* ]]; then
    claw_pass "Correct answer, no leaked tags" "reasoning_tags" "$duration"
  else
    claw_fail "Wrong answer: $response" "reasoning_tags" "$duration"
  fi
}
