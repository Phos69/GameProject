# TODO

Questo file contiene solo backlog operativo, follow-up tracciati e reference
storiche consolidate. I dettagli completi delle milestone gia chiuse restano in
`ROADMAP.md`, `CHANGELOG.md`, `docs/milestones/`, nelle roadmap dedicate e nel
report `docs/latest_commit_validation_report.md`.
L'audit operativo del 2026-06-20 e tracciato in `repo_status_report.md` e
`repo_fix_roadmap.md`.
La Milestone 1 di `repo_fix_roadmap.md` e completata: runner PowerShell,
categorie test e log persistenti sono il workflow corrente.
La Milestone 2 di `repo_fix_roadmap.md` e completata: il contratto
`Zombie Survival` usa il default `3x3` multi-bioma e l'arena `1x1` e solo un
profilo context esplicito.
La Milestone 3 di `repo_fix_roadmap.md` e completata con validazione mirata:
`Infinite Arena` e il default `1x1` murato, mentre `Zombie Survival` resta la
modalita `3x3` multi-bioma.
La Milestone 4 di `repo_fix_roadmap.md` e completata: il contratto HUD separa
corner card, world-space HUD e aggregazione, con reload/caricatore/XP/super
unicamente nel pacchetto sopra-player.
La Milestone 5 di `repo_fix_roadmap.md` e completata: Character Select espone
di nuovo il dossier personaggio, i test non restano appesi su errori e la
navigazione tastiera/joypad, inclusa la selezione indipendente per giocatore,
e coperta da smoke.
La Milestone 6 di `repo_fix_roadmap.md` e completata: `ZombieSpawner` mantiene
spawn preview e spawn effettivi fuori camera, valida walkable/hazard/blocker in
regioni streamate e usa fallback arena solo se valido.
La Milestone 7 di `repo_fix_roadmap.md` e completata: la Tower Defense possiede
il pannello status persistente, mentre Survival/Infinite Arena lo tengono
nascosto; il profilo Infinite Arena murato non genera fall zone interne.
La Milestone 8 di `repo_fix_roadmap.md` e completata: `WeaponVisualRenderer`
mantiene le API pubbliche ma delega le geometrie procedurali statiche a
`WeaponVisualShapeLibrary`, riducendo il file principale a 460 LOC.
La ripresa M8 ha chiuso un secondo hotspot: `IsometricSvgTextureLoader`
mantiene `load_texture` ma delega i fallback rasterizzati a
`IsometricSvgFallbackTextureBuilder`, scendendo a 136 LOC.
La ripresa M8 ha chiuso anche `IsometricTileResolver`: il catalogo statico di
tile/route vive in `IsometricTileCatalog`, mentre il resolver mantiene gli
alias pubblici; la ripresa finale sposta anche utility statiche in
`IsometricTileResolverUtils` e porta il resolver a 989 LOC.
La ripresa finale M8 ha chiuso `BiomeObstacle`: collisione e metadata restano
nel nodo runtime, mentre muri perimetrali e boundary tematiche sono delegati a
`BiomeObstaclePainter`; l'entry point scende a 961 LOC.
La Milestone 9 di `repo_fix_roadmap.md` e completata come prima passata:
lookup globali ridotti da 216 a 184 nel codice `game/`, con injection mirata
per player, HUD e spawner.
La Milestone 10 di `repo_fix_roadmap.md` e completata: fallback asset
classificati, manifest standard senza status temporanei, survival asset-driven
protetta da guardrail contro placeholder/generic e visual legacy.
La Milestone 11 di `repo_fix_roadmap.md` e completata: un guardrail
end-to-end copre pickup armi, switch inventario, ammo/reload, kill zombie,
drop fisico, XP RPG, level-up, passiva e feedback nel runtime survival reale.

Regole per nuove voci:

- ogni item aperto deve indicare obiettivo, milestone collegata, file/sistemi,
  criterio di accettazione e test richiesto;
- non riaprire milestone completate senza un nuovo goal esplicito;
- aggiornare questa TODO solo a fine lavoro quando una milestone cambia stato.

## Baseline tecnica - audit Milestone 0 del 2026-06-17

