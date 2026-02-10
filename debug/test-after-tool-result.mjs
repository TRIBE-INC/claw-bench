#!/usr/bin/env node
/**
 * Critical test: Response after tool result
 * This is where Kimi K2.5 fails on Bedrock
 */

import { BedrockRuntimeClient, ConverseStreamCommand } from "@aws-sdk/client-bedrock-runtime";

const modelId = process.argv[2] || "moonshotai.kimi-k2.5";
const client = new BedrockRuntimeClient({ region: "us-east-1" });

console.log("=== CRITICAL TEST: Response After Tool Result ===");
console.log(`Model: ${modelId}\n`);

const command = new ConverseStreamCommand({
  modelId,
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
          content: [{ text: JSON.stringify({ temperature: 22, conditions: "sunny", humidity: 60 }) }],
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
  console.log("Sending request with tool result...\n");
  const response = await client.send(command);

  let textContent = "";
  let eventCount = 0;
  let contentEvents = 0;
  let stopReason = null;

  console.log("--- Raw Events ---\n");

  for await (const event of response.stream) {
    eventCount++;
    console.log(`Event ${eventCount}:`, JSON.stringify(event, null, 2));

    if (event.contentBlockDelta?.delta?.text) {
      textContent += event.contentBlockDelta.delta.text;
      contentEvents++;
    }
    if (event.messageStop?.stopReason) {
      stopReason = event.messageStop.stopReason;
    }
  }

  console.log("\n--- RESULT ---");
  console.log("Text content:", textContent || "(EMPTY - THIS IS THE BUG!)");
  console.log("Stop reason:", stopReason);
  console.log("Total events:", eventCount);
  console.log("Content events with text:", contentEvents);

  if (textContent.trim() === "") {
    console.log("\n❌ BUG CONFIRMED: Model returns EMPTY content after tool result!");
    console.log("   The model received the tool result but produced no text response.");
  } else {
    console.log("\n✅ Model correctly returned content after tool result");
  }

} catch (error) {
  console.error("ERROR:", error.message);
  console.error(error.stack);
}
