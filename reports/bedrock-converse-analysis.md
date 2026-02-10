# Bedrock Converse API Implementation Analysis

**Date:** 2026-02-10
**clawdbot Version:** 2026.1.24-3
**pi-ai Version:** (from @mariozechner/pi-ai)

## Executive Summary

After analyzing the clawdbot Bedrock Converse API implementation, I've identified **three potential issues** that could cause empty responses with Kimi and Nova models.

## Implementation Analysis

### Source Files Examined

1. `@mariozechner/pi-ai/dist/providers/amazon-bedrock.js` - Main Bedrock streaming implementation
2. `@mariozechner/pi-ai/dist/providers/transform-messages.js` - Message transformation for cross-provider compatibility

### Key Implementation Details

The implementation uses:
- `ConverseStreamCommand` from `@aws-sdk/client-bedrock-runtime`
- Streaming event handlers for `contentBlockStart`, `contentBlockDelta`, `contentBlockStop`, `messageStop`

## Potential Issues Identified

### Issue 1: Unmapped Stop Reasons Treated as Errors

**Location:** `amazon-bedrock.js` lines 396-409

```javascript
function mapStopReason(reason) {
    switch (reason) {
        case BedrockStopReason.END_TURN:
        case BedrockStopReason.STOP_SEQUENCE:
            return "stop";
        case BedrockStopReason.MAX_TOKENS:
        case BedrockStopReason.MODEL_CONTEXT_WINDOW_EXCEEDED:
            return "length";
        case BedrockStopReason.TOOL_USE:
            return "toolUse";
        default:
            return "error";  // <-- PROBLEM
    }
}
```

**Available Bedrock Stop Reasons (not handled):**
- `CONTENT_FILTERED` → mapped to "error"
- `GUARDRAIL_INTERVENED` → mapped to "error"
- `MALFORMED_MODEL_OUTPUT` → mapped to "error"
- `MALFORMED_TOOL_USE` → mapped to "error"

**Impact:** If Kimi returns `MALFORMED_MODEL_OUTPUT` or any unhandled reason, messages are marked as "error" and **skipped entirely** in `transform-messages.js` (lines 109-111).

**Potential Fix:**
```javascript
function mapStopReason(reason) {
    switch (reason) {
        case BedrockStopReason.END_TURN:
        case BedrockStopReason.STOP_SEQUENCE:
            return "stop";
        case BedrockStopReason.MAX_TOKENS:
        case BedrockStopReason.MODEL_CONTEXT_WINDOW_EXCEEDED:
            return "length";
        case BedrockStopReason.TOOL_USE:
            return "toolUse";
        case BedrockStopReason.CONTENT_FILTERED:
            return "content_filtered";
        case BedrockStopReason.MALFORMED_MODEL_OUTPUT:
        case BedrockStopReason.MALFORMED_TOOL_USE:
            return "malformed";  // Don't treat as error
        default:
            console.warn(`Unknown Bedrock stop reason: ${reason}`);
            return "stop";  // Default to stop, not error
    }
}
```

### Issue 2: Empty Content After Tool Results

**Location:** `amazon-bedrock.js` lines 125-138

The streaming handler only creates text blocks when `delta?.text` is defined. If Kimi:
1. Receives tool results
2. Processes them internally
3. Never emits `contentBlockDelta` with text

Then `output.content` remains empty, resulting in blank responses.

**Symptoms:**
- Tool calls execute successfully
- Tool results are received
- Model returns `messageStop` with `END_TURN`
- No text content is streamed

**Potential Fix:** Add logging to detect and handle empty responses after tool use:

```javascript
// In the streaming loop, after messageStop
if (output.stopReason === "stop" && output.content.length === 0) {
    console.warn(`Model ${model.id} returned empty content after tool use`);
    // Optionally inject a fallback message
}
```

### Issue 3: Thinking Block Handling for Non-Anthropic Models

**Location:** `amazon-bedrock.js` lines 291-305

For non-Anthropic models with thinking/reasoning content, the code sends:
```javascript
reasoningContent: {
    reasoningText: { text: sanitizeSurrogates(c.thinking) }
}
```

But Kimi might not expect this format. The model could be:
1. Rejecting the `reasoningContent` field silently
2. Getting confused by its own reasoning being sent back

**Note:** This applies when replaying messages with thinking content, not on first generation.

## Comparison: Why OpenRouter Works

OpenRouter uses a different API format:
- Standard OpenAI-compatible chat completions
- Tool results as simple `{"role": "tool", "content": "..."}` messages
- No `reasoningContent` wrapper for thinking

The structural differences may explain why Kimi works on OpenRouter but fails on Bedrock.

## Recommended Testing

1. **Add Debug Logging:** Capture raw Bedrock stream events to see exactly what Kimi returns
2. **Test Stop Reasons:** Log `messageStop.stopReason` for Kimi to see if it's returning unexpected values
3. **Monitor Content Blocks:** Log all `contentBlockDelta` events to verify Kimi is (or isn't) streaming text

### Debug Code to Add

```javascript
// In streamBedrock function, add logging
for await (const item of response.stream) {
    console.log('Bedrock stream event:', JSON.stringify(item, null, 2));
    // ... existing handling
}
```

## Recommended Fixes (Priority Order)

1. **High:** Update `mapStopReason` to handle all Bedrock stop reasons gracefully
2. **Medium:** Add empty response detection after tool use
3. **Low:** Review `reasoningContent` handling for non-Anthropic models

## Testing the Fix

To verify fixes work:

1. Apply code changes to `@mariozechner/pi-ai`
2. Run benchmark tests on Kimi K2.5
3. Compare results to OpenRouter baseline

## Alternative: Use OpenRouter as Fallback

If Bedrock fixes are not feasible, configure clawdbot to route Kimi traffic through OpenRouter:

```json
{
  "models": {
    "providers": {
      "openrouter": {
        "baseUrl": "https://openrouter.ai/api/v1",
        "api": "openai-responses",
        "models": [
          {"id": "moonshotai/kimi-k2.5", "name": "Kimi K2.5"}
        ]
      }
    }
  }
}
```

---
*Analysis completed 2026-02-10*
