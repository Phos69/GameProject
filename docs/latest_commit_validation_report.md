# Latest Commit Validation Report

## Milestone 1 shutdown headless - 2026-06-17
- Branch: `master`
- HEAD corrente: `6522e4e`
- Scope validato: Milestone 1 di `todo_roadmap.md`, stabilizzazione shutdown
  headless e cleanup test.
- Esito: PASS sui criteri richiesti.
- Gameplay implementato: nessuna nuova regola di gioco.
- Nota residui: i runner QA visuali basati su screenshot (`audio_mix`,
  `visual_accessibility`, `menu_visual`, `survival_visual`) continuano a fallire
  nel renderer dummy headless per texture viewport nulla. Sono stati lasciati
  fuori scope perche non sono warning di shutdown o leak lifecycle.

| Criterio | Esito | Evidenza |
|---|---|---|
| Inventario cleanup warning | PASS | warning riprodotti e ricondotti ad audio headless, helper procedurali, dati world ciclici, timer encounter e teardown test |
| Loop 100 startup/shutdown main scene | PASS | `tests/headless_shutdown_loop_test.gd`, 100 cicli, exit code `0` |
| Bootstrap headless | PASS | `godot --headless --path . --quit`, exit code `0`, nessun cleanup warning |
| Smoke prioritari | PASS | combat, survival, dungeon, tower defense, pause/settings, Character Select RPG e mini-eventi bioma senza cleanup warning noti |
| Residui documentati | PASS | limite screenshot QA headless annotato sopra, non correlato a shutdown |

### Test Milestone 1 eseguiti

| Test | Esito | Note |
|---|---|---|
| `godot --headless --path . --quit` | PASS | exit code `0`, shutdown pulito |
| `tests/headless_shutdown_loop_test.gd` | PASS | 100 cicli main scene |
| `tests/combat_smoke_test.gd` | PASS | shutdown pulito |
| `tests/survival_wave_smoke_test.gd` | PASS | shutdown pulito |
| `tests/dungeon_smoke_test.gd` | PASS | shutdown pulito |
| `tests/tower_defense_smoke_test.gd` | PASS | shutdown pulito |
| `tests/pause_settings_smoke_test.gd` | PASS | shutdown pulito |
| `tests/character_select_ui_smoke_test.gd` | PASS | shutdown pulito |
| `tests/milestone_rpg_1_character_select_smoke_test.gd` | PASS | shutdown pulito |
| `tests/biome_mini_events_smoke_test.gd` | PASS | shutdown pulito |

### Sweep aggiuntivo cleanup-sensitive

Verificati senza cleanup warning noti anche boss, drop, visual smoke M10-M21,
RPG smoke M2-M13, melee resolution, zombie revamp/fall/transition/enemy/soak,
world graph, persistent world, open passage, terrain coverage, fall boundary,
dodge, exploration map, biome overlay, obstacle/status/roster e random
encounter.

### Fix applicati nella Milestone 1

- `game/audio/audio_manager.gd`: headless senza player audio temporanei e
  shutdown esplicito di voice pool/generatori.
- `game/procedural/world_generation/`: helper senza lifecycle di scena convertiti
  a `RefCounted`; world/celle/report ripuliti tra generazioni.
- `game/modes/zombie/`: cleanup di `BiomeManager`, `ZombieModeController`,
  `RandomEncounterSystem` e restore dei layout bioma base.
- `game/world/world_runtime.gd`: stop run con rilascio grafo e manager bioma.
- `game/visuals/` e `game/player/revive_indicator_visual.gd`: sync impostazioni
  visuali senza dipendenza statica obbligatoria da `VisualSettingsManager`.
- `tests/`: aggiunti loop shutdown e helper lifecycle; runner fragili aggiornati
  a teardown differito e cleanup esplicito delle risorse create.

## Milestone 0 document audit - 2026-06-17
- Branch: `master`
- HEAD corrente: `ce0fda5`
- Scope validato: consolidamento TODO, baseline tecnica e revisione documentale.
- Esito: PASS documentale.
- Gameplay implementato: nessuno.
- Test gameplay eseguiti in questo audit: nessuno; la Milestone 0 richiede
  revisione manuale e baseline, non regressione runtime.
- Discovery test corrente: 73 runner in `tests/`.
- Documenti rivisti: `README.md`, `ROADMAP.md`, `TODO.md`,
  `ARCHITECTURE.md`, `GAME_DESIGN.md`,
  `docs/latest_commit_validation_report.md` e
  `docs/testing/manual_checklist.md`.

