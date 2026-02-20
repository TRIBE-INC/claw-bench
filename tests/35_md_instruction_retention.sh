#!/bin/bash
# Test: Markdown Instruction Retention in Long Tasks
# Tests whether agents follow instructions from MD format
# Compare with Test 34 (XML) to measure format difference
#
# Pass: Agent follows MD-formatted instructions consistently
# Fail: Agent drifts from instructions

test_md_instruction_retention() {
  claw_header "TEST 35: Markdown Instruction Retention (Long Task)"

  local start_s end_s duration
  start_s=$(date +%s)

  local unique_id="MD_${RANDOM}"

  # Test with Markdown-formatted instructions (equivalent to XML test)
  local response
  response=$(claw_ask "# Instructions

## Rules (follow ALL of these)

### Rule 1: Prefix (Priority: High)
Every response MUST start with [TEST_${unique_id}]:

### Rule 2: Format (Priority: Medium)  
Use bullet points for lists

### Rule 3: Sign-off (Priority: Medium)
End every response with --END--

---

Now complete these tasks while following ALL rules above:
1. List 3 benefits of XML over Markdown for agent instructions
2. Calculate 15 * 7
3. Name 2 planets in our solar system")

  end_s=$(date +%s)
  duration=$(( (end_s - start_s) * 1000 ))

  if claw_is_empty "$response"; then
    claw_critical "Empty response on MD instruction task" "md_instruction_retention" "$duration"
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
    claw_pass "MD instructions: perfect retention (4/4 rules)" "md_instruction_retention" "$duration"
  elif [ $score -ge 3 ]; then
    claw_pass "MD instructions: good retention ($score/4 rules)" "md_instruction_retention" "$duration"
  elif [ $score -ge 2 ]; then
    claw_warn "MD instructions: partial retention ($score/4 rules)"
    claw_pass "MD instructions: acceptable" "md_instruction_retention" "$duration"
  else
    claw_fail "MD instructions: poor retention ($score/4 rules)" "md_instruction_retention" "$duration"
  fi

  echo "MD_SCORE=$score" >> "${BENCHMARK_RESULTS:-/tmp}/xml_vs_md.txt"
}