| Area | Stato noto | Evidenza | Prossima azione |
| --- | --- | --- | --- |
| Documentazione principale | Rivista | `README.md`, `ROADMAP.md`, `ARCHITECTURE.md`, `GAME_DESIGN.md`, `TODO.md`, report test e checklist manuale | Mantenere allineata durante le milestone successive |
| Test discovery | 75 runner trovati | `rg --files tests` | Usare come inventario per regressioni future |
| Suite smoke | PASS nella validazione Milestone 1 | `docs/latest_commit_validation_report.md` | Rieseguire dopo modifiche runtime o teardown |
| Build/export Windows | PASS nell'ultima validazione completa disponibile | `docs/latest_commit_validation_report.md` | Rieseguire in Milestone 12 o se cambia packaging |
| Shutdown headless | Risolto nella Milestone 1 | Loop 100 avvii main scene e smoke prioritari senza cleanup warning noti | Monitorare solo come regressione futura |
| Mini-eventi bioma | PASS nella validazione Milestone 2 | `tests/biome_mini_events_smoke_test.gd`, `tests/random_encounter_smoke_test.gd`, `docs/latest_commit_validation_report.md` | Riprendere solo dentro playtest/bilanciamento Milestone 11 |
| Default Infinite Arena | PASS nella validazione Milestone 3 repo-fix | `tests/infinite_arena_default_mode_smoke_test.gd`, `tests/zombie_survival_world_contract_smoke_test.gd`, `tests/milestone_9_smoke_test.gd`, `tests/milestone_17_run_results_smoke_test.gd` | Playtest manuale dei bordi murati e di `Zombie Survival` multi-bioma nella prossima iterazione |
| Character Select e menu navigation | PASS nella validazione Milestone 5 repo-fix | `tests/milestone_rpg_1_character_select_smoke_test.gd`, `tests/character_select_ui_smoke_test.gd`, `tests/character_select_independent_smoke_test.gd`, `tests/menu_visual_qa.gd` | Monitorare solo come regressione UI o nel playtest `UIUX-001` |
| Spawn zombie fuori camera | PASS nella validazione Milestone 6 repo-fix | `tests/zombie_spawner_edge_smoke_test.gd`, `tests/zombie_revamp_foundation_smoke_test.gd`, `tests/biome_world_generation_smoke_test.gd`, `tests/milestone_10_cross_biome_chase_smoke_test.gd`, `tests/zombie_fall_hazard_smoke_test.gd`, `tests/zombie_revamp_ten_wave_smoke_test.gd` | Monitorare come regressione survival, soprattutto vicino a void, blocker e cambi regione |
| HUD Tower Defense e arena murata | PASS nella validazione Milestone 7 repo-fix | `tests/tower_defense_smoke_test.gd`, `tests/milestone_10_visual_smoke_test.gd`, `tests/survival_wave_smoke_test.gd`, `tests/dungeon_smoke_test.gd`, `tests/zombie_survival_world_contract_smoke_test.gd`, `tests/infinite_arena_default_mode_smoke_test.gd` | Monitorare come regressione HUD modalita o world generation arena `walled` |
| Refactor weapon visual renderer | PASS nella validazione Milestone 8 repo-fix | `WeaponVisualRenderer` 460 LOC, `WeaponVisualShapeLibrary` 808 LOC, `tests/weapon_visual_catalog_smoke_test.gd`, `tests/weapon_pickup_visual_identity_smoke_test.gd`, `tests/weapon_held_hud_visual_identity_smoke_test.gd`, `tests/weapon_projectile_vfx_identity_smoke_test.gd`, `tests/weapon_melee_visual_identity_smoke_test.gd` | Monitorare come regressione presentazionale armi; prossimi hotspot M8 richiedono goal separati |
| Refactor SVG fallback loader | PASS nella ripresa Milestone 8 repo-fix | `IsometricSvgTextureLoader` 1022 -> 136 LOC, `IsometricSvgFallbackTextureBuilder` 908 LOC, `tests/milestone_10_asset_pipeline_smoke_test.gd`, `tests/milestone_10_object_asset_smoke_test.gd`, `tests/isometric_environment_manifest_smoke_test.gd` | Monitorare come regressione asset isometrici; prossimi hotspot M8 richiedono goal separati |
| Refactor tile resolver catalog/utils | PASS nella ripresa Milestone 8 repo-fix | `IsometricTileResolver` 1090 -> 989 LOC, `IsometricTileCatalog` 226 LOC, `IsometricTileResolverUtils` 29 LOC, `tests/milestone_10_tile_layer_smoke_test.gd`, `tests/milestone_10_void_cliff_asset_smoke_test.gd`, `tests/forest_isometric_texture_transition_smoke_test.gd`, `tests/isometric_environment_manifest_smoke_test.gd` | Monitorare come regressione resolver tile; `tests/milestone_10_passage_tile_smoke_test.gd` resta follow-up separato `BUG-001` |
| Refactor BiomeObstacle painter | PASS nella ripresa finale Milestone 8 repo-fix | `BiomeObstacle` 1226 -> 961 LOC, `BiomeObstaclePainter` 342 LOC, `tests/obstacle_rendering_contract_smoke_test.gd`, `tests/obstacle_3x3_smoke_test.gd`, `tests/milestone_10_object_asset_smoke_test.gd`, `tests/milestone_10_void_cliff_asset_smoke_test.gd`, `tests/forest_isometric_texture_transition_smoke_test.gd`, `tests/milestone_10_tile_layer_smoke_test.gd`, `tests/isometric_environment_manifest_smoke_test.gd`, `tests/obstacle_asset_visual_qa.gd`, `tests/obstacle_3x3_visual_qa.gd` | Monitorare come regressione render procedurale fallback; prossimi hotspot grandi richiedono goal separati |
| Dependency lookup player/HUD/spawner | PASS nella validazione Milestone 9 repo-fix | `get_first_node_in_group` in `game/` 216 -> 184; `HUDManager` 22 -> 1, `PlayerController` 6 -> 1, `ZombieSpawner` 7 -> 1; `tests/player_query_smoke_test.gd`, `tests/player_world_hud_layout_smoke_test.gd`, `tests/zombie_spawner_edge_smoke_test.gd`, `tests/survival_wave_smoke_test.gd`, `tests/tower_defense_smoke_test.gd` | Proseguire solo con goal separati su altri hotspot come `AudioEventRouter`, `BasicEnemy`, `MainMenu` o mode controller |
| Asset fallback policy M10 | PASS nella validazione Milestone 10 repo-fix | `docs/repo_fix_milestone_10_asset_fallback_policy.md`, `tests/milestone_10_asset_fallback_policy_smoke_test.gd`, asset generator `--check`, smoke manifest/legacy/object/cliff/tile e QA visuale finale M10 | Monitorare come regressione asset/fallback; nuovi status `needs_asset`/`procedural_fallback`/`deprecated` richiedono fallback path esplicito e TODO collegata |
| Weapon/drop/progressione M11 | PASS nella validazione Milestone 11 repo-fix | `tests/milestone_11_weapon_drop_progression_smoke_test.gd`, suite weapon fast 8 smoke, suite RPG fast 13 smoke, `tests/combat_smoke_test.gd`, `tests/enemy_drop_smoke_test.gd`, `tests/survival_wave_smoke_test.gd` | Monitorare come regressione integrata di inventario armi, ammo/reload, XP RPG, drop fisici e feedback; tuning futuro resta in `BAL-001` |
| Megamappa e streaming regioni | PASS nella validazione Milestone 3 | `tests/region_streaming_smoke_test.gd`, world graph, persistent world, open passage, exploration map, `docs/latest_commit_validation_report.md` | Riprendere in Milestone 4 (asset isometrici) o nel bilanciamento Milestone 11 |
| Caduta void e dodge | PASS nel pass runtime 2026-06-19 | `EntityVoidFallComponent`, query terrain di `HazardSystem`, `tests/zombie_fall_hazard_smoke_test.gd`, regressioni combat/drop/wave/ranged/terrain | QA manuale multiplayer locale e leggibilita animazione nel playtest Milestone 11 |
| Asset isometrici ambiente | PASS; contratto footprint v9 e primo pass albero/roccia 3x3 completati il 2026-06-20 | `tests/obstacle_rendering_contract_smoke_test.gd`, `tests/obstacle_3x3_smoke_test.gd`, `tests/obstacle_asset_visual_qa.gd`, `tests/obstacle_3x3_visual_qa.gd`, screenshot `build/qa/obstacle_3x3/`, `docs/obstacle_rendering.md`, manifest v9 | QA manuale player davanti/dietro e verifica `F9` nel playtest Milestone 11 |
| Audit migrazione isometrica | PASS completo: Milestone 1-9 e Milestone 10.1-10.11 chiuse con asset, cliff, transizione senza portali, vicini gameplay `FULL`, chase cross-bioma, cleanup legacy, QA screenshot e performance | `docs/isometric_generation_audit_roadmap.md`, `milestone_10_isometric_asset_rewrite_roadmap.md`, manifest ambiente v7, `BiomeTileLayer`, `IsometricTileResolver`, `IsometricEnvironmentObjectFactory`, `IsometricSvgTextureLoader`, `RegionSeamSystem`, `WorldRegionStreamer`, smoke e QA Milestone 10.11 | Monitorare solo come regressione futura o playtest visuale |
| Dungeon ramificato/shop | PASS nella validazione Milestone 5 | `tests/dungeon_graph_smoke_test.gd`, `tests/dungeon_smoke_test.gd`, `docs/latest_commit_validation_report.md` | UI shop dedicata e arte bioma dungeon restano follow-up; screenshot tre seed nel playtest Milestone 11 |
| Asset/pipeline personaggi RPG | PASS nella validazione Milestone 6 | `tests/rpg_character_asset_manifest_smoke_test.gd`, `assets/characters/index.json` v2, `docs/latest_commit_validation_report.md` | Arte definitiva per-personaggio (`final_quality`) resta follow-up manuale; screenshot QA nel playtest Milestone 11 |
| Tuning melee, super e classi RPG avanzate | PASS nella validazione Milestone 7 | `tests/rpg_melee_attack_resolution_smoke_test.gd`, `tests/milestone_rpg_8_adrenaline_super_smoke_test.gd`, `tests/milestone_rpg_12_feedback_smoke_test.gd`, `tests/milestone_rpg_13_new_classes_smoke_test.gd` | QA manuale multi-risoluzione/five-wave/due-player resta follow-up nel playtest Milestone 11 |
| Mercato zombie ricorrente | PASS il 2026-06-20 | `SurvivalMarketController`, `SurvivalMarketPurchaseService`, `SurvivalMarketUI`, `tests/zombie_market_smoke_test.gd`, `docs/zombie_market.md` | Bilanciamento prezzi e QA visuale 1-4 player confluiscono in `BAL-001`/`UIUX-001` |
| Roadmap storiche | Completate come primo pass o reference | `ROADMAP.md`, `roadmap_*.md`, `docs/milestones/` | Non usarle come backlog attivo se una voce e gia chiusa qui sotto |