| Area baseline | Stato noto | Evidenza | Azione successiva |
|---|---|---|---|
| Suite smoke automatica | PASS nell'ultima validazione completa disponibile | Sezione "Test automatici eseguiti" sotto | Rieseguire da Milestone 1 dopo il lavoro sul teardown |
| Build/export Windows | PASS nell'ultima validazione completa disponibile | Sezione "Build/export" sotto | Rieseguire solo in release readiness o regressione packaging |
| Warning shutdown headless | Debito aperto consolidato | 34 test con cleanup warning nel report precedente | Milestone 1 di `todo_roadmap.md` |
| Backlog aperto | Consolidato in un'unica lista strutturata | `TODO.md` aggiornato nella Milestone 0 | Usare una milestone alla volta |
| Roadmap storiche | Completate come primo pass/reference | `ROADMAP.md`, roadmap dedicate e `CHANGELOG.md` | Non riaprire senza nuovo goal esplicito |

## Working tree validation - 2026-06-17
- Branch: `master`
- HEAD di partenza: `4439fbe`
- Scope validato: pass RPG combat/readability con `WeaponData.attack_type`,
  `MeleeAttack`, risorse starter, Character Select e feedback melee/super.
- Esito: PASS sui test eseguiti.
- Nota: `tests/combat_smoke_test.gd` continua a mostrare warning cleanup
  `ObjectDB/resources still in use` a exit code `0`, gia tracciati nel TODO.

| Test | Esito | Note |
|---|---|---|
| tests/milestone_rpg_1_character_select_smoke_test.gd | PASS | exit code 0 |
| tests/milestone_rpg_2_stats_smoke_test.gd | PASS | exit code 0 |
| tests/milestone_rpg_3_weapons_smoke_test.gd | PASS | include `attack_type` |
| tests/milestone_rpg_4_hitbox_smoke_test.gd | PASS | verifica melee senza `projectile_scene` |
| tests/milestone_rpg_5_ammo_reload_smoke_test.gd | PASS | reload/ammo invariati |
| tests/milestone_rpg_6_xp_level_smoke_test.gd | PASS | exit code 0 |
| tests/milestone_rpg_7_passives_smoke_test.gd | PASS | passive invarianti |
| tests/milestone_rpg_8_adrenaline_super_smoke_test.gd | PASS | super/adrenalina invarianti |
| tests/milestone_rpg_9_hud_smoke_test.gd | PASS | HUD RPG invariato |
| tests/milestone_rpg_10_balance_smoke_test.gd | PASS | identita starter coerente |
| tests/milestone_rpg_11_data_driven_smoke_test.gd | PASS | profili data-driven |
| tests/milestone_rpg_12_feedback_smoke_test.gd | PASS | exit code 0 |
| tests/milestone_rpg_13_new_classes_smoke_test.gd | PASS | classi avanzate invarianti |
| tests/rpg_melee_attack_resolution_smoke_test.gd | PASS | arco projectile, ascia/spada zero projectile |
| tests/character_select_ui_smoke_test.gd | PASS | safe-area, scroll, wrap e Back |
| tests/combat_smoke_test.gd | PASS | exit code 0, warning cleanup noto |
| tests/survival_wave_smoke_test.gd | PASS | exit code 0 |

## Data e commit
- Data: 2026-06-16
- Branch: `master`
- HEAD: `ad7aa7a`
- Ultimi commit analizzati:
  - `ad7aa7a` `feat: add pause menu, settings panel, RPG character assets, and biome generation`
  - `8bfe434` `Merge pull request #4 from Phos69/codex/iterate-character-design-for-zombie-survival-game`
  - `235bb0c` `fix: replace character png assets with svg sources`
  - `c10a50c` `Merge pull request #3 from Phos69/codex/improve-biome-generation-in-zombie-survival-mode`
  - `77e75dd` `test: cover biome mini encounters`
  - `a902ea3` `Merge pull request #2 from Phos69/codex/revamp-character-designs-for-rpg`
  - `5fcd3a8` `feat: add advanced RPG survivor classes`
  - `75efeb4` `Merge pull request #1 from Phos69/codex/enhance-zombie-survival-biomes`
  - `80b3cf2` `feat: expand biome survival status encounters`
  - `12a83f1` `feat: add biome world generation engine`
  - `3a7e610` `feat: complete zombie mode revamp Z1-Z12`
  - `1f0633c` `boh`

## Ambiente
- OS: Microsoft Windows NT 10.0.26200.0
- Godot version: `4.6.3.stable.official.7d41c59c4`
- Export template disponibili: si
- Comando import eseguito: si, `godot --headless --path . --import`
- Caricamento progetto: `godot --headless --path . --quit`, exit code `0`, con warning cleanup `ObjectDB/resources still in use`.
- Discovery test: `Get-ChildItem tests -Filter "*test.gd" -Recurse | Sort-Object FullName`

