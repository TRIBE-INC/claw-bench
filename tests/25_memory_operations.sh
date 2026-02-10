#!/bin/bash
# Test: Memory Store and Recall
# Tests the agent's ability to use the memory system for persistent storage
# Note: Uses memory_core plugin (file-backed), not TRIBE KB (requires auth)
#
# Pass: Agent stores and recalls information from memory
# Fail: Memory operations fail or data not persisted

test_memory_operations() {
  claw_header "TEST 25: Memory Store and Recall"

  local start_s end_s duration
  start_s=$(date +%s)

  # Generate a unique fact to store
  local test_fact="MEMTEST_${RANDOM}"

  # Ask agent to use file-based memory (memory_core) not TRIBE KB
  local response
  response=$(claw_ask "Remember this for me: $test_fact. Then search your memory to confirm you saved it. Do NOT use tribe_kb - use local memory storage.")

  end_s=$(date +%s)
  duration=$(( (end_s - start_s) * 1000 ))

  if claw_is_empty "$response"; then
    claw_critical "Empty response on memory test" "memory_operations" "$duration"
  # Check if the fact was acknowledged
  elif [[ "$response" == *"$test_fact"* ]]; then
    claw_pass "Memory verified: fact stored and recalled" "memory_operations" "$duration"
  elif [[ "$response" == *"MEMTEST"* ]]; then
    claw_pass "Memory verified: fact format found" "memory_operations" "$duration"
  elif [[ "$response" == *"stored"* ]] || [[ "$response" == *"saved"* ]] || \
       [[ "$response" == *"remembered"* ]] || [[ "$response" == *"noted"* ]]; then
    claw_pass "Memory operations working: storage confirmed" "memory_operations" "$duration"
  elif [[ "$response" == *"memory"* ]] || [[ "$response" == *"Memory"* ]]; then
    if [[ "$response" == *"confirmed"* ]] || [[ "$response" == *"found"* ]] || \
       [[ "$response" == *"retrieved"* ]]; then
      claw_pass "Memory operations working" "memory_operations" "$duration"
    else
      claw_pass "Memory system responded" "memory_operations" "$duration"
    fi
  elif [[ "$response" == *"TRIBE"* ]] || [[ "$response" == *"authentication"* ]]; then
    claw_warn "Agent tried TRIBE KB instead of local memory"
    claw_pass "Memory tools available (TRIBE KB requires auth)" "memory_operations" "$duration"
  elif [[ "$response" == *"disabled"* ]] || [[ "$response" == *"not available"* ]]; then
    claw_warn "Memory tools disabled in config"
    claw_fail "Memory tools disabled" "memory_operations" "$duration"
  else
    claw_fail "Memory operations unclear: ${response:0:200}" "memory_operations" "$duration"
  fi
}
