#!/usr/bin/env node
/**
 * Direct test with exact format that worked for Kimi
 */

import { BedrockRuntimeClient, ConverseStreamCommand } from "@aws-sdk/client-bedrock-runtime";

const client = new BedrockRuntimeClient({ region: "us-east-1" });

// Test 1: The format that worked earlier
console.log("=== Test 1: Format that worked earlier ===\n");

const command1 = new ConverseStreamCommand({
  modelId: "moonshotai.kimi-k2.5",
  messages: [
    { role: "user", content: [{ text: "Get weather for Tokyo" }] },
    {
      role: "assistant",
      content: [
        { text: "I'll get the weather for Tokyo." },
        { toolUse: { toolUseId: "tooluse_123abc", name: "get_weather", input: { city: "Tokyo" } } }
      ]
    },
    {
      role: "user",
      content: [{
        toolResult: {
          toolUseId: "tooluse_123abc",
          content: [{ text: '{"temperature": 22, "conditions": "sunny", "humidity": 60}' }],
          status: "success"
        }
      }]
    }
  ],
  toolConfig: {
    tools: [{
      toolSpec: {
        name: "get_weather",
        description: "Get weather for a city",
        inputSchema: { json: { type: "object", properties: { city: { type: "string" } }, required: ["city"] } }
      }
    }]
  },
  inferenceConfig: { maxTokens: 200 }
});

try {
  const response1 = await client.send(command1);
  let text1 = "";
  let stopReason1 = "";

  const timeout1 = setTimeout(() => {
    console.log("⏱️ TIMEOUT after 20s");
    process.exit(1);
  }, 20000);

  for await (const event of response1.stream) {
    if (event.contentBlockDelta?.delta?.text) {
      text1 += event.contentBlockDelta.delta.text;
    }
    if (event.messageStop?.stopReason) {
      stopReason1 = event.messageStop.stopReason;
    }
  }

  clearTimeout(timeout1);
  console.log("Response:", text1.substring(0, 100) + "...");
  console.log("Stop reason:", stopReason1);
  console.log(text1.trim() ? "✅ PASSED" : "❌ EMPTY RESPONSE");

} catch (err) {
  console.log("❌ ERROR:", err.message);
}

// Test 2: Without text in assistant message (tool use only)
console.log("\n=== Test 2: Tool use only (no text) ===\n");

const command2 = new ConverseStreamCommand({
  modelId: "moonshotai.kimi-k2.5",
  messages: [
    { role: "user", content: [{ text: "Get weather for Tokyo" }] },
    {
      role: "assistant",
      content: [
        { toolUse: { toolUseId: "tooluse_abc123", name: "get_weather", input: { city: "Tokyo" } } }
      ]
    },
    {
      role: "user",
      content: [{
        toolResult: {
          toolUseId: "tooluse_abc123",
          content: [{ text: '{"temperature": 22, "conditions": "sunny"}' }],
          status: "success"
        }
      }]
    }
  ],
  toolConfig: {
    tools: [{
      toolSpec: {
        name: "get_weather",
        description: "Get weather for a city",
        inputSchema: { json: { type: "object", properties: { city: { type: "string" } }, required: ["city"] } }
      }
    }]
  },
  inferenceConfig: { maxTokens: 200 }
});

try {
  const response2 = await client.send(command2);
  let text2 = "";
  let stopReason2 = "";

  const timeout2 = setTimeout(() => {
    console.log("⏱️ TIMEOUT after 20s");
    process.exit(1);
  }, 20000);

  for await (const event of response2.stream) {
    if (event.contentBlockDelta?.delta?.text) {
      text2 += event.contentBlockDelta.delta.text;
    }
    if (event.messageStop?.stopReason) {
      stopReason2 = event.messageStop.stopReason;
    }
  }

  clearTimeout(timeout2);
  console.log("Response:", text2.substring(0, 100) + "...");
  console.log("Stop reason:", stopReason2);
  console.log(text2.trim() ? "✅ PASSED" : "❌ EMPTY RESPONSE");

} catch (err) {
  console.log("❌ ERROR:", err.message);
}

console.log("\n=== Tests Complete ===");