## File/sistemi toccati dagli ultimi commit
- RPG data e classi: `game/rpg/`, profili `game/rpg/characters/*.tres`, nuove classi `mago`, `domatrice`, `licantropo`, companion e super.
- Armi RPG: `game/weapons/rpg_staff.tres`, `rpg_slingshot.tres`, `rpg_claws.tres` e visual data collegati.
- Asset personaggi: `assets/characters/` con manifest e SVG testuali per tutti i 7 personaggi.
- UI/input/settings: `MainMenu`, `PauseMenu`, `SettingsPanel`, `InputManager`, `VideoSettingsManager`, HUD.
- Zombie survival: `game/modes/zombie/`, biomi, hazard/status, random encounter, spawner, wave director, debug overlay.
- Procedural generation: `game/procedural/world_generation/`, celle 200x200, passaggi, fall boundary, validazione layout.
- Sistemi core regressione: drop, health, enemies, player, audio e build smoke.
- Documentazione/backlog: `README.md`, `CHANGELOG.md`, `TODO.md`, `ROADMAP.md`, `ARCHITECTURE.md`, `GAME_DESIGN.md`.
- Test: suite smoke in `tests/`, inclusi biome, RPG, pause/settings, survival, dungeon, tower defense e build runtime smoke.

## Test automatici eseguiti
| Test | Esito | Note |
|---|---|---|
| tests/biome_debug_overlay_smoke_test.gd | PASS | 0.87s |
| tests/biome_mini_events_smoke_test.gd | PASS | 0.86s; cleanup warning |
| tests/biome_obstacle_generation_smoke_test.gd | PASS | 0.29s |
| tests/biome_roster_smoke_test.gd | PASS | 0.28s |
| tests/biome_status_effects_smoke_test.gd | PASS | 0.28s |
| tests/biome_world_generation_smoke_test.gd | PASS | 2.42s; cleanup warning |
| tests/boss_smoke_test.gd | PASS | 3.17s; cleanup warning |
| tests/combat_smoke_test.gd | PASS | 3.16s; cleanup warning |
| tests/dungeon_smoke_test.gd | PASS | 1.96s; cleanup warning |
| tests/enemy_drop_smoke_test.gd | PASS | 2.24s; cleanup warning |
| tests/milestone_10_visual_smoke_test.gd | PASS | 1.59s; cleanup warning |
| tests/milestone_11_boss_telegraph_smoke_test.gd | PASS | 1.86s; cleanup warning |
| tests/milestone_12_enemy_variants_smoke_test.gd | PASS | 1.49s; cleanup warning |
| tests/milestone_13_weapon_tower_visual_smoke_test.gd | PASS | 2.15s; cleanup warning |
| tests/milestone_14_final_polish_smoke_test.gd | PASS | 1.87s; cleanup warning |
| tests/milestone_15_ranged_enemy_smoke_test.gd | PASS | 1.68s; cleanup warning |
| tests/milestone_16_downed_revive_smoke_test.gd | PASS | 1.78s; cleanup warning |
| tests/milestone_17_run_results_smoke_test.gd | PASS | 1.96s; cleanup warning |
| tests/milestone_18_audio_mix_smoke_test.gd | PASS | 1.59s; cleanup warning |
| tests/milestone_19_boss_registry_smoke_test.gd | PASS | 1.50s; cleanup warning |
| tests/milestone_20_arena_environment_smoke_test.gd | PASS | 1.68s; cleanup warning |
| tests/milestone_20_arena_stress_test.gd | PASS | 3.26s; cleanup warning |
| tests/milestone_21_visual_settings_performance_smoke_test.gd | PASS | 3.65s; cleanup warning |
| tests/milestone_9_smoke_test.gd | PASS | 1.95s; cleanup warning |
| tests/milestone_rpg_1_character_select_smoke_test.gd | PASS | 1.59s; cleanup warning |
| tests/milestone_rpg_10_balance_smoke_test.gd | PASS | 0.29s |
| tests/milestone_rpg_11_data_driven_smoke_test.gd | PASS | 0.28s |
| tests/milestone_rpg_12_feedback_smoke_test.gd | PASS | 0.75s |
| tests/milestone_rpg_13_new_classes_smoke_test.gd | PASS | 0.76s |
| tests/milestone_rpg_2_stats_smoke_test.gd | PASS | 1.69s; cleanup warning |
| tests/milestone_rpg_3_weapons_smoke_test.gd | PASS | 0.85s |
| tests/milestone_rpg_4_hitbox_smoke_test.gd | PASS | 0.29s |
| tests/milestone_rpg_5_ammo_reload_smoke_test.gd | PASS | 0.75s |
| tests/milestone_rpg_6_xp_level_smoke_test.gd | PASS | 1.69s; cleanup warning |
| tests/milestone_rpg_7_passives_smoke_test.gd | PASS | 0.75s |
| tests/milestone_rpg_8_adrenaline_super_smoke_test.gd | PASS | 0.75s |
| tests/milestone_rpg_9_hud_smoke_test.gd | PASS | 0.84s |
| tests/pause_settings_smoke_test.gd | PASS | 1.40s; cleanup warning |
| tests/random_encounter_smoke_test.gd | PASS | 0.86s; cleanup warning |
| tests/survival_wave_smoke_test.gd | PASS | 2.16s; cleanup warning |
| tests/tower_defense_smoke_test.gd | PASS | 4.09s |
| tests/zombie_biome_enemy_smoke_test.gd | PASS | 1.88s; cleanup warning |
| tests/zombie_biome_transition_smoke_test.gd | PASS | 1.68s; cleanup warning |
| tests/zombie_biome_wave_director_smoke_test.gd | PASS | 1.31s; cleanup warning |
| tests/zombie_environment_milestone_smoke_test.gd | PASS | 3.18s; cleanup warning |
| tests/zombie_fall_hazard_smoke_test.gd | PASS | 2.15s; cleanup warning |
| tests/zombie_revamp_foundation_smoke_test.gd | PASS | 1.59s; cleanup warning |
| tests/zombie_revamp_ten_minute_soak_test.gd | PASS | 11.43s; cleanup warning |
| tests/zombie_revamp_ten_wave_smoke_test.gd | PASS | 3.67s |
| tests/zombie_spawner_edge_smoke_test.gd | PASS | 1.42s; cleanup warning |

