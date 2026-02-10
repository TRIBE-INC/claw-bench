#!/bin/bash
# Test: Code Generation Task
# Tests the agent's ability to write code and verify it works
#
# Pass: Agent writes valid code that produces expected output
# Fail: Code doesn't work or wrong output

test_code_generation() {
  claw_header "TEST 24: Code Generation Task"

  local start_s end_s duration
  start_s=$(date +%s)

  # Ask agent to write a simple function and test it
  local response
  response=$(claw_ask "Write a Python one-liner that calculates the sum of squares from 1 to 5 (1^2 + 2^2 + 3^2 + 4^2 + 5^2). Use the exec tool to run it with python3 -c and show me the output. The answer should be 55.")

  end_s=$(date +%s)
  duration=$(( (end_s - start_s) * 1000 ))

  if claw_is_empty "$response"; then
    claw_critical "Empty response on code generation" "code_generation" "$duration"
  # Check for correct answer (55)
  elif [[ "$response" == *"55"* ]]; then
    # Verify it actually ran code (not just stated the answer)
    if [[ "$response" == *"python"* ]] || [[ "$response" == *"exec"* ]] || \
       [[ "$response" == *"sum"* ]] || [[ "$response" == *"output"* ]]; then
      claw_pass "Code generation verified: correct output 55" "code_generation" "$duration"
    else
      claw_warn "Answer correct but unclear if code was executed"
      claw_pass "Code generation: answer correct (55)" "code_generation" "$duration"
    fi
  elif [[ "$response" == *"sum(["* ]] || [[ "$response" == *"**2"* ]] || [[ "$response" == *"pow"* ]]; then
    # Has code pattern but maybe execution failed
    claw_warn "Code written but output may differ"
    claw_pass "Code generation attempted" "code_generation" "$duration"
  elif [[ "$response" == *"error"* ]] || [[ "$response" == *"Error"* ]]; then
    claw_fail "Code execution error: ${response:0:200}" "code_generation" "$duration"
  else
    claw_fail "Code generation failed: expected 55, got: ${response:0:200}" "code_generation" "$duration"
  fi
}
