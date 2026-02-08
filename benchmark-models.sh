#!/bin/bash
# benchmark-models.sh - Test multiple Bedrock models and generate reports
#
# Usage: ./benchmark-models.sh [model-key]
#   model-key: optional - test only this model (e.g., "nova-lite", "mistral-large-3")
#   If no model-key provided, tests all models in models-to-test.json

set -uo pipefail
# Note: -e removed to allow continuing through model failures

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORTS_DIR="${SCRIPT_DIR}/reports"
MODELS_FILE="${SCRIPT_DIR}/models-to-test.json"

# SSH config (override with env vars)
: "${CLAW_HOST:?Error: CLAW_HOST must be set (e.g., ubuntu@your-bot-ip)}"
: "${CLAW_SSH_KEY:=$HOME/.ssh/id_rsa}"
CLAW_SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=10"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

mkdir -p "$REPORTS_DIR"

# Check dependencies
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is required${NC}"
    exit 1
fi

if [ ! -f "$MODELS_FILE" ]; then
    echo -e "${RED}Error: $MODELS_FILE not found${NC}"
    exit 1
fi

switch_model() {
    local model_id="$1"
    local model_key="$2"
    local model_name="$3"

    echo -e "${BLUE}Switching to model: ${model_name}${NC}"
    echo "  Model ID: $model_id"

    # Build the jq command to update the config
    local jq_cmd=".models.providers[\"amazon-bedrock\"].models[0].id = \"$model_id\" | .models.providers[\"amazon-bedrock\"].models[0].name = \"$model_key\" | .agents.defaults.model.primary = \"amazon-bedrock/$model_id\""

    # Update config on remote
    ssh -i "$CLAW_SSH_KEY" $CLAW_SSH_OPTS "$CLAW_HOST" -n "
        jq '$jq_cmd' ~/.clawdbot/clawdbot.json > /tmp/clawdbot.json.new && \
        mv /tmp/clawdbot.json.new ~/.clawdbot/clawdbot.json
    " 2>&1

    # Clear all sessions (prevents reasoning content errors across models)
    echo "  Clearing sessions..."
    ssh -i "$CLAW_SSH_KEY" $CLAW_SSH_OPTS "$CLAW_HOST" -n "
        rm -rf ~/.clawdbot/sessions/* ~/.clawdbot/agents/*/sessions/* 2>/dev/null || true
    " 2>&1

    # Restart clawdbot and wait
    echo "  Restarting clawdbot..."
    ssh -i "$CLAW_SSH_KEY" $CLAW_SSH_OPTS "$CLAW_HOST" -n "
        sudo systemctl restart clawdbot
        sleep 8
        for i in \$(seq 1 15); do
            if curl -sf http://localhost:18789/ >/dev/null 2>&1; then
                echo 'Gateway ready'
                exit 0
            fi
            sleep 2
        done
        echo 'Gateway timeout'
        exit 1
    " 2>&1

    # Verify model
    local active_model
    active_model=$(ssh -i "$CLAW_SSH_KEY" $CLAW_SSH_OPTS "$CLAW_HOST" -n "jq -r '.agents.defaults.model.primary' ~/.clawdbot/clawdbot.json" 2>&1)
    echo "  Active model: $active_model"
}

run_benchmark() {
    local model_key="$1"
    local model_name="$2"
    local report_file="${REPORTS_DIR}/${model_key}-report.md"
    local json_file="${REPORTS_DIR}/${model_key}-results.json"

    echo -e "${BLUE}Running benchmark for: ${model_name}${NC}"

    local start_time
    start_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Run benchmark with JSON output
    local raw_output json_result
    raw_output=$(CLAW_HOST="$CLAW_HOST" CLAW_SSH_KEY="$CLAW_SSH_KEY" "${SCRIPT_DIR}/run.sh" --ssh --json 2>&1) || true

    # Extract JSON from the end of the output (everything from { to final })
    # The JSON starts with a { on its own line and ends with } on its own line
    json_result=$(echo "$raw_output" | sed -n '/^{$/,/^}$/p')

    # Save both raw output and parsed JSON
    echo "$raw_output" > "${json_file%.json}-raw.txt"
    echo "$json_result" > "$json_file"

    # Parse results (with error handling)
    local total passed failed critical
    total=$(echo "$json_result" | jq -r '.results.total // 0' 2>/dev/null) || total=0
    passed=$(echo "$json_result" | jq -r '.results.passed // 0' 2>/dev/null) || passed=0
    failed=$(echo "$json_result" | jq -r '.results.failed // 0' 2>/dev/null) || failed=0
    critical=$(echo "$json_result" | jq -r '.results.critical // 0' 2>/dev/null) || critical=0

    # Get pricing from models file
    local input_cost output_cost
    input_cost=$(jq -r ".models[] | select(.key == \"$model_key\") | .inputCostPerMillion // 0" "$MODELS_FILE")
    output_cost=$(jq -r ".models[] | select(.key == \"$model_key\") | .outputCostPerMillion // 0" "$MODELS_FILE")

    # Generate markdown report
    cat > "$report_file" << EOF
# Benchmark Report: ${model_name}

**Date:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")
**Model ID:** $(jq -r ".models[] | select(.key == \"$model_key\") | .modelId" "$MODELS_FILE")
**Provider:** $(jq -r ".models[] | select(.key == \"$model_key\") | .provider" "$MODELS_FILE")

## Pricing

| Metric | Cost per 1M tokens |
|--------|-------------------|
| Input | \$${input_cost} |
| Output | \$${output_cost} |

## Results Summary

| Metric | Value |
|--------|-------|
| Total Tests | ${total} |
| Passed | ${passed} |
| Failed | ${failed} |
| Critical Failures | ${critical} |
| Pass Rate | $([ "$total" -gt 0 ] && echo "scale=1; $passed * 100 / $total" | bc || echo "0")% |

## Test Details

| Test | Status | Notes |
|------|--------|-------|
EOF

    # Add individual test results
    echo "$json_result" | jq -r '.tests[] | "| \(.name) | \(if .status == "pass" then "✅ PASS" elif .status == "critical_fail" then "🔴 CRITICAL" else "❌ FAIL" end) | \(.reason // "-") |"' >> "$report_file" 2>/dev/null || echo "| (parse error) | - | - |" >> "$report_file"

    cat >> "$report_file" << EOF

## Comparison to Kimi K2

| Aspect | This Model | Kimi K2 |
|--------|-----------|---------|
| Input Cost | \$${input_cost}/1M | \$0.60/1M |
| Output Cost | \$${output_cost}/1M | \$2.50/1M |
| Pass Rate | $([ "$total" -gt 0 ] && echo "scale=1; $passed * 100 / $total" | bc || echo "0")% | ~40% (tool use fails) |

## Notes

$(jq -r ".models[] | select(.key == \"$model_key\") | .notes // \"No notes\"" "$MODELS_FILE")

---
*Generated by claw-bench $(date -u +"%Y-%m-%d")*
EOF

    echo -e "${GREEN}Report saved: ${report_file}${NC}"

    # Print summary
    if [ "$critical" -gt 0 ]; then
        echo -e "  ${RED}Result: ${passed}/${total} passed, ${critical} CRITICAL failures${NC}"
    elif [ "$failed" -gt 0 ]; then
        echo -e "  ${YELLOW}Result: ${passed}/${total} passed${NC}"
    else
        echo -e "  ${GREEN}Result: ${passed}/${total} passed - ALL TESTS PASSED${NC}"
    fi
}

# Main
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║              CLAW-BENCH Multi-Model Benchmark                    ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

# Get models to test
if [ $# -gt 0 ]; then
    # Test specific model
    MODEL_FILTER="$1"
    MODELS=$(jq -c ".models[] | select(.key == \"$MODEL_FILTER\")" "$MODELS_FILE")
    if [ -z "$MODELS" ]; then
        echo -e "${RED}Error: Model '$MODEL_FILTER' not found in $MODELS_FILE${NC}"
        exit 1
    fi
else
    # Test all models
    MODELS=$(jq -c '.models[]' "$MODELS_FILE")
fi

# Count models
MODEL_COUNT=$(echo "$MODELS" | wc -l | tr -d ' ')
echo "Testing $MODEL_COUNT model(s)..."
echo ""

# Save models to temp file to avoid stdin issues
echo "$MODELS" > /tmp/benchmark-models-list.json

CURRENT=0
for i in $(seq 1 "$MODEL_COUNT"); do
    CURRENT=$i
    model=$(sed -n "${i}p" /tmp/benchmark-models-list.json)

    model_key=$(echo "$model" | jq -r '.key')
    model_id=$(echo "$model" | jq -r '.modelId')
    model_name=$(echo "$model" | jq -r '.name')

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  MODEL ${CURRENT}/${MODEL_COUNT}: ${model_name}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Switch to this model
    if ! switch_model "$model_id" "$model_key" "$model_name"; then
        echo -e "${RED}Failed to switch to model: ${model_name}${NC}"
        continue
    fi

    # Run benchmark
    run_benchmark "$model_key" "$model_name"
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  BENCHMARK COMPLETE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Reports saved to: ${REPORTS_DIR}/"
ls -la "${REPORTS_DIR}"/*.md 2>/dev/null || echo "No reports generated"
