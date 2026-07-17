import path from "node:path";
import {
  DEFAULT_MAX_FILE_BYTES,
  DEFAULT_SEARCH_RESULTS,
  MAX_FILE_BYTES_CAP,
  MAX_SEARCH_RESULTS
} from "./config.js";
import { getProjectFileIndex } from "./file_index.js";
import { readTextFileLimited } from "./security.js";

export type SymbolKind = "class_name" | "inner_class" | "extends" | "func" | "signal" | "const" | "enum";

export type SymbolMatch = {
  name: string;
  kind: SymbolKind;
  path: string;
  line: number;
  signature: string;
};

const ALL_KINDS: SymbolKind[] = ["class_name", "inner_class", "extends", "func", "signal", "const", "enum"];

// One pattern per GDScript declaration kind. All anchor on optional leading
// whitespace so nested class bodies are still recognized, and only look at
// the start of a (trimmed) line, avoiding false positives inside strings/comments.
const PATTERNS: Array<{ kind: SymbolKind; regex: RegExp }> = [
  { kind: "class_name", regex: /^class_name\s+([A-Za-z_][A-Za-z0-9_]*)/ },
  { kind: "inner_class", regex: /^class\s+([A-Za-z_][A-Za-z0-9_]*)\s+extends\s+[A-Za-z_][A-Za-z0-9_.]*\s*:/ },
  { kind: "extends", regex: /^extends\s+([A-Za-z_][A-Za-z0-9_.]*)/ },
  { kind: "func", regex: /^(?:static\s+)?func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(/ },
  { kind: "signal", regex: /^signal\s+([A-Za-z_][A-Za-z0-9_]*)/ },
  { kind: "const", regex: /^const\s+([A-Za-z_][A-Za-z0-9_]*)/ },
  { kind: "enum", regex: /^enum\s+([A-Za-z_][A-Za-z0-9_]*)/ }
];

function clampResults(value: unknown): number {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    return DEFAULT_SEARCH_RESULTS;
  }
  return Math.max(1, Math.min(Math.trunc(value), MAX_SEARCH_RESULTS));
}

function clampFileBytes(value: unknown): number {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    return DEFAULT_MAX_FILE_BYTES;
  }
  return Math.max(1_000, Math.min(Math.trunc(value), MAX_FILE_BYTES_CAP));
}

function normalizeKinds(input: unknown): SymbolKind[] {
  if (!Array.isArray(input)) {
    return ALL_KINDS;
  }
  const requested = input.filter((item): item is SymbolKind => ALL_KINDS.includes(item as SymbolKind));
  return requested.length > 0 ? requested : ALL_KINDS;
}

export async function findSymbols(root: string, input: Record<string, unknown> = {}): Promise<{
  query: string;
  kinds: SymbolKind[];
  resultCount: number;
  truncated: boolean;
  searchedFiles: number;
  cache: { hit: boolean; ageMs: number };
  results: SymbolMatch[];
}> {
  const rawQuery = typeof input.query === "string" ? input.query.trim() : "";
  if (rawQuery.length > 200) {
    throw new Error("find_symbol query is too long.");
  }
  const exact = input.exact === true;
  const kinds = new Set(normalizeKinds(input.kind));
  const maxResults = clampResults(input.maxResults);
  const maxFileBytes = clampFileBytes(input.maxFileBytes);
  const needle = rawQuery.toLowerCase();

  const indexed = await getProjectFileIndex(root, { refresh: input.refresh === true });
  const files = indexed.files.filter((file) => file.extension === ".gd");
  const results: SymbolMatch[] = [];
  let searchedFiles = 0;

  for (const file of files) {
    if (results.length > maxResults) {
      break;
    }
    if (file.size > maxFileBytes) {
      continue;
    }

    searchedFiles++;
    const absolute = path.join(root, file.path);
    const { text } = await readTextFileLimited(absolute, maxFileBytes);
    const lines = text.split(/\r?\n/);

    for (let index = 0; index < lines.length; index++) {
      if (results.length > maxResults) {
        break;
      }
      const trimmed = lines[index].trim();
      for (const { kind, regex } of PATTERNS) {
        if (!kinds.has(kind)) {
          continue;
        }
        const match = trimmed.match(regex);
        if (!match) {
          continue;
        }
        const name = match[1];
        if (rawQuery) {
          const haystack = name.toLowerCase();
          const isMatch = exact ? haystack === needle : haystack.includes(needle);
          if (!isMatch) {
            continue;
          }
        }
        results.push({ name, kind, path: file.path, line: index + 1, signature: trimmed });
        break;
      }
    }
  }

  return {
    query: rawQuery,
    kinds: [...kinds],
    resultCount: Math.min(results.length, maxResults),
    truncated: results.length > maxResults,
    searchedFiles,
    cache: { hit: indexed.cacheHit, ageMs: indexed.ageMs },
    results: results.slice(0, maxResults)
  };
}
