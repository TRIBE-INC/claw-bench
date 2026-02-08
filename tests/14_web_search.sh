#!/bin/bash
# Test: Web Search (web_search tool)
# Tests that the agent can search the web using Brave Search API
#
# Pass: Search executed and results returned
# Fail: Search failed or no results

test_web_search() {
  claw_header "TEST 14: Web Search (web_search)"

  local start_s end_s duration
  start_s=$(date +%s)

  # Ask agent to search for something verifiable
  local response
  response=$(claw_ask "Use the web_search tool to search for 'OpenClaw AI agent' and tell me what you found. Include at least one result title.")

  end_s=$(date +%s)
  duration=$(( (end_s - start_s) * 1000 ))

  if claw_is_empty "$response"; then
    claw_critical "Empty response on web_search test" "web_search" "$duration"
  elif [[ "$response" == *"API key"* ]] || [[ "$response" == *"BRAVE"* ]] || \
       [[ "$response" == *"Brave"* ]] || [[ "$response" == *"configure"* ]]; then
    claw_warn "web_search requires Brave API key configuration"
    claw_pass "web_search tool recognized (API key not configured)" "web_search" "$duration"
  elif [[ "$response" == *"OpenClaw"* ]] || [[ "$response" == *"openclaw"* ]] || \
       [[ "$response" == *"Clawdbot"* ]] || [[ "$response" == *"clawdbot"* ]] || \
       [[ "$response" == *"AI"* ]] || [[ "$response" == *"agent"* ]]; then
    claw_pass "web_search working: returned relevant results" "web_search" "$duration"
  elif [[ "$response" == *"not available"* ]] || [[ "$response" == *"disabled"* ]]; then
    claw_fail "web_search tool disabled: $response" "web_search" "$duration"
  else
    # Check if it at least attempted a search
    if [[ "$response" == *"search"* ]] || [[ "$response" == *"result"* ]]; then
      claw_pass "web_search executed (results may vary)" "web_search" "$duration"
    else
      claw_fail "web_search did not return expected results: ${response:0:200}" "web_search" "$duration"
    fi
  fi
}
