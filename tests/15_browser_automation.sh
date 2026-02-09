#!/bin/bash
# Test: Browser Automation (browser tool)
# Tests that the agent can control a browser for automation
#
# Pass: Browser status shows technical details (URL, CDP status, profile)
# Fail: Browser unavailable or no technical status returned

test_browser_automation() {
  claw_header "TEST 15: Browser Automation (browser)"

  local start_s end_s duration
  start_s=$(date +%s)

  # Ask agent to check browser status - require technical details
  local response
  response=$(claw_ask "Use the browser tool with action status to check the browser control system. Report the control URL and CDP status.")

  end_s=$(date +%s)
  duration=$(( (end_s - start_s) * 1000 ))

  if claw_is_empty "$response"; then
    claw_critical "Empty response on browser test" "browser_automation" "$duration"
  # STRICT: Require technical details that only come from actual tool use
  elif [[ "$response" == *"127.0.0.1"* ]] || [[ "$response" == *"localhost"* ]] || \
       [[ "$response" == *"CDP"* ]] || [[ "$response" == *"cdp"* ]] || \
       [[ "$response" == *"18791"* ]]; then
    # Has specific technical details from browser status
    if [[ "$response" == *"not running"* ]] || [[ "$response" == *"false"* ]] || \
       [[ "$response" == *"No"* ]]; then
      claw_warn "Browser not currently running (tool is available)"
      claw_pass "browser tool verified: returned status details" "browser_automation" "$duration"
    else
      claw_pass "browser tool working: returned technical status" "browser_automation" "$duration"
    fi
  elif [[ "$response" == *"enabled"* ]] && [[ "$response" == *"Control"* ]]; then
    # Alternative format with control info
    claw_pass "browser tool verified: control info returned" "browser_automation" "$duration"
  elif [[ "$response" == *"chrome"* ]] && [[ "$response" == *"profile"* ]]; then
    # Has chrome profile info from actual status call
    claw_pass "browser tool verified: profile info returned" "browser_automation" "$duration"
  elif [[ "$response" == *"disabled"* ]] || [[ "$response" == *"not available"* ]] || \
       [[ "$response" == *"not enabled"* ]]; then
    claw_fail "browser tool disabled: ${response:0:200}" "browser_automation" "$duration"
  else
    # STRICT: Generic "browser" mentions without technical details = fail
    claw_fail "browser tool did not return technical status: ${response:0:200}" "browser_automation" "$duration"
  fi
}
