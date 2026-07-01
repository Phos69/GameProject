import path from "node:path";
import { fileURLToPath } from "node:url";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";

const here = path.dirname(fileURLToPath(import.meta.url));
const serverPath = path.resolve(here, "../src/server.js");
const packageRoot = path.resolve(here, "../..");

const transport = new StdioClientTransport({
  command: process.execPath,
  args: [serverPath],
  cwd: packageRoot
});

const client = new Client({
  name: "gameproject-mcp-smoke",
  version: "0.1.0"
});

try {
  await client.connect(transport);
  const tools = await client.listTools();
  const prompts = await client.listPrompts();
  console.log(JSON.stringify({
    toolCount: tools.tools.length,
    tools: tools.tools.map((tool) => tool.name),
    promptCount: prompts.prompts.length,
    prompts: prompts.prompts.map((prompt) => prompt.name)
  }, null, 2));
  if (tools.tools.length < 9) {
    throw new Error(`Expected at least 9 tools, got ${tools.tools.length}.`);
  }
  await client.close();
} catch (error) {
  await client.close().catch(() => undefined);
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
}
