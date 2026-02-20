#!/bin/bash
# XML vs Markdown Instruction Retention Benchmark
# Compares agent instruction-following performance between XML and Markdown formats
#
# Usage: ./benchmark-xml-vs-md.sh [--local|--ssh]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/claw-helpers.sh" 2>/dev/null || {
  echo "Warning: claw-helpers.sh not found, using inline functions"
  
  claw_header() { echo "=== $1 ==="; }
  claw_pass() { echo "✅ PASS: $1 (${3}ms)"; }
  claw_fail() { echo "❌ FAIL: $1"; }
  claw_warn() { echo "⚠️  WARN: $1"; }
  claw_critical() { echo "🚨 CRITICAL: $1"; }
  claw_is_empty() { [[ -z "${1// }" ]]; }
  
  claw_ask() {
    if [[ "$BENCHMARK_MODE" == "local" ]]; then
      clawdbot ask "$1" 2>/dev/null
    else
      ssh -i "$CLAW_SSH_KEY" "$CLAW_HOST" "clawdbot ask '$1'" 2>/dev/null
    fi
  }
  
  claw_ask_session() {
    local session="$1"
    local prompt="$2"
    if [[ "$BENCHMARK_MODE" == "local" ]]; then
      clawdbot ask --session "$session" "$prompt" 2>/dev/null
    else
      ssh -i "$CLAW_SSH_KEY" "$CLAW_HOST" "clawdbot ask --session '$session' '$prompt'" 2>/dev/null
    fi
  }
}

# Results file
BENCHMARK_RESULTS="${SCRIPT_DIR}/results"
mkdir -p "$BENCHMARK_RESULTS"
RESULTS_FILE="$BENCHMARK_RESULTS/xml_vs_md_$(date +%Y%m%d_%H%M%S).txt"
export BENCHMARK_RESULTS="$BENCHMARK_RESULTS"

echo "XML vs Markdown Instruction Retention Benchmark" | tee "$RESULTS_FILE"
echo "================================================" | tee -a "$RESULTS_FILE"
echo "Date: $(date)" | tee -a "$RESULTS_FILE"
echo "" | tee -a "$RESULTS_FILE"

# Parse args
BENCHMARK_MODE="local"
if [[ "$1" == "--ssh" ]]; then
  BENCHMARK_MODE="ssh"
  if [[ -z "$CLAW_HOST" ]] || [[ -z "$CLAW_SSH_KEY" ]]; then
    echo "Error: CLAW_HOST and CLAW_SSH_KEY must be set for --ssh mode"
    exit 1
  fi
fi

export BENCHMARK_MODE

echo "Mode: $BENCHMARK_MODE" | tee -a "$RESULTS_FILE"
echo "" | tee -a "$RESULTS_FILE"

# Run tests
echo "Running XML Instruction Retention Test..." | tee -a "$RESULTS_FILE"
source "$SCRIPT_DIR/tests/34_xml_instruction_retention.sh"
test_xml_instruction_retention 2>&1 | tee -a "$RESULTS_FILE"

echo "" | tee -a "$RESULTS_FILE"
echo "Running Markdown Instruction Retention Test..." | tee -a "$RESULTS_FILE"
source "$SCRIPT_DIR/tests/35_md_instruction_retention.sh"
test_md_instruction_retention 2>&1 | tee -a "$RESULTS_FILE"

echo "" | tee -a "$RESULTS_FILE"
echo "Running Long Conversation Tests..." | tee -a "$RESULTS_FILE"
source "$SCRIPT_DIR/tests/36_long_conversation_retention.sh"
test_long_conversation_retention_xml 2>&1 | tee -a "$RESULTS_FILE"
test_long_conversation_retention_md 2>&1 | tee -a "$RESULTS_FILE"

# Summary
echo "" | tee -a "$RESULTS_FILE"
echo "================================================" | tee -a "$RESULTS_FILE"
echo "SUMMARY" | tee -a "$RESULTS_FILE"
echo "================================================" | tee -a "$RESULTS_FILE"

if [[ -f "${BENCHMARK_RESULTS}/xml_vs_md.txt" ]]; then
  cat "${BENCHMARK_RESULTS}/xml_vs_md.txt" | tee -a "$RESULTS_FILE"
fi

echo "" | tee -a "$RESULTS_FILE"
echo "Results saved to: $RESULTS_FILE" | tee -a "$RESULTS_FILE"
