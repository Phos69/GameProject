import path from "node:path";
import { fileURLToPath } from "node:url";
import { beforeEach, describe, expect, it } from "vitest";
import {
  clearProjectFileIndexCache,
  listProjectFiles,
  safeReadProjectFiles
} from "../src/file_index.js";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../..");

describe("project file index", () => {
  beforeEach(() => clearProjectFileIndexCache());

  it("filters before pagination and returns compact pages", async () => {
    const first = await listProjectFiles(root, { area: "config", pageSize: 2 });
    expect(first.files).toHaveLength(2);
    expect(first.files.every((file) => Object.keys(file).join(",") === "path")).toBe(true);
    expect(first.hasMore).toBe(true);
    expect(first.nextCursor).toBe("2");

    const second = await listProjectFiles(root, { area: "config", pageSize: 2, cursor: first.nextCursor });
    expect(second.files).toHaveLength(2);
    expect(second.cache.hit).toBe(true);
  });

  it("rejects unknown areas instead of listing the entire repository", async () => {
    await expect(listProjectFiles(root, { area: "typo" })).rejects.toThrow(/Unsupported project area/);
  });

  it("reads bounded line windows with aggregate metadata", async () => {
    const result = await safeReadProjectFiles(root, {
      paths: ["README.md"],
      aroundLine: 1,
      contextLines: 2,
      maxTotalBytes: 2_000
    });
    expect(result.files[0].startLine).toBe(1);
    expect(result.files[0].endLine).toBe(3);
    expect(result.files[0].content).toContain("Local Action Sandbox");
    expect(result.totalBytesRead).toBeGreaterThan(0);
  });
});
