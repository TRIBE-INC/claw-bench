# claw-bench

A comprehensive benchmark suite for testing [clawdbot](https://github.com/openclaw/clawdbot) agents.

## Benchmark Scores (2026-02-10)

Ranked by pass rate (best first). All Bedrock tests unless noted.

| Rank | Model | Pass Rate | Input $/1M | Output $/1M | Notes | Report |
|------|-------|-----------|------------|-------------|-------|--------|
| 🥇 | **Kimi K2.5 (OpenRouter)** | **~100%** | $0.60 | $3.00 | Works on OpenRouter, not Bedrock | [✅ Verified](./reports/openrouter-vs-bedrock-comparison.md) |
| 🥈 | **Mistral Large 3** | **90.6%** (29/32) | $0.50 | $1.50 | Tool use works, best value | [✅ Report](./reports/mistral-large-3-report.md) |
| 🥉 | Amazon Nova Lite | 33.3% (4/12) | $0.06 | $0.24 | Ultra-cheap, limited capability | [✅ Report](./reports/nova-lite-report.md) |
| 4 | Llama 3.3 70B | 25.0% (3/12) | $0.72 | $0.72 | Requires inference profile | [✅ Report](./reports/llama-3-3-70b-report.md) |
| 5 | Amazon Nova Pro | 25.0% (3/12) | $0.80 | $3.20 | Bedrock API issues | [✅ Report](./reports/nova-pro-report.md) |
| 6 | DeepSeek R1 | 25.0% (3/12) | $1.35 | $5.40 | Requires inference profile | [✅ Report](./reports/deepseek-r1-report.md) |
| 7 | Kimi K2.5 (Bedrock) | 9.1% (3/33) | $0.60 | $2.50 | ❌ 40% timeout rate - proven bug | [✅ Report](./reports/kimi-k2.5-report.md) ([Proof](./reports/bedrock-kimi-bug-proof.md)) |
| - | Claude Opus 4.5 | ~100%* | $5.00 | $25.00 | Premium tier | ⚠️ No report |
| - | Kimi K2 (Thinking) | ~40%* | $0.60 | $2.50 | Same Bedrock bug as K2.5 | ⚠️ No report |

*Estimated - no benchmark report on file.

**Pricing source:** [AWS Bedrock Pricing](https://aws.amazon.com/bedrock/pricing/)

### Integration Discovery Test (Test 34)

Tests whether an agent can recognize a missing capability from an implicit user request, guide the user through setup conversationally, accept an API key, configure the tool, and use it successfully.

| Model | Phase A (Gap Recognition) | Phase B (Tool Install) | Result | Failure Reason |
|-------|--------------------------|----------------------|--------|----------------|
| **Mistral Large 3** | 3/3 | ✅ Key written + search working | **PASS** | - |
| Kimi K2.5 | 0/3 | ❌ Key not written to config | FAIL | Tried web_fetch instead of recognizing gap |
| Amazon Nova Lite | 0/3 | ❌ | FAIL | Bedrock "reasoning content" validation bug |
| Amazon Nova Pro | 0/3 | ❌ | FAIL | Bedrock "reasoning content" validation bug |
| DeepSeek R1 | 0/3 | ❌ | FAIL | Not provisioned for on-demand |
| DeepSeek V3.1 | 0/3 | ❌ | FAIL | Invalid model identifier |
| Llama 3.3 70B | 0/3 | ❌ | FAIL | Not provisioned for on-demand |

*Note: DeepSeek, Llama failures are Bedrock provisioning issues (not model capability). Nova failures are a Bedrock content validation bug. Only Mistral and Kimi got clean test signals.*

### Parallel Sessions Tests (Tests 35-40)

Tests for the parallel sessions feature ([openclaw PR #23179](https://github.com/openclaw/openclaw/pull/23179)).
Requires `parallelSessions.enabled: true` in agent config.

| Test | Name | What It Validates |
|------|------|-------------------|
| 35 | Session Isolation | Two sessions with different secrets don't leak context |
| 36 | Cross-Session Knowledge | High-importance facts propagate via global knowledge |
| 37 | Session Persistence | Context survives hibernation and reactivation |
| 38 | Concurrent Session Stress | 5 simultaneous sessions with unique codes — no corruption |
| 39 | Memory Search | Keyword-targeted retrieval from shared memory |
| 40 | Context Briefing | Agent surfaces prior context without explicit recall |

**No reports yet** — these tests require clawdbot builds with parallel sessions enabled.

### Bedrock vs OpenRouter: Which Models Work?

**TL;DR:** Some models fail on Bedrock but work on OpenRouter due to API differences.

| Model | Bedrock | OpenRouter | Recommendation |
|-------|---------|------------|----------------|
| **Mistral Large 3** | ✅ 91% | ✅ Works | Use either |
| **Claude Opus 4.5** | ✅ Works | ✅ Works | Use either |
| **Kimi K2.5** | ❌ 9% | ✅ Works | **Use OpenRouter** |
| **Nova Lite/Pro** | ❌ 25-33% | ✅ Works | **Use OpenRouter** |

**Why?** Kimi K2.5 has a **40% intermittent timeout rate** when processing tool results on Bedrock. The stream simply hangs without returning events. This compounds across multiple tool uses (60%^n success rate). This is an **AWS Bedrock infrastructure bug** - Kimi works 100% reliably on OpenRouter. See [definitive proof](./reports/bedrock-kimi-bug-proof.md).

See [reports/](./reports/) for detailed test breakdowns.

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
| **Integration Discovery** | Capability gap + setup | Agent recognizes missing tools, guides user through conversational setup |
| **Parallel Sessions** | Isolation, shared memory, hibernation | Concurrent sessions with knowledge sharing (tests 35-40) |

## Quick Start

### Option 1: Live AWS Instance Benchmarking (Recommended)

The easiest way to benchmark models with real clawdbot instances:

```bash
# 1. Configure environment
cp .env.example .env
# Edit .env with your AWS credentials and settings

# 2. Run single model benchmark
./benchmark-live.sh mistral-large-3

# 3. Or run all models sequentially
./benchmark-live.sh --all

# 4. Or run in parallel with MUSE (requires TRIBE CLI)
./benchmark-parallel.sh -n 3   # 3 concurrent benchmarks
```

This automatically:
- Launches EC2 instances with clawdbot pre-installed
- Configures the specified model via Bedrock
- Runs the full test suite
- Generates reports in `reports/`
- Terminates instances when done

### Option 2: Manual SSH to Existing Instance

```bash
# Configure SSH access to an existing clawdbot instance
export CLAW_HOST="ubuntu@your-bot-ip"
export CLAW_SSH_KEY="~/.ssh/your-key.pem"

# Run benchmark
./run.sh --ssh
```

### Option 3: Local Clawdbot

```bash
# Ensure clawdbot is running locally (requires Node >=22)
clawdbot gateway

# Run benchmark
./run.sh --local
```

### Option 4: Direct Gateway API

```bash
# Configure gateway endpoint
export CLAW_GATEWAY="http://localhost:18789"
export CLAW_TOKEN="your-gateway-token"

# Run benchmark (not yet implemented)
./run.sh --api
```

## Installation

```bash
git clone https://github.com/TRIBE-INC/claw-bench.git
cd claw-bench
chmod +x *.sh infra/*.sh
```

### Dependencies

**Required:**
- bash, curl, jq
- AWS CLI (for live instance benchmarking)

**Optional:**
- TRIBE CLI (for parallel benchmarking with MUSE)

### AWS Setup for Live Benchmarking

```bash
# 1. Install AWS CLI
brew install awscli

# 2. Configure credentials
aws configure

# 3. Copy and edit environment file
cp .env.example .env
# Set CLAWGO_AMI_ID, CLAWGO_SECURITY_GROUP_ID, etc.

# 4. Create SSH key pair (if needed)
aws ec2 create-key-pair --key-name claw-bench \
  --query 'KeyMaterial' --output text > ~/.ssh/claw-bench.pem
chmod 600 ~/.ssh/claw-bench.pem
```

## Infrastructure Scripts

Located in `infra/`:

| Script | Purpose |
|--------|---------|
| `launch-instance.sh` | Launch a benchmark EC2 instance |
| `wait-for-ready.sh` | Wait for instance to be ready |
| `terminate-instance.sh` | Terminate instance(s) safely |

### Manual Instance Management

```bash
# Launch instance for specific model
INSTANCE_ID=$(./infra/launch-instance.sh mistral.mistral-large-3-675b-instruct)

# Wait for it to be ready
PUBLIC_IP=$(./infra/wait-for-ready.sh $INSTANCE_ID)

# Run benchmark manually
CLAW_HOST="ubuntu@$PUBLIC_IP" ./run.sh --ssh

# Clean up
./infra/terminate-instance.sh $INSTANCE_ID

# Or terminate all benchmark instances
./infra/terminate-instance.sh --all
```

## Parallel Benchmarking with MUSE

For running multiple model benchmarks concurrently:

```bash
# Install TRIBE CLI first
curl -fsSL https://tribecode.ai/install.sh | bash

# Run 3 concurrent benchmarks
./benchmark-parallel.sh -n 3

# Benchmark specific models
./benchmark-parallel.sh -m "mistral-large-3,nova-pro"

# Monitor progress
./benchmark-parallel.sh --status

# Collect results
./benchmark-parallel.sh --collect

# Clean up everything
./benchmark-parallel.sh --cleanup
```

MUSE spawns isolated agents that each:
1. Launch their own EC2 instance
2. Run the full benchmark suite
3. Generate reports
4. Terminate the instance

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

### Empty Response After Tool Use (AWS Bedrock + Kimi)

**Symptom:** Agent calls a tool (e.g., `web_fetch`) but returns no text to the user.

**Detection:** Benchmark checks JSON response for `payloads: []` and low output token count.

**Impact:** Users see blank messages after asking the agent to fetch URLs.

**Root Cause (PROVEN):** Kimi K2.5 has a **40% timeout rate** on Bedrock when processing tool results. The Bedrock stream hangs indefinitely with no events returned. This is NOT a model bug - the same model works 100% reliably on OpenRouter.

**Proof:**
```
Kimi K2.5 on Bedrock (10 identical requests):
- 6 passed, 4 timed out (60% success rate)

Mistral Large 3 on Bedrock (10 identical requests):
- 10 passed, 0 timed out (100% success rate)
```

**Why 9% overall pass rate?** The 40% failure rate compounds: 60%^n success for n tool uses.

**Models affected:** Kimi K2 and K2.5 via AWS Bedrock Converse API

**Workaround:** Use OpenRouter instead of Bedrock for Kimi models.

**Report:** [Definitive Proof](./reports/bedrock-kimi-bug-proof.md)

## Testing with OpenRouter

To test models via OpenRouter instead of AWS Bedrock:

```bash
# Copy the example env file
cp .env.example .env

# Add your OpenRouter API key
# Get one at: https://openrouter.ai/keys
echo "OPENROUTER_API_KEY=sk-or-v1-your-key-here" > .env

# Test Kimi K2.5 via OpenRouter
curl -s https://openrouter.ai/api/v1/chat/completions \
  -H "Authorization: Bearer $(cat .env | grep OPENROUTER_API_KEY | cut -d= -f2)" \
  -H "Content-Type: application/json" \
  -d '{"model": "moonshotai/kimi-k2.5", "max_tokens": 100, "messages": [{"role": "user", "content": "What is 2+2?"}]}'
```

**Note:** `.env` is gitignored. Never commit API keys.

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
