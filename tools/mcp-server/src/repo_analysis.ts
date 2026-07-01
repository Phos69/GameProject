import fs from "node:fs/promises";
import path from "node:path";
import {
  ASSET_EXTENSIONS,
  DOCUMENTATION_FILES,
  OUTPUT_LIMIT_BYTES,
  TEXT_EXTENSIONS
} from "./config.js";
import { listProjectFiles, safeReadProjectFiles, walkProjectFiles } from "./file_index.js";
import { readTextFileLimited, toRepoPath } from "./security.js";

type Evidence = {
  path: string;
  why: string;
};

async function exists(filePath: string): Promise<boolean> {
  try {
    await fs.access(filePath);
    return true;
  } catch {
    return false;
  }
}

async function readIfExists(root: string, repoPath: string, maxBytes = OUTPUT_LIMIT_BYTES): Promise<string> {
  const absolute = path.join(root, repoPath);
  if (!(await exists(absolute))) {
    return "";
  }
  return (await readTextFileLimited(absolute, maxBytes)).text;
}

function extractPackageScripts(jsonText: string): Record<string, string> {
  try {
    const parsed = JSON.parse(jsonText) as { scripts?: Record<string, string> };
    return parsed.scripts ?? {};
  } catch {
    return {};
  }
}

function extractGodotVersion(projectText: string): string | undefined {
  const match = projectText.match(/config\/features=PackedStringArray\("([^"]+)"\)/);
  return match?.[1];
}

function extractMainScene(projectText: string): string | undefined {
  const match = projectText.match(/run\/main_scene="([^"]+)"/);
  return match?.[1];
}

function firstExisting(files: string[], expected: string[]): string[] {
  const fileSet = new Set(files);
  return expected.filter((item) => fileSet.has(item));
}

export async function repoOverview(root: string): Promise<Record<string, unknown>> {
  const files = await walkProjectFiles(root, { maxResults: 10_000, includeLockfiles: true });
  const paths = files.map((file) => file.path);
  const projectText = await readIfExists(root, "project.godot");
  const rootPackage = await readIfExists(root, "package.json");
  const mcpPackage = await readIfExists(root, "tools/mcp-server/package.json");
  const extensionCounts = new Map<string, number>();
  for (const file of files) {
    extensionCounts.set(file.extension || "(none)", (extensionCounts.get(file.extension || "(none)") ?? 0) + 1);
  }

  return {
    name: "Iso Local Sandbox",
    root,
    stack: {
      engine: "Godot 4.x",
      godotFeatureVersion: extractGodotVersion(projectText) ?? "not_found",
      gameplayLanguage: "typed GDScript",
      mcpServerRuntime: "Node.js / TypeScript / @modelcontextprotocol/sdk",
      testFramework: "GUT"
    },
    entrypoints: {
      mainScene: extractMainScene(projectText) ?? "res://game/main/main.tscn",
      godotProject: paths.includes("project.godot") ? "project.godot" : "missing",
      mcpServer: "tools/mcp-server/src/server.ts"
    },
    packageScripts: {
      root: extractPackageScripts(rootPackage),
      mcpServer: extractPackageScripts(mcpPackage)
    },
    mainDirectories: firstExisting(paths, [
      "game/main/main.gd",
      "game/modes/game_mode_manager.gd",
      "game/modes/zombie/zombie_mode_controller.gd",
      "game/player/player_controller.gd",
      "game/weapons/weapon_system.gd",
      "game/ui/hud_manager.gd",
      "assets/environment/isometric/manifest.json",
      "tests/suites/_sanity/gut_bootstrap_test.gd"
    ]),
    documentationStatus: Object.fromEntries(
      DOCUMENTATION_FILES.map((file) => [file, paths.includes(file) ? "present" : "missing"])
    ),
    topLevelAreas: {
      game: paths.filter((item) => item.startsWith("game/")).length,
      assets: paths.filter((item) => item.startsWith("assets/")).length,
      docs: paths.filter((item) => item.startsWith("docs/") || DOCUMENTATION_FILES.includes(item)).length,
      tests: paths.filter((item) => item.startsWith("tests/")).length,
      tools: paths.filter((item) => item.startsWith("tools/")).length
    },
    extensionCounts: Object.fromEntries([...extensionCounts.entries()].sort())
  };
}

