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
  version: "0.2.0"
});

try {
  await client.connect(transport);
  const tools = await client.listTools();
  const prompts = await client.listPrompts();
  const overview = await client.callTool({ name: "repo_overview", arguments: {} });
  const search = await client.callTool({
    name: "search_project",
    arguments: { query: "class_name PlayerController", extensions: [".gd"], directories: ["game/player"], maxResults: 1 }
  });
  const blockedRead = await client.callTool({
    name: "read_project_context",
    arguments: { paths: ["../outside.txt"] }
  });
  const safeBuild = await client.callTool({
    name: "run_safe_check",
    arguments: { check: "mcp:build", timeoutMs: 60_000 }
  });
  const overviewData = overview.structuredContent as Record<string, unknown> | undefined;
  const searchData = search.structuredContent as Record<string, unknown> | undefined;
  const blockedData = blockedRead.structuredContent as { files?: Array<{ skipped?: string }> } | undefined;
  const safeBuildData = safeBuild.structuredContent as { exitCode?: number } | undefined;
  console.log(JSON.stringify({
    toolCount: tools.tools.length,
    tools: tools.tools.map((tool) => tool.name),
    promptCount: prompts.prompts.length,
    prompts: prompts.prompts.map((prompt) => prompt.name),
    checks: {
      overview: overviewData?.name,
      searchResults: searchData?.resultCount,
      traversalBlocked: blockedData?.files?.[0]?.skipped?.includes("escapes project root") ?? false,
      safeBuildExitCode: safeBuildData?.exitCode
    }
  }, null, 2));
  if (tools.tools.length < 13) {
    throw new Error(`Expected at least 13 tools, got ${tools.tools.length}.`);
  }
  if (overviewData?.name !== "Local Action Sandbox" || searchData?.resultCount !== 1) {
    throw new Error("Representative MCP context calls failed.");
  }
  if (!(blockedData?.files?.[0]?.skipped?.includes("escapes project root"))) {
    throw new Error("Traversal smoke check was not blocked.");
  }
  if (safeBuildData?.exitCode !== 0) {
    throw new Error("Allowlisted MCP build check failed over stdio.");
  }
  await client.close();
} catch (error) {
  await client.close().catch(() => undefined);
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
}
