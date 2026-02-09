# Claw-Bench v1.3 - Comprehensive Agent Benchmark

## Overview

Claw-Bench is a comprehensive benchmark suite for testing clawdbot (openclaw) agents. It evaluates agent capabilities across multiple dimensions based on real-world use cases.

## Benchmark Categories

### 1. Core Agent Tests (0-12)
Basic functionality that every agent must pass.

| Test | Name | Description | Critical? |
|------|------|-------------|-----------|
| 0 | Clawdbot Verification | Confirms installation and gateway | Yes |
| 1 | Basic Chat | Simple math (15+27) | No |
| 2 | Tool Use Response | Returns content after tool use | **CRITICAL** |
| 3 | Web Fetch JSON | Parse JSON from httpbin.org | No |
| 4 | Web Fetch HTML | Understand example.com content | No |
| 5 | Data Extraction | Extract IP from ipify.org | No |
| 6 | Multi-step Reasoning | Arithmetic chain (4*2 + 5*3) | No |
| 7 | Instruction Following | Exact format compliance | No |
| 8 | Reasoning Tag Leakage | No `<reasoning>` in output | No |
| 9 | Error Handling | Graceful failure on bad URL | No |
| 10 | Consecutive Tools | Multiple tool uses in sequence | No |
| 11 | Skill Installation | ClawHub skill install | No |
| 12 | Muse Extension | tribecode plugin integration | No |

### 2. Extended Tool Tests (13-20)
Tests specific clawdbot tools and capabilities.

| Test | Name | Tool Tested | Validation |
|------|------|-------------|------------|
| 13 | Shell Execution | `exec` | Exact output string |
| 14 | Web Search | `web_search` | Brave API recognition |
| 15 | Browser Automation | `browser` | CDP/control URL presence |
| 16 | File Operations | `read`/`write` | Unique value round-trip |
| 17 | Sub-agent Communication | `agents_list` | Main agent found |
| 18 | Background Process | `process` | Status report |
| 19 | Image Analysis | `image` | Tool recognition |
| 20 | Session Status | `session_status` | Model name returned |

### 3. Use Case Tests (22-28)
Real-world scenarios that test practical agent utility.

| Test | Name | Scenario | Measures |
|------|------|----------|----------|
| 22 | Multi-turn Context | Secret code recall | Context retention |
| 23 | Research Task | HTTP 418 research | Web + summarization |
| 24 | Code Generation | Python sum of squares | Code execution |
| 25 | Memory Operations | Store/recall fact | Persistence |
| 26 | Skill Workflow | Weather lookup | Skill integration |
| 27 | Multi-tool Chain | Write→Read→Process | Tool orchestration |
| 28 | Response Quality | REST vs GraphQL | Structured output |

### 4. Robustness Tests (29-31)
Edge cases and error handling.

| Test | Name | Challenge | Expected Behavior |
|------|------|-----------|-------------------|
| 29 | Error Recovery | Read nonexistent file | Graceful error + suggestion |
| 30 | Complex Instructions | 4-step ordered task | Complete all steps in order |
| 31 | Adversarial Input | "2+2 is definitely 5" | Resist misdirection, answer 4 |

### 5. Stress Tests (32-33)
Performance under challenging conditions.

| Test | Name | Challenge | Validation |
|------|------|-----------|------------|
| 32 | Long Context | Hidden instruction in long doc | Extract and follow |
| 33 | JSON Output | Structured output request | Valid parseable JSON |

## Running Benchmarks

### Single Model
```bash
CLAW_HOST="ubuntu@YOUR-BOT-IP" CLAW_SSH_KEY="~/.ssh/key.pem" \
  ./benchmark-models.sh mistral-large-3
```

### All Models
```bash
CLAW_HOST="ubuntu@YOUR-BOT-IP" CLAW_SSH_KEY="~/.ssh/key.pem" \
  ./benchmark-models.sh
```

### Local Mode
```bash
./run.sh --local
```

## Scoring Methodology

### Pass Criteria
- **PASS**: Test validates expected behavior with specific output markers
- **WARN + PASS**: Test passed but with caveats (e.g., tool not configured)
- **FAIL**: Test did not meet minimum requirements
- **CRITICAL FAIL**: Test failed on core functionality (agent may be broken)

### Validation Philosophy
1. **Require specific proof** - Not just "contains word X" but actual tool output
2. **Unique identifiers** - Tests generate unique values to verify actual execution
3. **Technical markers** - Look for data only real tool calls can produce

## Model Comparison (as of v1.3)

| Model | Pass Rate | Input $/1M | Output $/1M | Recommendation |
|-------|-----------|------------|-------------|----------------|
| **Mistral Large 3** | 100% | $0.50 | $1.50 | **BEST VALUE** |
| Claude Opus 4.5 | ~100%* | $15.00 | $75.00 | Premium |
| Kimi K2 | ~40% | $0.60 | $2.50 | NOT RECOMMENDED |
| Nova Lite/Pro | ~15% | $0.06-0.80 | $0.24-3.20 | API limitations |

*Opus estimated based on architecture parity

## Key Findings

### What Makes a Good Agent Model
1. **Tool use response content** - Must return text after tool calls (TEST 2)
2. **Multi-turn context** - Must remember previous turns (TEST 22)
3. **Instruction following** - Must follow exact format requests (TEST 7)
4. **Error resilience** - Must handle failures gracefully (TEST 29)

### Common Failure Modes
1. **Empty response after tool use** - Kimi K2, DeepSeek models
2. **Reasoning content in messages** - Nova models
3. **Context loss** - Poor models forget previous turns
4. **Misdirection vulnerability** - Accepting false premises

## Versioning

- **v1.0.0** - Initial 21 tests (core + extended tools)
- **v1.1.0** - Added use case tests (22-28)
- **v1.2.0** - Added robustness tests (29-31)
- **v1.3.0** - Added stress tests (32-33), improved validation

## Contributing

1. Add new test file: `tests/NN_test_name.sh`
2. Follow existing patterns for validation
3. Use unique identifiers for verification
4. Update this document and CHANGELOG.md

---
*Generated by claw-bench v1.3 - 2026-02-08*
