import os from "node:os";
import fs from "node:fs/promises";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { safeReadProjectFiles } from "../src/file_index.js";
import { isSensitivePath, ProjectSecurityError, resolveProjectPath } from "../src/security.js";

describe("project path security", () => {
  it("rejects traversal outside the root", async () => {
    const root = await fs.mkdtemp(path.join(os.tmpdir(), "mcp-root-"));
    expect(() => resolveProjectPath(root, "../outside.txt")).toThrow(ProjectSecurityError);
  });

  it("marks credentials and keys as sensitive", () => {
    expect(isSensitivePath(".env")).toBe(true);
    expect(isSensitivePath("config/.env.local")).toBe(true);
    expect(isSensitivePath("keys/service.pem")).toBe(true);
    expect(isSensitivePath("game/player/player_controller.gd")).toBe(false);
  });

  it("skips sensitive files even when they are inside the root", async () => {
    const root = await fs.mkdtemp(path.join(os.tmpdir(), "mcp-root-"));
    await fs.writeFile(path.join(root, ".env"), "TOKEN=secret");
    const result = await safeReadProjectFiles(root, { paths: [".env"] });
    expect(result.files[0].skipped).toBe("sensitive_path");
    expect(result.files[0]).not.toHaveProperty("content");
  });
});
