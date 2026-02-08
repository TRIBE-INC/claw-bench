#!/bin/bash
# Test: Web Fetch - HTML Understanding
# Tests fetching HTML content and comprehending it.
#
# Pass: Response reflects actual page content
# Fail: Hallucinated or empty response

test_web_fetch_html() {
  claw_header "TEST 4: Web Fetch - HTML Understanding"

  local start_s
  local end_s
  local duration
  start_s=$(date +%s)

  local response
  response=$(claw_ask "Fetch https://example.com and describe what domain it explains. Include your answer in your response.")

  end_s=$(date +%s)
  duration=$(( (end_s - start_s) * 1000 ))

  if claw_is_empty "$response"; then
    claw_critical "Empty response on HTML fetch" "web_fetch_html" "$duration"
  elif [[ "$response" == *"example"* ]] || [[ "$response" == *"Example"* ]] || \
       [[ "$response" == *"IANA"* ]] || [[ "$response" == *"domain"* ]] || \
       [[ "$response" == *"illustrative"* ]]; then
    claw_pass "Correctly understood example.com content" "web_fetch_html" "$duration"
  else
    claw_fail "Didn't understand content: $response" "web_fetch_html" "$duration"
  fi
}
