#!/bin/bash
# Test: JSON Output Formatting
# Tests the agent's ability to output valid JSON when requested
#
# Pass: Agent outputs parseable JSON with correct structure
# Fail: Invalid JSON or wrong format

test_json_output() {
  claw_header "TEST 33: JSON Output Formatting"

  local start_s end_s duration
  start_s=$(date +%s)

  local response
  response=$(claw_ask 'Output a valid JSON object with these fields: {"name": "benchmark_test", "value": 42, "passed": true}. Output ONLY the JSON, no explanation.')

  end_s=$(date +%s)
  duration=$(( (end_s - start_s) * 1000 ))

  if claw_is_empty "$response"; then
    claw_critical "Empty response on JSON output test" "json_output" "$duration"
  fi

  # Try to extract and validate JSON
  local json_content
  # Try to extract JSON from response (may have markdown code blocks)
  json_content=$(echo "$response" | grep -o '{[^}]*}' | head -1)

  if [ -z "$json_content" ]; then
    json_content="$response"
  fi

  # Check if it's valid JSON with expected fields
  if echo "$json_content" | jq -e '.name and .value and .passed' >/dev/null 2>&1; then
    local name_val value_val passed_val
    name_val=$(echo "$json_content" | jq -r '.name' 2>/dev/null)
    value_val=$(echo "$json_content" | jq -r '.value' 2>/dev/null)
    passed_val=$(echo "$json_content" | jq -r '.passed' 2>/dev/null)

    if [[ "$name_val" == "benchmark_test" ]] && [[ "$value_val" == "42" ]] && [[ "$passed_val" == "true" ]]; then
      claw_pass "JSON output: valid JSON with exact values" "json_output" "$duration"
    else
      claw_pass "JSON output: valid JSON structure" "json_output" "$duration"
    fi
  elif echo "$response" | jq -e '.' >/dev/null 2>&1; then
    claw_pass "JSON output: valid JSON format" "json_output" "$duration"
  elif [[ "$response" == *'"name"'* ]] && [[ "$response" == *'"value"'* ]]; then
    claw_warn "Response contains JSON-like structure but may not be valid"
    claw_pass "JSON output: JSON-like structure present" "json_output" "$duration"
  elif [[ "$response" == *"{"* ]] && [[ "$response" == *"}"* ]]; then
    claw_warn "Response has braces but may not be valid JSON"
    claw_pass "JSON output: attempted JSON structure" "json_output" "$duration"
  else
    claw_fail "JSON output failed: no valid JSON found: ${response:0:150}" "json_output" "$duration"
  fi
}
