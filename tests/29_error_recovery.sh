#!/bin/bash
# Test: Error Recovery
# Tests the agent's ability to recover from tool errors and provide useful responses
#
# Pass: Agent handles error gracefully and provides alternative or explanation
# Fail: Agent crashes, loops, or provides no useful output

test_error_recovery() {
  claw_header "TEST 29: Error Recovery"

  local start_s end_s duration
  start_s=$(date +%s)

  # Ask agent to do something that will fail (read nonexistent file) and recover
  local response
  response=$(claw_ask "Try to read the file /tmp/definitely_does_not_exist_xyz_12345.txt using the read tool. If it fails, tell me what happened and suggest what I should do instead.")

  end_s=$(date +%s)
  duration=$(( (end_s - start_s) * 1000 ))

  if claw_is_empty "$response"; then
    claw_critical "Empty response on error recovery test" "error_recovery" "$duration"
  # Check for graceful error handling
  elif [[ "$response" == *"not exist"* ]] || [[ "$response" == *"doesn't exist"* ]] || \
       [[ "$response" == *"not found"* ]] || [[ "$response" == *"No such file"* ]]; then
    if [[ "$response" == *"suggest"* ]] || [[ "$response" == *"instead"* ]] || \
       [[ "$response" == *"try"* ]] || [[ "$response" == *"create"* ]] || \
       [[ "$response" == *"check"* ]]; then
      claw_pass "Error recovery excellent: explained error and suggested action" "error_recovery" "$duration"
    else
      claw_pass "Error recovery good: recognized file not found" "error_recovery" "$duration"
    fi
  elif [[ "$response" == *"error"* ]] || [[ "$response" == *"Error"* ]] || \
       [[ "$response" == *"failed"* ]]; then
    claw_pass "Error recovery: error acknowledged" "error_recovery" "$duration"
  elif [[ "$response" == *"cannot"* ]] || [[ "$response" == *"unable"* ]]; then
    claw_pass "Error recovery: limitation acknowledged" "error_recovery" "$duration"
  else
    claw_fail "Error recovery unclear: ${response:0:200}" "error_recovery" "$duration"
  fi
}
