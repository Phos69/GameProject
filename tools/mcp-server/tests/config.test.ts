import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { findProjectRoot, PROJECT_ROOT_MARKER } from "../src/config.js";

const testDir = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(testDir, "../../..");

describe("project root detection", () => {
  it("locates the repo root from the built dist/src depth", () => {
    // The built server lives one level deeper than the source, so a fixed
    // number of `..` cannot work for both. Marker search must handle both.
    const builtLikePath = path.join(repoRoot, "tools", "mcp-server", "dist", "src");
    const found = findProjectRoot(builtLikePath);
    expect(found).toBe(repoRoot);
    expect(fs.existsSync(path.join(found!, PROJECT_ROOT_MARKER))).toBe(true);
  });

  it("locates the same root from the source depth", () => {
    const sourcePath = path.join(repoRoot, "tools", "mcp-server", "src");
    expect(findProjectRoot(sourcePath)).toBe(repoRoot);
  });
});
