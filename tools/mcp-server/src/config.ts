import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

export const SERVER_NAME = "gameproject-mcp";
export const SERVER_VERSION = "0.1.0";

export const SERVER_INSTRUCTIONS =
  "Read-only project MCP for Iso Local Sandbox. Work only inside the repo root. Do not expose secrets. Use run_safe_check only for allowlisted checks; it never runs arbitrary shell commands. File reads and searches are size-limited and skip build/cache/vendor/sensitive paths by default.";

export const DEFAULT_MAX_FILE_BYTES = 200_000;
export const MAX_FILE_BYTES_CAP = 1_000_000;
export const DEFAULT_SEARCH_RESULTS = 50;
export const MAX_SEARCH_RESULTS = 200;
export const DEFAULT_LIST_RESULTS = 300;
export const MAX_LIST_RESULTS = 2_000;
export const OUTPUT_LIMIT_BYTES = 16_000;

export const DEFAULT_IGNORED_DIRS = new Set([
  ".git",
  ".godot",
  ".import",
  ".cache",
  ".next",
  ".vscode",
  ".idea",
  "build",
  "coverage",
  "dist",
  "exports",
  "node_modules",
  "out"
]);

export const DEFAULT_IGNORED_PREFIXES = [
  "addons/gut/",
  "tools/mcp-server/dist/"
];

export const LOCKFILE_NAMES = new Set([
  "package-lock.json",
  "pnpm-lock.yaml",
  "yarn.lock",
  "bun.lockb",
  "Cargo.lock",
  "Pipfile.lock"
]);

export const TEXT_EXTENSIONS = new Set([
  ".cfg",
  ".gd",
  ".godot",
  ".import",
  ".json",
  ".md",
  ".ps1",
  ".sh",
  ".toml",
  ".tres",
  ".ts",
  ".tscn",
  ".txt",
  ".xml",
  ".yaml",
  ".yml"
]);

export const ASSET_EXTENSIONS = new Set([
  ".gif",
  ".jpeg",
  ".jpg",
  ".mp3",
  ".ogg",
  ".opus",
  ".png",
  ".svg",
  ".wav",
  ".webp"
]);

export const DOCUMENTATION_FILES = [
  "AGENTS.md",
  "README.md",
  "ROADMAP.md",
  "TODO.md",
  "ARCHITECTURE.md",
  "GAME_DESIGN.md",
  "CHANGELOG.md",
  "CONTRIBUTING.md"
];

export const AREA_PREFIXES: Record<string, string[]> = {
  all: [""],
  gameplay: [
    "game/core/",
    "game/player/",
    "game/health/",
    "game/combat/",
    "game/weapons/",
    "game/projectiles/",
    "game/enemies/",
    "game/bosses/",
    "game/drops/",
    "game/progression/",
    "game/rpg/",
    "game/modes/",
    "game/world/"
  ],
  rendering: [
    "game/visuals/",
    "game/camera/",
    "game/modes/zombie/ground/",
    "game/modes/zombie/cliffs/",
    "game/modes/zombie/isometric_",
    "assets/environment/isometric/"
  ],
  biomi: [
    "game/modes/zombie/biome",
    "game/modes/zombie/biomes/",
    "game/procedural/world_generation/",
    "assets/environment/isometric/",
    "docs/",
    "biome_",
    "isometric_biome"
  ],
  "zombie mode": [
    "game/modes/zombie/",
    "game/modes/survival/",
    "docs/zombie",
    "tests/suites/modes/",
    "tests/suites/enemies/"
  ],
  zombie_mode: [
    "game/modes/zombie/",
    "game/modes/survival/",
    "docs/zombie",
    "tests/suites/modes/",
    "tests/suites/enemies/"
  ],
  gui: [
    "game/ui/",
    "game/settings/",
    "tests/suites/ui_audio/",
    "tests/visual_qa/",
    "docs/testing/"
  ],
  assets: [
    "assets/",
    "game/weapons/",
    "game/rpg/characters/",
    "game/modes/zombie/biomes/"
  ],
  tests: [
    "tests/",
    ".gutconfig",
    "tools/run_gut",
    "tools/run_tests",
    "tools/run_visual_qa"
  ],
  docs: [
    "docs/",
    "prompts/",
    "README.md",
    "ROADMAP.md",
    "TODO.md",
    "ARCHITECTURE.md",
    "GAME_DESIGN.md",
    "CHANGELOG.md",
    "AGENTS.md"
  ],
  config: [
    ".github/",
    ".gitattributes",
    ".gitignore",
    ".gutconfig",
    "export_presets.cfg",
    "project.godot",
    "package.json",
    "tools/"
  ]
};

// Marker file that identifies the repository root regardless of clone location.
export const PROJECT_ROOT_MARKER = "project.godot";

// Ascend from `startDir` until the project marker is found. This keeps root
// detection independent of the machine and of how deep the running file is
// nested (dev `src/` vs built `dist/src/`), which a fixed `../../..` cannot.
export function findProjectRoot(startDir: string): string | undefined {
  let current = path.resolve(startDir);
  for (let depth = 0; depth < 20; depth++) {
    if (fs.existsSync(path.join(current, PROJECT_ROOT_MARKER))) {
      return current;
    }
    const parent = path.dirname(current);
    if (parent === current) {
      break;
    }
    current = parent;
  }
  return undefined;
}

export function defaultProjectRoot(): string {
  if (process.env.PROJECT_MCP_ROOT) {
    return path.resolve(process.env.PROJECT_MCP_ROOT);
  }

  const here = path.dirname(fileURLToPath(import.meta.url));
  return findProjectRoot(here) ?? path.resolve(here, "../../..");
}