Test eseguiti per questo audit: nessun test gameplay. La Milestone 0 richiede
revisione manuale, baseline e consolidamento TODO.

## Backlog aperto prioritizzato

### UIUX-001 - UI, HUD, audio e polish UX trasversale

- Avanzamento 2026-06-20: completato il pass del faceplate world-space con
  livello/EXP al posto di P1-P4, vita cromatica sulle due righe superiori,
  super verticale blu con glow e testi HP/ammo piu leggibili; restano menu, HUD
  globale, audio e QA completa multi-risoluzione.
- Obiettivo: rifinire menu, HUD, Character Select, status, mappa, boss, feedback
  audio e leggibilita senza cambiare regole di gioco.
- Milestone collegata: `todo_roadmap.md` Milestone 8.
- File/sistemi coinvolti: `game/ui/`, `game/audio/`, `assets/audio/`,
  `game/visuals/`, `game/settings/`, `docs/testing/manual_checklist.md`.
- Criterio di accettazione: focus joypad sempre visibile, informazioni critiche
  leggibili senza testo piccolo, nessun SFX esterno obbligatorio e audio
  critico udibile con quattro player e boss wave.
- Test richiesto: QA menu/Character Select/Settings a 1280x720, 1024x768 e
  960x540, QA survival con quattro player, `character_select_ui`,
  `pause_settings` e regressione audio mix.

