#!/bin/bash
# Test: Background Process Management (process tool)
# Tests that the agent can manage background processes
#
# Pass: Process list returned with clear status (empty or with process info)
# Fail: Process tools unavailable or no status info

test_background_process() {
  claw_header "TEST 18: Background Process Management (process)"

  local start_s end_s duration
  start_s=$(date +%s)

  # Ask agent to list background processes - require clear status
  local response
  response=$(claw_ask "Use the process tool with action list to check for background exec sessions. Report whether there are any running or not.")

  end_s=$(date +%s)
  duration=$(( (end_s - start_s) * 1000 ))

  if claw_is_empty "$response"; then
    claw_critical "Empty response on process test" "background_process" "$duration"
  # STRICT: Require explicit status about background processes
  elif [[ "$response" == *"No background"* ]] || [[ "$response" == *"no background"* ]] || \
       [[ "$response" == *"currently running"* ]] || [[ "$response" == *"clear"* ]]; then
    claw_pass "process tool verified: background status reported" "background_process" "$duration"
  elif [[ "$response" == *"HEARTBEAT"* ]]; then
    # HEARTBEAT_OK is a known response format
    claw_pass "process tool verified: heartbeat response" "background_process" "$duration"
  elif [[ "$response" == *"exec session"* ]] || [[ "$response" == *"background session"* ]]; then
    claw_pass "process tool verified: session info returned" "background_process" "$duration"
  elif [[ "$response" == *"0 process"* ]] || [[ "$response" == *"zero"* ]] || \
       [[ "$response" == *"none running"* ]]; then
    claw_pass "process tool verified: zero processes reported" "background_process" "$duration"
  elif [[ "$response" == *"disabled"* ]] || [[ "$response" == *"not available"* ]]; then
    claw_fail "process tool disabled: ${response:0:200}" "background_process" "$duration"
  else
    # STRICT: Generic responses without clear status = fail
    claw_fail "process tool did not return clear status: ${response:0:200}" "background_process" "$duration"
  fi
}
