# Claw-Bench Testing Skill

Use when writing new benchmark tests, modifying existing tests, debugging test failures, or understanding the test validation philosophy.

## Overview

Claw-bench is a **bash-native** benchmarking framework for testing clawdbot agents. It does NOT use Jest, Playwright, or any JavaScript test runners. All tests are bash scripts that communicate with agents via CLI or SSH.

**Key facts:**
- 33 test files in `tests/` directory
- Tests are numbered: `NN_test_name.sh` format
- Each file exports one function: `test_{test_name}()`
- Shared helpers live in `lib/common.sh`
- Runner: `run.sh` (single model) or `benchmark-models.sh` (multi-model)

## Quick Commands

```bash
# Run all tests locally
./run.sh --local

# Run via SSH to remote agent
CLAW_HOST="ubuntu@IP" CLAW_SSH_KEY="~/.ssh/key.pem" ./run.sh --ssh

# Run against all models (generates reports/)
./benchmark-models.sh

# Output formats
./run.sh --local --json   # Machine-readable JSON
./run.sh --local --tap    # TAP protocol for CI
```

## Test File Structure

### Naming Convention

```
tests/NN_test_name.sh
```

Where:
- `NN` = Sequence number (00-33)
- `test_name` = Snake_case descriptive name

### Required Function

Each file must export exactly one function:

```bash
test_your_test_name() {
  # Test implementation
}
```

### Standard Template

```bash
#!/bin/bash
# Test: Human-readable Name
# Description of what this tests and why it matters
#
# Pass: What constitutes a passing result
# Fail: What constitutes a failing result

test_your_test() {
  claw_header "TEST NN: Human-readable Name"

  local start_s end_s duration
  start_s=$(date +%s)

  # Optionally provide context
  claw_info "Testing specific behavior..."

  # Send message to agent
  local response
  response=$(claw_ask "Your prompt to the agent")

  # Calculate duration
  end_s=$(date +%s)
  duration=$(( (end_s - start_s) * 1000 ))

  # Validate response
  if claw_is_empty "$response"; then
    claw_critical "Empty response" "your_test" "$duration"
  elif [[ "$response" == *"expected_pattern"* ]]; then
    claw_pass "Verification succeeded" "your_test" "$duration"
  else
    claw_fail "Unexpected response: ${response:0:200}" "your_test" "$duration"
  fi
}
```

## Helper Functions (lib/common.sh)

### Agent Communication

```bash
# Send message, get text response (unique session per call)
response=$(claw_ask "Your message here")

# Send message, get raw JSON response (for debugging)
json_response=$(claw_ask_json "Your message here")

# Multi-turn: Use shared session for context retention tests
# (defined in tests/22_multi_turn_context.sh)
claw_ask_session() {
  local session_id="$1"
  local message="$2"
  # ... uses same session_id across calls
}

# Usage:
local shared_session="context-test-$(date +%s)"
turn1=$(claw_ask_session "$shared_session" "Remember: SECRET_123")
turn2=$(claw_ask_session "$shared_session" "What was the secret?")
```

**Notes:**
- Each `claw_ask` uses a unique session ID to prevent context overflow
- Use `claw_ask_session` when testing multi-turn context retention
- SSH mode uses base64 encoding for reliable message transmission
- Timeout is configurable via `CLAW_TIMEOUT` (default: 90s)

### Response Validation

```bash
# Check if response is empty/useless
if claw_is_empty "$response"; then
  # Handle empty response
fi

# Check for reasoning tag leakage (bug in some models)
if claw_has_reasoning_tags "$response"; then
  # Response contains <reasoning> or <think> tags
fi

# Check JSON for empty payload bug (critical for tool use)
if claw_json_has_empty_payload "$json_response"; then
  # Agent used tool but returned no content
fi
```

### Test Reporting

```bash
# Record pass (counted, shows green)
claw_pass "Success message" "test_name" "$duration_ms"

# Record failure (counted, shows red)
claw_fail "Failure message" "test_name" "$duration_ms"

# Record critical failure (counted, blocks deployment)
claw_critical "Critical failure message" "test_name" "$duration_ms"

# Informational output (not counted)
claw_info "Informational message"
claw_warn "Warning message"
```

### Output Formatting

```bash
# Section header
claw_header "TEST N: Name"

# Summary outputs (called by runner, not tests)
claw_summary_human   # Pretty box format
claw_summary_json    # Machine-readable
claw_summary_tap     # TAP protocol
```

## Validation Philosophy

### Core Principles

1. **Require specific proof** - Not just "contains word X" but actual tool output
2. **Unique identifiers** - Generate unique values to verify actual execution
3. **Technical markers** - Look for data only real tool calls can produce
4. **Graceful degradation** - Warn on misconfiguration, pass on basic functionality

### Good Validation Examples

```bash
# BAD: Could be hallucinated
if [[ "$response" == *"weather"* ]]; then

# GOOD: Requires actual tool execution
local unique_id="DATA_$(date +%s)_${RANDOM}"
response=$(claw_ask "Write '$unique_id' to /tmp/test.txt, then read it back")
if [[ "$response" == *"$unique_id"* ]]; then
```

```bash
# BAD: String matching without verification
if [[ "$response" == *"UUID"* ]]; then

# GOOD: Structural validation
if [[ "$response" =~ [0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12} ]]; then
```

### When to Use Critical vs Fail

