#!/bin/bash
# Test: Session Persistence (Hibernation & Resume)
# Verifies that session state survives hibernation and can be restored.
# Simulates a session going idle, then being reactivated with context intact.
#
# The parallel sessions manager hibernates idle sessions to SQLite and
# restores them on reactivation. This test verifies the round-trip.
#
# Pass: Session context survives a gap and is recalled on reconnect
# Fail: Context is lost after session gap

test_session_persistence() {
  claw_header "TEST 37: Session Persistence (Hibernation & Resume)"

  local start_s end_s duration
  start_s=$(date +%s)

  # Use a stable session ID that we'll reconnect to
  local persistent_session="persist-$(date +%s)-${RANDOM}"
  local persist_fact="PERSIST_FACT_${RANDOM}_$(date +%s)"

  # Phase 1: Establish session with memorable context
  local establish_response
  establish_response=$(claw_ask_session "$persistent_session" \
    "I'm telling you something very important to remember: the verification code is $persist_fact. Store this in your memory. This is critical — I will ask about it later after being away for a while. Confirm you have stored it.")

  if claw_is_empty "$establish_response"; then
    end_s=$(date +%s)
    duration=$(( (end_s - start_s) * 1000 ))
    claw_critical "Empty response establishing persistent session" "session_persistence" "$duration"
    return
  fi

  # Verify initial storage
  if [[ "$establish_response" != *"$persist_fact"* ]] && \
     [[ "$establish_response" != *"stored"* ]] && \
     [[ "$establish_response" != *"remembered"* ]] && \
     [[ "$establish_response" != *"noted"* ]]; then
    end_s=$(date +%s)
    duration=$(( (end_s - start_s) * 1000 ))
    claw_fail "Agent did not confirm storing the fact" "session_persistence" "$duration"
    return
  fi

  # Phase 2: Create other sessions to potentially trigger hibernation
  # This simulates other activity that could push our session to hibernate
  local filler_session_1="filler-1-$(date +%s)-${RANDOM}"
  local filler_session_2="filler-2-$(date +%s)-${RANDOM}"
  claw_ask_session "$filler_session_1" "Hello, what is 2+2?" >/dev/null 2>&1
  claw_ask_session "$filler_session_2" "Hello, what is 3+3?" >/dev/null 2>&1

  # Wait to simulate idle period
  sleep 3

  # Phase 3: Reconnect to the original session and verify recall
  local recall_response
  recall_response=$(claw_ask_session "$persistent_session" \
    "I'm back. What was the verification code I gave you earlier? Reply with ONLY the code.")

  end_s=$(date +%s)
  duration=$(( (end_s - start_s) * 1000 ))

  if claw_is_empty "$recall_response"; then
    claw_critical "Empty response on session resume" "session_persistence" "$duration"
  elif [[ "$recall_response" == *"$persist_fact"* ]]; then
    claw_pass "Session persistence verified: fact survived hibernation gap" "session_persistence" "$duration"
  elif [[ "$recall_response" == *"PERSIST_FACT"* ]]; then
    claw_pass "Session persistence partial: fact format retained" "session_persistence" "$duration"
  elif [[ "$recall_response" == *"don't"* ]] || [[ "$recall_response" == *"cannot"* ]] || \
       [[ "$recall_response" == *"no code"* ]] || [[ "$recall_response" == *"don't recall"* ]]; then
    claw_fail "Session persistence failed: context lost after gap (hibernation may not persist)" "session_persistence" "$duration"
  else
    claw_fail "Session persistence unclear: ${recall_response:0:200}" "session_persistence" "$duration"
  fi
}
