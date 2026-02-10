# Clawdbot Model Benchmark Summary

**Date:** 2026-02-10
**Test Suite:** claw-bench v1.3 (33 tests)

> **IMPORTANT NOTICE**: Previous benchmark data contained errors. See [Issue #1](https://github.com/TRIBE-INC/claw-bench/issues/1) for details.

## Results Overview

| Model | Provider | Bedrock | OpenRouter | Input $/1M | Output $/1M | Status |
|-------|----------|---------|------------|------------|-------------|--------|
| **Mistral Large 3** | Mistral AI | ✅ 91% (29/32) | ✅ Works | $0.50 | $1.50 | **Recommended** - tool use works |
| **Claude Opus 4.5** | Anthropic | ✅ Works | ✅ Works | $5.00 | $25.00 | Premium tier |
| Kimi K2.5 | Moonshot | ❌ 9% | ✅ Works | $0.60 | $2.50 | **Bedrock API bug** - use OpenRouter |
| Kimi K2 | Moonshot | ❌ ~40% | ✅ Works | $0.60 | $2.50 | Same Bedrock bug |
| Amazon Nova Lite | Amazon | 33% | ✅ Works | $0.06 | $0.24 | Bedrock API issues |
| Amazon Nova Pro | Amazon | 25% | ✅ Works | $0.80 | $3.20 | Bedrock API issues |
| DeepSeek R1 | DeepSeek | ⚠️ Config | ✅ Works | $1.35 | $5.40 | Needs inference profile |
| Llama 3.3 70B | Meta | ⚠️ Config | ⚠️ Issues | $0.72 | $0.72 | Unusual tool behavior |

**Key Findings:**
1. **Mistral Large 3 works well on Bedrock** - 91% pass rate, tool use returns content correctly
2. **Kimi and Nova models have Bedrock API bugs** - Same models work correctly on OpenRouter
3. See [OpenRouter vs Bedrock Comparison](./openrouter-vs-bedrock-comparison.md) for detailed analysis

**Pricing source:** [AWS Bedrock Pricing](https://aws.amazon.com/bedrock/pricing/)

## Known Issues

### Resolved
1. **Kimi K2.5 empty responses** - This is a **Bedrock Converse API bug**, not a model issue. Kimi works correctly on OpenRouter. See [comparison report](./openrouter-vs-bedrock-comparison.md).
2. **Test file permissions** - Tests 22-33 now have execute permissions ([Issue #2](https://github.com/TRIBE-INC/claw-bench/issues/2) - CLOSED)
3. **Mistral Large 3 benchmark** - Re-run completed with 91% pass rate. Tool use works correctly. See [mistral-large-3-report.md](./mistral-large-3-report.md)

### Config Issues
4. **DeepSeek R1 and Llama 3.3 70B** require inference profile ARNs, not model IDs ([Issue #3](https://github.com/TRIBE-INC/claw-bench/issues/3))
5. **Session contamination** affects Nova models - reasoning content from previous models bleeds into new sessions ([Issue #4](https://github.com/TRIBE-INC/claw-bench/issues/4))

## Test Categories (v1.3 - 33 Tests)

### Core Agent Tests (0-12) - 13 tests
Basic functionality every agent must pass:
- Clawdbot verification, basic chat, tool use response
- Web fetch (JSON/HTML), data extraction, reasoning
- Instruction following, reasoning tags, error handling
- Consecutive tools, skill installation, Muse extension

### Extended Tool Tests (13-20) - 8 tests
Tests specific clawdbot tools:
- exec, web_search, browser, file operations
- subagent spawn, background process, image analysis, session status

### Use Case Tests (22-28) - 7 tests
Real-world scenarios:
- Multi-turn context retention
- Research task (web + summarize)
- Code generation and execution
- Memory store/recall
- Skill-based workflow (weather)
- Multi-tool chain
- Response quality

### Robustness Tests (29-31) - 3 tests
Edge cases and error handling:
- Error recovery from failures
- Complex multi-step instructions
- Adversarial input handling

### Stress Tests (32-33) - 2 tests
Performance under challenging conditions:
- Long context handling (hidden instructions)
- JSON output formatting

## Verified Results: Mistral Large 3 (Bedrock)

**Date:** 2026-02-10 | **Provider:** AWS Bedrock | **clawdbot:** v2026.1.24-3

| Metric | Value |
|--------|-------|
| Pass Rate | **91% (29/32)** |
| Critical Failures | 2 (instruction following edge cases) |
| Tool Use Works | ✅ Yes |
| Infrastructure Fails | 1 (tribecode plugin not enabled) |

**Key Finding:** Mistral Large 3 works correctly on Bedrock Converse API. The critical "tool use returns content" test (Test 2) passes, unlike Kimi and Nova models.

**Minor Issues:** Tests 7 and 30 (instruction following) return empty responses on complex format requirements. This is a model quirk, not a Bedrock API issue.

See [mistral-large-3-report.md](./mistral-large-3-report.md) for full details.

---

## Verified Results: Kimi K2.5 (Bedrock)

| Metric | Bedrock | OpenRouter |
|--------|---------|------------|
| Pass Rate | 9% (3/33) | ✅ Works |
| Critical Failures | 24 | 0 |
| Primary Issue | Empty responses | None |

**Root Cause:** The empty responses are caused by the **Bedrock Converse API**, not the Kimi model. The same model works correctly on OpenRouter.

**Recommendation:** Use OpenRouter for Kimi models until AWS fixes the Bedrock integration.

## What Makes a Good Agent Model

1. **Tool use response content** - Must return text after tool calls (TEST 2)
2. **Multi-turn context** - Must remember previous turns (TEST 22)
3. **Instruction following** - Must follow exact format requests (TEST 7)
4. **Error resilience** - Must handle failures gracefully (TEST 29)
5. **Adversarial resistance** - Must resist misdirection (TEST 31)

## How to Run Benchmarks

### Local Mode (requires clawdbot installed)
```bash
# Requires Node >=22.0.0
clawdbot gateway &
./run.sh --local
```

### SSH Mode (remote clawdbot instance)
```bash
export CLAW_HOST="ubuntu@your-bot-ip"
export CLAW_SSH_KEY="~/.ssh/your-key.pem"
./run.sh --ssh
```

### Multi-Model Benchmark
```bash
# Test single model
./benchmark-models.sh mistral-large-3

# Test all models in models-to-test.json
./benchmark-models.sh
```

## Using Without TRIBE/MUSE

This benchmark suite is standalone and does not require TRIBE or MUSE:

1. Clone the repo: `git clone https://github.com/TRIBE-INC/claw-bench.git`
2. Configure SSH access to your clawdbot instance
3. Run: `./run.sh --ssh`

For parallel benchmarking without MUSE:
```bash
# Run benchmarks in parallel using GNU parallel
cat models-to-test.json | jq -r '.models[].key' | \
  parallel -j2 "./benchmark-models.sh {}"
```

## Documentation
- [README.md](../README.md) - Full setup instructions
- [CHANGELOG.md](../CHANGELOG.md) - Version history

---
*Updated 2026-02-10 - Mistral Large 3 benchmark verified (91% pass rate)*
