import { safeReadProjectFiles } from "./file_index.js";
import { gitContext } from "./git.js";
import { findSymbols, type SymbolKind } from "./symbols.js";

type ImpactRule = {
  prefixes: string[];
  system: string;
  checks: string[];
  docs: string[];
};

const IMPACT_RULES: ImpactRule[] = [
  { prefixes: ["game/weapons/", "game/combat/", "game/projectiles/", "game/drops/"], system: "combat/weapons", checks: ["gut:area combat"], docs: ["ARCHITECTURE.md", "GAME_DESIGN.md"] },
  { prefixes: ["game/player/", "game/input/", "game/multiplayer/"], system: "player/input", checks: ["gut:area progression", "gut:quick"], docs: ["ARCHITECTURE.md", "GAME_DESIGN.md"] },
  { prefixes: ["game/modes/zombie/", "game/modes/survival/"], system: "zombie survival", checks: ["gut:area modes"], docs: ["ARCHITECTURE.md", "GAME_DESIGN.md"] },
  { prefixes: ["game/procedural/", "game/world/"], system: "world generation", checks: ["gut:area world_gen"], docs: ["ARCHITECTURE.md"] },
  { prefixes: ["game/ui/", "game/settings/", "game/audio/"], system: "ui/audio", checks: ["gut:area ui_audio"], docs: ["ARCHITECTURE.md", "GAME_DESIGN.md"] },
  { prefixes: ["assets/", "game/visuals/", "game/environment/"], system: "assets/rendering", checks: ["gut:area assets", "asset:check"], docs: ["ARCHITECTURE.md"] },
  { prefixes: ["tests/"], system: "tests", checks: ["gut:quick"], docs: [] },
  { prefixes: ["tools/mcp-server/"], system: "MCP tooling", checks: ["mcp:build", "mcp:test", "mcp:smoke"], docs: ["tools/mcp-server/README.md", "ARCHITECTURE.md"] },
  { prefixes: ["README.md", "ROADMAP.md", "TODO.md", "ARCHITECTURE.md", "GAME_DESIGN.md", "CHANGELOG.md", "docs/"], system: "documentation", checks: [], docs: [] }
];

function stringField(value: unknown, key: string): string {
  if (!value || typeof value !== "object") return "";
  const field = (value as Record<string, unknown>)[key];
  return typeof field === "string" ? field : "";
}

function parseStatusPaths(stdout: string): string[] {
  const paths = new Set<string>();
  for (const line of stdout.split(/\r?\n/)) {
    if (!line || line.startsWith("## ") || line.length < 4) continue;
    const raw = line.slice(3).trim();
    const renamed = raw.includes(" -> ") ? raw.split(" -> ").at(-1)! : raw;
    paths.add(renamed.replace(/^"|"$/g, ""));
  }
  return [...paths].sort();
}

export async function changedContext(root: string, input: Record<string, unknown> = {}): Promise<Record<string, unknown>> {
  const status = await gitContext(root, { command: "status" });
  const changedFiles = parseStatusPaths(stringField(status, "stdout"));
  const impact = analyzeChangedFiles(changedFiles);

  const includeDiff = input.includeDiff === true;
  const diff = includeDiff
    ? await gitContext(root, { command: "diff", staged: input.staged === true })
    : undefined;

  return {
    branch: stringField(status, "stdout").split(/\r?\n/).find((line) => line.startsWith("## "))?.slice(3) ?? "unknown",
    clean: changedFiles.length === 0,
    changedFiles,
    ...impact,
    workflowNotes: [
      "Read AGENTS.md and the relevant architecture contract before editing.",
      "Update TODO.md only when the open backlog changes and ROADMAP.md only when a milestone advances.",
      "Record a manual checklist or automated test for every feature change."
    ],
    ...(diff ? { diff } : {})
  };
}

export function analyzeChangedFiles(changedFiles: string[]): {
  impactedSystems: string[];
  recommendedChecks: string[];
  documentationToReview: string[];
} {
  const impactedSystems = new Set<string>();
  const recommendedChecks = new Set<string>();
  const documentation = new Set<string>();

  for (const file of changedFiles) {
    for (const rule of IMPACT_RULES) {
      if (!rule.prefixes.some((prefix) => file === prefix || file.startsWith(prefix))) continue;
      impactedSystems.add(rule.system);
      rule.checks.forEach((check) => recommendedChecks.add(check));
      rule.docs.forEach((doc) => documentation.add(doc));
    }
  }

  if (changedFiles.some((file) => !file.endsWith(".md"))) {
    documentation.add("CHANGELOG.md");
  }

  return {
    impactedSystems: [...impactedSystems],
    recommendedChecks: [...recommendedChecks],
    documentationToReview: [...documentation]
  };
}

export async function readSymbolContext(root: string, input: Record<string, unknown>): Promise<Record<string, unknown>> {
  const query = typeof input.query === "string" ? input.query.trim() : "";
  if (!query) throw new Error("read_symbol_context requires a non-empty query.");
  const maxResults = typeof input.maxResults === "number" ? Math.max(1, Math.min(10, Math.trunc(input.maxResults))) : 5;
  const contextLines = typeof input.contextLines === "number" ? Math.max(0, Math.min(100, Math.trunc(input.contextLines))) : 20;
  const found = await findSymbols(root, {
    query,
    kind: input.kind as SymbolKind[] | undefined,
    exact: input.exact === true,
    maxResults,
    refresh: input.refresh === true
  });

  const results = [];
  for (const match of found.results) {
    const read = await safeReadProjectFiles(root, {
      paths: [match.path],
      aroundLine: match.line,
      contextLines,
      maxBytesPerFile: 300_000,
      maxTotalBytes: 100_000
    });
    results.push({ ...match, context: read.files[0] });
  }

  return {
    query,
    resultCount: results.length,
    truncated: found.truncated,
    cache: found.cache,
    results
  };
}
