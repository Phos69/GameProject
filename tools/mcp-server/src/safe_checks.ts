import { spawn } from "node:child_process";
import path from "node:path";
import { OUTPUT_LIMIT_BYTES } from "./config.js";

export type SafeCheckSpec = {
  name: string;
  description: string;
  defaultTimeoutMs: number;
  buildCommand: (root: string, input: Record<string, unknown>) => { command: string; args: string[]; env?: Record<string, string> };
};

const GUT_AREAS = new Set([
  "_sanity",
  "assets",
  "balance",
  "combat",
  "enemies",
  "environment",
  "modes",
  "obstacles",
  "progression",
  "ui_audio",
  "world_gen"
]);

function npmCommand(): string {
  return process.platform === "win32" ? "npm.cmd" : "npm";
}

function powershellCommand(): string {
  return process.platform === "win32" ? "powershell.exe" : "pwsh";
}

function gutCommand(
  root: string,
  windowsArgs: string[],
  bashArgs: string[] = []
): { command: string; args: string[]; env?: Record<string, string> } {
  if (process.platform === "win32") {
    return {
      command: powershellCommand(),
      args: ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", path.join(root, "tools/run_gut.ps1"), ...windowsArgs]
    };
  }
  return {
    command: "bash",
    args: [path.join(root, "tools/run_gut.sh"), ...bashArgs],
    env: { SKIP_IMPORT: "1" }
  };
}

export const SAFE_CHECKS: Record<string, SafeCheckSpec> = {
  "gut:quick": {
    name: "gut:quick",
    description: "Run the default fast GUT suite with import skipped.",
    defaultTimeoutMs: 180_000,
    buildCommand: (root) => gutCommand(root, ["-SkipImport"])
  },
  "gut:golden": {
    name: "gut:golden",
    description: "Run the golden GUT suite with import skipped.",
    defaultTimeoutMs: 180_000,
    buildCommand: (root) => gutCommand(root, ["-SkipImport", "-Golden"], ["--golden"])
  },
  "gut:area": {
    name: "gut:area",
    description: "Run one allowlisted GUT area under tests/suites.",
    defaultTimeoutMs: 120_000,
    buildCommand: (root, input) => {
      const area = typeof input.area === "string" ? input.area : "";
      if (!GUT_AREAS.has(area)) {
        throw new Error(`Unsupported GUT area '${area}'. Allowed: ${[...GUT_AREAS].join(", ")}`);
      }
      return gutCommand(root, ["-SkipImport", "-GutDir", `res://tests/suites/${area}`], [`-gdir=res://tests/suites/${area}`]);
    }
  },
  "godot:import": {
    name: "godot:import",
    description: "Run Godot headless import for local cache regeneration.",
    defaultTimeoutMs: 120_000,
    buildCommand: () => ({ command: process.env.GODOT || "godot", args: ["--headless", "--path", ".", "--import"] })
  },
  "asset:check": {
    name: "asset:check",
    description: "Run the isometric environment asset generator in check mode.",
    defaultTimeoutMs: 120_000,
    buildCommand: () => ({
      command: process.env.GODOT || "godot",
      args: ["--headless", "--path", ".", "--script", "res://tools/generate_isometric_environment_assets.gd", "--", "--check"]
    })
  },
  "mcp:build": {
    name: "mcp:build",
    description: "Compile the MCP server TypeScript package.",
    defaultTimeoutMs: 60_000,
    buildCommand: () => ({ command: npmCommand(), args: ["--prefix", "tools/mcp-server", "run", "build"] })
  },
  "mcp:test": {
    name: "mcp:test",
    description: "Run the MCP server Vitest suite.",
    defaultTimeoutMs: 60_000,
    buildCommand: () => ({ command: npmCommand(), args: ["--prefix", "tools/mcp-server", "run", "test"] })
  },
  "mcp:smoke": {
    name: "mcp:smoke",
    description: "Build the MCP server and verify tools/prompts can be listed over stdio.",
    defaultTimeoutMs: 60_000,
    buildCommand: () => ({ command: npmCommand(), args: ["--prefix", "tools/mcp-server", "run", "smoke"] })
  }
};

export function listSafeChecks(): Array<{ name: string; description: string; defaultTimeoutMs: number }> {
  return Object.values(SAFE_CHECKS).map(({ name, description, defaultTimeoutMs }) => ({
    name,
    description,
    defaultTimeoutMs
  }));
}

export function buildSafeCheckCommand(root: string, input: Record<string, unknown>): {
  name: string;
  command: string;
  args: string[];
  env?: Record<string, string>;
  timeoutMs: number;
} {
  const check = typeof input.check === "string" ? input.check : "";
  const spec = SAFE_CHECKS[check];
  if (!spec) {
    throw new Error(`Unsupported safe check '${check}'. Use one of: ${Object.keys(SAFE_CHECKS).join(", ")}`);
  }
  const requestedTimeout = typeof input.timeoutMs === "number" && Number.isFinite(input.timeoutMs)
    ? Math.trunc(input.timeoutMs)
    : spec.defaultTimeoutMs;
  const timeoutMs = Math.max(1_000, Math.min(requestedTimeout, Math.max(spec.defaultTimeoutMs, 240_000)));
  const command = spec.buildCommand(root, input);
  return {
    name: check,
    command: command.command,
    args: command.args,
    env: command.env,
    timeoutMs
  };
}

function appendLimited(current: string, chunk: Buffer): string {
  if (current.length >= OUTPUT_LIMIT_BYTES) {
    return current;
  }
  const next = current + chunk.toString("utf8");
  if (next.length <= OUTPUT_LIMIT_BYTES) {
    return next;
  }
  return `${next.slice(0, OUTPUT_LIMIT_BYTES)}\n[output truncated]`;
}

export async function runSafeCheck(root: string, input: Record<string, unknown>): Promise<Record<string, unknown>> {
  const prepared = buildSafeCheckCommand(root, input);
  const startedAt = Date.now();

  return await new Promise((resolve) => {
    let stdout = "";
    let stderr = "";
    let timedOut = false;
    const child = spawn(prepared.command, prepared.args, {
      cwd: root,
      shell: false,
      env: { ...process.env, ...(prepared.env ?? {}) }
    });

    const timeout = setTimeout(() => {
      timedOut = true;
      child.kill("SIGTERM");
    }, prepared.timeoutMs);

    child.stdout.on("data", (chunk: Buffer) => {
      stdout = appendLimited(stdout, chunk);
    });
    child.stderr.on("data", (chunk: Buffer) => {
      stderr = appendLimited(stderr, chunk);
    });
    child.on("error", (error) => {
      clearTimeout(timeout);
      resolve({
        check: prepared.name,
        command: prepared.command,
        args: prepared.args,
        exitCode: null,
        timedOut,
        durationMs: Date.now() - startedAt,
        stdout,
        stderr: `${stderr}\n${error.message}`.trim()
      });
    });
    child.on("close", (code) => {
      clearTimeout(timeout);
      resolve({
        check: prepared.name,
        command: prepared.command,
        args: prepared.args,
        exitCode: code,
        timedOut,
        durationMs: Date.now() - startedAt,
        stdout,
        stderr
      });
    });
  });
}
