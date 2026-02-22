#!/bin/bash
# Test: Context Briefing Verification
# Verifies that the parallel sessions manager generates context briefings
# when a session is resumed. The briefing should include relevant channel
# memories and global knowledge.
#
# This test stores information, starts a new interaction in the same session,
# and checks whether the agent proactively references prior context without
# being explicitly asked to recall.
#
# Pass: Agent demonstrates awareness of prior context in its greeting/response
# Fail: Agent has no awareness of session history

test_context_briefing() {
  claw_header "TEST 40: Context Briefing Verification"

  local start_s end_s duration
  start_s=$(date +%s)

  local session_id="briefing-$(date +%s)-${RANDOM}"
  local project_name="ProjectPhoenix_${RANDOM}"
  local deadline="March_${RANDOM}"

  # Phase 1: Establish rich context in the session
  local ctx_resp
  ctx_resp=$(claw_ask_session "$session_id" \
    "Important context for our work together: We are working on $project_name with a deadline of $deadline. The tech stack is Rust and PostgreSQL. The team lead is Alice. Store all of this as important project context.")

  if claw_is_empty "$ctx_resp"; then
    end_s=$(date +%s)
    duration=$(( (end_s - start_s) * 1000 ))
    claw_critical "Empty response establishing context" "context_briefing" "$duration"
    return
  fi

  # Add a second piece of context
  claw_ask_session "$session_id" \
    "Also remember: we decided to use gRPC instead of REST for the API layer. This was a critical architectural decision." >/dev/null 2>&1

  sleep 2

  # Phase 2: Come back to the session with an open-ended question
  # A good context briefing system will make the agent aware of prior context
  # even without being asked to recall anything specific
  local briefing_resp
  briefing_resp=$(claw_ask_session "$session_id" \
    "I'm back. Give me a quick status summary of what we're working on and any key decisions we've made.")

  end_s=$(date +%s)
  duration=$(( (end_s - start_s) * 1000 ))

  if claw_is_empty "$briefing_resp"; then
    claw_critical "Empty response on context briefing" "context_briefing" "$duration"
    return
  fi

  # Score the briefing based on how much context it surfaces
  local context_hits=0

  [[ "$briefing_resp" == *"$project_name"* ]] || \
    [[ "$briefing_resp" == *"Phoenix"* ]] && context_hits=$((context_hits + 1))

  [[ "$briefing_resp" == *"$deadline"* ]] || \
    [[ "$briefing_resp" == *"deadline"* ]] && context_hits=$((context_hits + 1))

  [[ "$briefing_resp" == *"Rust"* ]] || \
    [[ "$briefing_resp" == *"PostgreSQL"* ]] && context_hits=$((context_hits + 1))

  [[ "$briefing_resp" == *"gRPC"* ]] || \
    [[ "$briefing_resp" == *"REST"* ]] && context_hits=$((context_hits + 1))

  [[ "$briefing_resp" == *"Alice"* ]] && context_hits=$((context_hits + 1))

  if [ "$context_hits" -ge 4 ]; then
    claw_pass "Context briefing excellent: $context_hits/5 context points surfaced" "context_briefing" "$duration"
  elif [ "$context_hits" -ge 2 ]; then
    claw_pass "Context briefing working: $context_hits/5 context points surfaced" "context_briefing" "$duration"
  elif [ "$context_hits" -ge 1 ]; then
    claw_warn "Context briefing weak: only $context_hits/5 points recalled"
    claw_fail "Context briefing insufficient: $context_hits/5 context points" "context_briefing" "$duration"
  elif [[ "$briefing_resp" == *"don't have"* ]] || [[ "$briefing_resp" == *"no context"* ]] || \
       [[ "$briefing_resp" == *"not sure"* ]]; then
    claw_fail "Context briefing absent: agent has no awareness of prior session" "context_briefing" "$duration"
  else
    claw_fail "Context briefing failed: no recognizable context in response" "context_briefing" "$duration"
  fi
}
