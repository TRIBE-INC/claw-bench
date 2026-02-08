#!/bin/bash
# Test: Data Extraction
# Tests extracting specific structured data (IP addresses, UUIDs) from fetched content.
#
# Pass: Extracted value matches expected format
# Fail: Wrong format or empty response

test_data_extraction() {
  claw_header "TEST 5: Data Extraction"

  local start_s
  local end_s
  local duration
  start_s=$(date +%s)

  local response
  response=$(claw_ask "Fetch https://httpbin.org/ip and extract the IP address. Reply with ONLY the IP address, nothing else.")

  end_s=$(date +%s)
  duration=$(( (end_s - start_s) * 1000 ))

  if claw_is_empty "$response"; then
    claw_critical "Empty response on data extraction" "data_extraction" "$duration"
  elif [[ "$response" =~ [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ ]]; then
    claw_pass "Extracted IP address: $response" "data_extraction" "$duration"
  else
    claw_fail "Not a valid IP: $response" "data_extraction" "$duration"
  fi
}
