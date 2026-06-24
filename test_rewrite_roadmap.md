# Roadmap — Riscrittura totale della suite di test

Riscrittura completa dei test del progetto, riorganizzati per **zone di interesse**
(domini funzionali del gioco) invece che per milestone storiche, con l'obiettivo
di **accorpare** quanti più test possibile e **ridurre drasticamente il tempo di
esecuzione** lanciando il gioco nel modo più ottimizzato.

> Stato: PROPOSTA. Nessuna milestone ancora avviata.

---

## 1. Diagnosi dello stato attuale

| Metrica | Valore |
| --- | --- |
| File di test (`tests/*.gd`) | **138** |
| Di cui `extends SceneTree` standalone | **135** |
| Di cui Visual QA (`*_qa.gd`) | **~24** |
| Test che fanno boot completo di `main.tscn` | **68** |
| Test che usano l'helper condiviso `GoldenWorld` | **1** |
| Framework di test | nessuno (assert/quit reimplementati a mano) |
| Autoload di progetto | nessuno (i sistemi sono `class_name` globali) |

### Problemi strutturali

1. **Un processo Godot per file.** [tools/run_tests.sh](tools/run_tests.sh) lancia
   `godot --headless --path . --script <file>` per ognuno dei 135 test → **~135
   cold-start dell'engine**. È il collo di bottiglia dominante del wall-clock.
2. **Boot ripetuto del mondo.** 68 test istanziano `main.tscn` da zero, in
   isolamento, ognuno ripagando l'intero costo di boot.
3. **Naming milestone-centrico.** `milestone_4`→`21`, `milestone_rpg_1`→`13`: è
   archeologia di sviluppo, non documentazione viva del comportamento. Forte
   sovrapposizione (es. i soli `milestone_10_*` sono ~15 file).
4. **Boilerplate duplicato.** Ogni file reimplementa `_expect`/`_assert`/`_finish`.
5. **Classificazione fragile.** Le categorie fast/slow/soak/visual sono decise per
   pattern sul nome file dentro il runner.

---

## 2. Decisioni adottate

| Tema | Scelta | Implicazione |
| --- | --- | --- |
| **Runner** | **GUT (Godot Unit Test) 9.6.0** | Framework standard per Godot 4.6, esegue l'intera cartella in **un solo processo**. `before_all`/`after_all` per fixture condivise. Exit 0/1 per la CI. |
| **Scope** | **Solo logica/smoke** | Si riscrivono i ~112 test di logica. I ~24 Visual QA e i soak/stress restano com'è e migrano in una milestone finale. |
| **Migrazione** | **In-place incrementale** | Si converte area per area dentro `tests/`, cancellando i file legacy man mano. La CI fa girare vecchio + nuovo durante la transizione. |

---

## 3. Strategia di ottimizzazione (il "perché" dei tempi)

Tre leve, in ordine d'impatto:

1. **Un solo boot dell'engine.** GUT scopre ed esegue tutte le suite in un unico
   processo Godot:
   `godot --headless -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/suites -ginclude_subdirs -gexit`.
   → **135 processi → 1 processo.** Sparisce il costo di N cold-start.
2. **Fixture di mondo condivise per area.** Ogni suite costruisce il mondo golden
   **una volta** in `before_all()` e lo riusa tra i `test_*` della stessa area.
   → **68 boot di `main.tscn` → ~9** (uno per area; spesso meno, perché molte
   asserzioni lavorano su sotto-sistemi senza boot completo).
3. **Accorpamento + parametrizzazione.** I gruppi di file quasi-identici (varianti
   biome, varianti voidfirst, varianti weapon, manifest…) diventano **un test
   parametrizzato** (`use_parameters`) invece di N file.
   → meno file, meno setup ripetuto, copertura esplicita nei parametri.

**Target indicativo:** da ~135 invocazioni a **1 sessione GUT**, con riduzione del
wall-clock attesa nell'ordine di **5–10×** (dominata dall'eliminazione dei
cold-start e dal boot condiviso). I numeri esatti si misurano in M1 (baseline).

---

## 4. Tassonomia — le zone di interesse

Le nuove suite vivono in `tests/suites/<area>/` e sostituiscono i file legacy
elencati. Ogni area = una zona di interesse con una fixture condivisa.

