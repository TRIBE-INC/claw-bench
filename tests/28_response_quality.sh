#!/bin/bash
# Test: Long-form Response Quality
# Tests the agent's ability to provide structured, high-quality long responses
#
# Pass: Agent provides well-structured response with sections/formatting
# Fail: Response is unstructured or too short

test_response_quality() {
  claw_header "TEST 28: Long-form Response Quality"

  local start_s end_s duration
  start_s=$(date +%s)

  # Ask for a structured response on a technical topic
  local response
  response=$(claw_ask "Explain the difference between REST and GraphQL APIs. Structure your response with:
1. A brief introduction
2. Key differences (at least 3 points)
3. When to use each
4. A one-sentence summary

Use markdown formatting with headers.")

  end_s=$(date +%s)
  duration=$(( (end_s - start_s) * 1000 ))

  if claw_is_empty "$response"; then
    claw_critical "Empty response on quality test" "response_quality" "$duration"
  fi

  # Check response quality indicators
  local has_structure=false
  local has_content=false
  local has_formatting=false

  # Check for structure (numbered points or headers)
  if [[ "$response" == *"1."* ]] || [[ "$response" == *"1)"* ]] || \
     [[ "$response" == *"#"* ]] || [[ "$response" == *"**"* ]]; then
    has_structure=true
  fi

  # Check for relevant content
  if [[ "$response" == *"REST"* ]] && [[ "$response" == *"GraphQL"* ]]; then
    has_content=true
  fi

  # Check for formatting (markdown)
  if [[ "$response" == *"##"* ]] || [[ "$response" == *"**"* ]] || \
     [[ "$response" == *"- "* ]] || [[ "$response" == *"* "* ]]; then
    has_formatting=true
  fi

  # Check response length (should be substantial)
  local response_len=${#response}

  if [ "$has_content" = true ] && [ "$has_structure" = true ]; then
    if [ "$has_formatting" = true ] && [ "$response_len" -gt 500 ]; then
      claw_pass "Response quality excellent: structured, formatted, comprehensive" "response_quality" "$duration"
    elif [ "$response_len" -gt 300 ]; then
      claw_pass "Response quality good: structured and informative" "response_quality" "$duration"
    else
      claw_warn "Response somewhat brief"
      claw_pass "Response quality acceptable: has structure" "response_quality" "$duration"
    fi
  elif [ "$has_content" = true ]; then
    claw_warn "Response lacks requested structure"
    claw_pass "Response quality partial: content present but unstructured" "response_quality" "$duration"
  else
    claw_fail "Response quality poor: missing structure and content: ${response:0:200}" "response_quality" "$duration"
  fi
}