### BOSS-001 - Boss aggiuntivi e pattern avanzati

- Obiettivo: espandere il registro boss con un nuovo boss o pattern avanzati
  mantenendo il contratto condiviso tra modalita.
- Milestone collegata: `todo_roadmap.md` Milestone 9.
- File/sistemi coinvolti: `game/bosses/`, `game/visuals/`,
  `game/projectiles/`, `game/weapons/`, `game/drops/`, `HUDManager`,
  `BossSystem`.
- Criterio di accettazione: boss richiedibile per ID senza cambiare i chiamanti,
  compatibilita per modalita tipizzata, telegraph leggibile senza danno durante
  il warning e drop tramite `DropSystem`.
- Test richiesto: nuovo smoke boss/pattern, regressione `boss_smoke` e
  `milestone_19_boss_registry_smoke_test.gd`, QA survival/dungeon.

### TD-001 - Tower defense avanzata a scope minimo

- Obiettivo: valutare e implementare una sola espansione controllata tra
  upgrade, vendita, riparazione, nuovi tipi torre o percorsi multipli.
- Milestone collegata: `todo_roadmap.md` Milestone 10.
- File/sistemi coinvolti: `game/modes/tower_defense/`,
  `DefenseTowerVisual`, `game/weapons/`, `HUDManager`,
  `tests/tower_defense_smoke_test.gd`.
