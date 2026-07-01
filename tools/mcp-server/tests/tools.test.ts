import path from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { callProjectTool, TOOL_DEFINITIONS } from "../src/mcp_server.js";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../..");

function parseToolText(response: Awaited<ReturnType<typeof callProjectTool>>) {
  return JSON.parse(response.content[0].text);
}

describe("MCP tool handlers", () => {
  it("registers the required tools", () => {
    const names = TOOL_DEFINITIONS.map((tool) => tool.name);
    expect(names).toEqual(expect.arrayContaining([
      "repo_overview",
      "list_project_files",
      "read_project_context",
      "search_project",
      "game_system_summary",
      "roadmap_context",
      "run_safe_check",
      "asset_inventory",
      "codex_task_brief"
    ]));
  });

  it("builds a repository overview from real files", async () => {
    const overview = parseToolText(await callProjectTool(root, "repo_overview"));
    expect(overview.stack.engine).toBe("Godot 4.x");
    expect(overview.entrypoints.mainScene).toBe("res://game/main/main.tscn");
  });

  it("reads project context safely", async () => {
    const result = parseToolText(await callProjectTool(root, "read_project_context", { paths: ["README.md"], maxBytesPerFile: 2_000 }));
    expect(result.files[0].path).toBe("README.md");
    expect(result.files[0].content).toContain("Iso Local Sandbox");
  });

  it("summarizes game systems with evidence paths", async () => {
    const summary = parseToolText(await callProjectTool(root, "game_system_summary"));
    expect(summary.systems.zombieMode.evidence.length).toBeGreaterThan(0);
    expect(summary.systems.weaponsCombat.evidence.length).toBeGreaterThan(0);
  });

  it("creates a task brief from a textual goal", async () => {
    const brief = parseToolText(await callProjectTool(root, "codex_task_brief", { goal: "Improve zombie spawn balance near hazards" }));
    expect(brief.impactedSystems).toContain("zombie survival");
    expect(brief.recommendedTests.length).toBeGreaterThan(0);
  });
});
