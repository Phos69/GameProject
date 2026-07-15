export type PromptDefinition = {
  name: string;
  description: string;
  arguments?: Array<{
    name: string;
    description: string;
    required?: boolean;
  }>;
  render: (args: Record<string, string>) => string;
};

export const PROMPTS: PromptDefinition[] = [
  {
    name: "audit_top_down_generation",
    description: "Audit top-down cardinal biome/world contracts before changing terrain, cliffs, obstacles or streaming.",
    arguments: [{ name: "focus", description: "Optional subsystem or bug to focus on." }],
    render: ({ focus }) => `Audit the top-down cardinal generation pipeline${focus ? ` with focus on: ${focus}` : ""}.

Use repo_overview, game_system_summary, roadmap_context and search_project before editing. Inspect docs/top_down_cardinal_contract.md, manifest, tile resolver, tile layer, world generation, streamer, obstacle and hazard contracts. Preserve coordinate_system=orthogonal_top_down, volume_style=controlled_perspective, terrain classification, analog movement, collision, fall-zone behavior and existing GUT coverage. Ground and routes must stay screen-aligned and cardinal; volume may expose a controlled south facade without changing footprints. Return findings with files, risks and test plan.`
  },
  {
    name: "improve_zombie_mode",
    description: "Prepare an implementation brief for zombie survival, waves, spawns, hazards or biome gameplay.",
    arguments: [{ name: "goal", description: "Desired zombie-mode improvement.", required: true }],
    render: ({ goal }) => `Prepare a scoped zombie-mode task for: ${goal}.

Use codex_task_brief, game_system_summary and search_project. Check ZombieModeController, SurvivalMode, WaveDirector, ZombieSpawner, BiomeManager, HazardSystem and relevant tests. Avoid duplicating shared mode/combat logic. Include acceptance criteria and safe checks.`
  },
  {
    name: "implement_roadmap_milestone",
    description: "Turn an open roadmap/TODO item into a concrete implementation plan.",
    arguments: [{ name: "milestone", description: "Milestone or TODO id.", required: true }],
    render: ({ milestone }) => `Implement roadmap/TODO milestone: ${milestone}.

Start with roadmap_context, then read the linked docs and architecture sections. Keep changes incremental, update CHANGELOG/TODO/ROADMAP/ARCHITECTURE/GAME_DESIGN when contracts change, and include a manual or automated checklist.`
  },
  {
    name: "refactor_gameplay_system",
    description: "Guide a behavior-preserving gameplay refactor.",
    arguments: [{ name: "system", description: "Gameplay system to refactor.", required: true }],
    render: ({ system }) => `Refactor gameplay system: ${system}.

Search for existing ownership boundaries before editing. Preserve public signals, scenes, resource contracts and test behavior. Prefer extracting small helpers in the existing folder or modes/shared when responsibility is shared. Run focused GUT suites plus any safe checks named by codex_task_brief.`
  },
  {
    name: "asset_quality_pass",
    description: "Plan an asset/readability pass using the manifest and inventory.",
    arguments: [{ name: "focus", description: "Asset category, biome or readability issue." }],
    render: ({ focus }) => `Run an asset quality pass${focus ? ` for: ${focus}` : ""}.

Use asset_inventory, game_system_summary and search_project. Inspect docs/top_down_cardinal_contract.md, manifest status, fallback paths, duplicate names, missing references and visual QA docs. Require screen-aligned ground, cardinal routes and rectangular footprints; controlled perspective is allowed only on object volume. Do not make external assets mandatory for the prototype. Document manual QA and asset check results.`
  }
];

export function listPrompts() {
  return {
    prompts: PROMPTS.map(({ name, description, arguments: args }) => ({
      name,
      description,
      arguments: args ?? []
    }))
  };
}

export function getPrompt(name: string, args: Record<string, string> = {}) {
  const prompt = PROMPTS.find((item) => item.name === name);
  if (!prompt) {
    throw new Error(`Unknown prompt '${name}'.`);
  }
  return {
    description: prompt.description,
    messages: [
      {
        role: "user" as const,
        content: {
          type: "text" as const,
          text: prompt.render(args)
        }
      }
    ]
  };
}
