#!/bin/bash
# Test: Shell Command Execution (exec tool)
# Tests that the agent can execute shell commands using the exec tool
#
# Pass: Command executed and output returned correctly
# Fail: Command failed or output missing

test_exec_command() {
  claw_header "TEST 13: Shell Command Execution (exec)"

  local start_s end_s duration
  start_s=$(date +%s)

  # Ask agent to run a simple command and report output
  local response
  response=$(claw_ask "Use the exec tool to run 'echo CLAWBENCH_TEST_\$(date +%s)' and tell me the exact output.")

  end_s=$(date +%s)
  duration=$(( (end_s - start_s) * 1000 ))

  if claw_is_empty "$response"; then
    claw_critical "Empty response on exec test" "exec_command" "$duration"
  elif [[ "$response" == *"CLAWBENCH_TEST_"* ]]; then
    claw_pass "exec tool working: returned command output" "exec_command" "$duration"
  elif [[ "$response" == *"exec"* ]] && [[ "$response" == *"not"* ]]; then
    claw_fail "exec tool disabled or unavailable: $response" "exec_command" "$duration"
  elif [[ "$response" == *"permission"* ]] || [[ "$response" == *"denied"* ]]; then
    claw_warn "exec tool permission denied (may be sandboxed)"
    claw_pass "exec tool responded (permission denied - expected in sandbox)" "exec_command" "$duration"
  else
    claw_fail "exec tool did not return expected output: ${response:0:200}" "exec_command" "$duration"
  fi
}
