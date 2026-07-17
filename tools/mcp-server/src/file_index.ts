import fs from "node:fs/promises";
import path from "node:path";
import {
  AREA_PREFIXES,
  DEFAULT_READ_TOTAL_BYTES,
  FILE_INDEX_TTL_MS,
  DEFAULT_IGNORED_DIRS,
  DEFAULT_IGNORED_PREFIXES,
  DEFAULT_LIST_RESULTS,
  LOCKFILE_NAMES,
  MAX_LIST_RESULTS,
  MAX_READ_TOTAL_BYTES
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
  refresh?: boolean;
};

type FileIndexEntry = {
  createdAt: number;
  files: ProjectFile[];
};

const fileIndexCache = new Map<string, Promise<FileIndexEntry>>();

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
  const maxResults = typeof options.maxResults === "number" && Number.isFinite(options.maxResults)
    ? Math.max(1, Math.trunc(options.maxResults))
    : Number.MAX_SAFE_INTEGER;
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

function fileIndexKey(root: string, options: WalkOptions): string {
  return JSON.stringify([
    path.resolve(root),
    options.includeIgnored === true,
    options.includeLockfiles === true,
    options.includeSensitive === true
  ]);
}

export async function getProjectFileIndex(root: string, options: WalkOptions = {}): Promise<{
  files: ProjectFile[];
  cacheHit: boolean;
  ageMs: number;
}> {
  const key = fileIndexKey(root, options);
  const existing = fileIndexCache.get(key);
  if (!options.refresh && existing) {
    const entry = await existing;
    const ageMs = Date.now() - entry.createdAt;
    if (ageMs <= FILE_INDEX_TTL_MS) {
      return { files: entry.files, cacheHit: true, ageMs };
    }
  }

  const pending = (async () => ({
    createdAt: Date.now(),
    files: await walkProjectFiles(root, { ...options, maxResults: Number.MAX_SAFE_INTEGER })
  }))();
  fileIndexCache.set(key, pending);
  try {
    const entry = await pending;
    return { files: entry.files, cacheHit: false, ageMs: 0 };
  } catch (error) {
    fileIndexCache.delete(key);
    throw error;
  }
}

export function clearProjectFileIndexCache(): void {
  fileIndexCache.clear();
}

export function matchesArea(repoPath: string, area = "all"): boolean {
  const normalizedArea = area.trim().toLowerCase();
  const prefixes = AREA_PREFIXES[normalizedArea] ?? AREA_PREFIXES[normalizedArea.replace(/\s+/g, "_")];
  if (!prefixes) {
    throw new Error(`Unsupported project area '${area}'. Use one of: ${Object.keys(AREA_PREFIXES).join(", ")}.`);
  }
  if (normalizedArea === "all") {
    return true;
  }
  const normalizedPath = normalizeSlashes(repoPath);
  return prefixes.some((prefix) => normalizedPath.startsWith(prefix));
}

export async function listProjectFiles(root: string, input: Record<string, unknown> = {}): Promise<{
  area: string;
  files: Array<ProjectFile | { path: string }>;
  totalResults: number;
  pageSize: number;
  nextCursor: string | null;
  hasMore: boolean;
  cache: { hit: boolean; ageMs: number };
  ignoredByDefault: string[];
}> {
  const area = typeof input.area === "string" ? input.area : "all";
  const pageSize = clampListResults(input.pageSize ?? input.maxResults);
  const cursor = typeof input.cursor === "string" && /^\d+$/.test(input.cursor)
    ? Number.parseInt(input.cursor, 10)
    : 0;
  const includeMetadata = input.includeMetadata === true;
  const options: WalkOptions = {
    includeIgnored: input.includeIgnored === true,
    includeLockfiles: input.includeLockfiles === true,
    refresh: input.refresh === true
  };

  // Validate before walking: unknown areas must not silently degrade to `all`.
  matchesArea("", area);
  const indexed = await getProjectFileIndex(root, options);
  const filtered = indexed.files.filter((file) => matchesArea(file.path, area));
  const page = filtered.slice(cursor, cursor + pageSize);
  const nextOffset = cursor + page.length;
  const hasMore = nextOffset < filtered.length;
  return {
    area,
    files: includeMetadata ? page : page.map((file) => ({ path: file.path })),
    totalResults: filtered.length,
    pageSize,
    nextCursor: hasMore ? String(nextOffset) : null,
    hasMore,
    cache: { hit: indexed.cacheHit, ageMs: indexed.ageMs },
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
    startLine?: number;
    endLine?: number;
    totalLines?: number;
    skipped?: string;
  }>;
  totalBytesRead: number;
  omittedPaths: number;
}> {
  const requested = Array.isArray(input.paths) ? input.paths : [];
  const maxBytes = typeof input.maxBytesPerFile === "number" ? Number(input.maxBytesPerFile) : undefined;
  const { clampFileBytes, isTextLikePath, readTextFileLimited } = await import("./security.js");
  const limit = clampFileBytes(maxBytes);
  const requestedTotal = typeof input.maxTotalBytes === "number" && Number.isFinite(input.maxTotalBytes)
    ? Math.trunc(input.maxTotalBytes)
    : DEFAULT_READ_TOTAL_BYTES;
  const totalLimit = Math.max(1_000, Math.min(requestedTotal, MAX_READ_TOTAL_BYTES));
  const startLineInput = typeof input.startLine === "number" ? Math.max(1, Math.trunc(input.startLine)) : undefined;
  const endLineInput = typeof input.endLine === "number" ? Math.max(1, Math.trunc(input.endLine)) : undefined;
  const aroundLine = typeof input.aroundLine === "number" ? Math.max(1, Math.trunc(input.aroundLine)) : undefined;
  const contextLines = typeof input.contextLines === "number"
    ? Math.max(0, Math.min(200, Math.trunc(input.contextLines)))
    : 20;
  const files = [];
  let totalBytesRead = 0;
  let processedPaths = 0;

  for (const rawPath of requested.slice(0, 20)) {
    if (totalBytesRead >= totalLimit) {
      break;
    }
    if (typeof rawPath !== "string") {
      continue;
    }
    processedPaths++;

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
      const lines = read.text.split(/\r?\n/);
      const startLine = aroundLine !== undefined
        ? Math.max(1, aroundLine - contextLines)
        : (startLineInput ?? 1);
      const endLine = aroundLine !== undefined
        ? Math.min(lines.length, aroundLine + contextLines)
        : Math.min(lines.length, endLineInput ?? lines.length);
      const selected = endLine >= startLine ? lines.slice(startLine - 1, endLine).join("\n") : "";
      const remaining = totalLimit - totalBytesRead;
      const selectedBuffer = Buffer.from(selected, "utf8");
      const contentBuffer = selectedBuffer.subarray(0, remaining);
      const content = contentBuffer.toString("utf8");
      totalBytesRead += contentBuffer.length;
      files.push({
        path: repoPath,
        size: stat.size,
        bytesRead: contentBuffer.length,
        truncated: read.truncated || contentBuffer.length < selectedBuffer.length,
        startLine,
        endLine,
        totalLines: lines.length,
        content
      });
    } catch (error) {
      files.push({
        path: rawPath,
        size: 0,
        skipped: error instanceof Error ? error.message : "read_error"
      });
    }
  }

  return { files, totalBytesRead, omittedPaths: Math.max(0, requested.length - processedPaths) };
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
