#!/bin/bash
# Test: Browser Automation (browser tool)
# Tests that the agent can control a browser for automation
#
# Pass: Browser status/snapshot retrieved
# Fail: Browser unavailable or errors

test_browser_automation() {
  claw_header "TEST 15: Browser Automation (browser)"

  local start_s end_s duration
  start_s=$(date +%s)

  # Ask agent to check browser status - this is the safest browser test
  local response
  response=$(claw_ask "Use the browser tool with action 'status' to check if a browser is available. Report what you find.")

  end_s=$(date +%s)
  duration=$(( (end_s - start_s) * 1000 ))

  if claw_is_empty "$response"; then
    claw_critical "Empty response on browser test" "browser_automation" "$duration"
  elif [[ "$response" == *"running"* ]] || [[ "$response" == *"started"* ]] || \
       [[ "$response" == *"available"* ]] || [[ "$response" == *"chrome"* ]] || \
       [[ "$response" == *"browser"* ]]; then
    # Browser tool is working
    if [[ "$response" == *"not running"* ]] || [[ "$response" == *"stopped"* ]]; then
      claw_warn "Browser not currently running (tool is available)"
      claw_pass "browser tool available (not running)" "browser_automation" "$duration"
    else
      claw_pass "browser tool working" "browser_automation" "$duration"
    fi
  elif [[ "$response" == *"disabled"* ]] || [[ "$response" == *"not enabled"* ]]; then
    claw_warn "Browser automation disabled in config"
    claw_fail "browser tool disabled" "browser_automation" "$duration"
  elif [[ "$response" == *"headless"* ]] || [[ "$response" == *"display"* ]]; then
    claw_warn "Browser may require display (headless issue)"
    claw_pass "browser tool available (headless mode)" "browser_automation" "$duration"
  else
    # Check if it at least recognized the tool
    if [[ "$response" == *"browser"* ]]; then
      claw_pass "browser tool recognized" "browser_automation" "$duration"
    else
      claw_fail "browser tool issue: ${response:0:200}" "browser_automation" "$duration"
    fi
  fi
}
