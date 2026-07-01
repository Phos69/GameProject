import path from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { searchProject } from "../src/search.js";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../..");

describe("search_project", () => {
  it("returns literal matches with result limits", async () => {
    const result = await searchProject(root, {
      query: "class_name PlayerController",
      extensions: [".gd"],
      directories: ["game/player"],
      maxResults: 1
    });

    expect(result.resultCount).toBeLessThanOrEqual(1);
    expect(result.results[0]?.path).toBe("game/player/player_controller.gd");
  });

  it("respects file size limits", async () => {
    const result = await searchProject(root, {
      query: "Milestone",
      extensions: [".md"],
      maxFileBytes: 1_000,
      maxResults: 5
    });

    expect(result.skippedLargeFiles).toBeGreaterThan(0);
    expect(result.resultCount).toBeLessThanOrEqual(5);
  });
});
