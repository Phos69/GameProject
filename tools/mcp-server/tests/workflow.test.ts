import path from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { analyzeChangedFiles, changedContext, readSymbolContext } from "../src/workflow.js";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../..");

describe("workflow tools", () => {
  it("maps MCP changes to checks and documentation", () => {
    const result = analyzeChangedFiles(["tools/mcp-server/src/workflow.ts"]);
    expect(result.impactedSystems).toContain("MCP tooling");
    expect(result.recommendedChecks).toContain("mcp:test");
    expect(result.documentationToReview).toContain("CHANGELOG.md");
  });

  it("returns a stable current-worktree envelope", async () => {
    const result = await changedContext(root);
    expect(result).toHaveProperty("clean");
    expect(result).toHaveProperty("changedFiles");
    expect(result).toHaveProperty("workflowNotes");
  });

  it("returns source context around a GDScript declaration", async () => {
    const result = await readSymbolContext(root, {
      query: "PlayerController",
      kind: ["class_name"],
      exact: true,
      maxResults: 1,
      contextLines: 3
    });
    expect(result.resultCount).toBe(1);
    const first = (result.results as Array<{ context: { content?: string } }>)[0];
    expect(first.context.content).toContain("class_name PlayerController");
  });
});