## Build/export
| Comando | Esito | Note |
|---|---|---|
| `godot --headless --path . --export-release "Windows Desktop" build/iso_local_sandbox.exe` | PASS | Exit code `0` |
| `godot --headless --path . --export-pack "Windows Desktop" build/iso_local_sandbox.pck` | PASS | Exit code `0` |
| `build/iso_local_sandbox.exe --rendering-method gl_compatibility -- --build-smoke` | PASS | Exit code `0`; nessuna assertion FAIL dopo il fix del flusso Character Select; restano warning cleanup a shutdown |

## Controlli manuali consigliati
- Avvio menu principale.
- Character select con tutti i 7 personaggi.
- Survival 10 wave con seed fisso.
- Attraversamento dei 5 biomi.
- Verifica mini-eventi bioma.
- Verifica HUD status/malus.
- Verifica joypad e tastiera.
- Dungeon smoke manuale.
- Tower defense smoke manuale.

## Problemi trovati
- HIGH, risolto: `SupplyCrate` apriva e spawnava drop direttamente dentro `body_entered`, causando errori Godot durante il flush fisico nel boss/build smoke.
- MEDIUM, risolto: `BuildRuntimeSmoke` usava il vecchio flusso survival diretto e falliva dopo l'introduzione obbligatoria del Character Select.
- MEDIUM, risolto: alcuni smoke test recenti erano obsoleti o fragili rispetto a Godot 4.6.3: root `SceneTree` non ancora valido, risorse RPG avanzate non dichiarate, proiettile torre liberato prima dell'asserzione, fall zone procedurali multiple e soak accelerato dipendente da `Engine.time_scale`.
- LOW, aperto: warning di cleanup headless `ObjectDB instances leaked` / `resources still in use` persistono in shutdown e in 34 test, gia tracciati nel TODO come debito manutentivo.

## Fix applicati
- `game/drops/supply_crate.gd`: apertura automatica differita da `body_entered`.
- `game/debug/build_runtime_smoke.gd`: aggiornato lo smoke build per aprire Character Select e confermare il primo personaggio prima di verificare survival/HUD/audio.
- `tests/biome_debug_overlay_smoke_test.gd`, `tests/biome_mini_events_smoke_test.gd`, `tests/random_encounter_smoke_test.gd`: runner differiti e root agganciato alla `SceneTree`.
- `tests/biome_status_effects_smoke_test.gd`: root agganciato correttamente alla `SceneTree`.
- `tests/milestone_rpg_3_weapons_smoke_test.gd`: caricate le risorse `staff`, `slingshot` e `claws` prima delle asserzioni.
- `tests/milestone_13_weapon_tower_visual_smoke_test.gd`: salvato il profilo del proiettile torre al segnale di sparo per evitare accesso a nodi gia liberati.
- `tests/zombie_fall_hazard_smoke_test.gd`: asserzione aggiornata alla copertura fall zone procedurale, che puo generare piu zone sui bordi esterni.
- `tests/zombie_revamp_ten_minute_soak_test.gd`: soak reso deterministico senza dipendere da `Engine.time_scale` in headless.
- `CHANGELOG.md`: documentati i fix di regressione.
- `docs/latest_commit_validation_report.md`: creato questo report.

## Stato finale
`PASS`: ultimi commit verificati e suite principale funzionante.
