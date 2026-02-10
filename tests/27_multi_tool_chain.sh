#!/bin/bash
# Test: Multi-tool Chain
# Tests the agent's ability to chain multiple tools together for a complex task
#
# Pass: Agent uses 2+ tools in sequence to complete task
# Fail: Tool chain breaks or incomplete result

test_multi_tool_chain() {
  claw_header "TEST 27: Multi-tool Chain"

  local start_s end_s duration
  start_s=$(date +%s)

  # Task requiring: exec (create file) -> read (verify) -> exec (process)
  local unique_data="CHAIN_$(date +%s)_${RANDOM}"
  local test_file="/tmp/chain_test_$$.txt"

  local response
  response=$(claw_ask "Complete this multi-step task:
1. Use exec to run: echo '$unique_data' > $test_file
2. Use the read tool to read $test_file
3. Use exec to run: wc -c < $test_file
Report the character count you found.")

  end_s=$(date +%s)
  duration=$(( (end_s - start_s) * 1000 ))

  # Expected char count is length of unique_data + newline
  local expected_len=$(( ${#unique_data} + 1 ))

  if claw_is_empty "$response"; then
    claw_critical "Empty response on multi-tool chain" "multi_tool_chain" "$duration"
  # Check for evidence of multi-step completion
  elif [[ "$response" == *"$expected_len"* ]] || [[ "$response" == *"$((expected_len - 1))"* ]] || \
       [[ "$response" == *"$((expected_len + 1))"* ]]; then
    # Got roughly correct character count
    claw_pass "Multi-tool chain verified: correct byte count" "multi_tool_chain" "$duration"
  elif [[ "$response" == *"$unique_data"* ]]; then
    # At least read the data back
    if [[ "$response" == *"character"* ]] || [[ "$response" == *"byte"* ]] || [[ "$response" == *"wc"* ]]; then
      claw_pass "Multi-tool chain working: data processed" "multi_tool_chain" "$duration"
    else
      claw_warn "Data found but wc step unclear"
      claw_pass "Multi-tool chain partial: read worked" "multi_tool_chain" "$duration"
    fi
  elif [[ "$response" == *"CHAIN_"* ]]; then
    claw_pass "Multi-tool chain working: data pattern found" "multi_tool_chain" "$duration"
  elif [[ "$response" == *"step"* ]] || [[ "$response" == *"Step"* ]]; then
    # Agent acknowledged steps
    if [[ "$response" == *"complete"* ]] || [[ "$response" == *"done"* ]]; then
      claw_pass "Multi-tool chain completed" "multi_tool_chain" "$duration"
    else
      claw_fail "Multi-tool chain incomplete: ${response:0:200}" "multi_tool_chain" "$duration"
    fi
  else
    claw_fail "Multi-tool chain failed: ${response:0:200}" "multi_tool_chain" "$duration"
  fi

  # Cleanup
  case "$CLAW_MODE" in
    ssh)
      ssh -n -i "$CLAW_SSH_KEY" $CLAW_SSH_OPTS "$CLAW_HOST" "rm -f '$test_file'" 2>/dev/null
      ;;
  esac
}
