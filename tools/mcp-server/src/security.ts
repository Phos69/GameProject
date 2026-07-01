import fs from "node:fs/promises";
import path from "node:path";
import { DEFAULT_MAX_FILE_BYTES, MAX_FILE_BYTES_CAP, TEXT_EXTENSIONS } from "./config.js";

export class ProjectSecurityError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ProjectSecurityError";
  }
}

export function toRepoPath(filePath: string): string {
  return filePath.split(path.sep).join("/");
}

export function normalizeSlashes(value: string): string {
  return value.replace(/\\/g, "/");
}

export function normalizeRequestedPath(requestedPath: string): string {
  const trimmed = requestedPath.trim();
  if (!trimmed) {
    throw new ProjectSecurityError("Path is required.");
  }
  if (trimmed.startsWith("res://")) {
    return normalizeSlashes(trimmed.slice("res://".length));
  }
  return trimmed;
}

export function isInsidePath(root: string, candidate: string): boolean {
  const relative = path.relative(root, candidate);
  return relative === "" || (!relative.startsWith("..") && !path.isAbsolute(relative));
}

export function isSensitivePath(repoPath: string): boolean {
  const normalized = normalizeSlashes(repoPath).toLowerCase();
  const base = path.posix.basename(normalized);
  if (base === ".env" || base.startsWith(".env.")) {
    return true;
  }
  if (
    base === ".npmrc" ||
    base === ".pypirc" ||
    base === "auth.json" ||
    base === "credentials.json" ||
    base === "id_rsa" ||
    base === "id_dsa" ||
    base === "id_ecdsa" ||
    base === "id_ed25519"
  ) {
    return true;
  }
  if (/\.(key|pem|p12|pfx|asc|gpg)$/i.test(base)) {
    return true;
  }
  if (/(^|[/_.-])(secret|secrets|token|tokens|credential|credentials)([/_.-]|$)/i.test(normalized)) {
    return true;
  }
  return false;
}

export function resolveProjectPath(root: string, requestedPath: string): string {
  const normalized = normalizeRequestedPath(requestedPath);
  const candidate = path.isAbsolute(normalized) ? path.resolve(normalized) : path.resolve(root, normalized);
  if (!isInsidePath(root, candidate)) {
    throw new ProjectSecurityError(`Path escapes project root: ${requestedPath}`);
  }
  return candidate;
}

export async function resolveExistingProjectPath(root: string, requestedPath: string): Promise<string> {
  const candidate = resolveProjectPath(root, requestedPath);
  const realRoot = await fs.realpath(root);
  const realCandidate = await fs.realpath(candidate);
  if (!isInsidePath(realRoot, realCandidate)) {
    throw new ProjectSecurityError(`Resolved path escapes project root: ${requestedPath}`);
  }
  return realCandidate;
}

export function isTextLikePath(filePath: string): boolean {
  return TEXT_EXTENSIONS.has(path.extname(filePath).toLowerCase());
}

export function clampFileBytes(value: unknown): number {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    return DEFAULT_MAX_FILE_BYTES;
  }
  return Math.max(1_000, Math.min(Math.trunc(value), MAX_FILE_BYTES_CAP));
}

export async function readTextFileLimited(filePath: string, maxBytes = DEFAULT_MAX_FILE_BYTES): Promise<{
  text: string;
  bytesRead: number;
  truncated: boolean;
}> {
  const stat = await fs.stat(filePath);
  const limit = Math.min(maxBytes, MAX_FILE_BYTES_CAP);
  const handle = await fs.open(filePath, "r");
  try {
    const length = Math.min(stat.size, limit);
    const buffer = Buffer.alloc(length);
    const { bytesRead } = await handle.read(buffer, 0, length, 0);
    return {
      text: buffer.subarray(0, bytesRead).toString("utf8"),
      bytesRead,
      truncated: stat.size > bytesRead
    };
  } finally {
    await handle.close();
  }
}
