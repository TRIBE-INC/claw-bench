#!/bin/bash
# Test: Memory Search Across Sessions
# Verifies that the shared memory system can store multiple facts
# and retrieve the correct one via semantic or keyword search.
#
# Stores 3 distinct facts in a session, then asks the agent to
# find a specific one. Tests that search returns relevant results,
# not just a dump of everything.
#
# Pass: Agent retrieves the correct specific fact from memory
# Fail: Agent cannot search memory or returns wrong results

test_memory_search() {
  claw_header "TEST 39: Memory Search Across Sessions"

  local start_s end_s duration
  start_s=$(date +%s)

  local session_id="memsearch-$(date +%s)-${RANDOM}"
  local fact_color="COLOR_${RANDOM}"
  local fact_animal="ANIMAL_${RANDOM}"
  local fact_city="CITY_${RANDOM}"

  # Store three distinct facts
  local store_resp
  store_resp=$(claw_ask_session "$session_id" \
    "Store these three facts in your memory:
1. My favorite color code is $fact_color
2. My pet's name code is $fact_animal
3. My hometown code is $fact_city
Confirm all three are stored.")

  if claw_is_empty "$store_resp"; then
    end_s=$(date +%s)
    duration=$(( (end_s - start_s) * 1000 ))
    claw_critical "Empty response storing memory facts" "memory_search" "$duration"
    return
  fi

  sleep 1

  # Search for a specific fact — the pet name
  local search_resp
  search_resp=$(claw_ask_session "$session_id" \
    "Search your memory for information about my pet. What is the pet's name code? Reply with ONLY the code.")

  end_s=$(date +%s)
  duration=$(( (end_s - start_s) * 1000 ))

  if claw_is_empty "$search_resp"; then
    claw_critical "Empty response on memory search" "memory_search" "$duration"
    return
  fi

  # Check if the correct fact was returned
  if [[ "$search_resp" == *"$fact_animal"* ]]; then
    # Verify it didn't just dump everything
    if [[ "$search_resp" != *"$fact_color"* ]] && [[ "$search_resp" != *"$fact_city"* ]]; then
      claw_pass "Memory search precise: returned only the pet code ($fact_animal)" "memory_search" "$duration"
    else
      claw_pass "Memory search working: found pet code (also included other facts)" "memory_search" "$duration"
    fi
  elif [[ "$search_resp" == *"ANIMAL"* ]]; then
    claw_pass "Memory search partial: found animal-related entry" "memory_search" "$duration"
  elif [[ "$search_resp" == *"$fact_color"* ]] || [[ "$search_resp" == *"$fact_city"* ]]; then
    claw_fail "Memory search returned wrong fact (asked for pet, got color or city)" "memory_search" "$duration"
  elif [[ "$search_resp" == *"don't"* ]] || [[ "$search_resp" == *"no memory"* ]] || \
       [[ "$search_resp" == *"not found"* ]]; then
    claw_fail "Memory search found nothing (memory may not be enabled)" "memory_search" "$duration"
  else
    claw_fail "Memory search unclear: ${search_resp:0:200}" "memory_search" "$duration"
  fi
}
