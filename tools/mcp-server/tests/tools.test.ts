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
      "codex_task_brief",
      "git_context",
      "find_symbol"
    ]));
  });

  it("runs read-only git status without arbitrary shell", async () => {
    const status = parseToolText(await callProjectTool(root, "git_context", { command: "status" }));
    expect(status.command).toBe("status");
    // status/log/diff are the only allowed subcommands; git.exe on win32.
    expect(status.args[0]).toBe("status");
  });

  it("rejects unsupported git commands", async () => {
    const response = await callProjectTool(root, "git_context", { command: "push" });
    expect(response.isError).toBe(true);
    expect(parseToolText(response).error).toContain("Unsupported git command");
  });

  it("finds GDScript declarations by name", async () => {
    const result = parseToolText(await callProjectTool(root, "find_symbol", {
      query: "ResourceCrateSystem",
      exact: true
    }));
    expect(result.resultCount).toBeGreaterThan(0);
    const match = result.results.find((item: { kind: string }) => item.kind === "class_name");
    expect(match).toBeTruthy();
    expect(match.path).toBe("game/modes/zombie/resource_crate_system.gd");
  });

  it("filters find_symbol results by kind", async () => {
    const result = parseToolText(await callProjectTool(root, "find_symbol", {
      query: "spawn_encounter_crate",
      kind: ["func"]
    }));
    expect(result.results.every((item: { kind: string }) => item.kind === "func")).toBe(true);
    expect(result.results.some((item: { path: string }) => item.path === "game/modes/zombie/resource_crate_system.gd")).toBe(true);
  });

  it("builds a repository overview from real files", async () => {
    const overview = parseToolText(await callProjectTool(root, "repo_overview"));
    expect(overview.stack.engine).toBe("Godot 4.x");
    expect(overview.entrypoints.mainScene).toBe("res://game/main/main.tscn");
  });

  it("reads project context safely", async () => {
    const result = parseToolText(await callProjectTool(root, "read_project_context", { paths: ["README.md"], maxBytesPerFile: 2_000 }));
    expect(result.files[0].path).toBe("README.md");
    expect(result.files[0].content).toContain("Local Action Sandbox");
  });

  it("summarizes game systems with evidence paths", async () => {
    const summary = parseToolText(await callProjectTool(root, "game_system_summary"));
    expect(summary.systems.zombieMode.evidence.length).toBeGreaterThan(0);
    expect(summary.systems.weaponsCombat.evidence.length).toBeGreaterThan(0);
    expect(summary.systems.topDownRendering.evidence.length).toBeGreaterThan(0);
  });

  it("creates a task brief from a textual goal", async () => {
    const brief = parseToolText(await callProjectTool(root, "codex_task_brief", { goal: "Improve zombie spawn balance near hazards" }));
    expect(brief.impactedSystems).toContain("zombie survival");
    expect(brief.recommendedTests.length).toBeGreaterThan(0);
  });
});