- Criterio di accettazione: la tower defense resta giocabile, non duplica
  combat/projectile/boss, ogni nuova azione ha costo e feedback chiari, retry e
  menu puliscono torri, crediti e nemici.
- Test richiesto: estensione `tower_defense_smoke_test`, smoke feature scelta e
  QA tower defense 5 wave con tastiera/joypad.

### QA-001 - Ampliare i test automatici dei sistemi critici

- Obiettivo: coprire meglio health, multiplayer, wave, save/load, world runtime
  e lifecycle oltre agli smoke gia presenti.
- Milestone collegata: `todo_roadmap.md` Milestone 11.
- File/sistemi coinvolti: `tests/`, `HealthSystem`, `LocalMultiplayerManager`,
  `WaveManager`, `SaveManager`, `WorldRuntime`, modalita gameplay.
- Criterio di accettazione: ogni sistema condiviso critico ha almeno uno smoke
  headless o una checklist automatizzabile, e la suite principale resta
  eseguibile con exit code `0`.
- Test richiesto: suite headless completa, nuovi smoke mirati e report test
  aggiornato.

### BUG-001 - Ripristinare passage tile smoke

- Obiettivo: correggere il caso in cui i passaggi sorgente di `biome_0_0`
  generano `passage_type` `snow_pass` ma i probe del resolver vedono
  `road_tags=[broken_street]`, facendo risolvere tile terrain invece di entry,
  exit e connector passage.
- Milestone collegata: follow-up `repo_fix_roadmap.md` Milestone 8 / `QA-001`.
- File/sistemi coinvolti: `BiomeManager`, `BiomeEnvironmentLayout`,
  `WorldGraph`, `IsometricTileResolver`, `tests/milestone_10_passage_tile_smoke_test.gd`.
- Criterio di accettazione: ogni apertura di passaggio generata espone tag
  coerenti con `passage.passage_type` su outer, inner e connector, senza
  rompere route decorative o transizioni forestali.
- Test richiesto: `tests/milestone_10_passage_tile_smoke_test.gd` con exit code
  `0`, piu regressione `tests/milestone_10_tile_layer_smoke_test.gd`.

### BAL-001 - Bilanciamento, performance e playtest end-to-end

- Obiettivo: affinare valori data-driven e performance dopo playtest reali su
  survival, dungeon, tower defense, RPG, biomi e boss.
- Milestone collegata: `todo_roadmap.md` Milestone 11.
- File/sistemi coinvolti: `game/modes/`, `game/rpg/`, `game/weapons/`,
  `game/enemies/`, `game/bosses/`, `game/visuals/`, `tests/`,
  `docs/testing/manual_checklist.md`.
- Criterio di accettazione: survival 10 wave e soak 10 minuti restano stabili,
  ogni classe RPG ha un motivo chiaro per essere scelta, i biomi avanzati sono
  pericolosi ma non frustranti e il frame time resta nel target documentato o
  viene tracciato come debito.
- Test richiesto: playtest survival 20 minuti con 1-4 player, dungeon con tre
  seed, tower defense 5 wave, profiling e regressione smoke principale.

### REL-001 - Packaging, firma digitale e release readiness

- Obiettivo: preparare una build Windows pubblicabile con export ripetibile,
  build smoke, asset attribuiti e firma digitale se il certificato e
  disponibile.
- Milestone collegata: `todo_roadmap.md` Milestone 12.
- File/sistemi coinvolti: `export_presets.cfg`, `build/`,
  `assets/ATTRIBUTION.md`, `assets/README.md`, `README.md`,
  `docs/latest_commit_validation_report.md`, `BuildRuntimeSmoke`.
- Criterio di accettazione: EXE/PCK generati da checkout pulito, build smoke
  exit code `0`, attribuzioni complete, EXE firmato oppure blocco esterno
  documentato.
- Test richiesto: export release, export pack, build smoke, avvio manuale
  Windows con controller/audio e verifica firma se toolchain disponibile.

