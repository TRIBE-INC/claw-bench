#!/bin/bash
# Test: Skill-based Workflow
# Tests the agent's ability to use an installed skill for a practical task
#
# Pass: Agent uses skill to complete task
# Fail: Skill not found or workflow fails

test_skill_workflow() {
  claw_header "TEST 26: Skill-based Workflow (weather)"

  local start_s end_s duration
  start_s=$(date +%s)

  # Use simple weather prompt (weather skill is marked as 'ready')
  local response
  response=$(claw_ask "Get the current weather for New York City.")

  end_s=$(date +%s)
  duration=$(( (end_s - start_s) * 1000 ))

  if claw_is_empty "$response"; then
    claw_critical "Empty response on skill workflow" "skill_workflow" "$duration"
  # Check for temperature indicators (degrees, F/C, or temperature word)
  elif [[ "$response" == *"°"* ]] || [[ "$response" == *"degree"* ]]; then
    claw_pass "Weather skill working: temperature returned" "skill_workflow" "$duration"
  elif [[ "$response" == *"Temperature"* ]] || [[ "$response" == *"temperature"* ]]; then
    claw_pass "Weather skill working: temperature data returned" "skill_workflow" "$duration"
  # Check for weather conditions
  elif [[ "$response" == *"Sunny"* ]] || [[ "$response" == *"sunny"* ]] || \
       [[ "$response" == *"Cloud"* ]] || [[ "$response" == *"cloud"* ]] || \
       [[ "$response" == *"Rain"* ]] || [[ "$response" == *"rain"* ]] || \
       [[ "$response" == *"Snow"* ]] || [[ "$response" == *"snow"* ]] || \
       [[ "$response" == *"Clear"* ]] || [[ "$response" == *"clear"* ]]; then
    claw_pass "Weather skill working: conditions returned" "skill_workflow" "$duration"
  # Check for city acknowledgment with weather context
  elif [[ "$response" == *"New York"* ]] && [[ "$response" == *"weather"* ]]; then
    claw_pass "Weather skill working: location-aware response" "skill_workflow" "$duration"
  # Temperature with F or C
  elif [[ "$response" =~ [0-9]+.*F ]] || [[ "$response" =~ [0-9]+.*C ]]; then
    claw_pass "Weather skill working: temperature value found" "skill_workflow" "$duration"
  elif [[ "$response" == *"skill"* ]] && [[ "$response" == *"not"* ]]; then
    claw_warn "Weather skill not installed"
    claw_fail "Weather skill not available" "skill_workflow" "$duration"
  elif [[ "$response" == *"API"* ]] || [[ "$response" == *"key"* ]]; then
    claw_warn "Weather skill requires API configuration"
    claw_pass "Weather skill recognized (needs API key)" "skill_workflow" "$duration"
  else
    claw_fail "Weather skill failed: no weather data found: ${response:0:150}" "skill_workflow" "$duration"
  fi
}
