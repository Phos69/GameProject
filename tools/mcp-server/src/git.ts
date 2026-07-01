import { spawn } from "node:child_process";
import path from "node:path";
import { OUTPUT_LIMIT_BYTES } from "./config.js";
import { resolveExistingProjectPath, toRepoPath } from "./security.js";

// Read-only git inspection. Only allowlisted subcommands are ever invoked and
// the process is spawned with `shell: false`, so user input can never become a
// shell command or an extra git flag.
const GIT_TIMEOUT_MS = 15_000;
const DEFAULT_LOG_COUNT = 20;
const MAX_LOG_COUNT = 100;

export type GitCommandResult = {
  command: string;
  args: string[];
  exitCode: number | null;
  timedOut: boolean;
  durationMs: number;
  stdout: string;
  stderr: string;
};

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

function gitCommand(): string {
  return process.platform === "win32" ? "git.exe" : "git";
}

function clampLogCount(value: unknown): number {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    return DEFAULT_LOG_COUNT;
  }
  return Math.max(1, Math.min(Math.trunc(value), MAX_LOG_COUNT));
}

// Validate an optional pathspec: must resolve inside the repo and must not be
// interpretable as an option. Callers always place it after a `--` separator.
async function resolvePathspec(root: string, value: unknown): Promise<string | undefined> {
  if (typeof value !== "string" || !value.trim()) {
    return undefined;
  }
  const trimmed = value.trim();
  if (trimmed.startsWith("-")) {
    throw new Error(`Invalid git path '${trimmed}'.`);
  }
  const absolute = await resolveExistingProjectPath(root, trimmed);
  const repoPath = toRepoPath(path.relative(root, absolute));
  return repoPath === "" ? undefined : repoPath;
}

async function runGit(root: string, args: string[]): Promise<GitCommandResult> {
  const startedAt = Date.now();
  const command = gitCommand();

  return await new Promise((resolve) => {
    let stdout = "";
    let stderr = "";
    let timedOut = false;
    const child = spawn(command, args, { cwd: root, shell: false });

    const timeout = setTimeout(() => {
      timedOut = true;
      child.kill("SIGTERM");
    }, GIT_TIMEOUT_MS);

    child.stdout.on("data", (chunk: Buffer) => {
      stdout = appendLimited(stdout, chunk);
    });
    child.stderr.on("data", (chunk: Buffer) => {
      stderr = appendLimited(stderr, chunk);
    });
    child.on("error", (error) => {
      clearTimeout(timeout);
      resolve({
        command,
        args,
        exitCode: null,
        timedOut,
        durationMs: Date.now() - startedAt,
        stdout,
        stderr: `${stderr}\n${error.message}`.trim()
      });
    });
    child.on("close", (code) => {
      clearTimeout(timeout);
      resolve({ command, args, exitCode: code, timedOut, durationMs: Date.now() - startedAt, stdout, stderr });
    });
  });
}

export async function gitContext(root: string, input: Record<string, unknown> = {}): Promise<Record<string, unknown>> {
  const command = typeof input.command === "string" ? input.command : "";

  switch (command) {
    case "status": {
      // Porcelain output is stable and locale-independent (unlike plain status).
      const result = await runGit(root, ["status", "--porcelain=v1", "--branch"]);
      return { command, ...result };
    }
    case "log": {
      const maxCount = clampLogCount(input.maxCount);
      const pathspec = await resolvePathspec(root, input.path);
      const args = [
        "log",
        `--max-count=${maxCount}`,
        "--no-color",
        "--date=short",
        "--pretty=format:%h%x09%ad%x09%an%x09%s"
      ];
      if (pathspec) {
        args.push("--", pathspec);
      }
      const result = await runGit(root, args);
      return { command, maxCount, path: pathspec ?? null, ...result };
    }
    case "diff": {
      const staged = input.staged === true;
      const pathspec = await resolvePathspec(root, input.path);
      const args = ["diff", "--no-color"];
      if (staged) {
        args.push("--cached");
      }
      if (pathspec) {
        args.push("--", pathspec);
      }
      const result = await runGit(root, args);
      return { command, staged, path: pathspec ?? null, ...result };
    }
    default:
      throw new Error(`Unsupported git command '${command}'. Use one of: status, log, diff.`);
  }
}
