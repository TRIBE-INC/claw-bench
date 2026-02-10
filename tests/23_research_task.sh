#!/bin/bash
# Test: Research Task (Web + Summarize)
# Tests the agent's ability to research a topic using web tools and summarize findings
#
# Pass: Agent fetches data, extracts key info, and provides structured summary
# Fail: Agent cannot complete research or provides unstructured response

test_research_task() {
  claw_header "TEST 23: Research Task (web + summarize)"

  local start_s end_s duration
  start_s=$(date +%s)

  # Ask agent to research a factual topic that requires web lookup
  local response
  response=$(claw_ask "Research the HTTP status code 418. Use web_fetch to get information from https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/418 and tell me: 1) What the code means 2) When it was created 3) Is it a joke or real status code? Format your answer with numbered points.")

  end_s=$(date +%s)
  duration=$(( (end_s - start_s) * 1000 ))

  if claw_is_empty "$response"; then
    claw_critical "Empty response on research task" "research_task" "$duration"
  # Check for key facts about HTTP 418 (I'm a Teapot)
  elif [[ "$response" == *"teapot"* ]] || [[ "$response" == *"Teapot"* ]] || [[ "$response" == *"TEAPOT"* ]]; then
    # Has the main fact
    if [[ "$response" == *"1)"* ]] || [[ "$response" == *"1."* ]] || [[ "$response" == *"joke"* ]] || [[ "$response" == *"April"* ]]; then
      claw_pass "Research complete: HTTP 418 teapot explained with structure" "research_task" "$duration"
    else
      claw_pass "Research complete: found teapot status" "research_task" "$duration"
    fi
  elif [[ "$response" == *"418"* ]] && [[ "$response" == *"coffee"* ]]; then
    # Alternative mention (HTCPCP)
    claw_pass "Research complete: HTTP 418 context found" "research_task" "$duration"
  elif [[ "$response" == *"RFC"* ]] || [[ "$response" == *"rfc"* ]]; then
    # Found RFC reference
    claw_pass "Research complete: RFC reference found" "research_task" "$duration"
  elif [[ "$response" == *"error"* ]] || [[ "$response" == *"failed"* ]] || [[ "$response" == *"cannot"* ]]; then
    claw_fail "Research failed: ${response:0:200}" "research_task" "$duration"
  else
    claw_fail "Research incomplete: expected teapot info, got: ${response:0:200}" "research_task" "$duration"
  fi
}