function systemEvidence(rootFiles: string[], candidates: Evidence[]): Evidence[] {
  const fileSet = new Set(rootFiles);
  return candidates.filter((item) => fileSet.has(item.path));
}

export async function gameSystemSummary(root: string): Promise<Record<string, unknown>> {
  const files = await walkProjectFiles(root, { maxResults: 10_000 });
  const paths = files.map((file) => file.path);
  const systems = {
    zombieMode: {
      summary: "Zombie Survival is coordinated by mode, biome, wave, spawn, hazard and resource systems.",
      evidence: systemEvidence(paths, [
        { path: "game/modes/zombie/zombie_mode_controller.gd", why: "main zombie revamp coordinator" },
        { path: "game/modes/zombie/biome_manager.gd", why: "current biome and generated layout owner" },
        { path: "game/modes/zombie/wave_director.gd", why: "biome-aware wave composition" },
        { path: "game/modes/zombie/zombie_spawner.gd", why: "camera-edge spawn validation" },
        { path: "game/modes/survival/survival_mode.gd", why: "survival lifecycle and defeat flow" }
      ])
    },
    playerInput: {
      summary: "Player runtime is local-multiplayer oriented, with slot-based input, dodge and injected manager references.",
      evidence: systemEvidence(paths, [
        { path: "game/input/input_manager.gd", why: "keyboard and joypad action mapping" },
        { path: "game/multiplayer/local_multiplayer_manager.gd", why: "local slots and join/leave" },
        { path: "game/player/player_manager.gd", why: "spawn/despawn and dependency injection" },
        { path: "game/player/player_controller.gd", why: "movement, aim, attacks and dodge integration" },
        { path: "game/player/player_dodge_component.gd", why: "roll validation and invulnerability window" }
      ])
    },
    weaponsCombat: {
      summary: "Combat is data-driven through WeaponData, per-player WeaponInstance state, shared projectile/melee resolution and HealthSystem damage delivery.",
      evidence: systemEvidence(paths, [
        { path: "game/weapons/weapon_system.gd", why: "attack dispatch and loadout runtime" },
        { path: "game/weapons/weapon_catalog.gd", why: "drop weapon registry" },
        { path: "game/weapons/weapon_data.gd", why: "static weapon contract" },
        { path: "game/weapons/melee_attack.gd", why: "temporary melee hitbox" },
        { path: "game/projectiles/projectile_system.gd", why: "projectile spawn and ownership" },
        { path: "game/health/health_system.gd", why: "damage and healing facade" }
      ])
    },
    enemiesBosses: {
      summary: "Enemies share spawn/health/drop contracts; bosses are registered by ID with mode compatibility and telegraphed patterns.",
      evidence: systemEvidence(paths, [
        { path: "game/enemies/enemy_system.gd", why: "enemy scene registry and spawn" },
        { path: "game/enemies/basic_enemy.gd", why: "shared zombie AI states" },
        { path: "game/enemies/ranged_enemy.gd", why: "ranged specialization with warning" },
        { path: "game/bosses/boss_system.gd", why: "boss registry and active boss lifecycle" },
        { path: "game/bosses/basic_boss.gd", why: "shared boss behavior" },
        { path: "game/bosses/rift_architect.gd", why: "second boss implementation" }
      ])
    },
    biomesWorldGeneration: {
      summary: "The survival world uses seeded multi-region biome generation, streaming, terrain classification and persistent exploration state.",
      evidence: systemEvidence(paths, [
        { path: "game/procedural/world_generation/biome_world_generator.gd", why: "global biome generation orchestrator" },
        { path: "game/procedural/world_generation/biome_terrain_generator.gd", why: "per-region terrain layout" },
        { path: "game/world/world_runtime.gd", why: "persistent world runtime" },
        { path: "game/world/world_region_streamer.gd", why: "current and neighbor region streaming" },
        { path: "game/world/region_seam_system.gd", why: "world-space region transition tracking" }
      ])
    },
    isometricRendering: {
      summary: "Isometric rendering is asset-driven through the environment manifest, tile layer/resolver, SVG loader, cliff meshes and visual-only components.",
      evidence: systemEvidence(paths, [
        { path: "assets/environment/isometric/manifest.json", why: "asset and fallback contract" },
        { path: "game/modes/zombie/biome_tile_layer.gd", why: "chunked tile drawing" },
        { path: "game/modes/zombie/isometric_tile_resolver.gd", why: "terrain to tile selection" },
        { path: "game/modes/zombie/isometric_svg_texture_loader.gd", why: "runtime SVG rasterization" },
        { path: "game/modes/zombie/isometric_cliff_renderer.gd", why: "fall-zone cliff rendering" }
      ])
    },
    guiHud: {
      summary: "UI is split between menu/navigation, character select, settings, HUD aggregation, world-space player HUD and run result overlays.",
      evidence: systemEvidence(paths, [
        { path: "game/ui/main_menu.gd", why: "mode selection and character select flow" },
        { path: "game/ui/menu_navigation_controller.gd", why: "shared focus and gamepad navigation" },
        { path: "game/ui/hud_manager.gd", why: "HUD aggregation" },
        { path: "game/ui/player_world_hud_visual.gd", why: "above-player HUD" },
        { path: "game/ui/settings_panel.gd", why: "audio/video/control settings" },
        { path: "game/ui/run_results_screen.gd", why: "end-run overlay" }
      ])
    },
    assets: {
      summary: "Assets are stored in-repo with manifest-backed environment art, character manifests, weapon visual resources and generated import metadata.",
      evidence: systemEvidence(paths, [
        { path: "assets/README.md", why: "asset pipeline notes" },
        { path: "assets/ATTRIBUTION.md", why: "license/attribution ledger" },
        { path: "assets/characters/index.json", why: "character asset index" },
        { path: "assets/environment/isometric/manifest.json", why: "environment asset manifest" },
        { path: "game/weapons/weapon_visual_data.gd", why: "weapon visual resource contract" }
      ])
    }
  };

  return { systems };
}

