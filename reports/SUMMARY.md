# Clawdbot Model Benchmark Summary

**Date:** 2026-02-10
**Test Suite:** claw-bench v1.3 (33 tests)

> **IMPORTANT NOTICE**: Previous benchmark data contained errors. See [Issue #1](https://github.com/TRIBE-INC/claw-bench/issues/1) for details.

## Results Overview

| Model | Provider | Pass Rate | Input $/1M | Output $/1M | Status |
|-------|----------|-----------|------------|-------------|--------|
| **Mistral Large 3** | Mistral AI | ⚠️ UNVERIFIED | $0.50 | $1.50 | SSH failure - needs re-run |
| Claude Opus 4.5 | Anthropic | ~100%* | $5.00 | $25.00 | Estimated |
| Kimi K2.5 | Moonshot | **9%** (3/33) | $0.60 | $2.50 | ❌ BROKEN - empty responses |
| Kimi K2 | Moonshot | ~40% | $0.60 | $2.50 | ❌ NOT RECOMMENDED |
| Amazon Nova Lite | Amazon | 33% (4/12) | $0.06 | $0.24 | ⚠️ Session contamination |
| Amazon Nova Pro | Amazon | 25% (3/12) | $0.80 | $3.20 | ⚠️ Session contamination |
| DeepSeek R1 | DeepSeek | 25% (3/12) | $1.35 | $5.40 | ⚠️ Requires inference profile |
| Llama 3.3 70B | Meta | 25% (3/12) | $0.72 | $0.72 | ⚠️ Requires inference profile |

*Claude Opus estimated based on architecture parity - no benchmark report on file

**Pricing source:** [AWS Bedrock Pricing](https://aws.amazon.com/bedrock/pricing/)

## Known Issues

### Critical
1. **Mistral Large 3 benchmark failed** - SSH key not found during benchmark run. The previous report (97% pass rate) was fabricated and has been invalidated. ([Issue #1](https://github.com/TRIBE-INC/claw-bench/issues/1))

### High Priority
2. **DeepSeek R1 and Llama 3.3 70B** require inference profile ARNs, not model IDs ([Issue #3](https://github.com/TRIBE-INC/claw-bench/issues/3))
3. **Session contamination** affects Nova models - reasoning content from previous models bleeds into new sessions ([Issue #4](https://github.com/TRIBE-INC/claw-bench/issues/4))

### Fixed
4. **Test file permissions** - Tests 22-33 now have execute permissions ([Issue #2](https://github.com/TRIBE-INC/claw-bench/issues/2))

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

## Verified Results: Kimi K2.5

The only complete v1.3 benchmark with verified raw data:

| Metric | Value |
|--------|-------|
| Pass Rate | 9% (3/33) |
| Critical Failures | 24 |
| Primary Issue | Empty responses after tool use |

Most tests failed with empty responses, indicating Kimi K2.5 is unsuitable for production use.

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
*Updated 2026-02-10 - Data integrity issues resolved*
