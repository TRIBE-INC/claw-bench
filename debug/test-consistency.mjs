#!/usr/bin/env node
/**
 * Test consistency of Kimi responses after tool results
 * Runs the same test multiple times to detect intermittent failures
 */

import { BedrockRuntimeClient, ConverseStreamCommand } from "@aws-sdk/client-bedrock-runtime";

const client = new BedrockRuntimeClient({ region: "us-east-1" });

async function testToolResult(testNum) {
  const command = new ConverseStreamCommand({
    modelId: process.argv[2] || "moonshotai.kimi-k2.5",
    messages: [
      { role: "user", content: [{ text: "Weather for Tokyo?" }] },
      { role: "assistant", content: [{ text: "Getting it." }, { toolUse: { toolUseId: "abc123xyz", name: "get_weather", input: { city: "Tokyo" } } }] },
      { role: "user", content: [{ toolResult: { toolUseId: "abc123xyz", content: [{ text: '{"temp":22}' }], status: "success" } }] }
    ],
    toolConfig: { tools: [{ toolSpec: { name: "get_weather", description: "Get weather", inputSchema: { json: { type: "object", properties: { city: { type: "string" } } } } } }] },
    inferenceConfig: { maxTokens: 100 }
  });

  return new Promise(async (resolve) => {
    const timeout = setTimeout(() => resolve({ status: "TIMEOUT", text: "" }), 15000);

    try {
      const response = await client.send(command);
      let text = "";
      let stopReason = "";

      for await (const e of response.stream) {
        if (e.contentBlockDelta?.delta?.text) text += e.contentBlockDelta.delta.text;
        if (e.messageStop?.stopReason) stopReason = e.messageStop.stopReason;
      }

      clearTimeout(timeout);
      resolve({ status: text.trim() ? "OK" : "EMPTY", text: text.substring(0, 40), stopReason });
    } catch (error) {
      clearTimeout(timeout);
      resolve({ status: "ERROR", error: error.message.substring(0, 50) });
    }
  });
}

console.log("=== Kimi K2.5 Consistency Test ===\n");
console.log("Running 10 identical requests to check for intermittent failures...\n");

let passed = 0;
let failed = 0;

for (let i = 1; i <= 10; i++) {
  const result = await testToolResult(i);
  const icon = result.status === "OK" ? "✅" : "❌";
  console.log(`Test ${i.toString().padStart(2)}: ${icon} ${result.status.padEnd(7)} ${result.text || result.error || ""}`);

  if (result.status === "OK") passed++;
  else failed++;

  // Small delay between requests
  await new Promise(r => setTimeout(r, 500));
}

console.log(`\n=== Summary ===`);
console.log(`Passed: ${passed}/10`);
console.log(`Failed: ${failed}/10`);

if (failed > 0) {
  console.log(`\n⚠️ INTERMITTENT FAILURES DETECTED`);
  console.log(`   This confirms unreliable behavior with tool results on Bedrock`);
} else {
  console.log(`\n✅ All tests passed - behavior appears stable`);
}