function extractOpenTodoHeadings(todo: string): string[] {
  const start = todo.indexOf("## Backlog aperto prioritizzato");
  const relevant = start >= 0 ? todo.slice(start) : todo;
  return relevant
    .split(/\r?\n/)
    .filter((line) => line.startsWith("### "))
    .map((line) => line.replace(/^###\s+/, "").trim())
    .slice(0, 20);
}

function extractRoadmapStatuses(roadmap: string): string[] {
  const lines = roadmap.split(/\r?\n/);
  const statuses: string[] = [];
  for (let index = 0; index < lines.length; index++) {
    if (lines[index].startsWith("## Milestone")) {
      const status = lines.slice(index + 1, index + 6).find((line) => line.toLowerCase().startsWith("stato:"));
      statuses.push(status ? `${lines[index].replace(/^##\s+/, "")} - ${status}` : lines[index].replace(/^##\s+/, ""));
    }
  }
  return statuses.slice(0, 30);
}

export async function roadmapContext(root: string): Promise<Record<string, unknown>> {
  const files = await walkProjectFiles(root, { maxResults: 10_000 });
  const docs = files
    .filter((file) => {
      const lower = file.path.toLowerCase();
      return (
        DOCUMENTATION_FILES.includes(file.path) ||
        lower.startsWith("docs/") ||
        lower.includes("roadmap") ||
        lower.includes("milestone") ||
        lower.includes("audit")
      );
    })
    .map((file) => file.path)
    .slice(0, 200);

  const todo = await readIfExists(root, "TODO.md", 80_000);
  const roadmap = await readIfExists(root, "ROADMAP.md", 80_000);
  const architecture = await readIfExists(root, "ARCHITECTURE.md", 80_000);
  const debtLines = `${todo}\n${architecture}`
    .split(/\r?\n/)
    .filter((line) => /(debito|follow-up|resta|apert|warning|TODO|Non ancora|futuro)/i.test(line))
    .map((line) => line.trim())
    .filter(Boolean)
    .slice(0, 40);

  return {
    documentationFiles: docs,
    openBacklogItems: extractOpenTodoHeadings(todo),
    roadmapStatuses: extractRoadmapStatuses(roadmap),
    technicalDebtSignals: debtLines
  };
}

function collectStringPaths(value: unknown, results: Set<string>): void {
  if (typeof value === "string") {
    if (value.startsWith("res://") || value.startsWith("assets/")) {
      results.add(value.replace(/^res:\/\//, ""));
    }
    return;
  }
  if (Array.isArray(value)) {
    for (const item of value) {
      collectStringPaths(item, results);
    }
    return;
  }
  if (value && typeof value === "object") {
    for (const item of Object.values(value)) {
      collectStringPaths(item, results);
    }
  }
}

function categorizeAsset(repoPath: string): string {
  const lower = repoPath.toLowerCase();
  if (/\.(ogg|wav|mp3|opus)$/.test(lower) || lower.startsWith("game/audio/")) return "audio";
  if (lower.includes("/ui/") || lower.includes("hud") || lower.includes("icon")) return "ui";
  if (lower.includes("projectile") || lower.includes("bullet")) return "projectiles";
  if (lower.includes("weapon") || lower.startsWith("game/weapons/")) return "weapons";
  if (lower.includes("zombie") || lower.includes("enemy")) return "zombie";
  if (lower.startsWith("assets/characters") || lower.includes("player")) return "player";
  if (lower.includes("obstacle") || lower.includes("/objects/") || lower.includes("barrier") || lower.includes("rock")) return "obstacles";
  if (lower.includes("biome") || lower.includes("environment/isometric") || lower.includes("/tiles/")) return "biomes";
  return "other";
}

export async function assetInventory(root: string): Promise<Record<string, unknown>> {
  const files = await walkProjectFiles(root, { maxResults: 10_000, includeLockfiles: false });
  const assetFiles = files.filter((file) => ASSET_EXTENSIONS.has(file.extension));
  const byCategory: Record<string, string[]> = {};
  const duplicates = new Map<string, string[]>();
  const placeholders: string[] = [];

  for (const file of assetFiles) {
    const category = categorizeAsset(file.path);
    byCategory[category] ??= [];
    byCategory[category].push(file.path);
    const base = path.posix.basename(file.path).toLowerCase();
    duplicates.set(base, [...(duplicates.get(base) ?? []), file.path]);
    if (/(placeholder|missing|generic|fallback|procedural)/i.test(file.path)) {
      placeholders.push(file.path);
    }
  }

  const manifestPaths = new Set<string>();
  const manifestText = await readIfExists(root, "assets/environment/isometric/manifest.json", 500_000);
  if (manifestText) {
    try {
      collectStringPaths(JSON.parse(manifestText), manifestPaths);
    } catch {
      // Keep inventory useful even if a manifest is temporarily invalid.
    }
  }

  const missingManifestAssets = [];
  for (const manifestPath of manifestPaths) {
    if (!(await exists(path.join(root, manifestPath)))) {
      missingManifestAssets.push(manifestPath);
    }
  }

  const textFiles = files.filter((file) => TEXT_EXTENSIONS.has(file.extension) && file.size < 300_000);
  const referenceBlobParts: string[] = [];
  for (const file of textFiles.slice(0, 1_000)) {
    const absolute = path.join(root, file.path);
    referenceBlobParts.push((await readTextFileLimited(absolute, 300_000)).text);
  }
  const referenceBlob = referenceBlobParts.join("\n");
  const unlinkedCandidates = assetFiles
    .filter((file) => !referenceBlob.includes(`res://${file.path}`) && !referenceBlob.includes(file.path))
    .map((file) => file.path)
    .slice(0, 80);

  return {
    counts: Object.fromEntries(Object.entries(byCategory).map(([category, items]) => [category, items.length])),
    samplesByCategory: Object.fromEntries(Object.entries(byCategory).map(([category, items]) => [category, items.slice(0, 30)])),
    placeholders: placeholders.slice(0, 80),
    duplicateBasenames: Object.fromEntries(
      [...duplicates.entries()].filter(([, items]) => items.length > 1).slice(0, 50)
    ),
    missingManifestAssets: missingManifestAssets.slice(0, 80),
    possiblyUnlinkedAssets: unlinkedCandidates
  };
}

export async function codexTaskBrief(root: string, input: Record<string, unknown>): Promise<Record<string, unknown>> {
  const goal = typeof input.goal === "string" ? input.goal : "";
  if (!goal.trim()) {
    throw new Error("codex_task_brief requires a goal.");
  }
  const lower = goal.toLowerCase();
  const impactedAreas = new Set<string>();
  const likelyFiles = new Set<string>();
  const risks = new Set<string>();
  const tests = new Set<string>();

  const keywordMap: Array<[RegExp, string, string[], string[], string[]]> = [
    [/zombie|wave|survival|biom|spawn/, "zombie survival", ["game/modes/zombie/", "game/modes/survival/"], ["spawn regressions near camera, hazard or streamed regions"], ["./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/modes"]],
    [/player|input|joypad|controller|dodge/, "player/input", ["game/player/", "game/input/", "game/multiplayer/"], ["input mapping or local multiplayer regressions"], ["./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/progression"]],
    [/weapon|combat|damage|projectile|melee|drop/, "combat/weapons", ["game/weapons/", "game/combat/", "game/projectiles/", "game/drops/"], ["damage, ammo, reload or drop contract regressions"], ["./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/combat"]],
    [/ui|hud|menu|settings|audio/, "ui/audio", ["game/ui/", "game/settings/", "game/audio/"], ["focus, safe-area, save round-trip or audio bus regressions"], ["./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/ui_audio"]],
    [/asset|sprite|isometric|obstacle|cliff|tile|render/, "assets/rendering", ["assets/", "game/modes/zombie/isometric_", "game/modes/zombie/biome_tile_layer.gd"], ["manifest fallback, footprint, collision or visual readability regressions"], ["./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/assets", "godot --headless --path . --script res://tools/generate_isometric_environment_assets.gd -- --check"]],
    [/roadmap|todo|docs|architecture|design/, "documentation", ["README.md", "ROADMAP.md", "TODO.md", "ARCHITECTURE.md", "GAME_DESIGN.md"], ["documentation drift against implemented contracts"], ["manual review of updated docs"]]
  ];

  for (const [pattern, area, files, areaRisks, areaTests] of keywordMap) {
    if (pattern.test(lower)) {
      impactedAreas.add(area);
      files.forEach((file) => likelyFiles.add(file));
      areaRisks.forEach((risk) => risks.add(risk));
      areaTests.forEach((test) => tests.add(test));
    }
  }

  if (impactedAreas.size === 0) {
    impactedAreas.add("general repository task");
    likelyFiles.add("README.md");
    risks.add("scope may touch multiple systems; inspect with search_project before editing");
    tests.add("./tools/run_gut.ps1 -SkipImport");
  }

  return {
    goal,
    likelyFiles: [...likelyFiles],
    impactedSystems: [...impactedAreas],
    risks: [...risks],
    recommendedTests: [...tests],
    acceptanceCriteria: [
      "change is scoped to the named systems",
      "existing public contracts and documented controls still work",
      "documentation/backlog is updated when behavior or milestone status changes",
      "manual checklist or automated test evidence is recorded for the touched area"
    ],
    firstSteps: [
      "run search_project for the main symbols in the goal",
      "read the files returned by codex_task_brief and repo docs before editing",
      "prefer existing systems over duplicate controllers"
    ]
  };
}

export { listProjectFiles, safeReadProjectFiles };