### DOC-001 - Documentazione finale e workflow di iterazione

- Obiettivo: chiudere la TODO critica, aggiornare documentazione e lasciare un
  workflow chiaro per futuri goal.
- Milestone collegata: `todo_roadmap.md` Milestone 13.
- File/sistemi coinvolti: `README.md`, `ROADMAP.md`, `TODO.md`,
  `CHANGELOG.md`, `ARCHITECTURE.md`, `GAME_DESIGN.md`, `docs/`, `prompts/`.
- Criterio di accettazione: nessun punto TODO critico resta aperto senza owner
  o decisione, README descrive avvio/test/build/stato reale e i documenti
  tecnici non contraddicono il codice.
- Test richiesto: revisione incrociata documenti, avvio principale e build
  smoke solo se la release e nello scope.

## Follow-up e decisioni aperte

Queste decisioni non avviano lavoro da sole; vanno risolte dentro la milestone
collegata prima di implementare.

- Asset personaggi: RISOLTA nella Milestone 6 -> pipeline mista SVG testuale +
  PNG in-repo, gameplay procedurale di fallback, nessun asset esterno
  obbligatorio. `ASSET-002` completata; resta solo l'arte `final_quality` come
  follow-up manuale per-personaggio.
- Dungeon shop: RISOLTA nella Milestone 5 -> usa run credit (valuta di run),
  non denaro party persistente, per non toccare save/progressione. `DUN-001`
  completata.
- Tower defense avanzata: confermare priorita prima di aprire un goal lungo.
  Collegata a `TD-001`.
- Nuovi boss: scegliere nuovo boss o espansione pattern esistenti. Collegata a
  `BOSS-001`.
- Firma digitale: verificare disponibilita certificato e toolchain. Collegata a
  `REL-001`.
- Mini-eventi bioma: durante il playtest end-to-end di `BAL-001`, raccogliere
  screenshot/video reali dei quattro eventi come materiale QA, senza riaprire
  `BIO-001` salvo nuovi bug o tuning richiesti.

## Reference storiche completate

Queste voci sono chiuse come primo pass o prototipo stabile. Restano qui per
evitare reimplementazioni e per indirizzare le regressioni.

- Milestone 0-21 della roadmap principale: completate; riferimento in
  `ROADMAP.md`, `docs/milestones/`, `README.md` e `CHANGELOG.md`.
- Roadmap Revamp Modalita Zombie Z1-Z12: completata; sopravvivono follow-up in
  `MAP-001`, `MAP-002` e `ASSET-001`.
- Roadmap Motore Generazione Mappe e Biomi: completata come primo motore
  procedurale integrato; usare come riferimento per regressioni world/biomi.
- Roadmap Megamappa Persistente Isometrica: completata come primo pass stabile;
  streaming e QA reale (`MAP-001`, `MAP-002`) chiusi nella Milestone 3 di
  `todo_roadmap.md`. Follow-up residuo: profiling/bilanciamento (`BAL-001`).
- MAP-001 QA attraversamento megamappa e MAP-002 streaming regioni: completati
  nella Milestone 3 di `todo_roadmap.md`; contratto `active_regions` formalizzato,
  persistenza runtime per regione (casse aperte non ricompaiono) e round-trip save
  v6 coperti da `tests/region_streaming_smoke_test.gd` e dalle regressioni world
  graph/persistent world/open passage/exploration map. Cattura screenshot reale
  rinviata al playtest Milestone 11. Ledger pronto per ostacoli distruttibili ed
  encounter region-bound futuri (oggi senza trigger di gioco).
- ASSET-001 pass asset isometrici ambiente: completato nella Milestone 4 di
  `todo_roadmap.md`; il manifest `assets/environment/isometric/manifest.json` (v2,
  poi esteso a v3/v4/v5/v6 in `ISO-001` Milestone 1-5)
  e ora letto da `IsometricEnvironmentManifest` e copre gli obstacle_id reali con
  collisione/footprint/sort coerenti, categorie e draw mode oggetto/terrain;
  `BiomeObstacle` ha ombra a terra, `sort_offset` data-driven, draw procedurali
  dedicati per gli ID generati e border tematici per bioma; Y-sort abilitato in
  scena. Rendering procedurale (nessun asset esterno obbligatorio); conversione
  ad arte esterna definitiva e screenshot per bioma restano follow-up opzionali
  (playtest Milestone 11).
  Coperto da `tests/isometric_environment_manifest_smoke_test.gd`.
