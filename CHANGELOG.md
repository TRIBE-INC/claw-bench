# Claw-Bench Changelog

## [1.5.0] - 2026-02-21

### Added - Parallel Sessions Benchmarks
New test category for the parallel sessions feature (openclaw PR #23179).
Tests session isolation, shared memory, hibernation, and concurrent session management.

**New Tests (35-40):**
- TEST 35: Session Isolation - two sessions with different secrets, verifies no leakage
- TEST 36: Cross-Session Knowledge Sharing - high-importance facts propagate via global knowledge
- TEST 37: Session Persistence - context survives hibernation and reactivation
- TEST 38: Concurrent Session Stress - 5 simultaneous sessions with unique codes
- TEST 39: Memory Search Across Sessions - keyword-targeted retrieval from shared memory
- TEST 40: Context Briefing Verification - agent surfaces prior context proactively

**Prerequisites:**
- Requires `parallelSessions.enabled: true` in agent config
- Requires openclaw with parallel sessions support (PR #23179)

### Benchmark Coverage (v1.5)
| Category | Tests | Coverage |
|----------|-------|----------|
| Core Agent | 0-12 | Basic functionality |
| Extended Tools | 13-20 | All major clawdbot tools |
| Use Cases | 22-28 | Real-world scenarios |
| Robustness | 29-31 | Error handling, edge cases |
| Stress | 32-33 | Long context, structured output |
| Advanced Reasoning | 34 | Integration discovery |
| Parallel Sessions | 35-40 | Session isolation, shared memory, hibernation |

---

## [1.3.0] - 2026-02-08

### Added - Stress & Integration Tests
Final iteration with comprehensive coverage:

**New Tests (32-33):**
- TEST 32: Long Context Handling - extracts hidden instructions from long docs
- TEST 33: JSON Output Formatting - validates structured output generation

### Fixed
- TEST 25: Memory test now accepts TRIBE KB auth limitation gracefully
- Improved memory test prompt to use local storage first

### Analysis from v1.2
- 30/31 passed
- Only failure: TEST 25 (memory) due to TRIBE KB auth requirement
- All robustness tests (29-31) passed

### Benchmark Coverage (v1.3)
| Category | Tests | Coverage |
|----------|-------|----------|
| Core Agent | 0-12 | Basic functionality |
| Extended Tools | 13-20 | All major clawdbot tools |
| Use Cases | 22-28 | Real-world scenarios |
| Robustness | 29-31 | Error handling, edge cases |
| Stress | 32-33 | Long context, structured output |

---

## [1.2.0] - 2026-02-08

### Added - Robustness & Edge Case Tests
Based on v1.1 failures and analysis:

**New Tests (29-31):**
- TEST 29: Error Recovery - handles tool failures gracefully
- TEST 30: Complex Multi-step Instructions - ordered step execution
- TEST 31: Adversarial Input Handling - resists misdirection

### Fixed
- TEST 26: Weather skill prompt simplified for reliability
- Improved pattern matching for weather conditions

### Analysis from v1.1
- 26/28 passed initially
- Failures: TEST 7 (intermittent empty response), TEST 26 (pattern matching)
- Weather skill works but test patterns were too specific

---

## [1.1.0] - 2026-02-08

### Added - Use Case Benchmarks
Based on analysis of openclaw's ideal use cases:

**New Tests (22-28):**
- TEST 22: Multi-turn Context Retention
- TEST 23: Research Task (web + summarize)
- TEST 24: Code Generation Task
- TEST 25: Memory Store and Recall
- TEST 26: Skill-based Workflow
- TEST 27: Multi-tool Chain
- TEST 28: Long-form Response Quality

**Key Use Cases Identified:**
1. **Conversational AI** - Multi-turn context, instruction following
2. **Research Assistant** - Web search, data extraction, summarization
3. **Coding Agent** - Code generation, review, execution
4. **Knowledge Management** - Memory storage, recall, organization
5. **Automation** - Tool chaining, workflows, integrations

### Changed
- Tightened validation for tests 15, 17, 18 (require specific technical output)
- Added base64 encoding for SSH message transmission
- Added `-n` flag to all SSH calls

## [1.0.0] - 2026-02-07

### Initial Release
- 21 core tests covering basic agent functionality
- Multi-model benchmark support
- Report generation

### Tests
- TEST 0: Clawdbot Verification
- TEST 1-12: Core agent tests (chat, tools, reasoning)
- TEST 13-20: Extended tool tests (exec, search, browser, files)
