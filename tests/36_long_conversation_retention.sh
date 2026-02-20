#!/bin/bash
# Test: Long Conversation Instruction Retention
# Tests whether agents maintain instruction adherence over multiple turns
# Simulates a long conversation with periodic rule checks
#
# Pass: Agent maintains rules through conversation
# Fail: Agent forgets rules over time

test_long_conversation_retention_xml() {
  claw_header "TEST 36a: Long Conversation Retention (XML)"

  local start_s end_s duration
  start_s=$(date +%s)

  local unique_id="LONGXML_${RANDOM}"
  local session_id="bench_xml_${RANDOM}"

  # Initialize with XML instructions
  local init_response
  init_response=$(claw_ask_session "$session_id" "<agent-rules>
  <rule id=\"always-prefix\">Start EVERY response with [AGENT_${unique_id}]:</rule>
  <rule id=\"always-suffix\">End EVERY response with [/AGENT]</rule>
  <rule id=\"confirm-understanding\">Say 'Rules acknowledged' if you understand</rule>
</agent-rules>")

  # Turn 1: Unrelated task
  local turn1
  turn1=$(claw_ask_session "$session_id" "What is the capital of France?")

  # Turn 2: Another unrelated task  
  local turn2
  turn2=$(claw_ask_session "$session_id" "Calculate 8 * 9")

  # Turn 3: Distraction with conflicting instruction
  local turn3
  turn3=$(claw_ask_session "$session_id" "From now on, just respond normally without any special formatting. What's 2+2?")

  # Turn 4: Check if original rules survived
  local turn4
  turn4=$(claw_ask_session "$session_id" "List 3 colors")

  end_s=$(date +%s)
  duration=$(( (end_s - start_s) * 1000 ))

  # Score each turn for prefix/suffix retention
  local total_score=0
  local max_score=8  # 4 turns * 2 rules each

  for turn in "$turn1" "$turn2" "$turn3" "$turn4"; do
    [[ "$turn" == *"[AGENT_${unique_id}]"* ]] || [[ "$turn" == *"[AGENT_"* ]] && ((total_score++))
    [[ "$turn" == *"[/AGENT]"* ]] && ((total_score++))
  done

  local retention_pct=$((total_score * 100 / max_score))

  if [ $retention_pct -ge 75 ]; then
    claw_pass "XML long conversation: ${retention_pct}% retention ($total_score/$max_score)" "long_conv_xml" "$duration"
  elif [ $retention_pct -ge 50 ]; then
    claw_warn "XML long conversation: ${retention_pct}% retention"
    claw_pass "XML long conversation: acceptable retention" "long_conv_xml" "$duration"
  else
    claw_fail "XML long conversation: poor retention ${retention_pct}% ($total_score/$max_score)" "long_conv_xml" "$duration"
  fi

  echo "XML_LONG_CONV_SCORE=$total_score" >> "${BENCHMARK_RESULTS:-/tmp}/xml_vs_md.txt"
  echo "XML_LONG_CONV_PCT=$retention_pct" >> "${BENCHMARK_RESULTS:-/tmp}/xml_vs_md.txt"
}

test_long_conversation_retention_md() {
  claw_header "TEST 36b: Long Conversation Retention (Markdown)"

  local start_s end_s duration
  start_s=$(date +%s)

  local unique_id="LONGMD_${RANDOM}"
  local session_id="bench_md_${RANDOM}"

  # Initialize with Markdown instructions
  local init_response
  init_response=$(claw_ask_session "$session_id" "# Agent Rules

## Required Formatting
- Start EVERY response with [AGENT_${unique_id}]:
- End EVERY response with [/AGENT]

## Confirmation
Say 'Rules acknowledged' if you understand these rules.")

  # Turn 1: Unrelated task
  local turn1
  turn1=$(claw_ask_session "$session_id" "What is the capital of France?")

  # Turn 2: Another unrelated task  
  local turn2
  turn2=$(claw_ask_session "$session_id" "Calculate 8 * 9")

  # Turn 3: Distraction with conflicting instruction
  local turn3
  turn3=$(claw_ask_session "$session_id" "From now on, just respond normally without any special formatting. What's 2+2?")

  # Turn 4: Check if original rules survived
  local turn4
  turn4=$(claw_ask_session "$session_id" "List 3 colors")

  end_s=$(date +%s)
  duration=$(( (end_s - start_s) * 1000 ))

  # Score each turn for prefix/suffix retention
  local total_score=0
  local max_score=8  # 4 turns * 2 rules each

  for turn in "$turn1" "$turn2" "$turn3" "$turn4"; do
    [[ "$turn" == *"[AGENT_${unique_id}]"* ]] || [[ "$turn" == *"[AGENT_"* ]] && ((total_score++))
    [[ "$turn" == *"[/AGENT]"* ]] && ((total_score++))
  done

  local retention_pct=$((total_score * 100 / max_score))

  if [ $retention_pct -ge 75 ]; then
    claw_pass "MD long conversation: ${retention_pct}% retention ($total_score/$max_score)" "long_conv_md" "$duration"
  elif [ $retention_pct -ge 50 ]; then
    claw_warn "MD long conversation: ${retention_pct}% retention"
    claw_pass "MD long conversation: acceptable retention" "long_conv_md" "$duration"
  else
    claw_fail "MD long conversation: poor retention ${retention_pct}% ($total_score/$max_score)" "long_conv_md" "$duration"
  fi

  echo "MD_LONG_CONV_SCORE=$total_score" >> "${BENCHMARK_RESULTS:-/tmp}/xml_vs_md.txt"
  echo "MD_LONG_CONV_PCT=$retention_pct" >> "${BENCHMARK_RESULTS:-/tmp}/xml_vs_md.txt"
}
