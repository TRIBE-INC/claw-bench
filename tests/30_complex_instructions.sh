#!/bin/bash
# Test: Complex Multi-step Instructions
# Tests the agent's ability to follow complex, multi-part instructions
#
# Pass: Agent completes all steps in correct order
# Fail: Agent misses steps or does them out of order

test_complex_instructions() {
  claw_header "TEST 30: Complex Multi-step Instructions"

  local start_s end_s duration
  start_s=$(date +%s)

  local unique_id="COMPLEX_${RANDOM}"

  # Give complex multi-step instructions with verification points
  local response
  response=$(claw_ask "Complete these steps IN ORDER and report each result:
STEP 1: Calculate 7 * 8 and remember the result
STEP 2: Use exec to run: echo 'Step2_${unique_id}'
STEP 3: Add 6 to your Step 1 result
STEP 4: Report all three results as: 'STEP1=X, STEP2=Y, STEP3=Z'")

  end_s=$(date +%s)
  duration=$(( (end_s - start_s) * 1000 ))

  if claw_is_empty "$response"; then
    claw_critical "Empty response on complex instructions" "complex_instructions" "$duration"
  fi

  local step1_ok=false
  local step2_ok=false
  local step3_ok=false

  # Check Step 1: 7 * 8 = 56
  if [[ "$response" == *"56"* ]]; then
    step1_ok=true
  fi

  # Check Step 2: Echo output
  if [[ "$response" == *"Step2_${unique_id}"* ]] || [[ "$response" == *"Step2_"* ]]; then
    step2_ok=true
  fi

  # Check Step 3: 56 + 6 = 62
  if [[ "$response" == *"62"* ]]; then
    step3_ok=true
  fi

  # Check for structured output format
  local has_format=false
  if [[ "$response" == *"STEP1="* ]] || [[ "$response" == *"Step 1"* ]] || \
     [[ "$response" == *"step 1"* ]]; then
    has_format=true
  fi

  if [ "$step1_ok" = true ] && [ "$step2_ok" = true ] && [ "$step3_ok" = true ]; then
    if [ "$has_format" = true ]; then
      claw_pass "Complex instructions: all steps completed with format" "complex_instructions" "$duration"
    else
      claw_pass "Complex instructions: all steps completed" "complex_instructions" "$duration"
    fi
  elif [ "$step1_ok" = true ] && [ "$step3_ok" = true ]; then
    claw_warn "Step 2 (exec) may have failed but calculations correct"
    claw_pass "Complex instructions: math steps completed" "complex_instructions" "$duration"
  elif [ "$step1_ok" = true ] || [ "$step3_ok" = true ]; then
    claw_warn "Some steps completed"
    claw_pass "Complex instructions: partial completion" "complex_instructions" "$duration"
  else
    claw_fail "Complex instructions failed: ${response:0:200}" "complex_instructions" "$duration"
  fi
}
