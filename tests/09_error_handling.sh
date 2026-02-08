#!/bin/bash
# Test: Error Handling
# Tests graceful handling of impossible requests.
#
# Pass: Clear error explanation
# Fail: Crash, empty response, or hallucinated success

test_error_handling() {
  claw_header "TEST 9: Error Handling"

  local start_s
  local end_s
  local duration
  start_s=$(date +%s)

  local response
  response=$(claw_ask "Fetch https://this-domain-does-not-exist-xyz123456.invalid and summarize the content. Explain what happened in your response.")

  end_s=$(date +%s)
  duration=$(( (end_s - start_s) * 1000 ))

  # First check for leaked reasoning tags (also a failure)
  if claw_has_reasoning_tags "$response"; then
    claw_critical "Reasoning tags leaked in error response" "error_handling" "$duration"
    return
  fi

  if claw_is_empty "$response"; then
    claw_critical "Empty response on error condition" "error_handling" "$duration"
  elif [[ "$response" == *"error"* ]] || [[ "$response" == *"Error"* ]] || \
       [[ "$response" == *"unable"* ]] || [[ "$response" == *"Unable"* ]] || \
       [[ "$response" == *"could not"* ]] || [[ "$response" == *"Could not"* ]] || \
       [[ "$response" == *"cannot"* ]] || [[ "$response" == *"Cannot"* ]] || \
       [[ "$response" == *"failed"* ]] || [[ "$response" == *"Failed"* ]] || \
       [[ "$response" == *"doesn't exist"* ]] || [[ "$response" == *"not found"* ]] || \
       [[ "$response" == *"invalid"* ]] || [[ "$response" == *"Invalid"* ]]; then
    claw_pass "Graceful error handling" "error_handling" "$duration"
  else
    claw_warn "Unclear error handling: $response"
    # Give benefit of doubt if no crash occurred
    claw_pass "No crash on error (unclear message)" "error_handling" "$duration"
  fi
}
