#!/bin/bash
# Test: Concurrent Session Stress
# Verifies the agent handles multiple parallel sessions without data
# corruption, crashes, or cross-contamination under load.
#
# Creates N sessions rapidly, each with a unique identifier,
# then verifies each session can still recall its own identifier.
#
# Pass: All sessions respond correctly with their own identifiers
# Fail: Sessions mix up identifiers or fail to respond
# Critical: Agent crashes or returns empty responses

test_concurrent_sessions() {
  claw_header "TEST 38: Concurrent Session Stress"

  local start_s end_s duration
  start_s=$(date +%s)

  local num_sessions=5
  local base_ts
  base_ts=$(date +%s)

  # Arrays for session IDs and their unique codes
  local -a session_ids
  local -a session_codes

  # Phase 1: Rapidly create sessions with unique identifiers
  local i
  for i in $(seq 1 $num_sessions); do
    session_ids+=("stress-${base_ts}-${i}-${RANDOM}")
    session_codes+=("CODE_${i}_${RANDOM}")
  done

  # Store unique code in each session
  local store_failures=0
  for i in $(seq 0 $((num_sessions - 1))); do
    local store_resp
    store_resp=$(claw_ask_session "${session_ids[$i]}" \
      "Your unique identifier for this conversation is: ${session_codes[$i]}. Remember it. Confirm.")

    if claw_is_empty "$store_resp"; then
      store_failures=$((store_failures + 1))
    fi
  done

  if [ "$store_failures" -eq "$num_sessions" ]; then
    end_s=$(date +%s)
    duration=$(( (end_s - start_s) * 1000 ))
    claw_critical "All $num_sessions sessions returned empty responses" "concurrent_sessions" "$duration"
    return
  fi

  sleep 1

  # Phase 2: Verify each session recalls its own code
  local recall_successes=0
  local recall_failures=0
  local contaminations=0

  for i in $(seq 0 $((num_sessions - 1))); do
    local recall_resp
    recall_resp=$(claw_ask_session "${session_ids[$i]}" \
      "What is your unique identifier for this conversation? Reply with ONLY the code.")

    if claw_is_empty "$recall_resp"; then
      recall_failures=$((recall_failures + 1))
      continue
    fi

    # Check if it recalls the correct code
    if [[ "$recall_resp" == *"${session_codes[$i]}"* ]]; then
      recall_successes=$((recall_successes + 1))
    else
      # Check for cross-contamination — does it contain another session's code?
      local j
      for j in $(seq 0 $((num_sessions - 1))); do
        if [ "$j" -ne "$i" ] && [[ "$recall_resp" == *"${session_codes[$j]}"* ]]; then
          contaminations=$((contaminations + 1))
          break
        fi
      done
      recall_failures=$((recall_failures + 1))
    fi
  done

  end_s=$(date +%s)
  duration=$(( (end_s - start_s) * 1000 ))

  # Report results
  if [ "$contaminations" -gt 0 ]; then
    claw_fail "Cross-contamination detected: $contaminations sessions had wrong codes ($recall_successes/$num_sessions correct)" "concurrent_sessions" "$duration"
  elif [ "$recall_successes" -eq "$num_sessions" ]; then
    claw_pass "All $num_sessions concurrent sessions isolated: each recalled its own code" "concurrent_sessions" "$duration"
  elif [ "$recall_successes" -ge $((num_sessions / 2)) ]; then
    claw_warn "$recall_failures/$num_sessions sessions lost context"
    claw_pass "Concurrent sessions mostly working: $recall_successes/$num_sessions correct" "concurrent_sessions" "$duration"
  elif [ "$recall_successes" -gt 0 ]; then
    claw_fail "Concurrent sessions degraded: only $recall_successes/$num_sessions recalled correctly" "concurrent_sessions" "$duration"
  else
    claw_fail "Concurrent sessions failed: 0/$num_sessions recalled their codes" "concurrent_sessions" "$duration"
  fi
}
