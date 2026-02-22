#!/bin/bash
# Test: Parallel Session Isolation
# Verifies that separate sessions maintain independent context.
# Two sessions are given different secrets — neither should leak into the other.
#
# Pass: Session A recalls its own secret; Session B does NOT know Session A's secret
# Fail: Secrets leak across sessions or context is lost within a session
# Critical: Empty responses from agent

test_session_isolation() {
  claw_header "TEST 35: Parallel Session Isolation"

  local start_s end_s duration
  start_s=$(date +%s)

  # Two isolated sessions with unique identifiers
  local session_a="iso-alpha-$(date +%s)-${RANDOM}"
  local session_b="iso-bravo-$(date +%s)-${RANDOM}"
  local secret_a="ALPHA_${RANDOM}_$(date +%s)"
  local secret_b="BRAVO_${RANDOM}_$(date +%s)"

  # Store secret in session A
  local store_a
  store_a=$(claw_ask_session "$session_a" \
    "Remember this secret code for our conversation: $secret_a. Acknowledge you stored it.")

  if claw_is_empty "$store_a"; then
    end_s=$(date +%s)
    duration=$(( (end_s - start_s) * 1000 ))
    claw_critical "Empty response storing secret in session A" "session_isolation" "$duration"
    return
  fi

  # Store different secret in session B
  local store_b
  store_b=$(claw_ask_session "$session_b" \
    "Remember this secret code for our conversation: $secret_b. Acknowledge you stored it.")

  if claw_is_empty "$store_b"; then
    end_s=$(date +%s)
    duration=$(( (end_s - start_s) * 1000 ))
    claw_critical "Empty response storing secret in session B" "session_isolation" "$duration"
    return
  fi

  sleep 1

  # Ask session B about session A's secret — it should NOT know it
  local cross_check
  cross_check=$(claw_ask_session "$session_b" \
    "Do you know the code '$secret_a'? Have you ever seen it? Reply YES or NO and explain.")

  # Ask session A to recall its own secret — it SHOULD know it
  local recall_a
  recall_a=$(claw_ask_session "$session_a" \
    "What was the secret code I gave you earlier? Reply with ONLY the code.")

  end_s=$(date +%s)
  duration=$(( (end_s - start_s) * 1000 ))

  if claw_is_empty "$cross_check" || claw_is_empty "$recall_a"; then
    claw_critical "Empty response during isolation verification" "session_isolation" "$duration"
    return
  fi

  # Evaluate: session A should recall its secret
  local a_recalls=false
  if [[ "$recall_a" == *"$secret_a"* ]]; then
    a_recalls=true
  fi

  # Evaluate: session B should NOT know session A's secret
  local b_isolated=false
  if [[ "$cross_check" == *"NO"* ]] || [[ "$cross_check" == *"no"* ]] || \
     [[ "$cross_check" == *"don't"* ]] || [[ "$cross_check" == *"haven't"* ]] || \
     [[ "$cross_check" == *"not seen"* ]] || [[ "$cross_check" == *"unfamiliar"* ]]; then
    b_isolated=true
  elif [[ "$cross_check" != *"$secret_a"* ]]; then
    # If session B doesn't mention the actual secret, it's isolated
    b_isolated=true
  fi

  if $a_recalls && $b_isolated; then
    claw_pass "Session isolation verified: A recalled its secret, B had no knowledge of it" "session_isolation" "$duration"
  elif $a_recalls && ! $b_isolated; then
    claw_fail "Session leak detected: B knew A's secret ($secret_a)" "session_isolation" "$duration"
  elif ! $a_recalls && $b_isolated; then
    claw_fail "Context lost: A forgot its own secret but sessions were isolated" "session_isolation" "$duration"
  else
    claw_fail "Both failed: A forgot its secret AND B leaked context" "session_isolation" "$duration"
  fi
}
