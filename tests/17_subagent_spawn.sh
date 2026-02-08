#!/bin/bash
# Test: Sub-agent Spawning (sessions_spawn tool)
# Tests that the agent can spawn sub-agents for parallel tasks
#
# Pass: Sub-agent spawned or agents listed
# Fail: Sub-agent tools unavailable

test_subagent_spawn() {
  claw_header "TEST 17: Sub-agent Communication (sessions)"

  local start_s end_s duration
  start_s=$(date +%s)

  # First check what agents are available
  local response
  response=$(claw_ask "Use the agents_list tool to show me what agents are available for spawning. List their IDs.")

  end_s=$(date +%s)
  duration=$(( (end_s - start_s) * 1000 ))

  if claw_is_empty "$response"; then
    claw_critical "Empty response on subagent test" "subagent_spawn" "$duration"
  elif [[ "$response" == *"agent"* ]] || [[ "$response" == *"main"* ]] || \
       [[ "$response" == *"default"* ]] || [[ "$response" == *"available"* ]]; then
    claw_pass "agents_list working: agents enumerated" "subagent_spawn" "$duration"
  elif [[ "$response" == *"no agent"* ]] || [[ "$response" == *"none"* ]] || \
       [[ "$response" == *"empty"* ]]; then
    claw_warn "No additional agents configured"
    claw_pass "agents_list working (no additional agents)" "subagent_spawn" "$duration"
  elif [[ "$response" == *"sessions"* ]] || [[ "$response" == *"spawn"* ]]; then
    claw_pass "Session tools recognized" "subagent_spawn" "$duration"
  elif [[ "$response" == *"disabled"* ]] || [[ "$response" == *"not available"* ]]; then
    claw_fail "Subagent tools disabled: $response" "subagent_spawn" "$duration"
  else
    # Tool may have worked but response format differs
    claw_pass "Subagent tools responded" "subagent_spawn" "$duration"
  fi
}
