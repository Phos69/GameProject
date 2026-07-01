import path from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { buildSafeCheckCommand, listSafeChecks } from "../src/safe_checks.js";

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
});
