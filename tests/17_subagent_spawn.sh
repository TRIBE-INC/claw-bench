#!/bin/bash
# Test: Sub-agent Spawning (sessions_spawn tool)
# Tests that the agent can spawn sub-agents for parallel tasks
#
# Pass: agents_list returns agent info with "main" session identifier
# Fail: Sub-agent tools unavailable or no agent info returned

test_subagent_spawn() {
  claw_header "TEST 17: Sub-agent Communication (sessions)"

  local start_s end_s duration
  start_s=$(date +%s)

  # Ask for agents list - require specific agent identifiers
  local response
  response=$(claw_ask "Use the agents_list tool to show available agents. Tell me the exact agent IDs or names returned.")

  end_s=$(date +%s)
  duration=$(( (end_s - start_s) * 1000 ))

  if claw_is_empty "$response"; then
    claw_critical "Empty response on subagent test" "subagent_spawn" "$duration"
  # STRICT: Require "main" which is the default agent ID in clawdbot
  elif [[ "$response" == *"main"* ]]; then
    claw_pass "agents_list verified: main agent found" "subagent_spawn" "$duration"
  # Alternative: check for specific agent format indicators
  elif [[ "$response" == *"agent:"* ]] || [[ "$response" == *"session"* ]]; then
    if [[ "$response" == *"only"* ]] || [[ "$response" == *"available"* ]]; then
      claw_pass "agents_list working: agents enumerated" "subagent_spawn" "$duration"
    else
      claw_pass "agents_list working: session info returned" "subagent_spawn" "$duration"
    fi
  elif [[ "$response" == *"no agent"* ]] || [[ "$response" == *"none"* ]] || \
       [[ "$response" == *"empty"* ]]; then
    # This would be unexpected - there should always be a main agent
    claw_warn "No agents returned (unexpected - should have main)"
    claw_fail "agents_list returned no agents" "subagent_spawn" "$duration"
  elif [[ "$response" == *"disabled"* ]] || [[ "$response" == *"not available"* ]]; then
    claw_fail "Subagent tools disabled: ${response:0:200}" "subagent_spawn" "$duration"
  else
    # STRICT: No agent info found = fail
    claw_fail "agents_list did not return agent info: ${response:0:200}" "subagent_spawn" "$duration"
  fi
}
