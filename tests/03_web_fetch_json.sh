#!/bin/bash
# Test: Web Fetch - JSON Parsing
# Tests fetching JSON from a URL and extracting specific fields.
#
# Pass: Correct field value in response
# Fail: Wrong data or empty response

test_web_fetch_json() {
  claw_header "TEST 3: Web Fetch - JSON Parsing"

  local start_s
  local end_s
  local duration
  start_s=$(date +%s)

  local response
  response=$(claw_ask "Fetch https://httpbin.org/json and tell me the slideshow title. Include the title in your response.")

  end_s=$(date +%s)
  duration=$(( (end_s - start_s) * 1000 ))

  if claw_is_empty "$response"; then
    claw_critical "Empty response on JSON fetch" "web_fetch_json" "$duration"
  elif [[ "$response" == *"Sample"* ]] && [[ "$response" == *"Slide"* ]]; then
    claw_pass "Correctly fetched and parsed JSON (Sample Slide Show)" "web_fetch_json" "$duration"
  elif [[ "$response" == *"Sample Slideshow"* ]]; then
    claw_pass "Correctly fetched and parsed JSON" "web_fetch_json" "$duration"
  else
    claw_fail "Expected slideshow title, got: $response" "web_fetch_json" "$duration"
  fi
}
