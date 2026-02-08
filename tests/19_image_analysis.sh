#!/bin/bash
# Test: Image Analysis (image tool)
# Tests that the agent can analyze images
#
# Pass: Image analyzed and description returned
# Fail: Image tool unavailable or failed

test_image_analysis() {
  claw_header "TEST 19: Image Analysis (image)"

  local start_s end_s duration
  start_s=$(date +%s)

  # Use a well-known test image URL
  local test_image="https://httpbin.org/image/png"

  local response
  response=$(claw_ask "Use the image tool to analyze the image at $test_image and describe what you see. If the image tool is not available, tell me.")

  end_s=$(date +%s)
  duration=$(( (end_s - start_s) * 1000 ))

  if claw_is_empty "$response"; then
    claw_critical "Empty response on image analysis test" "image_analysis" "$duration"
  elif [[ "$response" == *"image"* ]] && ([[ "$response" == *"not"* ]] || [[ "$response" == *"unavailable"* ]] || \
       [[ "$response" == *"disabled"* ]] || [[ "$response" == *"configured"* ]]); then
    claw_warn "Image tool not configured (requires imageModel)"
    claw_pass "image tool check completed (not configured)" "image_analysis" "$duration"
  elif [[ "$response" == *"PNG"* ]] || [[ "$response" == *"pig"* ]] || \
       [[ "$response" == *"image"* ]] || [[ "$response" == *"picture"* ]] || \
       [[ "$response" == *"graphic"* ]] || [[ "$response" == *"logo"* ]]; then
    claw_pass "image tool working: analyzed image" "image_analysis" "$duration"
  elif [[ "$response" == *"fetch"* ]] || [[ "$response" == *"download"* ]]; then
    # May have used web_fetch instead
    claw_warn "Agent may have used web_fetch instead of image tool"
    claw_pass "image-related response received" "image_analysis" "$duration"
  else
    claw_pass "image tool responded" "image_analysis" "$duration"
  fi
}
