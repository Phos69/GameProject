import path from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { buildSafeCheckCommand, listSafeChecks, runSafeCheck } from "../src/safe_checks.js";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../..");

describe("safe check allowlist", () => {
  it("lists only named checks", () => {
    const checks = listSafeChecks().map((check) => check.name);
    expect(checks).toContain("mcp:test");
    expect(checks).toContain("gut:area");
    expect(checks).not.toContain("shell");
  });

  it("rejects arbitrary commands", () => {
    expect(() => buildSafeCheckCommand(root, { check: "rm -rf ." })).toThrow(/Unsupported safe check/);
  });

  it("validates GUT area names", () => {
    expect(() => buildSafeCheckCommand(root, { check: "gut:area", area: "../game" })).toThrow(/Unsupported GUT area/);
    const prepared = buildSafeCheckCommand(root, { check: "gut:area", area: "combat" });
    expect(prepared.args.join(" ")).toContain("res://tests/suites/combat");
  });

  it("uses the top-down asset contract check", () => {
    const prepared = buildSafeCheckCommand(root, { check: "asset:check" });
    expect(prepared.args.join(" ")).toContain("res://tools/generate_top_down_environment_assets.gd");
  });

  it("runs the MCP build without spawning npm.cmd directly", async () => {
    const result = await runSafeCheck(root, { check: "mcp:build", timeoutMs: 60_000 });
    expect(result.exitCode, String(result.stderr ?? "")).toBe(0);
  }, 70_000);
});
