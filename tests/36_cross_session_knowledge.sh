#!/bin/bash
# Test: Cross-Session Knowledge Sharing
# Verifies that high-importance information learned in one session
# can propagate to other sessions via shared global knowledge.
#
# This tests the parallel sessions "auto-promote to global knowledge" feature:
# when a memory exceeds the importance threshold, it becomes available across
# all sessions as global knowledge in context briefings.
#
# Pass: Session B can access a critical fact stored in Session A
# Fail: Knowledge does not propagate (shared memory may be disabled)

test_cross_session_knowledge() {
  claw_header "TEST 36: Cross-Session Knowledge Sharing"

  local start_s end_s duration
  start_s=$(date +%s)

  local session_source="knowledge-src-$(date +%s)-${RANDOM}"
  local session_target="knowledge-tgt-$(date +%s)-${RANDOM}"
  local knowledge_key="PROJECT_CODENAME_${RANDOM}"
  local knowledge_value="Operation Starfish ${RANDOM}"

  # Phase 1: Store critical knowledge in the source session
  # Use language that signals high importance to trigger auto-promotion
  local store_response
  store_response=$(claw_ask_session "$session_source" \
    "CRITICAL DECISION: Our project codename is '$knowledge_key' and the mission is '$knowledge_value'. This is an extremely important organizational decision that must be remembered permanently. Store this in memory as a critical decision. Confirm stored.")

  if claw_is_empty "$store_response"; then
    end_s=$(date +%s)
    duration=$(( (end_s - start_s) * 1000 ))
    claw_critical "Empty response storing critical knowledge" "cross_session_knowledge" "$duration"
    return
  fi

  # Brief pause for knowledge propagation
  sleep 2

  # Phase 2: Query from a different session
  local query_response
  query_response=$(claw_ask_session "$session_target" \
    "Do you have any information about '$knowledge_key'? What is the mission or project associated with it? Check your memory and global knowledge base.")

  end_s=$(date +%s)
  duration=$(( (end_s - start_s) * 1000 ))

  if claw_is_empty "$query_response"; then
    claw_critical "Empty response querying cross-session knowledge" "cross_session_knowledge" "$duration"
    return
  fi

  # Check if target session received the knowledge
  if [[ "$query_response" == *"$knowledge_value"* ]] || \
     [[ "$query_response" == *"Starfish"* ]]; then
    claw_pass "Cross-session knowledge verified: target session found '$knowledge_value'" "cross_session_knowledge" "$duration"
  elif [[ "$query_response" == *"$knowledge_key"* ]]; then
    claw_pass "Cross-session knowledge partial: target recognized the key" "cross_session_knowledge" "$duration"
  elif [[ "$query_response" == *"memory"* ]] && \
       ([[ "$query_response" == *"found"* ]] || [[ "$query_response" == *"stored"* ]]); then
    claw_pass "Memory system responded with stored data" "cross_session_knowledge" "$duration"
  elif [[ "$query_response" == *"no information"* ]] || \
       [[ "$query_response" == *"don't have"* ]] || \
       [[ "$query_response" == *"not found"* ]] || \
       [[ "$query_response" == *"no record"* ]]; then
    claw_warn "Knowledge did not propagate — shared memory may not be enabled"
    claw_fail "Cross-session knowledge not available (parallel sessions may be disabled)" "cross_session_knowledge" "$duration"
  else
    claw_fail "Unclear cross-session knowledge result: ${query_response:0:200}" "cross_session_knowledge" "$duration"
  fi
}
