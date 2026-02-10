#!/usr/bin/env node
/**
 * Debug script to capture raw Bedrock Converse API events
 * Usage: node bedrock-debug.js <model-id>
 *
 * Examples:
 *   node bedrock-debug.js moonshotai.kimi-k2.5
 *   node bedrock-debug.js mistral.mistral-large-3-675b-instruct
 *   node bedrock-debug.js anthropic.claude-3-5-sonnet-20241022-v2:0
 */

import { BedrockRuntimeClient, ConverseStreamCommand } from "@aws-sdk/client-bedrock-runtime";

const modelId = process.argv[2] || "moonshotai.kimi-k2.5";
const region = process.env.AWS_REGION || process.env.BEDROCK_REGION || "us-east-1";

console.log(`\n${"=".repeat(60)}`);
console.log(`BEDROCK CONVERSE API DEBUG`);
console.log(`Model: ${modelId}`);
console.log(`Region: ${region}`);
console.log(`${"=".repeat(60)}\n`);

const client = new BedrockRuntimeClient({ region });

// Test 1: Basic chat (no tools)
async function testBasicChat() {
  console.log("\n--- TEST 1: Basic Chat (No Tools) ---\n");

  const command = new ConverseStreamCommand({
    modelId,
    messages: [
      { role: "user", content: [{ text: "What is 15 + 27? Reply with just the number." }] }
    ],
    inferenceConfig: { maxTokens: 100 }
  });

  try {
    const response = await client.send(command);
    let textContent = "";
    let stopReason = null;

    for await (const event of response.stream) {
      console.log("Event:", JSON.stringify(event, null, 2));

      if (event.contentBlockDelta?.delta?.text) {
        textContent += event.contentBlockDelta.delta.text;
      }
      if (event.messageStop?.stopReason) {
        stopReason = event.messageStop.stopReason;
      }
    }

    console.log("\n--- RESULT ---");
    console.log("Text content:", textContent || "(empty)");
    console.log("Stop reason:", stopReason);
    return { success: true, content: textContent, stopReason };
  } catch (error) {
    console.error("ERROR:", error.message);
    return { success: false, error: error.message };
  }
}

// Test 2: Tool call (model should call the tool)
async function testToolCall() {
  console.log("\n--- TEST 2: Tool Call ---\n");

  const command = new ConverseStreamCommand({
    modelId,
    messages: [
      { role: "user", content: [{ text: "What's the weather in San Francisco?" }] }
    ],
    toolConfig: {
      tools: [{
        toolSpec: {
          name: "get_weather",
          description: "Get the current weather for a location",
          inputSchema: {
            json: {
              type: "object",
              properties: {
                location: { type: "string", description: "City name" }
              },
              required: ["location"]
            }
          }
        }
      }]
    },
    inferenceConfig: { maxTokens: 200 }
  });

  try {
    const response = await client.send(command);
    let textContent = "";
    let toolUse = null;
    let stopReason = null;

    for await (const event of response.stream) {
      console.log("Event:", JSON.stringify(event, null, 2));

      if (event.contentBlockDelta?.delta?.text) {
        textContent += event.contentBlockDelta.delta.text;
      }
      if (event.contentBlockStart?.start?.toolUse) {
        toolUse = event.contentBlockStart.start.toolUse;
      }
      if (event.contentBlockDelta?.delta?.toolUse) {
        if (!toolUse) toolUse = {};
        toolUse.input = (toolUse.input || "") + (event.contentBlockDelta.delta.toolUse.input || "");
      }
      if (event.messageStop?.stopReason) {
        stopReason = event.messageStop.stopReason;
      }
    }

    console.log("\n--- RESULT ---");
    console.log("Text content:", textContent || "(empty)");
    console.log("Tool use:", toolUse ? JSON.stringify(toolUse) : "(none)");
    console.log("Stop reason:", stopReason);
    return { success: true, content: textContent, toolUse, stopReason };
  } catch (error) {
    console.error("ERROR:", error.message);
    return { success: false, error: error.message };
  }
}

// Test 3: Response after tool result (THE CRITICAL TEST)
async function testAfterToolResult() {
  console.log("\n--- TEST 3: Response After Tool Result (CRITICAL) ---\n");

  const command = new ConverseStreamCommand({
    modelId,
    messages: [
      { role: "user", content: [{ text: "What's the weather in San Francisco?" }] },
      {
        role: "assistant",
        content: [{
          toolUse: {
            toolUseId: "tool_001",
            name: "get_weather",
            input: { location: "San Francisco" }
          }
        }]
      },
      {
        role: "user",
        content: [{
          toolResult: {
            toolUseId: "tool_001",
            content: [{ text: JSON.stringify({ temperature: 65, conditions: "sunny", humidity: 55 }) }],
            status: "success"
          }
        }]
      }
    ],
    toolConfig: {
      tools: [{
        toolSpec: {
          name: "get_weather",
          description: "Get the current weather for a location",
          inputSchema: {
            json: {
              type: "object",
              properties: {
                location: { type: "string", description: "City name" }
              },
              required: ["location"]
            }
          }
        }
      }]
    },
    inferenceConfig: { maxTokens: 200 }
  });

  try {
    const response = await client.send(command);
    let textContent = "";
    let stopReason = null;
    let allEvents = [];

    for await (const event of response.stream) {
      allEvents.push(event);
      console.log("Event:", JSON.stringify(event, null, 2));

      if (event.contentBlockDelta?.delta?.text) {
        textContent += event.contentBlockDelta.delta.text;
      }
      if (event.messageStop?.stopReason) {
        stopReason = event.messageStop.stopReason;
      }
    }

    console.log("\n--- RESULT ---");
    console.log("Text content:", textContent || "(EMPTY - THIS IS THE BUG!)");
    console.log("Stop reason:", stopReason);
    console.log("Total events:", allEvents.length);
    console.log("Content events:", allEvents.filter(e => e.contentBlockDelta).length);

    return {
      success: true,
      content: textContent,
      stopReason,
      eventCount: allEvents.length,
      contentEventCount: allEvents.filter(e => e.contentBlockDelta).length,
      isEmpty: !textContent || textContent.trim() === ""
    };
  } catch (error) {
    console.error("ERROR:", error.message);
    return { success: false, error: error.message };
  }
}

// Run all tests
async function main() {
  const results = {
    model: modelId,
    region,
    timestamp: new Date().toISOString(),
    tests: {}
  };

  results.tests.basicChat = await testBasicChat();
  results.tests.toolCall = await testToolCall();
  results.tests.afterToolResult = await testAfterToolResult();

  console.log("\n" + "=".repeat(60));
  console.log("SUMMARY");
  console.log("=".repeat(60));
  console.log(JSON.stringify(results, null, 2));

  // Diagnosis
  console.log("\n--- DIAGNOSIS ---");
  if (results.tests.afterToolResult.isEmpty) {
    console.log("❌ BUG CONFIRMED: Model returns empty content after tool result");
    console.log("   Stop reason was:", results.tests.afterToolResult.stopReason);
    console.log("   Events received:", results.tests.afterToolResult.eventCount);
    console.log("   Content events:", results.tests.afterToolResult.contentEventCount);
  } else {
    console.log("✅ Model correctly returns content after tool result");
  }
}

main().catch(console.error);