| # | Area (suite) | Cartella | File legacy assorbiti (logica) |
| --- | --- | --- | --- |
| A1 | **World Generation & Determinism** ✅ | `world_gen/` | golden_seed_default, biome_roster, persistent_world_generation, isometric_biome_generation_rewrite, isometric_biome_terrain_coverage, voidfirst_forests, voidfirst_roads, voidfirst_road_border, voidfirst_rocks, voidfirst_void_lottery, voidfirst_integration |
| A2 | **Environment, Streaming & Graph** | `environment/` | region_streaming, world_graph_connectivity, milestone_7_graph_connectivity, milestone_10_full_region_streaming, milestone_10_tile_layer, milestone_10_passage_tile, milestone_10_no_portal_transition, open_passage_transition, isometric_perimeter_wall, isometric_block_props, milestone_10_legacy_cleanup, milestone_10_isometric_performance, milestone_10_cross_biome_chase, fall_boundary_visual_logic, zombie_fall_hazard, player_dodge_gap, exploration_map, zombie_biome_transition, zombie_environment_milestone, biome_world_generation _(re-bucket da A1: integrazione main.tscn)_ |
| A3 | **Obstacles & Collision** ✅ | `obstacles/` | milestone_4_obstacle_collision, obstacle_3x3, obstacle_rendering_contract, scalable_obstacle |
| A4 | **Assets & Manifests** ✅ | `assets/` | milestone_10_asset_manifest_v7, milestone_10_asset_fallback_policy, milestone_10_asset_pipeline, milestone_10_object_asset, milestone_10_void_cliff_asset, isometric_environment_manifest, rpg_character_asset_manifest, forest_grass_generated_texture, void_cliff_generated_texture, forest_isometric_texture_transition, biome_obstacle_generation _(re-bucket da A1: categorie manifest)_ |
| A5 | **Combat, Weapons & Drops** ✅ | `combat/` | combat, rpg_melee_attack_resolution, milestone_rpg_3_weapons, milestone_rpg_4_hitbox, milestone_rpg_5_ammo_reload, weapon_inventory_catalog, weapon_visual_catalog, weapon_held_hud_visual_identity, weapon_melee_visual_identity, weapon_pickup_visual_identity, weapon_projectile_vfx_identity, milestone_11_weapon_drop_progression, milestone_13_weapon_tower_visual, enemy_drop, biome_status_effects _(re-bucket da A1: BiomeStatusRuntime/health)_ |
| A6 | **Enemies & Bosses** ✅ | `enemies/` | zombie_biome_enemy, zombie_biome_wave_director, zombie_spawner_edge, milestone_12_enemy_variants, milestone_15_ranged_enemy, boss, milestone_11_boss_telegraph, milestone_19_boss_registry, offscreen_enemy_markers |
| A7 | **Characters, RPG & Progression** ✅ | `progression/` | milestone_rpg_1_character_select, milestone_rpg_2_stats, milestone_rpg_6_xp_level, milestone_rpg_7_passives, milestone_rpg_8_adrenaline_super, milestone_rpg_11_data_driven, milestone_rpg_13_new_classes, character_select_ui, character_select_independent, all_modes_character_system, milestone_16_downed_revive, player_query |
| A8 | **Game Modes & Waves** ✅ | `modes/` | survival_wave, tower_defense, dungeon, dungeon_graph, zombie_revamp_foundation, zombie_market, zombie_survival_world_contract, infinite_arena_default_mode, milestone_20_arena_environment, random_encounter, wave_cycle, milestone_9, biome_mini_events _(re-bucket da A1: RandomEncounterSystem)_ |
| A9 | **UI, HUD, Audio, Settings & Feedback** | `ui_audio/` | milestone_rpg_9_hud, milestone_rpg_12_feedback, player_world_hud_layout, milestone_17_run_results, pause_settings, milestone_21_visual_settings_performance, biome_debug_overlay, game_log, milestone_18_audio_mix |
| A10 | **Balance & Metrics** | `balance/` | milestone_12_balance_metrics, milestone_12_zombie_balance_metrics, milestone_rpg_10_balance |

**Infra/Core** (helper, non test): `headless_shutdown_loop`, `test_scene_lifecycle`,
`golden_world` → confluiscono nelle utility condivise di M0.

**Differiti a M-FINAL** (per scelta di scope): i ~24 `*_qa.gd` Visual QA e i soak/
stress (`milestone_20_arena_stress`, `zombie_revamp_ten_minute_soak`,
`zombie_revamp_ten_wave`).

