import fs from "node:fs/promises";
import path from "node:path";
import {
  AREA_PREFIXES,
  DEFAULT_IGNORED_DIRS,
  DEFAULT_IGNORED_PREFIXES,
  DEFAULT_LIST_RESULTS,
  LOCKFILE_NAMES,
  MAX_LIST_RESULTS
} from "./config.js";
import { isSensitivePath, normalizeSlashes, resolveExistingProjectPath, toRepoPath } from "./security.js";

export type ProjectFile = {
  path: string;
  size: number;
  extension: string;
  modifiedTime: string;
};

export type WalkOptions = {
  includeIgnored?: boolean;
  includeLockfiles?: boolean;
  includeSensitive?: boolean;
  maxResults?: number;
};

export function clampListResults(value: unknown): number {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    return DEFAULT_LIST_RESULTS;
  }
  return Math.max(1, Math.min(Math.trunc(value), MAX_LIST_RESULTS));
}

export function isIgnoredRepoPath(repoPath: string, options: WalkOptions = {}): boolean {
  const normalized = normalizeSlashes(repoPath);
  const segments = normalized.split("/");
  if (!options.includeIgnored) {
    if (segments.some((segment) => DEFAULT_IGNORED_DIRS.has(segment))) {
      return true;
    }
    if (DEFAULT_IGNORED_PREFIXES.some((prefix) => normalized.startsWith(prefix))) {
      return true;
    }
  }
  if (!options.includeLockfiles && LOCKFILE_NAMES.has(path.posix.basename(normalized))) {
    return true;
  }
  if (!options.includeSensitive && isSensitivePath(normalized)) {
    return true;
  }
  return false;
}

export async function walkProjectFiles(root: string, options: WalkOptions = {}): Promise<ProjectFile[]> {
  const maxResults = clampListResults(options.maxResults);
  const results: ProjectFile[] = [];

  async function visit(current: string): Promise<void> {
    if (results.length >= maxResults) {
      return;
    }

    const entries = await fs.readdir(current, { withFileTypes: true });
    entries.sort((left, right) => left.name.localeCompare(right.name));

    for (const entry of entries) {
      if (results.length >= maxResults) {
        return;
      }

      const absolute = path.join(current, entry.name);
      const repoPath = toRepoPath(path.relative(root, absolute));
      if (isIgnoredRepoPath(repoPath, options)) {
        continue;
      }

      if (entry.isDirectory()) {
        await visit(absolute);
      } else if (entry.isFile()) {
        const stat = await fs.stat(absolute);
        results.push({
          path: repoPath,
          size: stat.size,
          extension: path.extname(entry.name).toLowerCase(),
          modifiedTime: stat.mtime.toISOString()
        });
      }
    }
  }

  await visit(root);
  return results;
}

export function matchesArea(repoPath: string, area = "all"): boolean {
  const normalizedArea = area.trim().toLowerCase();
  const prefixes = AREA_PREFIXES[normalizedArea] ?? AREA_PREFIXES[normalizedArea.replace(/\s+/g, "_")];
  if (!prefixes || normalizedArea === "all") {
    return true;
  }
  const normalizedPath = normalizeSlashes(repoPath);
  return prefixes.some((prefix) => normalizedPath.startsWith(prefix));
}

export async function listProjectFiles(root: string, input: Record<string, unknown> = {}): Promise<{
  area: string;
  files: ProjectFile[];
  ignoredByDefault: string[];
}> {
  const area = typeof input.area === "string" ? input.area : "all";
  const maxResults = clampListResults(input.maxResults);
  const options: WalkOptions = {
    includeIgnored: input.includeIgnored === true,
    includeLockfiles: input.includeLockfiles === true,
    maxResults: MAX_LIST_RESULTS
  };

  const files = (await walkProjectFiles(root, options))
    .filter((file) => matchesArea(file.path, area))
    .slice(0, maxResults);
  return {
    area,
    files,
    ignoredByDefault: Array.from(DEFAULT_IGNORED_DIRS).concat(DEFAULT_IGNORED_PREFIXES)
  };
}

export async function safeReadProjectFiles(root: string, input: Record<string, unknown>): Promise<{
  files: Array<{
    path: string;
    size: number;
    bytesRead?: number;
    truncated?: boolean;
    content?: string;
    skipped?: string;
  }>;
}> {
  const requested = Array.isArray(input.paths) ? input.paths : [];
  const maxBytes = typeof input.maxBytesPerFile === "number" ? Number(input.maxBytesPerFile) : undefined;
  const { clampFileBytes, isTextLikePath, readTextFileLimited } = await import("./security.js");
  const limit = clampFileBytes(maxBytes);
  const files = [];

  for (const rawPath of requested.slice(0, 20)) {
    if (typeof rawPath !== "string") {
      continue;
    }

    try {
      const absolute = await resolveExistingProjectPath(root, rawPath);
      const repoPath = toRepoPath(path.relative(root, absolute));
      const stat = await fs.stat(absolute);
      if (isSensitivePath(repoPath)) {
        files.push({ path: repoPath, size: stat.size, skipped: "sensitive_path" });
        continue;
      }
      if (!isTextLikePath(absolute)) {
        files.push({ path: repoPath, size: stat.size, skipped: "non_text_file" });
        continue;
      }
      const read = await readTextFileLimited(absolute, limit);
      files.push({
        path: repoPath,
        size: stat.size,
        bytesRead: read.bytesRead,
        truncated: read.truncated,
        content: read.text
      });
    } catch (error) {
      files.push({
        path: rawPath,
        size: 0,
        skipped: error instanceof Error ? error.message : "read_error"
      });
    }
  }

  return { files };
}

export async function resolveDirectoryFilters(root: string, directories: unknown): Promise<string[]> {
  if (!Array.isArray(directories)) {
    return [];
  }
  const prefixes: string[] = [];
  for (const directory of directories.slice(0, 20)) {
    if (typeof directory !== "string" || !directory.trim()) {
      continue;
    }
    const absolute = await resolveExistingProjectPath(root, directory);
    const stat = await fs.stat(absolute);
    if (stat.isDirectory()) {
      const repoPath = toRepoPath(path.relative(root, absolute));
      prefixes.push(repoPath === "" ? "" : `${repoPath}/`);
    }
  }
  return prefixes;
}