- ISO-001 coerenza isometrica di terrain, biomi e asset ambiente: completato
  come roadmap dedicata fino alla Milestone 10.11. Il manifest v7, la pipeline
  SVG locale, `BiomeTileLayer`, `IsometricTileResolver`, gli oggetti slot-based,
  cliff/vuoto asset-driven, `RegionSeamSystem`, `WorldRegionStreamer`, metadata
  regione nemici, cleanup legacy, QA screenshot e performance sono chiusi come
  primo pass stabile. Regressioni chiave: smoke Milestone 10.1-10.11,
  `isometric_environment_manifest`, `isometric_biome_terrain_coverage`,
  `fall_boundary_visual_logic`, `player_dodge_gap`,
  `milestone_8_multi_region` e `open_passage_transition`.
- ISO-RW-001 pareti perimetrali, void edge e texture forestali del rewrite
  `500x500`: completato come primo pass stabile. La survival usa pareti
  perimetrali isometriche, fall/void leggibili, varchi fisici senza portali e
  un set forestale asset-driven per `infected_plains` (`forest_grass`,
  `forest_tall_grass`, `forest_path`, `forest_road`, `forest_void`,
  `forest_cliff_edge`, `forest_mountain_wall` e transizioni). Il vertical slice
  starter aggiunge road network edge-to-edge, casa, vegetazione densa
  impassabile, fiume/bridge validato e summary debug deterministico. Coperto da
  `tests/starter_biome_vertical_slice_smoke_test.gd`,
  `tests/forest_isometric_texture_transition_smoke_test.gd`,
  `tests/isometric_biome_generation_rewrite_smoke_test.gd`,
  `tests/isometric_perimeter_wall_smoke_test.gd`,
  `tests/fall_boundary_visual_logic_smoke_test.gd`,
  `tests/milestone_10_tile_layer_smoke_test.gd` e
  `tests/milestone_10_void_cliff_asset_smoke_test.gd`.
- ISO-OBS-001 coerenza ostacoli/footprint: completato il 2026-06-19. Il
  manifest v9 copre slot `1x1`-`3x3` e case grandi, il generatore usa footprint
  canonici, gli SVG dichiarano la dimensione, collisione e base derivano dalle
  stesse celle e `F9` espone l'overlay runtime. Coperto da
  `tests/obstacle_rendering_contract_smoke_test.gd`; resta solo QA manuale
  multiplayer/screenshot dentro `QA-001` e il playtest Milestone 11.
- DUN-001 dungeon ramificato, shop e biomi dedicati: completato nella Milestone 5
  di `todo_roadmap.md`; `DungeonGenerator` produce un grafo con ramo reale e boss
  sempre raggiungibile, `DungeonMode` gestisce scelta stanza, run credit, shop
  (reward via `DropSystem`) e rest room, `DungeonRoom` ha doppia uscita e theming
  per kind. Decisione: shop su run credit, non denaro party. UI shop dedicata e
  arte bioma dungeon restano follow-up. Coperto da
  `tests/dungeon_graph_smoke_test.gd` e `tests/dungeon_smoke_test.gd`.
- ASSET-002 asset e pipeline personaggi RPG: completato nella Milestone 6 di
  `todo_roadmap.md` come pass di coerenza dati. I 7 `RpgCharacterData` hanno tutti
  i path asset popolati e i file presenti in-repo; `portrait_hud_path` uniformato
  al portrait HUD dedicato (fix 4 .tres); weapon layer separato via
  `WeaponData.visual_data`; index.json v2 con status_definitions. Decisione
  formato: pipeline mista SVG testuale + PNG in-repo, gameplay procedurale.
  L'arte definitiva per-personaggio (`final_quality`) resta follow-up manuale.
  Coperto da `tests/rpg_character_asset_manifest_smoke_test.gd` e
  `tests/character_select_ui_smoke_test.gd`.
- RPG-001 tuning melee RPG e super starter e RPG-002 polish classi RPG avanzate:
  completati nella Milestone 7 di `todo_roadmap.md`. `MeleeAttack` applica
  hitstop data-driven, i vincoli ascia/spada/arco/pistola sono coperti da smoke,
  Briciola resta assistiva/non bloccante, `Notte Bestiale` ha recovery visibile
  e le super starter/avanzate hanno VFX tipizzati. QA manuale
  multi-risoluzione/five-wave/due-player resta follow-up del playtest
  Milestone 11.
