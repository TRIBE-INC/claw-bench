#!/usr/bin/env node
/**
 * Test different toolUseId formats across models
 * This explores whether tool ID format causes issues
 */

import { BedrockRuntimeClient, ConverseStreamCommand } from "@aws-sdk/client-bedrock-runtime";

const client = new BedrockRuntimeClient({ region: "us-east-1" });

const models = [
  { id: "moonshotai.kimi-k2.5", name: "Kimi K2.5" },
  { id: "mistral.mistral-large-3-675b-instruct", name: "Mistral Large 3" }
];

const toolIdFormats = [
  { id: "tooluse_Vs4mS4NvbGY6Drf2RqzSNy", name: "Bedrock native format" },
  { id: "abc123xyz", name: "9-char alphanumeric (Mistral format)" },
  { id: "call_12345678", name: "OpenAI format" },
  { id: "tool-001", name: "Simple hyphenated" }
];

async function testToolIdFormat(modelId, toolUseId) {
  const command = new ConverseStreamCommand({
    modelId,
    messages: [
      { role: "user", content: [{ text: "Get weather for Tokyo" }] },
      {
        role: "assistant",
        content: [
          { text: "I'll check the weather." },
          { toolUse: { toolUseId, name: "get_weather", input: { city: "Tokyo" } } }
        ]
      },
      {
        role: "user",
        content: [{
          toolResult: {
            toolUseId,
            content: [{ text: '{"temp": 22, "conditions": "sunny"}' }],
            status: "success"
          }
        }]
      }
    ],
    toolConfig: {
      tools: [{
        toolSpec: {
          name: "get_weather",
          description: "Get weather",
          inputSchema: { json: { type: "object", properties: { city: { type: "string" } }, required: ["city"] } }
        }
      }]
    },
    inferenceConfig: { maxTokens: 100 }
  });

  return new Promise(async (resolve) => {
    const timeout = setTimeout(() => resolve({ status: "TIMEOUT", text: "" }), 15000);

    try {
      const response = await client.send(command);
      let text = "";
      let stopReason = null;

      for await (const event of response.stream) {
        if (event.contentBlockDelta?.delta?.text) {
          text += event.contentBlockDelta.delta.text;
        }
        if (event.messageStop?.stopReason) {
          stopReason = event.messageStop.stopReason;
        }
      }

      clearTimeout(timeout);
      resolve({ status: text.trim() ? "OK" : "EMPTY", text: text.substring(0, 50), stopReason });
    } catch (error) {
      clearTimeout(timeout);
      resolve({ status: "ERROR", error: error.message.substring(0, 80) });
    }
  });
}

console.log("=== Tool ID Format Compatibility Test ===\n");

for (const model of models) {
  console.log(`\n--- ${model.name} (${model.id}) ---\n`);

  for (const format of toolIdFormats) {
    const result = await testToolIdFormat(model.id, format.id);
    const status = result.status === "OK" ? "✅" : result.status === "TIMEOUT" ? "⏱️" : "❌";
    console.log(`${status} ${format.name}: ${result.status}`);
    if (result.error) console.log(`   Error: ${result.error}`);
    if (result.text) console.log(`   Response: "${result.text}..."`);
  }
}
