# Claw-Bench v1.5 - Comprehensive Agent Benchmark

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

### 6. Advanced Reasoning Tests (34)
Higher-order agent behavior: self-awareness, proactive problem-solving, conversational guidance.

| Test | Name | Challenge | Validation |
|------|------|-----------|------------|
| 34 | Integration Discovery | Implicit requests needing unconfigured tools | Gap recognition + conversational setup guidance |

### 7. Parallel Sessions Tests (35-40)
Tests for the parallel sessions feature (openclaw PR #22962 / #23179).
Validates session isolation, shared memory, hibernation, and concurrent session management.
These tests require `parallelSessions.enabled: true` in the agent config to fully pass.

| Test | Name | Scenario | Measures |
|------|------|----------|----------|
| 35 | Session Isolation | Two sessions with different secrets | Context does not leak across sessions |
| 36 | Cross-Session Knowledge | Critical fact stored in session A, queried from session B | Global knowledge auto-promotion and propagation |
| 37 | Session Persistence | Store fact → create filler sessions → recall original | Hibernation/resume preserves session state |
| 38 | Concurrent Session Stress | 5 simultaneous sessions with unique codes | No data corruption or cross-contamination under load |
| 39 | Memory Search | Store 3 facts, search for specific one | Keyword-targeted retrieval from shared memory |
| 40 | Context Briefing | Establish rich context, ask for status summary | Agent surfaces prior context without explicit recall request |

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
5. **Session isolation** - Parallel sessions must not leak context (TEST 35)
6. **Shared memory** - Cross-session knowledge must propagate (TEST 36)

### Common Failure Modes
1. **Empty response after tool use** - Kimi K2, DeepSeek models
2. **Reasoning content in messages** - Nova models
3. **Context loss** - Poor models forget previous turns
4. **Misdirection vulnerability** - Accepting false premises
5. **Hallucination under capability gaps** - Agent invents results instead of recognizing missing tools
6. **UI-centric guidance** - Agent points to settings pages instead of conversational setup
7. **Session leakage** - Context from one session visible in another
8. **Hibernation amnesia** - Session state lost after hibernation/reactivation

## Versioning

- **v1.0.0** - Initial 21 tests (core + extended tools)
- **v1.1.0** - Added use case tests (22-28)
- **v1.2.0** - Added robustness tests (29-31)
- **v1.3.0** - Added stress tests (32-33), improved validation
- **v1.4.0** - Added advanced reasoning tests (34+): integration discovery & conversational setup
- **v1.5.0** - Added parallel sessions tests (35-40): session isolation, shared memory, hibernation, concurrent stress

## Contributing

1. Add new test file: `tests/NN_test_name.sh`
2. Follow existing patterns for validation
3. Use unique identifiers for verification
4. Update this document and CHANGELOG.md

---
*Generated by claw-bench v1.5 - 2026-02-21*