- Roadmap RPG Mode M1-M13 e classi avanzate: completate come pass
  data-driven; tuning e polish Milestone 7 sono chiusi come reference storica.
- Menu pausa, Settings condivisi, navigazione gamepad e Character Select RPG:
  completati come polish post-roadmap, inclusa la selezione indipendente
  per-player nella Character Select; regressioni in `UIUX-001`.
- Pass personaggi RPG distinguibili e melee reali: completato; regressioni in
  smoke RPG e playtest Milestone 11.
- BIO-001 mini-eventi bioma, status e encounter: completato nella Milestone 2
  di `todo_roadmap.md`; telegraph, reward crate, cooldown, high contrast,
  reduced motion e status evitabile sono coperti da smoke, con checklist
  manuale aggiornata per acquisire evidenza visuale durante playtest futuri.
- Iterazione survival biome-based status, ostacoli, roster ed encounter:
  completata come primo pass; regressioni future passano dai test
  `biome_mini_events`, `random_encounter`, status e survival.
- Ammo survival anti-frustrazione, boss registry, audio mix, risultati run,
  downed/revive, arena survival e accessibilita: completati; usare i test
  elencati in README e nel report di validazione.
- TECH-001 shutdown headless e lifecycle test: completato nella Milestone 1 di
  `todo_roadmap.md`; regressioni future da verificare con
  `tests/headless_shutdown_loop_test.gd` e smoke prioritari.
- WPN-001 inventario armi e catalogo: completato il 2026-06-19; stato runtime
  per istanza, switch per-player, unicita drop di run, 30 armi e resolver
  effetti coperti da `tests/weapon_inventory_catalog_smoke_test.gd`. Il pass
  input del 2026-06-20 separa inoltre l'arma base dalla collezione: `RB` usa la
  base, `LB` l'equipaggiata e il D-pad cicla solo le armi raccolte. Follow-up
  ammessi solo per tuning, asset finali e playtest visuale dentro `BAL-001` o
  `UIUX-001`, non per parti core.
- ZMARKET-001 mercato zombie ricorrente: completato il 2026-06-20; boss wave
  ogni cinque, fase senza spawn, wallet comune, acquisti per-player, offerte
  catalogo pesate per rarita e ready multiplayer sono coperti dallo smoke
  dedicato. Follow-up ammessi solo per tuning e QA visuale in `BAL-001` e
  `UIUX-001`.
- WVIS-001 identita visuale completa delle armi: completato il 2026-06-20 con
  Milestone W0-W8 chiuse. Le 30 armi hanno profili, palette, pickup/held/HUD e
  projectile oppure melee specifici; smoke, QA su otto screenshot e performance
  M21 sono verdi. Evidenza in
  `docs/weapon_visual_identity_validation_report.md`. Arte finale opzionale e
  tuning secondario restano rispettivamente in `UIUX-001` e `BAL-001`; nuove
  armi seguono il contratto di `ARCHITECTURE.md` senza riaprire questo task.

## Mappatura dalle vecchie sezioni TODO

- `Prossima iterazione biomi zombie survival` -> `BIO-001` completata,
  `MAP-001`/`MAP-002` completate nella Milestone 3, `ASSET-001` completata nella
  Milestone 4, follow-up residuo in `BAL-001`.
- `Megamappa persistente isometrica - follow-up` -> `MAP-001`, `MAP-002` e
  `ASSET-001` completate (Milestone 3 e 4).
- Duplicato storico sulla manutenzione headless dei test -> `TECH-001`.
- `Espandere il dungeon oltre il percorso lineare` -> `DUN-001` completata
  (Milestone 5).
- `Asset definitivi` generico -> `ASSET-001` (Milestone 4, ambiente) e `ASSET-002`
  (Milestone 6, personaggi) completate; resta `UIUX-001`.
- `Ampliare i test automatici` -> `QA-001`.
- `Asset definitivi personaggi RPG - futuro` -> `ASSET-002` completata
  (Milestone 6); resta solo l'arte `final_quality` per-personaggio.
- `Tuning melee RPG e super - futuro` -> `RPG-001` completata (Milestone 7).
- `Polish classi RPG avanzate - futuro` -> `RPG-002` completata (Milestone 7).
- `Firma digitale dell'eseguibile Windows` -> `REL-001`.