---

## 5. Convenzioni della nuova suite

- **Base class:** ogni suite `extends GutTest`, file `tests/suites/<area>/<nome>_test.gd`.
- **Fixture condivisa:** `before_all()` costruisce il mondo golden via
  `GoldenWorld` (riuso dell'helper esistente); `after_all()` fa teardown con la
  logica già in [tests/test_scene_lifecycle.gd](tests/test_scene_lifecycle.gd).
- **Determinismo:** seed sempre dal `GoldenWorld.SEED` (= `GameConstants.GOLDEN_WORLD_SEED`).
- **Asincronia:** `await wait_frames(n)` / `await wait_physics_frames(n)` di GUT al
  posto dei loop manuali `await process_frame`.
- **Parametrizzazione:** varianti omogenee (biomi, armi, manifest) via
  `use_parameters([...])`, una funzione al posto di N file.
- **Niente milestone nel nome:** i nomi descrivono il comportamento
  (`weapon_ammo_reload_test.gd`, non `milestone_rpg_5_*`).
- **Categorie via tag GUT** (`-ginner_class`, gruppi) invece che pattern sul filename.

---

## 6. Milestone

### M0 — Fondazione GUT + utility condivise
- **Obiettivo:** installare GUT e creare le fondamenta riusabili senza ancora
  toccare i test legacy.
- **Attività:**
  - Vendorizzare `addons/gut/` (GUT 9.6.0) e committarlo (verificare che
    `.gitignore` non escluda `addons/`; i `.uid` rigenerati sono ignorati, ok).
  - Creare `tests/suites/` e `tests/support/` (estendere l'attuale `support/`).
  - Base fixture condivisa `tests/support/golden_world_fixture.gd` che incapsula
    boot/teardown del mondo golden, costruita sopra `GoldenWorld` e
    `TestSceneLifecycle`.
  - `.gutconfig.json` con `dirs=["res://tests/suites"]`, `include_subdirs=true`.
- **Criterio di accettazione:** `godot --headless -s res://addons/gut/gut_cmdln.gd
  -gconfig=.gutconfig.json -gexit` parte verde con una suite di esempio (1 test).

### M1 — Pilota: prima area + baseline tempi ✅ FATTA
- **Obiettivo:** convertire **A1 (World Generation & Determinism)** come pilota e
  validare il pattern di fixture condivisa + accorpamento.
- **Esito:** 11 file legacy → **3 suite GUT** (`world_gfirmen/golden_seed_test.gd`,
  `biome_map_test.gd`, `voidfirst_generation_test.gd`) + helper
  `tests/support/world_gen_helpers.gd`. Build condivise: la mappa 3x3 e il layout
  void-first si costruiscono una sola volta in `before_all`; il determinismo
  void-first è accorpato (da ~12 build a 2). 32 test world_gen / 316 asserzioni
  totali verdi. Cancellati gli 11 file legacy + `.uid`.
- **Re-bucket della tassonomia:** 4 file che la bozza A1 includeva ma che
  appartengono ad altre aree NON sono stati toccati e migreranno nella loro
  milestone: `biome_world_generation`→A2, `biome_obstacle_generation`→A4,
  `biome_status_effects`→A5, `biome_mini_events`→A8.
- **Baseline tempi (locale, Godot 4.6.3, post-import):** legacy A1 (11 boot)
  **~230s** → GUT world_gen (1 boot) **~130s** = **1.8x**. Area compute-bound
  (le build 500x500 dominano sul boot): le aree leggere renderanno molto di più
  con l'eliminazione dei boot.
- **Criterio di accettazione:** ✅ copertura ≥ legacy; suite A1 verde; nessun file
  legacy A1 residuo; baseline documentata.

### M2 — A2 Environment, Streaming & Graph ✅ FATTA (20/20 file)
- **Obiettivo:** convertire l'area più grande sfruttando build di mondo condivise
  per suite.
- **Esito (6 suite GUT, in-place, ognuna con commit dedicato):**
  - `world_graph_streaming_test.gd` ← world_graph_connectivity, milestone_7_graph_connectivity, region_streaming
  - `tile_layout_test.gd` ← milestone_10_tile_layer, isometric_block_props, isometric_perimeter_wall
  - `fall_test.gd` ← fall_boundary_visual_logic, player_dodge_gap
  - `passage_tile_test.gd` ← milestone_10_passage_tile
  - `exploration_map_test.gd` ← exploration_map
  - `integration_test.gd` ← cluster di integrazione (10 file che bootavano
    `main.tscn`), in 4 batch: streaming/profilo/cleanup (parte 6), transizioni
    seam (parte 7), biome gen + transizioni multi-step (parte 8), ambiente +
    fall hazard (parte 9). 10 test / 1062 assert verdi.
- **Fixture condivisa nuova:** `tests/support/main_scene_fixture.gd` istanzia
  `main.tscn` UNA volta (la aggancia alla root e la imposta come `current_scene`,
  necessario allo streaming regioni) e (ri)avvia survival per test. NB:
  `set_mode(SURVIVAL)` ricostruisce solo se la modalità è stata fermata prima,
  quindi `after_each` chiama `stop_survival`. I tunable mutati dai test (cooldown
  seam/transizione, move_party, active/neighbor radius, spawn_interval, slot
  multiplayer) sono ripristinati in `before_each` per rendere l'ordine irrilevante.
  La fixture è riusabile dalle aree future che bootano `main.tscn` (combat,
  enemies, modes).
- **Nota perf:** il profilo frame del test isometrico usa un tetto di 45 ms (era
  35 ms nel processo dedicato legacy): il boot condiviso GUT ha baseline più alto,
  il tetto resta un guard anti-regressione (una regressione vera è ~100 ms/frame).
- **Criterio di accettazione:** ✅ copertura ≥ legacy; tutti i 20 file legacy A2
  rimossi; cluster di integrazione 10 boot → 1.

### M3 — A3 Obstacles & Collision ✅ FATTA (4/4 file)
- **Esito (2 suite GUT sotto `tests/suites/obstacles/`):**
  - `collision_test.gd` ← milestone_4_obstacle_collision (shape/flag dal manifest,
    collisione runtime rectangle/circle/open, layer/mask dei proiettili, query
    jumpable/non-jumpable, chiavi stabili, proiettile fermato dal muro)
  - `footprint_contract_test.gd` ← obstacle_rendering_contract + obstacle_3x3 +
    scalable_obstacle (footprint a slot, layout autoriali/generati, oggetto
    runtime + Y-sort, identità void/cliff, feature 3x3, rocce scalabili, e il
    controllo su main.tscn — l'unico boot, isolato nell'ultimo test via fixture)
- **Manifest condiviso** caricato una volta in before_all; i layout 500x500 si
  costruiscono solo nei test che li verificano. Niente assert su pixel (restano nei
  Visual QA differiti `obstacle_3x3_visual_qa`/`obstacle_asset_visual_qa`).
- 15 test / 490 assert verdi, ~30s (area leggera, no boot ripetuto del mondo).
- **Criterio di accettazione:** ✅ copertura ≥ legacy (collisione, 3x3, rendering
  contract, scalabilità); legacy A3 rimossi.

### M4 — A4 Assets & Manifests ✅ FATTA (11/11 file)
- **Esito (7 suite GUT sotto `tests/suites/assets/`):**
  - `manifest_contract_test.gd` ← milestone_10_asset_manifest_v7 +
    isometric_environment_manifest + biome_obstacle_generation (con UNA megamappa
    3x3 condivisa per la copertura degli id generati)
  - `asset_pipeline_test.gd` ← milestone_10_asset_pipeline
  - `character_asset_test.gd` ← rpg_character_asset_manifest
  - `asset_fallback_test.gd` ← milestone_10_asset_fallback_policy (con boot di
    main.tscn via fixture per il percorso runtime)
  - `generated_texture_test.gd` ← forest_grass_generated_texture +
    void_cliff_generated_texture + forest_isometric_texture_transition
  - `object_asset_test.gd` ← milestone_10_object_asset
  - `void_cliff_asset_test.gd` ← milestone_10_void_cliff_asset (3x3 condivisa per
    metadati di lato + hazard runtime)
- **Nota:** assert su esistenza/contratto manifest e tileability strutturale di
  bordo, non su qualità artistica dei pixel (quella resta nei Visual QA differiti).
- 49 test / 7218 assert verdi (~3m10s).
- **Criterio di accettazione:** ✅ copertura ≥ legacy; tutti gli 11 file legacy A4
  rimossi.

### M5 — A5 Combat, Weapons & Drops ✅ FATTA (15/15 file)
- **Esito (4 suite GUT sotto `tests/suites/combat/`):**
  - `combat_test.gd` ← combat (boot main.tscn) + rpg_melee_attack_resolution +
    milestone_rpg_4_hitbox
  - `weapon_catalog_test.gd` ← milestone_rpg_3_weapons + milestone_rpg_5_ammo_reload
    + weapon_inventory_catalog
  - `weapon_visual_test.gd` ← weapon_visual_catalog + i 4 weapon_*_visual_identity
    (contratti di shape/VFX, niente confronto di pixel)
  - `drops_test.gd` ← milestone_11_weapon_drop_progression +
    milestone_13_weapon_tower_visual + enemy_drop + biome_status_effects
- **Note:** `WeaponEffectResolver.resolve_impact`/`process_runtime` ricevono
  `get_tree()` (SceneTree) al posto di `self`. Il check delle HUD card (tower) ha
  bisogno di più frame idle nel processo GUT condiviso perché l'HUD rinfresca le
  card nel `_process` (8 frame invece di 2).
- 20 test / 1639 assert verdi (~3m, dominato dai 3 boot di main.tscn in drops).
- **Criterio di accettazione:** ✅ copertura ≥ legacy (fuoco, danno, reload, ammo,
  inventario, drop progression, identità visiva, tower, status); legacy A5 rimossi.

### M6 — A6 Enemies & Bosses ✅ FATTA (9/9 file)
- **Esito (2 suite GUT sotto `tests/suites/enemies/`):**
  - `enemies_test.gd` ← zombie_biome_enemy + zombie_biome_wave_director +
    zombie_spawner_edge + milestone_12_enemy_variants + milestone_15_ranged_enemy
    + offscreen_enemy_markers
  - `boss_test.gd` ← boss + milestone_11_boss_telegraph + milestone_19_boss_registry
- Ogni test riusa il boot di main.tscn via `main_scene_fixture` (9 boot, uno per
  test). 9 test / 253 assert verdi (~4m17s).
- **Criterio di accettazione:** ✅ copertura ≥ legacy (varianti nemici, ranged,
  spawner, telegraph, registry boss, marker offscreen); legacy A6 rimossi.

### M7 — A7 Characters, RPG & Progression ✅ FATTA (12/12 file)
- **Esito (3 suite GUT sotto `tests/suites/progression/`):**
  - `rpg_progression_test.gd` ← milestone_rpg_2_stats + milestone_rpg_6_xp_level +
    milestone_rpg_7_passives + milestone_rpg_8_adrenaline_super +
    milestone_rpg_11_data_driven + milestone_rpg_13_new_classes
  - `character_select_test.gd` ← milestone_rpg_1_character_select +
    all_modes_character_system + character_select_ui + character_select_independent
  - `downed_revive_test.gd` ← milestone_16_downed_revive + player_query
- **Note:** i player sintetici di PlayerQuery usano uno script-risorsa reale
  (`tests/support/player_stub.gd`) perché GUT chiama `inst_to_dict()` sugli oggetti
  e fallisce sugli script generati a runtime. Il rilevamento di sconfitta delle
  modalità (`_process` che controlla `any_alive`) richiede qualche frame idle in
  più nel processo GUT (5 invece di 2).
- 12 test / 269 assert verdi (~4m38s).
- **Criterio di accettazione:** ✅ copertura ≥ legacy (character select, stats, xp,
  passive, adrenalina/super, classi, downed/revive, data-driven); legacy A7 rimossi.

### M8 — A8 Game Modes & Waves ✅ FATTA (13/13 file)
- **Esito (3 suite GUT sotto `tests/suites/modes/`):**
  - `core_modes_test.gd` ← survival_wave + tower_defense + dungeon + dungeon_graph
  - `zombie_modes_test.gd` ← zombie_revamp_foundation + zombie_market +
    zombie_survival_world_contract + infinite_arena_default_mode +
    milestone_20_arena_environment
  - `encounters_test.gd` ← wave_cycle + random_encounter + biome_mini_events +
    milestone_9 (menu/save/audio)
- **Note:** (1) gli status HUD per modalità si rinfrescano nel `_process`, servono
  alcuni frame idle dopo `set_mode`; (2) il posizionamento dei player agli spawn
  dell'arena è sincrono e la separazione fisica li sposta già al primo frame →
  match catturato prima di ogni await; (3) `RandomEncounterSystem` risolve il
  container via `current_scene`, quindi le scene sintetiche vanno agganciate alla
  root e impostate come `current_scene`.
- 13 test / 577 assert verdi (~12m, dominato dai boot di main.tscn).
- **Criterio di accettazione:** ✅ copertura ≥ legacy (survival, tower defense,
  dungeon, zombie revamp/market/contract, arena, encounter, wave cycle); legacy
  A8 rimossi.

### M9 — A9 UI, HUD, Audio, Settings & Feedback ✅ FATTA (9/9 file)
- **Esito (5 suite GUT sotto `tests/suites/ui_audio/`):**
  - `player_hud_test.gd` ← milestone_rpg_9_hud + player_world_hud_layout +
    milestone_rpg_12_feedback (solo player.tscn, niente boot di main.tscn)
  - `run_results_test.gd` ← milestone_17_run_results (boot main.tscn:
    survival/dungeon/tower)
  - `settings_test.gd` ← pause_settings + milestone_21_visual_settings_performance
    (un boot main.tscn per test, isolato per via dei rebind input/slot globali)
  - `audio_mix_test.gd` ← milestone_18_audio_mix (boot main.tscn + cue survival)
  - `diagnostics_test.gd` ← biome_debug_overlay (scena sintetica + current_scene)
    + game_log (gating per livello, logica pura)
- **Note:** (1) i tre test HUD usano solo `player.tscn` (boot leggero) e non
  condividono l'istanza perche mutano stato RPG distinto (XP/adrenalina/effetti);
  (2) pause_settings e visual_settings bootano main.tscn isolatamente perche
  mutano stato globale (InputMap, slot multiplayer, profili visivi); (3) il tetto
  del profilo frame del milestone_21 passa da 35 ms a **45 ms**, allineato al tetto
  gia adottato in M2 per il profilo isometrico nel processo GUT condiviso (baseline
  di boot piu alta; una regressione vera resta ~100 ms/frame).
- 9 test / ~188 assert (alcune in loop) sotto un unico processo GUT.
- **Criterio di accettazione:** ✅ copertura ≥ legacy (hud, feedback, run results,
  pause/settings, audio mix, debug overlay, game log); tutti i 9 file legacy A9
  rimossi.

### M10 — A10 Balance & Metrics ✅ FATTA (3/3 file)
- **Esito (2 suite GUT sotto `tests/suites/balance/`):**
  - `weapon_balance_test.gd` ← milestone_rpg_10_balance (registry classi + WeaponData,
    logica pura senza scena)
  - `wave_metrics_test.gd` ← milestone_12_balance_metrics + milestone_12_zombie_balance_metrics
    (entrambi bootano main.tscn, uno per test via fixture)
- **Accorpamento:** la raccolta metriche via segnali (wave_started/configured/
  enemy_spawned/completed, drop, damage, boss) era duplicata quasi identica nei due
  milestone_12: ora vive in handler condivisi nella suite. Un flag `_track_boss`
  distingue il picco di vivi dell'arena (conta anche il boss) da quello survival
  (solo nemici d'ondata); i segnali boss si collegano solo nello scenario arena.
  Lo stato metriche viene resettato e i segnali riconnessi all'inizio di ogni test
  sulla nuova istanza di main.tscn; un flag `_metrics_active` blocca gli handler
  dopo il teardown.
- **Note:** le attese d'ondata usano `await get_tree().physics_frame` in loop con
  tetto di frame come nei legacy (1200/360 arena, 900/300 survival). I nemici
  spawnati ricevono `set_physics_process(false)` e una loot table money garantita
  per metriche deterministiche, come nel legacy.
- 3 test / ~90 assert (alcune in loop) sotto un unico processo GUT.
- **Criterio di accettazione:** ✅ copertura ≥ legacy (balance metrics, zombie
  balance, rpg balance); tutti i 3 file legacy A10 rimossi.

### M-FINAL — Cutover, soak e Visual QA
- **Obiettivo:** chiudere la transizione.
- **Attività:**
  - Migrare i soak/stress in una cartella GUT dedicata `tests/suites/soak/` con
    tag escluso dal run rapido (eseguito solo su richiesta / notturno).
  - Decidere e attuare i Visual QA: mantenerli come tool a parte (lista esplicita)
    oppure incapsularli in GUT con asserzioni sui contratti, lasciando lo
    screenshot come artefatto.
  - **Ritirare** `tools/run_tests.sh` / `.ps1` legacy (o ridurli a wrapper di GUT).
  - Aggiornare `.github/workflows/ci.yml` per usare solo GUT.
  - Verifica finale: zero file legacy `extends SceneTree` in `tests/*.gd`.
- **Criterio di accettazione:** CI verde con il solo runner GUT; nessun residuo
  legacy; documentazione aggiornata.

---

## 7. Aggiornamento CI (transizione)

Durante M1→M10 la CI esegue **due step** in `ci.yml`:

1. **Legacy (decrescente):** `bash tools/run_tests.sh` sui file `tests/*.gd`
   ancora non migrati (il runner attuale fa già glob non ricorsivo, quindi
   **non** raccoglie `tests/suites/**` — nessun doppio-run).
2. **GUT (crescente):** `godot --headless -s res://addons/gut/gut_cmdln.gd
   -gconfig=.gutconfig.json -gexit`.

A M-FINAL resta solo lo step GUT.

---

## 8. Rischi e mitigazioni

| Rischio | Mitigazione |
| --- | --- |
| Fixture condivisa che "sporca" lo stato tra test | `before_each`/`after_each` per reset mirato; teardown rigoroso in `after_all`. |
| Perdita di copertura nell'accorpamento | Regola fissa: ogni milestone deve avere copertura **≥** legacy prima di cancellare; diff delle asserzioni nel PR. |
| GUT instabile in headless su Godot 4.6 | M0 valida l'invocazione headless prima di qualsiasi migrazione. |
| `.uid`/import su checkout pulito (CI) | Mantenere lo step `--import` prima del run, come oggi. |
| Visual QA difficili da automatizzare | Esplicitamente differiti a M-FINAL, fuori dallo scope logica. |

## 9. Rollback

Migrazione in-place ma reversibile per area: ogni milestone è un PR atomico che
rimuove i legacy di **una** area. Un revert del PR ripristina i file legacy di
quell'area senza toccare le altre.

---

## 10. Checklist di avanzamento

- [x] M0 — Fondazione GUT + utility condivise ✅ (GUT 9.6.0 vendorizzato, `.gutconfig.json`, fixture condivisa, suite bootstrap 4/4 verde, CI doppio runner, wrapper `tools/run_gut.*`)
- [x] M1 — A1 World Generation & Determinism ✅ (11 file → 3 suite GUT; baseline 230s→130s = 1.8x; 4 file re-bucketati ad A2/A4/A5/A8)
- [x] M2 — A2 Environment, Streaming & Graph ✅ (20/20 file → 6 suite GUT; cluster di integrazione 10 boot main.tscn → 1 via fixture condivisa; 10 test/1062 assert verdi)
- [x] M3 — A3 Obstacles & Collision ✅ (4/4 file → 2 suite GUT; 15 test/490 assert verdi, ~30s)
- [x] M4 — A4 Assets & Manifests ✅ (11/11 file → 7 suite GUT; 49 test/7218 assert verdi, ~3m10s)
- [x] M5 — A5 Combat, Weapons & Drops ✅ (15/15 file → 4 suite GUT; 20 test/1639 assert verdi)
- [x] M6 — A6 Enemies & Bosses ✅ (9/9 file → 2 suite GUT; 9 test/253 assert verdi)
- [x] M7 — A7 Characters, RPG & Progression ✅ (12/12 file → 3 suite GUT; 12 test/269 assert verdi)
- [x] M8 — A8 Game Modes & Waves ✅ (13/13 file → 3 suite GUT; 13 test/577 assert verdi)
- [x] M9 — A9 UI, HUD, Audio, Settings & Feedback ✅ (9/9 file → 5 suite GUT; player HUD/feedback, run results, settings/pausa, audio mix, diagnostica; 9 test/~188 assert)
- [x] M10 — A10 Balance & Metrics ✅ (3/3 file → 2 suite GUT; raccolta metriche d'ondata condivisa fra arena e zombie survival; 3 test/~90 assert)
- [ ] M-FINAL — Cutover + soak + Visual QA
