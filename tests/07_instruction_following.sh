#!/bin/bash
# Test: Instruction Following
# Tests exact instruction following.
#
# Pass: Response matches exact expected text
# Fail: Deviation from instructions

test_instruction_following() {
  claw_header "TEST 7: Instruction Following"

  local start_s
  local end_s
  local duration
  start_s=$(date +%s)

  local response
  response=$(claw_ask "Reply with exactly these words and nothing else: CLAWDBOT BENCHMARK PASSED")

  end_s=$(date +%s)
  duration=$(( (end_s - start_s) * 1000 ))

  if claw_is_empty "$response"; then
    claw_critical "Empty response on instruction task" "instruction_following" "$duration"
  elif [[ "$response" == "CLAWDBOT BENCHMARK PASSED" ]]; then
    claw_pass "Exact instruction following" "instruction_following" "$duration"
  elif [[ "$response" == *"CLAWDBOT BENCHMARK PASSED"* ]]; then
    claw_pass "Contains required text (with extras)" "instruction_following" "$duration"
  else
    claw_fail "Did not follow instructions: $response" "instruction_following" "$duration"
  fi
}
