import fs from "node:fs/promises";
import path from "node:path";
import {
  DEFAULT_MAX_FILE_BYTES,
  DEFAULT_SEARCH_RESULTS,
  MAX_FILE_BYTES_CAP,
  MAX_SEARCH_RESULTS
} from "./config.js";
import { resolveDirectoryFilters, walkProjectFiles } from "./file_index.js";
import { isTextLikePath, readTextFileLimited } from "./security.js";

export type SearchResult = {
  path: string;
  line: number;
  column: number;
  preview: string;
};

function normalizeExtension(extension: string): string {
  return extension.startsWith(".") ? extension.toLowerCase() : `.${extension.toLowerCase()}`;
}

function clampSearchResults(value: unknown): number {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    return DEFAULT_SEARCH_RESULTS;
  }
  return Math.max(1, Math.min(Math.trunc(value), MAX_SEARCH_RESULTS));
}

function clampSearchFileBytes(value: unknown): number {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    return DEFAULT_MAX_FILE_BYTES;
  }
  return Math.max(1_000, Math.min(Math.trunc(value), MAX_FILE_BYTES_CAP));
}

function linePreview(line: string, column: number): string {
  const start = Math.max(0, column - 90);
  const end = Math.min(line.length, column + 210);
  return line.slice(start, end).trim();
}

export async function searchProject(root: string, input: Record<string, unknown>): Promise<{
  query: string;
  resultCount: number;
  truncated: boolean;
  searchedFiles: number;
  skippedLargeFiles: number;
  results: SearchResult[];
}> {
  const query = typeof input.query === "string" ? input.query : "";
  if (!query.trim()) {
    throw new Error("search_project requires a non-empty query.");
  }
  if (query.length > 500) {
    throw new Error("search_project query is too long.");
  }

  const maxResults = clampSearchResults(input.maxResults);
  const maxFileBytes = clampSearchFileBytes(input.maxFileBytes);
  const caseSensitive = input.caseSensitive === true;
  const extensions = Array.isArray(input.extensions)
    ? new Set(input.extensions.filter((item): item is string => typeof item === "string").map(normalizeExtension))
    : undefined;
  const directoryPrefixes = await resolveDirectoryFilters(root, input.directories);

  const files = await walkProjectFiles(root, { maxResults: 10_000 });
  const needle = caseSensitive ? query : query.toLowerCase();
  const results: SearchResult[] = [];
  let searchedFiles = 0;
  let skippedLargeFiles = 0;

  for (const file of files) {
    if (results.length >= maxResults) {
      break;
    }
    if (extensions && !extensions.has(file.extension)) {
      continue;
    }
    if (directoryPrefixes.length > 0 && !directoryPrefixes.some((prefix) => file.path.startsWith(prefix))) {
      continue;
    }
    if (!isTextLikePath(file.path)) {
      continue;
    }

    const absolute = path.join(root, file.path);
    const stat = await fs.stat(absolute);
    if (stat.size > maxFileBytes) {
      skippedLargeFiles++;
      continue;
    }

    searchedFiles++;
    const { text } = await readTextFileLimited(absolute, maxFileBytes);
    const lines = text.split(/\r?\n/);
    for (let index = 0; index < lines.length; index++) {
      const haystack = caseSensitive ? lines[index] : lines[index].toLowerCase();
      const column = haystack.indexOf(needle);
      if (column === -1) {
        continue;
      }
      results.push({
        path: file.path,
        line: index + 1,
        column: column + 1,
        preview: linePreview(lines[index], column)
      });
      if (results.length >= maxResults) {
        break;
      }
    }
  }

  return {
    query,
    resultCount: results.length,
    truncated: results.length >= maxResults,
    searchedFiles,
    skippedLargeFiles,
    results
  };
}
