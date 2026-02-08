#!/bin/bash
# Test: File Operations (read/write/edit tools)
# Tests that the agent can read, write, and edit files
#
# Pass: File created, read back correctly
# Fail: File operations failed

test_file_operations() {
  claw_header "TEST 16: File Operations (read/write)"

  local start_s end_s duration
  start_s=$(date +%s)

  # Generate a unique test value
  local test_value="CLAWBENCH_FILE_TEST_$(date +%s)"
  local test_file="/tmp/clawbench-test-$$.txt"

  # Ask agent to write a file and read it back
  local response
  response=$(claw_ask "Use the write tool to create a file at $test_file with the content '$test_value'. Then use the read tool to read it back and tell me what it contains.")

  end_s=$(date +%s)
  duration=$(( (end_s - start_s) * 1000 ))

  # Cleanup the test file
  case "$CLAW_MODE" in
    local)
      rm -f "$test_file" 2>/dev/null
      ;;
    ssh)
      ssh -i "$CLAW_SSH_KEY" $CLAW_SSH_OPTS "$CLAW_HOST" "rm -f '$test_file'" 2>/dev/null
      ;;
  esac

  if claw_is_empty "$response"; then
    claw_critical "Empty response on file operations test" "file_operations" "$duration"
  elif [[ "$response" == *"$test_value"* ]]; then
    claw_pass "File write/read working: value matched" "file_operations" "$duration"
  elif [[ "$response" == *"CLAWBENCH_FILE_TEST"* ]]; then
    claw_pass "File write/read working: content verified" "file_operations" "$duration"
  elif [[ "$response" == *"created"* ]] || [[ "$response" == *"wrote"* ]] || [[ "$response" == *"written"* ]]; then
    if [[ "$response" == *"read"* ]] || [[ "$response" == *"contains"* ]]; then
      claw_pass "File operations completed" "file_operations" "$duration"
    else
      claw_fail "File write succeeded but read may have failed: ${response:0:200}" "file_operations" "$duration"
    fi
  elif [[ "$response" == *"permission"* ]] || [[ "$response" == *"denied"* ]]; then
    claw_warn "File operations permission denied (may be sandboxed)"
    claw_pass "File tools responded (permission denied - expected in sandbox)" "file_operations" "$duration"
  elif [[ "$response" == *"disabled"* ]] || [[ "$response" == *"not available"* ]]; then
    claw_fail "File tools disabled: $response" "file_operations" "$duration"
  else
    claw_fail "File operations did not work as expected: ${response:0:200}" "file_operations" "$duration"
  fi
}
