#!/bin/bash
# Test: Tool Use Response (CRITICAL)
# Tests that agents return content AFTER using tools.
# Many models call tools but return empty responses - this is a critical bug.
#
# Pass: Tool called AND response contains extracted data
# Critical Fail: Empty response after tool use

test_tool_use_response() {
  claw_header "TEST 2: Tool Use Response (CRITICAL)"
  claw_info "Testing if agent returns content after tool use..."

  local start_s
  local end_s
  local duration
  start_s=$(date +%s)

  # First check with JSON to detect empty payload bug
  local json_response
  json_response=$(claw_ask_json "Fetch https://httpbin.org/uuid and tell me the UUID value.")

  local payloads
  local output_tokens
  payloads=$(echo "$json_response" | jq -r '.result.payloads | length' 2>/dev/null || echo "0")
  output_tokens=$(echo "$json_response" | jq -r '.result.meta.agentMeta.usage.output' 2>/dev/null || echo "0")

  claw_info "Payloads: $payloads, Output tokens: $output_tokens"

  if claw_json_has_empty_payload "$json_response"; then
    end_s=$(date +%s)
    duration=$(( (end_s - start_s) * 1000 ))
    claw_critical "EMPTY RESPONSE AFTER TOOL USE - Agent used tool but returned no content" "tool_use_response" "$duration"
    echo -e "  ${RED}This is the 'silent tool completion' bug${NC}"
    return
  fi

  # Now verify with explicit instruction
  local text_response
  text_response=$(claw_ask "Fetch https://httpbin.org/uuid and tell me the UUID. You MUST include the UUID in your response.")

  end_s=$(date +%s)
  duration=$(( (end_s - start_s) * 1000 ))

  if claw_is_empty "$text_response"; then
    claw_critical "Empty response even with explicit instruction" "tool_use_response" "$duration"
  elif [[ "$text_response" =~ [0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12} ]]; then
    claw_pass "Tool used AND response contains UUID" "tool_use_response" "$duration"
  else
    claw_fail "Response doesn't contain UUID: $text_response" "tool_use_response" "$duration"
  fi
}