| Situation | Use |
|-----------|-----|
| Core functionality broken | `claw_critical` |
| Tool use returns no content | `claw_critical` |
| Nice-to-have feature missing | `claw_fail` |
| API not configured | `claw_warn` + `claw_pass` |
| Partial success | `claw_warn` + `claw_pass` |

## Test Categories

### Core Tests (0-12)
Basic functionality every agent must pass.

| Critical Tests | Why Critical |
|----------------|--------------|
| 0 - Installation | Agent won't work without it |
| 2 - Tool Use Response | Detects "silent tool completion" bug |

### Extended Tool Tests (13-20)
Specific clawdbot tools. Pass with warning if tool not configured.

### Use Case Tests (22-28)
Real-world scenarios. Multiple tool chains.

### Robustness Tests (29-31)
Error handling, complex instructions, adversarial input.

### Stress Tests (32-33)
Long context, structured output.

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CLAW_MODE` | (required) | `local`, `ssh`, or `api` |
| `CLAW_HOST` | - | SSH host (user@ip) |
| `CLAW_SSH_KEY` | `~/.ssh/id_rsa` | SSH private key path |
| `CLAW_TIMEOUT` | 90 | Request timeout in seconds |
| `CLAW_SESSION` | auto-generated | Session ID prefix |
| `CLAW_OUTPUT` | human | Output format: `human`, `json`, `tap` |

### Config File

Copy `config.example.sh` to `config.sh` for persistent settings.

## Exit Codes

| Code | Meaning | CI Action |
|------|---------|-----------|
| 0 | All tests passed | Continue deployment |
| 1 | Some tests failed | Review, may continue |
| 2 | Critical failures | **BLOCK DEPLOYMENT** |
| 3 | Configuration error | Fix config |

## Common Patterns

### Cleanup After Tests

```bash
# In SSH mode, cleanup temp files
case "$CLAW_MODE" in
  ssh)
    ssh -n -i "$CLAW_SSH_KEY" $CLAW_SSH_OPTS "$CLAW_HOST" \
      "rm -f '/tmp/test_file_$$.txt'" 2>/dev/null
    ;;
esac
```

### Handling Optional Features

```bash
# Feature may not be configured
if [[ "$response" == *"API key not configured"* ]] || \
   [[ "$response" == *"not enabled"* ]]; then
  claw_warn "Feature not configured (expected on some setups)"
  claw_pass "Gracefully handled missing feature" "test_name" "$duration"
elif # ... normal validation
```

### Multi-Step Validation

```bash
# Check multiple conditions
local step1_ok=false
local step2_ok=false

[[ "$response" == *"step1_marker"* ]] && step1_ok=true
[[ "$response" == *"step2_marker"* ]] && step2_ok=true

if [ "$step1_ok" = true ] && [ "$step2_ok" = true ]; then
  claw_pass "All steps completed" "test_name" "$duration"
elif [ "$step1_ok" = true ]; then
  claw_warn "Only step 1 completed"
  claw_pass "Partial completion" "test_name" "$duration"
else
  claw_fail "No steps completed" "test_name" "$duration"
fi
```

## Known Issues & Gotchas

### 1. Empty Response After Tool Use

Some models (Kimi K2, Nova) call tools but return no content. Test 02 specifically detects this:

```bash
if claw_json_has_empty_payload "$json_response"; then
  claw_critical "EMPTY RESPONSE AFTER TOOL USE" ...
fi
```

### 2. Reasoning Tag Leakage

Some models leak `<reasoning>` or `<think>` tags in responses:

```bash
if claw_has_reasoning_tags "$response"; then
  claw_fail "Reasoning tags leaked into response" ...
fi
```

### 3. Context Overflow

Long-running sessions accumulate context. Each `claw_ask` gets a unique session ID to prevent this. If you need multi-turn context, use a shared session ID explicitly.

### 4. SSH Special Characters

Messages are base64-encoded for SSH to handle special characters. This is automatic in `claw_ask`.

### 5. Timeout Issues

Complex tool chains may need longer timeout:

```bash
CLAW_TIMEOUT=180 ./run.sh --ssh
```

## Writing New Tests

### Checklist

- [ ] File named `tests/NN_test_name.sh` (next available number)
- [ ] Function named `test_test_name()` exactly matches filename
- [ ] Header comment describes what/why
- [ ] Uses `claw_header "TEST NN: Name"` first
- [ ] Captures start time before `claw_ask`
- [ ] Calculates duration after response
- [ ] Handles empty responses with `claw_is_empty`
- [ ] Uses unique identifiers for verification
- [ ] Cleans up any temp files (especially for SSH mode)
- [ ] Updates BENCHMARKS.md with new test

### Adding to Runner

Tests are auto-discovered from `tests/*.sh`. No registration needed.

### Testing Your Test

```bash
# Source the helpers
source lib/common.sh

# Set mode
export CLAW_MODE=local

# Initialize
claw_init

# Run your test
source tests/NN_your_test.sh
test_your_test

# Check result
echo "Passed: $CLAW_PASSED, Failed: $CLAW_FAILED"
```

## Report Generation

Multi-model benchmark generates:

```
reports/
├── {model}-report.md     # Human-readable report
├── {model}-results.json  # Machine-readable results
├── {model}-raw.txt       # Full test output
└── SUMMARY.md            # Cross-model comparison
```

## References

- Full test documentation: `BENCHMARKS.md`
- Change history: `CHANGELOG.md`
- Model configurations: `models-to-test.json`
- Infrastructure scripts: `infra/`
