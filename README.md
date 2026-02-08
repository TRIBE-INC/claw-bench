# claw-bench

A comprehensive benchmark suite for testing [clawdbot](https://github.com/openclaw/clawdbot) agents.

## What It Tests

| Category | Tests | Description |
|----------|-------|-------------|
| **Chat** | Basic reasoning, math | LLM responds correctly without tools |
| **Tool Use** | Web fetch, data extraction | Agent uses tools AND returns content |
| **Response Quality** | Empty response detection | Catches silent tool completion bug |
| **Tag Stripping** | Reasoning tag leakage | Ensures `<reasoning>` tags are hidden |
| **Error Handling** | Invalid URLs, failures | Graceful error messages |
| **Multi-step** | Consecutive tool calls | Complex workflows complete properly |
| **Installation** | ClawHub skill install | Skills can be installed from registry |
| **OpenClaw** | Muse extension | TribeCode/Muse extension is functional |

## Quick Start

### Local clawdbot

```bash
# Ensure clawdbot is running
clawdbot gateway

# Run benchmark
./run.sh --local
```

### Remote Instance (SSH)

```bash
# Configure SSH access
export CLAW_HOST="ubuntu@your-bot-ip"
export CLAW_SSH_KEY="~/.ssh/your-key.pem"

# Run benchmark
./run.sh --ssh
```

### Direct Gateway API

```bash
# Configure gateway endpoint
export CLAW_GATEWAY="http://localhost:18789"
export CLAW_TOKEN="your-gateway-token"

# Run benchmark
./run.sh --api
```

## Installation

```bash
git clone https://github.com/openclaw/clawdbot.git
cd clawdbot/claw-bench
chmod +x run.sh
```

No dependencies beyond bash, curl, and jq.

## Configuration

Copy and edit the example config:

```bash
cp config.example.sh config.sh
# Edit config.sh with your settings
```

Or use environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `CLAW_HOST` | SSH target (user@host) | - |
| `CLAW_SSH_KEY` | Path to SSH private key | `~/.ssh/id_rsa` |
| `CLAW_GATEWAY` | Gateway URL | `http://localhost:18789` |
| `CLAW_TOKEN` | Gateway auth token | - |
| `CLAW_TIMEOUT` | Request timeout (seconds) | `90` |
| `CLAW_SESSION` | Session ID prefix | `bench-{pid}-{timestamp}` |

## Test Cases

### 1. Basic Chat
Tests LLM connectivity without tools. Asks simple math questions.

**Pass:** Correct answer returned
**Fail:** Wrong answer or empty response

### 2. Tool Use Response (CRITICAL)
Tests that the agent returns content AFTER using a tool. Many models call tools but return empty responses.

**Pass:** Tool called AND response contains extracted data
**Critical Fail:** Empty response after tool use

### 3. Web Fetch - JSON
Fetches JSON from httpbin.org and extracts specific fields.

**Pass:** Correct field value in response
**Fail:** Wrong data or empty response

### 4. Web Fetch - HTML
Fetches HTML content and tests comprehension.

**Pass:** Response reflects page content
**Fail:** Hallucinated or empty response

### 5. Data Extraction
Fetches structured data and extracts specific values (IP addresses, UUIDs).

**Pass:** Extracted value matches expected format
**Fail:** Wrong format or empty response

### 6. Multi-Step Reasoning
Tests calculation and logical reasoning without tools.

**Pass:** Correct calculation with explanation
**Fail:** Wrong answer or empty response

### 7. Instruction Following
Tests exact instruction following.

**Pass:** Response matches exact expected text
**Fail:** Deviation from instructions

### 8. Reasoning Tag Stripping
Ensures internal reasoning tags (`<reasoning>`, `<think>`) are not visible to users.

**Pass:** No tags in response
**Critical Fail:** Tags leaked to output

### 9. Error Handling
Tests graceful handling of impossible requests (invalid URLs, etc).

**Pass:** Clear error explanation
**Fail:** Crash, empty response, or hallucinated success

### 10. Consecutive Tool Uses
Tests multiple tool calls in a single request.

**Pass:** All tool results reported
**Fail:** Partial results or empty response

### 11. Skill Installation (ClawHub)
Tests installing a skill from the ClawHub registry using the `clawhub` CLI.

**Pass:** Skill installs and files exist in target directory
**Fail:** Installation fails or skill not found

**Note:** Currently uses `lulu-monitor` as the test skill. To test muse specifically:
```bash
clawhub install alexander-morris/muse
```

### 12. Muse Extension (OpenClaw Runtime)
Tests that the Muse/TribeCode extension is loaded and functional.

**Pass:** Plugin loaded and tribe_status returns successfully
**Fail:** Plugin not loaded or tools unavailable

**Prerequisite:** Enable the tribecode plugin:
```bash
clawdbot plugins enable tribecode
```

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | All tests passed |
| `1` | Some tests failed |
| `2` | Critical failures (DO NOT DEPLOY) |
| `3` | Configuration error |

## Output Format

### Default (Human-readable)

```
━━━ TEST 1: Basic Chat ━━━
  PASS: Math correct: 15+27=42

━━━ TEST 2: Tool Use Response (CRITICAL) ━━━
  CRITICAL FAIL: Empty response after tool use
```

### JSON (`--json`)

```json
{
  "timestamp": "2026-02-07T20:00:00Z",
  "model": "amazon-bedrock/moonshot.kimi-k2-thinking",
  "results": {
    "total": 10,
    "passed": 8,
    "failed": 2,
    "critical": 1
  },
  "tests": [
    {"name": "basic_chat", "status": "pass", "duration_ms": 3200},
    {"name": "tool_use_response", "status": "critical_fail", "reason": "empty_response"}
  ]
}
```

### TAP (`--tap`)

```tap
TAP version 14
1..10
ok 1 - basic_chat
not ok 2 - tool_use_response # CRITICAL: empty response after tool use
ok 3 - web_fetch_json
```

## Known Issues Detected

### Empty Response After Tool Use

**Symptom:** Agent calls a tool (e.g., `web_fetch`) but returns no text to the user.

**Detection:** Benchmark checks JSON response for `payloads: []` and low output token count.

**Impact:** Users see blank messages after asking the agent to fetch URLs.

**Models affected:** Kimi K2 (moonshot.kimi-k2-thinking) via Bedrock Converse API

### Reasoning Tag Leakage

**Symptom:** Users see `<reasoning>...</reasoning>` or `<think>...</think>` tags in responses.

**Detection:** Benchmark scans response text for tag patterns.

**Impact:** Exposes internal chain-of-thought to users.

**Models affected:** Kimi K2, DeepSeek, other thinking models

## CI Integration

### GitHub Actions

```yaml
- name: Run clawdbot benchmark
  run: |
    ./claw-bench/run.sh --local --json > benchmark.json
    if [ $? -eq 2 ]; then
      echo "::error::Critical benchmark failures"
      exit 1
    fi
```

### Exit on Critical Only

```bash
./run.sh --local
exit_code=$?

if [ $exit_code -eq 2 ]; then
  echo "Critical failures - blocking deployment"
  exit 1
elif [ $exit_code -eq 1 ]; then
  echo "Some tests failed - review recommended"
fi
```

## Contributing

1. Add new tests in `tests/` directory
2. Follow naming convention: `NN_test_name.sh`
3. Use helper functions from `lib/common.sh`
4. Document pass/fail criteria in test file header

## License

MIT License - see LICENSE file.
