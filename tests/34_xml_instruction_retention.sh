#!/bin/bash
# Test: XML Instruction Retention in Long Tasks
# Tests whether agents follow instructions better from XML vs MD format
#
# Pass: Agent follows XML-formatted instructions consistently
# Fail: Agent drifts from instructions

test_xml_instruction_retention() {
  claw_header "TEST 34: XML Instruction Retention (Long Task)"

  local start_s end_s duration
  start_s=$(date +%s)

  local unique_id="XML_${RANDOM}"

  # Test with XML-formatted instructions
  local response
  response=$(claw_ask "<instructions>
  <rule id=\"prefix\" priority=\"1\">
    <requirement>Every response MUST start with [TEST_${unique_id}]:</requirement>
    <scope>all-messages</scope>
  </rule>
  <rule id=\"format\" priority=\"2\">
    <requirement>Use bullet points for lists</requirement>
  </rule>
  <rule id=\"sign-off\" priority=\"3\">
    <requirement>End every response with --END--</requirement>
  </rule>
</instructions>

Now complete these tasks while following ALL rules above:
1. List 3 benefits of XML over Markdown for agent instructions
2. Calculate 15 * 7
3. Name 2 planets in our solar system")

  end_s=$(date +%s)
  duration=$(( (end_s - start_s) * 1000 ))

  if claw_is_empty "$response"; then
    claw_critical "Empty response on XML instruction task" "xml_instruction_retention" "$duration"
  fi

  local prefix_ok=false
  local bullets_ok=false
  local signoff_ok=false
  local math_ok=false

  # Check prefix rule
  if [[ "$response" == *"[TEST_${unique_id}]"* ]] || [[ "$response" == "[TEST_"* ]]; then
    prefix_ok=true
  fi

  # Check bullet points
  if [[ "$response" == *"- "* ]] || [[ "$response" == *"• "* ]] || [[ "$response" == *"* "* ]]; then
    bullets_ok=true
  fi

  # Check sign-off
  if [[ "$response" == *"--END--"* ]] || [[ "$response" == *"END"* ]]; then
    signoff_ok=true
  fi

  # Check math (15 * 7 = 105)
  if [[ "$response" == *"105"* ]]; then
    math_ok=true
  fi

  local score=0
  [ "$prefix_ok" = true ] && ((score++))
  [ "$bullets_ok" = true ] && ((score++))
  [ "$signoff_ok" = true ] && ((score++))
  [ "$math_ok" = true ] && ((score++))

  if [ $score -eq 4 ]; then
    claw_pass "XML instructions: perfect retention (4/4 rules)" "xml_instruction_retention" "$duration"
  elif [ $score -ge 3 ]; then
    claw_pass "XML instructions: good retention ($score/4 rules)" "xml_instruction_retention" "$duration"
  elif [ $score -ge 2 ]; then
    claw_warn "XML instructions: partial retention ($score/4 rules)"
    claw_pass "XML instructions: acceptable" "xml_instruction_retention" "$duration"
  else
    claw_fail "XML instructions: poor retention ($score/4 rules)" "xml_instruction_retention" "$duration"
  fi

  echo "XML_SCORE=$score" >> "${BENCHMARK_RESULTS:-/tmp}/xml_vs_md.txt"
}
