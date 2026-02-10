# Bedrock Debug Tools

These scripts test the raw AWS Bedrock Converse API to diagnose tool use issues.

## Key Findings

**Kimi K2.5 has a 40% timeout rate on Bedrock** when processing tool results. This is an AWS infrastructure bug, not a model bug.

## Scripts

### test-consistency.mjs
Runs 10 identical tool-result requests to measure reliability:
```bash
node test-consistency.mjs moonshotai.kimi-k2.5        # ~60% pass rate
node test-consistency.mjs mistral.mistral-large-3-675b-instruct  # 100% pass rate
```

### test-after-tool-result.mjs
Tests a single tool-result flow with verbose logging:
```bash
node test-after-tool-result.mjs moonshotai.kimi-k2.5
```

### bedrock-debug.js
Original comprehensive test suite (3 tests):
```bash
node bedrock-debug.js moonshotai.kimi-k2.5
```

## Setup

```bash
npm install
# Requires AWS credentials configured (aws configure)
```

## Results

See [../reports/bedrock-kimi-bug-proof.md](../reports/bedrock-kimi-bug-proof.md) for detailed findings.
