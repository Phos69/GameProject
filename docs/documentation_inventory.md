# Documentation Inventory

Data audit: 2026-07-15

Questo inventario definisce quali Markdown sono documentazione viva, quali sono
reference storiche consolidate e quali sono stati rimossi per ridurre rumore e
link obsoleti.

## Regola di retention

- Tenere documenti che descrivono stato attuale, contratti runtime, workflow,
  checklist operative o policy ancora valide.
- Consolidare roadmap completate in `ROADMAP.md`, `CHANGELOG.md` e nei report
  tecnici; `TODO.md` resta solo backlog aperto.
- Rimuovere prompt grezzi, piani milestone chiusi, roadmap storiche duplicate e
  report tecnici sostituiti da documenti piu recenti.
- Non usare `CHANGELOG.md` come fonte operativa: puo citare file storici rimossi
  per preservare la cronologia.

## Da tenere

Documenti principali:

- `AGENTS.md`: regole operative agenti.
- `README.md`: avvio, test, struttura e stato corrente.
- `ROADMAP.md`: baseline archiviata e roadmap attiva categorizzata.
- `TODO.md`: backlog operativo aperto e decisioni ancora da prendere.
- `ARCHITECTURE.md`: contratti tra sistemi.
- `GAME_DESIGN.md`: regole di gioco, contenuti e identita gameplay.
- `CHANGELOG.md`: cronologia append-only.
- `CONTRIBUTING.md`: workflow contributi.

Documenti tecnici ancora utili:

- `docs/top_down_cardinal_contract.md`
- `docs/zombie_market.md`
- `docs/obstacle_rendering.md`
- `docs/forest_top_down_texture_system.md`
- `docs/weapon_visual_identity_validation_report.md`
- `docs/rpg_character_visual_checklist.md`
- `docs/testing/manual_checklist.md` (solo indice operativo corrente; le
  sezioni pre-cutover sono archivio e non sono fonte per nuovi asset)
- `docs/testing/visual_qa.md`
- `docs/testing/weapon_visual_identity_checklist.md`
- `assets/README.md`
- `assets/ATTRIBUTION.md`
- `tools/mcp-server/README.md`

Prompt operativi da tenere:

- `prompts/bugfix.md`
- `prompts/feature_request.md`
- `prompts/milestone_review.md`
- `prompts/refactor.md`

## Rimossi in questo pass

Root storici o obsoleti:

- `IMPLEMENTATION_PLAN.md`: roadmap zombie completata e consolidata.
- `REGENERATE_README.md`: istruzioni vecchie e potenzialmente distruttive,
  sostituite dal workflow README/Godot import.
- `prompt.md`: prompt grezzo con marker di merge conflict, non documentazione.
- `repo_status_report.md`: audit 2026-06-20 consolidato in ROADMAP/CHANGELOG.
- `repo_fix_roadmap.md`: roadmap completata e consolidata.
- `test_rewrite_roadmap.md`: migrazione GUT completata.
- `weapon_visual_identity_roadmap.md`: WVIS completata; resta il validation
  report.
- `biome_generation_voidfirst_roadmap.md`: pass completato e superato da
  documenti runtime/asset.
- `isometric_biome_generation_rewrite_roadmap.md`: consolidata in ROADMAP,
  asset docs e test.

Milestone storiche:

- `docs/milestones/milestone_0.md` ... `milestone_21.md`
- `docs/milestones/zombie_revamp_milestone_1.md` ...
  `zombie_revamp_milestone_12.md`

Report superato:

- `docs/technical_review_2026-06-19.md`

Generic docs rimossi nel follow-up:

- `docs/systems/local_multiplayer.md`: panoramica duplicata da
  `ARCHITECTURE.md`, `README.md` e dal codice runtime.
- `docs/systems/input.md`: contratto input gia coperto da architettura,
  settings e test.
- `docs/systems/game_modes.md`: sintesi dei mode duplicata da `ARCHITECTURE.md`,
  `GAME_DESIGN.md` e `ROADMAP.md`.
- `docs/testing/gut_warning_cleanup_plan.md`: piano completato, consolidato in
  `CHANGELOG.md`.

## Note residue

Documenti storici conservati come evidenza e marcati in apertura:

- `docs/archive/manual_checklist_pre_cardinal_2026-07-15.md`;
- `docs/iso_grid_scale_migration_report.md`;
- `docs/latest_commit_validation_report.md`;
- `docs/visual_qa_report_2026-07-01.md`;
- `docs/biome_art_vis_fix_roadmap.md`;
- `docs/biome_road_unification_plan.md`;
- `docs/repo_fix_milestone_10_asset_fallback_policy.md`.

`CHANGELOG.md` e questi report possono ancora citare nomi, percorsi e contratti
precedenti per preservare la cronologia. Non vanno usati come istruzioni
operative per nuove feature; prevale sempre
`docs/top_down_cardinal_contract.md`.
