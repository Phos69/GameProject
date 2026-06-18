# Latest Commit Validation Report

## Isometric biome generation rewrite R1 - 2026-06-18
- Branch: `feat/iso-milestone-10-complete`
- Scope validato: primo incremento del rewrite richiesto da `prompt.md`:
  chunk `500x500`, megamappa default `3x3`, base void con floor/strade/blocchi
  scavati, strade principali larghe 10, sentieri larghi 4, passaggi larghi 10,
  cache terrain e validazione spawn/crate su celle walkable.
- Esito: PASS sui test mirati eseguiti. Nota performance: il tile layer da
  250.000 celle passa ma resta sensibilmente piu pesante del precedente
  `200x200`; ottimizzazione/profiling ulteriore resta parte del prossimo ciclo.

| Test | Esito | Note |
|---|---|---|
| `tests/isometric_biome_generation_rewrite_smoke_test.gd` | PASS | copre `500x500`, strade 10, sentieri 4, blocchi, void/fall zone e passaggi |
| `tests/biome_world_generation_smoke_test.gd` | PASS | generazione default `3x3`, streaming e transizione legacy/debug |
| `tests/isometric_biome_terrain_coverage_smoke_test.gd` | PASS | classificazione completa `500x500` e passaggi walkable |
| `tests/milestone_10_tile_layer_smoke_test.gd` | PASS | 250.000 celle asset-backed per regione, chunk/cache |
| `tests/world_graph_connectivity_smoke_test.gd` | PASS | grafo `3x3` connesso e regioni `500x500` |
| `tests/milestone_7_graph_connectivity_smoke_test.gd` | PASS | 100 seed con grafo `3x3`, overlay e fog |
| `tests/milestone_10_no_portal_transition_smoke_test.gd` | PASS | crossing world-space senza gate/portali |

## Milestone 10.11 QA visuale/performance finale - 2026-06-18
- Branch: `feat/iso-milestone-10-complete`
- HEAD di partenza: `e282aac`
- Scope validato: chiusura di
  `milestone_10_isometric_asset_rewrite_roadmap.md` Milestone 10.11, con QA
  visuale finale, performance del path asset-driven `balanced` e regressione
  completa di manifest, tile, passaggi, oggetti, cliff, no-portal, streaming,
  chase cross-bioma e cleanup legacy.
- Esito: PASS. La survival standard resta asset-driven, senza gate di
  transizione o renderer legacy nel percorso normale; i cinque biomi hanno
  catture `1280x720`, lo zombie chase attraversa il seam e il budget
  performance resta sotto `35 ms`.
- Performance rilevata:
  `MILESTONE_10_ISOMETRIC_PROFILE: 7x7 world, 2 streamed regions, 28 enemies, avg 16.54 ms`.
- Screenshot generati in `build/qa/` (cartella ignorata da Git):
  `plains_full_region.png`, `toxic_void_edge.png`,
  `ash_passage_crossing.png`, `snow_objects_slots.png`,
  `marsh_bridge_void.png`, `cross_biome_chase_sequence_01.png` e
  `cross_biome_chase_sequence_02.png`, tutti a `1280x720`.

| Test | Esito | Note |
|---|---|---|
| `tools/generate_isometric_environment_assets.gd -- --check` | PASS | 93 SVG asset-driven verificati |
| `tests/milestone_10_asset_manifest_v7_smoke_test.gd` | PASS | manifest v7 e fallback policy |
| `tests/milestone_10_asset_pipeline_smoke_test.gd` | PASS | filesystem, metadata e attribution |
| `tests/milestone_10_tile_layer_smoke_test.gd` | PASS | tile layer `200x200`, determinismo e chunk |
| `tests/milestone_10_passage_tile_smoke_test.gd` | PASS | route/passaggi/entry/exit asset-driven |
| `tests/milestone_10_object_asset_smoke_test.gd` | PASS | oggetti e crate asset-backed |
| `tests/milestone_10_void_cliff_asset_smoke_test.gd` | PASS | cliff/void/fall zone asset-driven |
| `tests/milestone_10_no_portal_transition_smoke_test.gd` | PASS | nessun gate runtime di transizione |
| `tests/milestone_10_full_region_streaming_smoke_test.gd` | PASS | active ring con regioni `FULL` |
| `tests/milestone_10_cross_biome_chase_smoke_test.gd` | PASS | chase oltre seam senza despawn/reset |
| `tests/milestone_10_legacy_cleanup_smoke_test.gd` | PASS | nessun visual legacy nel bootstrap survival |
| `tests/milestone_10_isometric_performance_smoke_test.gd` | PASS | mappa `7x7`, 28 nemici, media `16,54 ms` |
| `tests/milestone_10_visual_smoke_test.gd` | PASS | regressione visual survival legacy |
| `tests/isometric_environment_manifest_smoke_test.gd` | PASS | regressione manifest/categorie/Y-sort |
| `tests/isometric_biome_terrain_coverage_smoke_test.gd` | PASS | classificazione terrain e copertura biomi |
| `tests/fall_boundary_visual_logic_smoke_test.gd` | PASS | fall boundary e query dedicate |
| `tests/player_dodge_gap_smoke_test.gd` | PASS | dodge/gap invariato |
| `tests/milestone_8_multi_region_smoke_test.gd` | PASS | fallback/prototipo storico ancora verde |
| `tests/open_passage_transition_smoke_test.gd` | PASS | passaggi fisici aperti |
| `tests/milestone_10_isometric_final_visual_qa.gd` | PASS | sette screenshot finali `1280x720` con `gl_compatibility` |

## Milestone 10.10 cleanup legacy survival - 2026-06-18
- Branch: `master`
- HEAD corrente: non committato al momento della validazione locale.
- Scope validato: standard survival asset-driven con `WorldRegionStreamer`,
  fallback `MultiRegionRenderer` lazy-only, assenza di gate/ground/patch legacy
  nel bootstrap e audit sorgente del path di configurazione bioma.
- Esito: PASS sui criteri automatizzabili. La survival standard streama current
  + vicini come contenuto gameplay `FULL` senza creare `BiomeTransitionGate`,
  `BiomeRegionGround`, `BiomeTerrainPatch`, `NeighborGround_` o nodi
  `multi_region_renderer`; i test storici del renderer fallback restano verdi.

| Test | Esito | Note |
|---|---|---|
| `tests/milestone_10_legacy_cleanup_smoke_test.gd` | PASS | audit sorgente e bootstrap survival senza visual legacy |
| `tests/milestone_10_full_region_streaming_smoke_test.gd` | PASS | streamer gameplay ancora percorso standard |
| `tests/milestone_10_no_portal_transition_smoke_test.gd` | PASS | no gate runtime |
| `tests/open_passage_transition_smoke_test.gd` | PASS | crossing senza trigger/gate |
| `tests/milestone_8_multi_region_smoke_test.gd` | PASS | fallback/prototipo visuale storico invariato |

## Milestone 10.9 chase zombie cross-bioma - 2026-06-18
- Branch: `master`
- HEAD corrente: non committato al momento della validazione locale.
- Scope validato: metadata regione su `BasicEnemy`, regione di spawn risolta da
  `EnemySystem`, validazione spawn world-space nello `ZombieSpawner` e chase di
  uno zombie attraverso un varco aperto tra regioni streamate.
- Esito: PASS sui criteri automatizzabili. Lo zombie mantiene target, stato
  chase/attack, health e registrazione in `EnemySystem` attraversando il seam;
  aggiorna `current_region_id` e `last_seen_player_region_id` senza despawn o
  reset.

| Test | Esito | Note |
|---|---|---|
| `tests/milestone_10_cross_biome_chase_smoke_test.gd` | PASS | chase oltre seam, metadata regione, no despawn/reset |
| `tests/milestone_10_full_region_streaming_smoke_test.gd` | PASS | streamer gameplay ancora coerente |
| `tests/milestone_10_no_portal_transition_smoke_test.gd` | PASS | no gate runtime |
| `tests/zombie_biome_enemy_smoke_test.gd` | PASS | profili tematici e status invariati |
| `tests/survival_wave_smoke_test.gd` | PASS | wave survival invariata |
| `tests/enemy_drop_smoke_test.gd` | PASS | targeting/drop base invariati |

## Milestone 10.8 streaming gameplay multi-regione - 2026-06-18
- Branch: `master`
- HEAD corrente: non committato al momento della validazione locale.
- Scope validato: `WorldRegionStreamer`, registrazione di tile/ostacoli/hazard/
  crate multi-regione nei sistemi zombie esistenti, persistenza crate per
  `region_id` e assenza di duplicati al re-stream.
- Esito: PASS sui criteri automatizzabili. Current + vicini connessi sono
  contenuto `FULL`, le query obstacle/hazard vedono i vicini prima
  dell'attraversamento, una crate aperta in un vicino aggiorna il ledger del
  territorio corretto e non ricompare al re-stream.

| Test | Esito | Note |
|---|---|---|
| `tests/milestone_10_full_region_streaming_smoke_test.gd` | PASS | active ring `FULL`, query vicini, ledger crate e deduplicazione |
| `tests/milestone_10_no_portal_transition_smoke_test.gd` | PASS | no gate runtime dopo integrazione streamer |
| `tests/open_passage_transition_smoke_test.gd` | PASS | crossing senza trigger/gate |
| `tests/biome_world_generation_smoke_test.gd` | PASS | bootstrap survival con streamer attivo |
| `tests/zombie_biome_transition_smoke_test.gd` | PASS | contenuti bioma e transizioni legacy compatibili |
| `tests/region_streaming_smoke_test.gd` | PASS | ledger persistente storico |
| `tests/milestone_8_multi_region_smoke_test.gd` | PASS | fallback/prototipo visuale storico invariato |

## Milestone 10.7 transizione senza portali - 2026-06-18
- Branch: `master`
- HEAD corrente: non committato al momento della validazione locale.
- Scope validato: eliminazione dei `BiomeTransitionGate` dal runtime survival,
  introduzione di `RegionSeamSystem` per cambio regione da posizione
  world-space e mantenimento di `BiomeTransitionSystem.transition_to()` come
  API legacy/debug senza nodi gate.
- Esito: PASS sui criteri automatizzabili. La survival non crea nodi nel gruppo
  `biome_transition_gates`, attraversare un varco aperto aggiorna
  `BiomeManager` e `WorldRuntime`, i bordi senza edge non cambiano regione e
  gli smoke storici restano compatibili con il nuovo contratto senza portali.

| Test | Esito | Note |
|---|---|---|
| `tests/milestone_10_no_portal_transition_smoke_test.gd` | PASS | nessun gate runtime, crossing world-space e bordo bloccato |
| `tests/open_passage_transition_smoke_test.gd` | PASS | passaggio fisico senza trigger/gate |
| `tests/biome_world_generation_smoke_test.gd` | PASS | bootstrap survival e generazione mondo senza gate |
| `tests/zombie_biome_transition_smoke_test.gd` | PASS | transizioni legacy via comando e contenuti bioma invariati |
| `tests/milestone_6_open_passage_smoke_test.gd` | PASS | contratto storico `BiomeTransitionGate` mantenuto come compatibilita |

## Polish strade diagonali e oggetti isometrici - 2026-06-18
- Branch: `master`
- HEAD corrente: non committato al momento della validazione locale.
- Scope validato: iterazione su visuale isometrica post Milestone 10.4/10.5:
  route diagonali per strade e diramazioni, SVG ambiente trasparenti,
  silhouette dedicate per oggetti principali e fix del loader runtime che
  eliminava le forme reali a favore della sagoma placeholder.
- Esito: PASS sui criteri automatizzabili. Le route generate usano
  `road_cell_tags` diagonali, i passaggi conservano aperture e connector
  compatibili, gli oggetti caricano sprite `object_scenes` senza fallback
  procedurale, il loader rasterizza SVG trasparenti o fallback isometrici per
  categoria e il manifest non contiene piu status placeholder/procedurali per
  gli oggetti principali.

| Test | Esito | Note |
|---|---|---|
| `tools/generate_isometric_environment_assets.gd -- --check` | PASS | 93 SVG verificati |
| `tests/milestone_10_passage_tile_smoke_test.gd` | PASS | include regressione sulle due diagonali principali |
| `tests/milestone_10_tile_layer_smoke_test.gd` | PASS | route cell diagonali risolte come tile asset-backed |
| `tests/milestone_10_object_asset_smoke_test.gd` | PASS | oggetti/crate asset-backed e silhouette runtime distinte |
| `tests/biome_world_generation_smoke_test.gd` | PASS | layout generato e survival bootstrap coerenti |
| `tests/isometric_biome_terrain_coverage_smoke_test.gd` | PASS | copertura terrain 200x200 e passage walkable |
| `tests/milestone_10_asset_manifest_v7_smoke_test.gd` | PASS | manifest v7 e asset contract |
| `tests/open_passage_transition_smoke_test.gd` | PASS | transizioni fisiche aperte |
| `tests/isometric_environment_manifest_smoke_test.gd` | PASS | manifest, categorie e collisione/Y-sort |
| `tests/biome_obstacle_generation_smoke_test.gd` | PASS | layout ostacoli e categorie |
| `tests/milestone_4_obstacle_collision_smoke_test.gd` | PASS | layer movimento/proiettili invariati |

Nota QA visuale: `tests/zombie_biome_visual_qa.gd` eseguito con
`--rendering-method gl_compatibility` ha chiuso con exit code `0`, ma in questa
sessione non ha prodotto la cartella `build/qa`; non viene quindi contato come
evidenza screenshot.

## Milestone 10.5 oggetti e ostacoli slot-based - 2026-06-18
- Branch: `master`
- HEAD corrente: non committato al momento della validazione locale.
- Scope validato: sotto-milestone 10.5 di
  `milestone_10_isometric_asset_rewrite_roadmap.md`, oggetti, ostacoli e crate
  come scene/sprite isometriche slot-based.
- Esito: PASS sui criteri automatizzabili. Gli ostacoli generati usano
  `IsometricEnvironmentObject` tramite factory, mantengono collisioni/layer e
  gruppi storici, caricano texture da `object_scenes` e non tornano al vecchio
  `_draw()` se l'asset SVG esiste. La crate usa lo stesso contratto asset.

| Criterio | Esito | Evidenza |
|---|---|---|
| Ogni oggetto richiesto ha asset path | PASS | `tests/milestone_10_object_asset_smoke_test.gd` controlla case, barriere, props e `supply_crate` |
| Factory runtime asset-driven | PASS | `ObstacleSystem` crea `IsometricEnvironmentObject` per il layout `infected_plains` |
| Collision layer invariati | PASS | smoke 10.5 e `tests/milestone_4_obstacle_collision_smoke_test.gd` confermano layer movimento/proiettili |
| Crate asset-backed | PASS | `SupplyCrateVisual` carica `object_scenes/supply_crate` e mantiene layer/mask/shape |
| SVG headless sicuri | PASS | `IsometricSvgTextureLoader` produce `ImageTexture` runtime dagli SVG generati senza dipendere dalla cache import editor |

### Test Milestone 10.5 eseguiti

| Test | Esito | Note |
|---|---|---|
| `tests/milestone_10_object_asset_smoke_test.gd` | PASS | object scenes, factory, crate, layer e sort |
| `tests/biome_obstacle_generation_smoke_test.gd` | PASS | regressione layout ostacoli |
| `tests/isometric_environment_manifest_smoke_test.gd` | PASS | manifest, categorie, fallback storici e Y-sort |
| `tests/milestone_4_obstacle_collision_smoke_test.gd` | PASS | collision shape/layer/proiettili invariati |
| `tests/zombie_environment_milestone_smoke_test.gd` | PASS | bootstrap survival con factory attiva |
| `tests/milestone_10_asset_manifest_v7_smoke_test.gd` | PASS | regressione manifest v7 |
| `tests/milestone_10_asset_pipeline_smoke_test.gd` | PASS | filesystem/metadata SVG |
| `tools/generate_isometric_environment_assets.gd -- --check` | PASS | 93 SVG verificati |
| `tests/milestone_10_tile_layer_smoke_test.gd` | PASS | regressione tile layer |
| `tests/milestone_10_passage_tile_smoke_test.gd` | PASS | regressione passaggi asset-driven |
| `tests/world_graph_connectivity_smoke_test.gd` | PASS | grafo e passaggi fisici |
| `tests/open_passage_transition_smoke_test.gd` | PASS | transizioni aperte |
| `tests/milestone_8_multi_region_smoke_test.gd` | PASS | renderer multi-regione |
| `tests/milestone_10_visual_smoke_test.gd` | PASS | visual survival/crate senza label |

### Fix applicati nella Milestone 10.5

- `game/modes/zombie/isometric_environment_object.gd` e `.tscn`: scena base
  slot-based con sprite, ombra, collisione manifest, anchor, sort e debug
  footprint opzionale.
- `game/modes/zombie/isometric_environment_object_factory.gd`: factory che
  sceglie scena asset-driven o fallback `BiomeObstacle` dichiarato.
- `game/modes/zombie/isometric_svg_texture_loader.gd`: loader tecnico per SVG
  generati in headless, convertiti in `ImageTexture`.
- `game/modes/zombie/obstacle_system.gd`: integrazione factory mantenendo chiavi
  stabili, gruppi e cleanup.
- `game/visuals/supply_crate_visual.gd`: sprite asset-backed da
  `object_scenes/supply_crate` con draw procedurale solo fallback.
- `tests/milestone_10_object_asset_smoke_test.gd`: smoke dedicato 10.5.

### Limiti e follow-up Milestone 10.5

- Gli SVG restano asset base generati, non final quality; la revisione estetica
  completa resta nella Milestone 10.11.
- La Milestone 10.6 puo partire solo dopo questo commit e dovra sostituire il
  vuoto/cliff/fall zone con asset dedicati.

## Milestone 10.4 strade e passaggi asset-driven - 2026-06-18
- Branch: `master`
- HEAD corrente: non committato al momento della validazione locale.
- Scope validato: sotto-milestone 10.4 di
  `milestone_10_isometric_asset_rewrite_roadmap.md`, strade, ponti, passaggi e
  raccordi come tile asset-driven.
- Esito: PASS sui criteri automatizzabili. I passaggi espongono tile dedicati
  per tipo, entry/exit leggibili al bordo, connector continui in coordinate
  globali e nessuna direzione viene comunicata da `BiomeTransitionGate._draw()`.

| Criterio | Esito | Evidenza |
|---|---|---|
| Ogni `passage_type` ha tile dedicati | PASS | manifest v7 contiene `road`, `bridge`, `snow_pass`, `broken_gate`, `burned_road` in `passage_tiles` piu entry/exit |
| Raccordi route presenti | PASS | `road_intersection`, `road_edge`, `road_curve_north/east/south/west`, `bridge_broken`, `cliff_ramp` hanno asset SVG |
| Passaggi sui quattro lati con span coerente | PASS | `tests/milestone_10_passage_tile_smoke_test.gd` valida north/south/east/west e `passage_width` |
| Nessun passaggio su fall/wall | PASS | smoke 10.4 controlla opening e connector contro fall zone, obstacle, border e void |
| Continuita globale tra regioni | PASS | `WorldRegionConnection` conserva `world_rect`, connector source/target e tile entry/exit |
| Gate non comunicano direzione | PASS | `BiomeTransitionGate.show_debug_visual` default false; smoke verifica assenza di frecce/marker |

### Test Milestone 10.4 eseguiti

| Test | Esito | Note |
|---|---|---|
| `tools/generate_isometric_environment_assets.gd -- --write` | PASS | 18 nuovi SVG generati, 75 esistenti saltati |
| `tools/generate_isometric_environment_assets.gd -- --check` | PASS | 93 SVG verificati |
| `tests/milestone_10_passage_tile_smoke_test.gd` | PASS | contratti, span, overlap, coordinate globali e gate debug |
| `tests/milestone_10_tile_layer_smoke_test.gd` | PASS | regressione tile layer con route tile specifici |
| `tests/milestone_10_asset_manifest_v7_smoke_test.gd` | PASS | regressione manifest v7 |
| `tests/milestone_10_asset_pipeline_smoke_test.gd` | PASS | regressione pipeline asset |
| `tests/zombie_biome_transition_smoke_test.gd` | PASS | transizioni survival con tile layer |
| `tests/open_passage_transition_smoke_test.gd` | PASS | trigger fisici allineati ai passaggi |
| `tests/world_graph_connectivity_smoke_test.gd` | PASS | grafo persistente e passaggi fisici |
| `tests/milestone_6_open_passage_smoke_test.gd` | PASS | contratto gate/span storico |
| `tests/zombie_environment_milestone_smoke_test.gd` | PASS | regressione ambiente survival |
| `tests/isometric_biome_terrain_coverage_smoke_test.gd` | PASS | classificazione e terrain tag |
| `tests/milestone_8_multi_region_smoke_test.gd` | PASS | regressione renderer multi-regione |
| `tests/isometric_environment_manifest_smoke_test.gd` | PASS | regressione manifest/ostacoli/Y-sort |

### Fix applicati nella Milestone 10.4

- `assets/environment/isometric/manifest.json`: aggiunti route connector, entry
  e exit per ogni `passage_type`, `bridge_broken` e `cliff_ramp`.
- `assets/environment/isometric/passages/*.svg` e
  `assets/environment/isometric/tiles/shared/road_*.svg`: 18 SVG generati
  internamente.
- `game/modes/zombie/isometric_tile_resolver.gd`: risoluzione route/passage con
  sezioni distinte e priorita ai connector di passaggio.
- `game/procedural/world_generation/biome_passage.gd` e
  `game/world/world_region_connection.gd`: rettangoli local/global, connector e
  tile entry/exit serializzati.
- `game/modes/zombie/biome_transition_gate.gd`: draw runtime ridotto a debug
  opzionale.
- `tests/milestone_10_passage_tile_smoke_test.gd`: smoke dedicato 10.4.

### Limiti e follow-up Milestone 10.4

- Gli SVG restano placeholder testuali generati in-repo; il pass visuale finale
  resta tracciato nella Milestone 10.11.
- La Milestone 10.5 deve spostare oggetti e ostacoli verso scene isometriche
  slot-based, mantenendo collisioni e fallback controllati.

## Milestone 10.3 tile layer persistente - 2026-06-18
- Branch: `master`
- HEAD corrente: non committato al momento della validazione locale.
- Scope validato: sotto-milestone 10.3 di
  `milestone_10_isometric_asset_rewrite_roadmap.md`, tile base persistenti per
  tutto il bioma `200x200`.
- Esito: PASS sui criteri automatizzabili. `BiomeTileLayer` e
  `IsometricTileResolver` coprono ogni cella logica con tile asset-backed
  deterministico; `TerrainGenerator` usa il tile layer come ground primario e
  disattiva i patch terreno legacy in modalita asset.

| Criterio | Esito | Evidenza |
|---|---|---|
| Ogni cella `200x200` risolve un tile | PASS | `tests/milestone_10_tile_layer_smoke_test.gd` controlla 40.000 celle per cinque biomi campione |
| Varianti stabili per seed+cella+bioma | PASS | smoke 10.3 confronta due risoluzioni della stessa cella |
| Asset contract presenti | PASS | resolver verifica `floor_*`, `road`, `hazard_floor`, `border_floor`, `void_edge_near`, `void_depth` |
| Chunk/caching attivi | PASS | `BiomeTileLayer` usa chunk 20x20 balanced e cache 40.000 celle senza nodi per-tile |
| Patch ovali legacy disattivati | PASS | smoke 10.3 e smoke survival verificano `generated_patches` vuoto con tile layer attivo |

### Test Milestone 10.3 eseguiti

| Test | Esito | Note |
|---|---|---|
| `godot --headless --path . --import` | PASS | classi globali aggiornate e SVG importabili |
| `tools/generate_isometric_environment_assets.gd -- --check` | PASS | 75 SVG verificati dopo `void_edge_near` |
| `tests/milestone_10_tile_layer_smoke_test.gd` | PASS | contratti, determinismo, copertura, chunk e integrazione |
| `tests/milestone_10_asset_manifest_v7_smoke_test.gd` | PASS | regressione manifest v7 |
| `tests/milestone_10_asset_pipeline_smoke_test.gd` | PASS | regressione pipeline asset |
| `tests/isometric_environment_manifest_smoke_test.gd` | PASS | regressione manifest/ostacoli/Y-sort |
| `tests/isometric_biome_terrain_coverage_smoke_test.gd` | PASS | classificazione `200x200` e passaggi walkable |
| `tests/zombie_environment_milestone_smoke_test.gd` | PASS | survival runtime con tile layer primario |
| `tests/zombie_biome_transition_smoke_test.gd` | PASS | transizione bioma con tile layer e patch legacy disattivati |
| `tests/milestone_8_multi_region_smoke_test.gd` | PASS | regressione vicini visual-only legacy |

### Fix applicati nella Milestone 10.3

- `game/modes/zombie/isometric_tile_resolver.gd`: resolver deterministico per
  tile base, road, hazard, border e void.
- `game/modes/zombie/biome_tile_layer.gd`: layer chunked/cache per 40.000 celle
  senza nodi per-tile.
- `game/modes/zombie/terrain_generator.gd`: tile layer come ground primario;
  `BiomeRegionGround`/`BiomeTerrainPatch` solo fallback tecnico.
- `assets/environment/isometric/manifest.json`: aggiunto `void_edge_near`.
- `assets/environment/isometric/edges/cliffs/void_edge_near.svg`: nuovo SVG
  generato internamente.
- `tests/milestone_10_tile_layer_smoke_test.gd`: smoke dedicato 10.3.

### Limiti e follow-up Milestone 10.3

- I passaggi specializzati (`bridge`, `snow_pass`, `broken_gate`,
  `burned_road`) sono ancora normalizzati dal tile base `road`; la Milestone
  10.4 li trasforma in tile asset-driven dedicati.
- QA screenshot reale cinque biomi a 1280x720 e 960x540 era tracciato nella
  checklist manuale ed e stato poi chiuso nella Milestone 10.11.

## Milestone 10.2 asset pipeline locale - 2026-06-18
- Branch: `master`
- HEAD corrente: non committato al momento della validazione locale.
- Scope validato: sotto-milestone 10.2 di
  `milestone_10_isometric_asset_rewrite_roadmap.md`, struttura cartelle e
  generatore asset locale.
- Esito: PASS sui criteri automatizzabili. Generati 74 SVG testuali interni
  sotto `assets/environment/isometric/`; nessun asset esterno o binario pesante
  introdotto.

| Criterio | Esito | Evidenza |
|---|---|---|
| Struttura asset locale presente | PASS | cartelle tile, oggetti, edge, passaggi e preview create |
| Tool dry-run/write/check disponibile | PASS | `tools/generate_isometric_environment_assets.gd` |
| Manifest e filesystem allineati | PASS | `--check` controlla 74 SVG e lo smoke pipeline verifica status non `needs_asset` |
| Attribution completa | PASS | `assets/ATTRIBUTION.md` include contratto v7 e SVG generati |
| Regressione manifest invariata | PASS | smoke v7 e manifest legacy verdi |

### Test Milestone 10.2 eseguiti

| Test | Esito | Note |
|---|---|---|
| `tools/generate_isometric_environment_assets.gd -- --dry-run` | PASS | 74 path SVG unici pianificati prima della generazione |
| `tools/generate_isometric_environment_assets.gd -- --write` | PASS | 74 SVG creati, nessun overwrite final |
| `tools/generate_isometric_environment_assets.gd -- --check` | PASS | 74 SVG verificati |
| `tests/milestone_10_asset_pipeline_smoke_test.gd` | PASS | directory, file, metadata, naming, docs e guardia final |
| `tests/milestone_10_asset_manifest_v7_smoke_test.gd` | PASS | contratto v7 aggiornato a `base_complete` |
| `tests/isometric_environment_manifest_smoke_test.gd` | PASS | regressione manifest/oggetti/Y-sort |

### Fix applicati nella Milestone 10.2

- `tools/generate_isometric_environment_assets.gd`: nuovo generatore headless.
- `assets/environment/isometric/**`: 74 SVG placeholder asset-driven con metadata
  stabile.
- `assets/environment/isometric/manifest.json`: status default dei contratti v7
  avanzato a `base_complete`.
- `tests/milestone_10_asset_pipeline_smoke_test.gd`: nuovo smoke pipeline.
- Documentazione aggiornata in README asset, attribution, roadmap, TODO,
  checklist e report.

### Limiti e follow-up Milestone 10.2

- Gli SVG sono asset base generati, non ancora collegati al renderer runtime.
  Il collegamento dei tile base su tutta la regione `200x200` parte in
  Milestone 10.3.

## Milestone 10.1 asset manifest v7 - 2026-06-18
- Branch: `master`
- HEAD corrente: non committato al momento della validazione locale.
- Scope validato: sotto-milestone 10.1 di
  `milestone_10_isometric_asset_rewrite_roadmap.md`, contratto asset v7 e
  inventario finale dell'ambiente isometrico.
- Esito: PASS sui criteri automatizzabili. Nessun asset esterno obbligatorio
  introdotto; gli asset assenti sono tracciati come `needs_asset` con fallback
  tecnico esplicito.

| Criterio | Esito | Evidenza |
|---|---|---|
| Manifest v7 completo | PASS | sezioni `tile_sets`, `tile_variants`, `terrain_tiles`, `edge_tiles`, `void_tiles`, `object_scenes`, `passage_tiles`, `biome_asset_sets` e `fallback_policy` validate |
| ID generati coperti dal contratto asset | PASS | generazione `5x5` verifica object, terrain, passage, border e `fall_zone` |
| Asset opzionale mancante sicuro | PASS | `small_rock` dichiara `needs_asset`, `asset_path` pianificato e `fallback_path` |
| Regressione manifest/terrain invariata | PASS | smoke manifest e terrain coverage esistenti verdi |

### Test Milestone 10.1 eseguiti

| Test | Esito | Note |
|---|---|---|
| `godot --headless --path . --import` | PASS | cache Godot rigenerata e classi globali aggiornate |
| `tests/milestone_10_asset_manifest_v7_smoke_test.gd` | PASS | contratto v7, fallback policy, generazione `5x5`, negativo asset mancante |
| `tests/isometric_environment_manifest_smoke_test.gd` | PASS | regressione manifest/oggetti/Y-sort |
| `tests/isometric_biome_terrain_coverage_smoke_test.gd` | PASS | regressione terrain `200x200` e tag generati |

### Fix applicati nella Milestone 10.1

- `assets/environment/isometric/manifest.json`: portato a v7 con sezioni
  asset-driven e fallback policy.
- `game/modes/zombie/isometric_environment_manifest.gd`: parsing, API e
  validazione dei contratti v7 normalizzati.
- `tests/milestone_10_asset_manifest_v7_smoke_test.gd`: nuovo smoke dedicato.
- Documentazione aggiornata in `assets/README.md`, `assets/ATTRIBUTION.md`,
  `ARCHITECTURE.md`, `ROADMAP.md`, `TODO.md`,
  `docs/isometric_generation_audit_roadmap.md`,
  `milestone_10_isometric_asset_rewrite_roadmap.md` e checklist manuale.

### Limiti e follow-up Milestone 10.1

- Il contratto v7 definisce path e fallback, ma non crea ancora file asset:
  quello e lo scope della Milestone 10.2.
- Il runtime usa ancora i draw procedurali principali finche le milestone
  successive non collegano tile, passaggi, oggetti e cliff asset-driven.

## Milestone 7 tuning melee, super starter e classi RPG avanzate - 2026-06-17
- Branch: `feat/milestone-3-5-streaming-iso-dungeon`
- HEAD corrente: non committato al momento della validazione locale.
- Scope validato: Milestone 7 di `todo_roadmap.md`, tuning melee RPG, super
  starter e polish automatizzabile di Mago/Domatrice/Licantropo.
- Esito: PASS sui criteri automatizzabili; QA manuale multi-risoluzione e
  cinque-wave resta documentata in checklist per playtest end-to-end.

| Criterio | Esito | Evidenza |
|---|---|---|
| Ogni starter ha rischio/beneficio percepibile | PASS | smoke melee/balance verificano ascia piu lenta/pesante, spada piu sicura/rapida, arco e pistola ancora projectile distinti |
| Super riconoscibili a colpo d'occhio | PASS | `GameplayEffects.spawn_rpg_super` restituisce kind distinti per starter e avanzate |
| Briciola aiuta senza giocare da solo e non blocca Nina | PASS | danno/cadenza/frenzy bounded e companion `Node2D` senza collisione, coperti da smoke |
| Notte Bestiale termina con recovery leggibile | PASS | `is_beast_recovering()`, status `RECUPERO` e marker visuale in `PlayerVisual` coperti da smoke |
| Projectile/melee split invariato | PASS | arco/pistola restano projectile; ascia/spada/artigli restano melee |

### Test Milestone 7 eseguiti

| Test | Esito | Note |
|---|---|---|
| `godot --headless --path . --import --quit` | PASS | import script/risorse |
| `tests/rpg_melee_attack_resolution_smoke_test.gd` | PASS | split melee/projectile, rischio starter, hitstop runtime |
| `tests/milestone_rpg_13_new_classes_smoke_test.gd` | PASS | Mago/Domatrice/Licantropo, Briciola bounded, recovery licantropo |
| `tests/milestone_rpg_12_feedback_smoke_test.gd` | PASS | VFX super starter e avanzate tipizzate |
| `tests/milestone_rpg_8_adrenaline_super_smoke_test.gd` | PASS | super starter e recovery invulnerabilita Phantom Blade |
| `tests/milestone_rpg_10_balance_smoke_test.gd` | PASS | vincoli balance starter |
| `tests/survival_wave_smoke_test.gd` | PASS | regressione survival, exit code `0` |

### Fix applicati nella Milestone 7

- `game/weapons/melee_attack.gd` e `game/weapons/weapon_system.gd`: `hitstop`
  configurato nei `WeaponData` ora viene passato e applicato dal runtime melee.
- `game/rpg/companions/briciola_companion.gd`: danno/cooldown/frenzy resi
  bounded e interrogabili dagli smoke.
- `game/rpg/rpg_player_component.gd` e `game/visuals/player_visual.gd`: recovery
  di `Notte Bestiale` esposta e visualizzata.
- `game/visuals/gameplay_effects.gd`: super avanzate mappate a kind/colori
  distinti.

### Limiti e follow-up Milestone 7

- QA manuale survival con quattro starter a 1280x720 e 960x540 non eseguita in
  headless; resta in `docs/testing/manual_checklist.md` per playtest Milestone 11.
- QA manuale Mago/Domatrice/Licantropo per cinque wave e prova due-player
  Briciola/trasformazione resta da acquisire in playtest reale.
- Arte finale per-personaggio (`final_quality`) resta follow-up artistico
  separato dalla milestone di tuning.

## Milestone 6 asset definitivi e animazioni personaggi RPG - 2026-06-17
- Branch: `master`
- HEAD corrente: non committato al momento della validazione locale.
- Scope validato: Milestone 6 di `todo_roadmap.md`, pipeline asset dei sette
  personaggi RPG (coerenza dati, non qualita artistica).
- Esito: PASS sui criteri automatizzabili; checklist visuale aggiornata per la QA
  artistica manuale (multi-risoluzione/profili).
- Decisione aperta risolta: formato asset = **pipeline mista in-repo** (sorgenti
  SVG testuali + portrait PNG opzionali), nessun asset esterno obbligatorio,
  gameplay procedurale di fallback.

| Criterio | Esito | Evidenza |
|---|---|---|
| Ogni personaggio ha asset configurati dai campi RpgCharacterData | PASS | `rpg_character_asset_manifest_smoke_test` valida 7 personaggi: tutti i path popolati e i file presenti in-repo |
| Weapon layer e VFX separati dal corpo | PASS | weapon via `WeaponData.visual_data` (layer separato in `PlayerVisual._draw_weapon`); VFX via GameplayEffects; verificato per i 7 |
| Character Select, HUD e gameplay usano gli stessi dati senza fallback incoerenti | PASS | `portrait_hud_path` ora punta sempre al portrait HUD dedicato (fix 4 .tres); Character Select carica via catena coerente; HUD usa icona procedurale dalla stessa palette |
| Nessun asset esterno privo di licenza nel repo | PASS | ogni path sotto `res://assets/characters/`; ATTRIBUTION aggiornata (asset originali del progetto) |

### Test Milestone 6 eseguiti

| Test | Esito | Note |
|---|---|---|
| `tests/rpg_character_asset_manifest_smoke_test.gd` | PASS | 7 personaggi: path, file in-repo, weapon layer, HUD coerente, index allineato (199 assert) |
| `tests/character_select_ui_smoke_test.gd` | PASS | esteso: ogni HUD portrait carica dal path dati; safe-area, scroll, joypad |
| `tests/milestone_rpg_1_character_select_smoke_test.gd` | PASS | regressione character select |
| `tests/milestone_rpg_13_new_classes_smoke_test.gd` | PASS | regressione roster/classi avanzate |
| `tests/milestone_rpg_9_hud_smoke_test.gd` | PASS | regressione HUD RPG |
| `tests/survival_wave_smoke_test.gd` | PASS | regressione survival |
| `tests/combat_smoke_test.gd` | PASS | regressione combat/player visual |
| `tests/headless_shutdown_loop_test.gd` | PASS | 100 cicli main scene |

### Fix applicati nella Milestone 6

- `game/rpg/characters/{ranger,berserker,domatrice,licantropo}.tres`:
  `portrait_hud_path` ora punta al portrait HUD dedicato (`*_portrait_hud.svg`)
  invece del PNG full, uniformando la pipeline sui 7 personaggi.
- `assets/characters/index.json`: schema v2 con `status_definitions`
  (base_complete vs final_quality), `available_assets` completi (passive/super
  icon), `runtime_source_of_truth` e note pipeline.
- `assets/ATTRIBUTION.md`, `docs/rpg_character_visual_checklist.md`: documentati
  pipeline mista, statuses e separazione weapon/VFX.
- `tests/rpg_character_asset_manifest_smoke_test.gd`: nuovo smoke validazione asset.
- `tests/character_select_ui_smoke_test.gd`: esteso su path asset HUD.

### Limiti e follow-up Milestone 6

- L'arte definitiva per-personaggio (`final_quality`) resta un follow-up manuale
  artistico (uno alla volta, da `ranger_final_quality_pass`); il gameplay usa
  rendering procedurale data-driven come oggi.
- Le sprite sheet SVG sono cablate come dato/preview ma il corpo gameplay resta
  procedurale; l'eventuale switch a sprite animate e follow-up.
- Screenshot QA personaggi (1280x720/1024x768/960x540, default/reduced/high
  contrast) da acquisire nel playtest end-to-end Milestone 11.

## Milestone 5 dungeon ramificato, shop e biomi dedicati - 2026-06-17
- Branch: `master`
- HEAD corrente: non committato al momento della validazione locale.
- Scope validato: Milestone 5 di `todo_roadmap.md`, espansione del dungeon oltre
  il percorso lineare.
- Esito: PASS sui criteri automatizzabili; checklist manuale aggiornata per la QA
  con tre seed, scelta stanza, shop e ritorno menu.
- Decisione aperta risolta: lo shop usa **run credit** (valuta di run), non il
  denaro party persistente, per non toccare save/progressione.

| Criterio | Esito | Evidenza |
|---|---|---|
| Almeno un seed produce una scelta reale tra due stanze | PASS | generatore a grafo con ramo (forward >= 2); `dungeon_graph_smoke_test` su 8 seed, `dungeon_smoke_test` sceglie il ramo shop |
| Il percorso al boss resta sempre raggiungibile | PASS | `DungeonGenerator.boss_is_always_reachable` verificato su tutti i seed/room count |
| Shop e loot non duplicano DropSystem o progressione | PASS | shop spende run credit e genera reward via `DropSystem`; nessun uso del denaro party/save |
| La run termina dopo boss e torna ai risultati | PASS | boss -> unlock -> `request_next_room` -> stato `complete` -> `dungeon_completed` -> RunSessionTracker |

### Test Milestone 5 eseguiti

| Test | Esito | Note |
|---|---|---|
| `tests/dungeon_graph_smoke_test.gd` | PASS | grafo: ramo reale, boss raggiungibile, shop, determinismo, grid uniche (8 seed x 3 room count) |
| `tests/dungeon_smoke_test.gd` | PASS | traversata con scelta stanza, clear combat, shop purchase via DropSystem, boss e completamento |
| `tests/boss_smoke_test.gd` | PASS | regressione boss condiviso |
| `tests/milestone_19_boss_registry_smoke_test.gd` | PASS | regressione registry boss (rift_architect) |
| `tests/survival_wave_smoke_test.gd` | PASS | regressione survival |
| `tests/tower_defense_smoke_test.gd` | PASS | regressione cambio modalita |
| `tests/combat_smoke_test.gd` | PASS | regressione combat |
| `tests/isometric_environment_manifest_smoke_test.gd` | PASS | regressione Milestone 4 |
| `tests/region_streaming_smoke_test.gd` | PASS | regressione Milestone 3 |
| `tests/headless_shutdown_loop_test.gd` | PASS | 100 cicli main scene, lifecycle invariato |

### Fix applicati nella Milestone 5

- `game/procedural/dungeon_generator.gd`: generatore a grafo (DAG) con spine che
  garantisce il boss raggiungibile, un ramo con scelta reale che rientra sulla
  spine, kind `shop`/`rest`, helper statici `get_boss_room_id` e
  `boss_is_always_reachable`.
- `game/modes/dungeon/dungeon_room.gd`: supporto fino a due uscite mirate con
  etichetta destinazione, theming pavimento per kind e tint per profondita.
- `game/modes/dungeon/dungeon_mode.gd`: traversata su grafo, `choose_next_room`,
  run credit (guadagnati al clear combat), shop con offerte acquistabili via
  `DropSystem`, rest room curativa, mappa testuale e stato esteso.
- `game/ui/hud_manager.gd`: HUD dungeon mostra credit, scelta e mappa percorso.
- `tests/dungeon_graph_smoke_test.gd` e `tests/dungeon_smoke_test.gd`: nuovi/estesi.
- `docs/testing/manual_checklist.md`: checklist QA Milestone 5.

### Limiti e follow-up Milestone 5

- Lo shop e interagibile camminando sui marker offerta (acquisto a contatto se i
  credit bastano); una UI shop dedicata con conferma esplicita resta follow-up.
- Il bioma dungeon e un theming minimo (colore pavimento per kind + tint
  profondita) che riusa il rendering esistente; arte dedicata e follow-up.
- Screenshot dei tre seed e della scelta stanza da acquisire nel playtest
  end-to-end (Milestone 11).

## Milestone 4 asset isometrici ambiente e ostacoli coerenti - 2026-06-17
- Branch: `master`
- HEAD corrente: non committato al momento della validazione locale.
- Scope validato: Milestone 4 di `todo_roadmap.md`, pipeline asset isometrici
  ambientali guidata dal manifest con fallback procedurale.
- Esito: PASS sui criteri automatizzabili; checklist manuale aggiornata per la
  QA visuale a piu risoluzioni e profili.
- Gameplay implementato: nessuna nuova regola. Il manifest ambientale e ora
  letto dal codice; gli ostacoli ottengono ombra a terra e `sort_offset`
  data-driven; Y-sort abilitato in scena per ordinare correttamente ostacoli,
  zombie e pickup. Nessuna milestone successiva avviata.

| Criterio | Esito | Evidenza |
|---|---|---|
| Visual/collisione/footprint coerenti per oggetto convertito | PASS | `IsometricEnvironmentManifest` valida shape/footprint; `tests/isometric_environment_manifest_smoke_test.gd` costruisce ostacoli rettangolo/cerchio con collisione coerente |
| Y-sort non copre player/zombie/pickup in modo errato | PASS | `World/Enemies/Pickups/EnvironmentProps` con `y_sort_enabled`; ostacoli a `z_index=0` partecipano al sort; player a z=4 restano visibili (scelta co-op) |
| Oggetti grandi creano corridoi leggibili | PASS | layout/corridoio invariati (`biome_obstacle_generation`); ombra/sort non alterano collisioni |
| Nessun asset esterno obbligatorio per il bootstrap | PASS | tutti i `visual_scene` sono script `.gd` o vuoti; `requires_external_asset` = false per ogni oggetto |

### Test Milestone 4 eseguiti

| Test | Esito | Note |
|---|---|---|
| `tests/isometric_environment_manifest_smoke_test.gd` | PASS | manifest live, copertura biomi, no asset esterni, collisione/footprint/sort, Y-sort scena |
| `tests/biome_obstacle_generation_smoke_test.gd` | PASS | regressione layout/corridoi |
| `tests/zombie_environment_milestone_smoke_test.gd` | PASS | regressione props/casse per arena |
| `tests/survival_wave_smoke_test.gd` | PASS | regressione survival |
| `tests/dungeon_smoke_test.gd` | PASS | regressione modalita con World Y-sort |
| `tests/tower_defense_smoke_test.gd` | PASS | regressione enemies/pickups Y-sort |
| `tests/open_passage_transition_smoke_test.gd` | PASS | regressione megamappa/transizioni |
| `tests/combat_smoke_test.gd` | PASS | regressione combat |
| `tests/region_streaming_smoke_test.gd` | PASS | regressione Milestone 3 |
| `tests/milestone_20_arena_environment_smoke_test.gd` | PASS | gate/props arena con Y-sort |
| `tests/milestone_10_visual_smoke_test.gd` | PASS | sistemi visual |
| `tests/biome_world_generation_smoke_test.gd` | PASS | generazione mondo |
| `tests/headless_shutdown_loop_test.gd` | PASS | 100 cicli main scene, lifecycle invariato |

### Fix applicati nella Milestone 4

- `assets/environment/isometric/manifest.json`: riscritto alla versione 2 con i 21
  `obstacle_id` reali dei cinque biomi piu cliff/passaggio/cassa, ognuno con
  collision_shape, footprint_tiles, flag di blocco, jumpable e `sort_offset`.
- `game/modes/zombie/isometric_environment_manifest.gd`: nuovo loader/validatore
  con cache statica.
- `game/modes/zombie/biome_obstacle.gd`: ombra a terra procedurale, `sort_offset`
  data-driven e `z_index=0` per il Y-sort; rendering resta procedurale (fallback).
- `game/modes/zombie/obstacle_system.gd`: usa il manifest per `sort_offset` e per
  i flag di blocco (rimozione dai gruppi blocker se non bloccante).
- `game/main/main.tscn`: `y_sort_enabled` su `World`, `Enemies`, `Pickups` e
  `EnvironmentProps`.
- `assets/README.md`, `assets/ATTRIBUTION.md`: documentata la pipeline ambiente
  isometrica procedurale.
- `tests/isometric_environment_manifest_smoke_test.gd`: nuovo smoke.
- `docs/testing/manual_checklist.md`: nuova checklist QA visuale Milestone 4.

### Limiti e follow-up Milestone 4

- Gli oggetti ambientali restano render procedurale: la conversione ad arte
  esterna definitiva e volutamente rinviata (nessun asset esterno introdotto).
  Il manifest e pronto a ricevere `visual_scene` reali per categoria.
- I player restano sempre sopra gli ostacoli (`z=4`) per leggibilita co-op; il
  Y-sort completo player-vs-ambiente resta una scelta di design futura.
- Screenshot per bioma (default/high contrast) da acquisire nel playtest
  end-to-end della Milestone 11.

## Milestone 3 attraversamento megamappa e streaming regioni - 2026-06-17
- Branch: `master`
- HEAD corrente: non committato al momento della validazione locale.
- Scope validato: Milestone 3 di `todo_roadmap.md`, QA attraversamento megamappa
  e streaming controllato delle regioni.
- Esito: PASS sui criteri automatizzabili; checklist manuale aggiornata per la
  traversata reale e la cattura screenshot.
- Gameplay implementato: nessuna nuova modalita. Aggiunta persistenza runtime per
  regione (casse aperte non ricompaiono al rientro) e formalizzato il contratto
  `active_regions` (regione corrente + vicini come dati, regioni lontane non
  istanziate). Nessuna milestone successiva avviata.

| Criterio | Esito | Evidenza |
|---|---|---|
| Attraversamento di otto regioni senza teletrasporti | PASS | `tests/region_streaming_smoke_test.gd` cammina 8+ regioni connesse; `open_passage_transition` conferma il no-teleport fisico |
| Regioni lontane non istanziate | PASS | `active_regions` = regione corrente + vicini; oltre il raggio resta dato; solo la regione corrente istanzia contenuti (casse) |
| Casse aperte non ricompaiono al rientro | PASS | apertura cassa registrata nel ledger per regione; rientro in regione A non rigenera la cassa consumata |
| Encounter completati non ricompaiono | PASS | ledger `completed_encounters` per regione persistito; gli encounter casuali restano transitori per wave, non legati alla regione |
| Mappa esplorazione e save v6 coerenti | PASS | round-trip save v6 del ledger (casse/ostacoli/encounter); `exploration_map` e `persistent_world` invariati |

### Test Milestone 3 eseguiti

| Test | Esito | Note |
|---|---|---|
| `godot --headless --path . --quit` | PASS | bootstrap pulito, exit code `0` |
| `tests/region_streaming_smoke_test.gd` | PASS | contratto active_regions, traversata 8+ regioni, persistenza casse, round-trip save v6 |
| `tests/world_graph_connectivity_smoke_test.gd` | PASS | regressione grafo mondo |
| `tests/persistent_world_generation_smoke_test.gd` | PASS | regressione stato persistente |
| `tests/open_passage_transition_smoke_test.gd` | PASS | regressione passaggi aperti / no-teleport |
| `tests/exploration_map_smoke_test.gd` | PASS | regressione mappa esplorazione |
| `tests/survival_wave_smoke_test.gd` | PASS | regressione survival wave |
| `tests/milestone_9_smoke_test.gd` | PASS | regressione save/load progressione |
| `tests/random_encounter_smoke_test.gd` | PASS | regressione encounter/reward crate |
| `tests/biome_mini_events_smoke_test.gd` | PASS | regressione mini-eventi/reward crate |
| `tests/zombie_environment_milestone_smoke_test.gd` | PASS | regressione casse/ostacoli per arena |
| `tests/headless_shutdown_loop_test.gd` | PASS | 100 cicli main scene, lifecycle invariato |

### Fix applicati nella Milestone 3

- `game/world/persistent_world_state.gd`: ledger per regione tipizzato
  (`opened_crates`, `destroyed_obstacles`, `completed_encounters`) con API di
  marcatura/lettura, sopra il `region_runtime_state` esistente.
- `game/world/world_runtime.gd`: contratto `active_regions` documentato, accessor
  `is_region_active`, pass-through del ledger e nuovo segnale
  `region_runtime_changed`.
- `game/saves/save_manager.gd`: autosave su `region_runtime_changed` per portare
  le casse aperte nel save v6 senza bump di versione.
- `game/modes/zombie/resource_crate_system.gd`: le casse di layout ricevono una
  chiave stabile per regione, vengono saltate se gia aperte e registrano il
  consumo all'apertura; reset dei riferimenti in `stop_run`.
- `tests/region_streaming_smoke_test.gd`: nuovo smoke per streaming, persistenza
  e round-trip save.
- `docs/testing/manual_checklist.md`: nuova checklist QA traversata 20 minuti.

### Limiti e follow-up Milestone 3

- `destroyed_obstacles` e `completed_encounters` sono persistiti a livello dati e
  coperti dal round-trip save, ma non hanno ancora un trigger di gioco: gli
  ostacoli `BiomeObstacle` non sono distruttibili e gli encounter casuali restano
  transitori per wave. Il ledger e pronto per encounter region-bound o ostacoli
  distruttibili futuri senza cambi di contratto.
- Screenshot/video reali della traversata e della mappa restano da acquisire nel
  playtest end-to-end di bilanciamento (Milestone 11).

## Milestone 2 mini-eventi bioma - 2026-06-17
- Branch: `master`
- HEAD corrente: non committato al momento della validazione locale.
- Scope validato: Milestone 2 di `todo_roadmap.md`, QA/tuning di
  mini-eventi bioma, status e encounter.
- Esito: PASS sui criteri automatizzabili e checklist manuale aggiornata.
- Gameplay implementato: tuning mirato dei mini-eventi esistenti; nessuna nuova
  modalita o milestone successiva avviata.
- Nota manuale: screenshot/video dei quattro eventi non sono stati acquisiti in
  questa sessione headless; la checklist manuale in
  `docs/testing/manual_checklist.md` specifica la cattura da fare durante il
  playtest end-to-end di bilanciamento.

| Criterio | Esito | Evidenza |
|---|---|---|
| Mini-eventi leggibili e identificabili | PASS | telegraph con ID reale per `toxic_leak`, `fire_breakout`, `whiteout`, `marsh_emergence` |
| Rischio evitabile | PASS | `whiteout` applica `freeze` solo al player rimasto nel warning; player fuori area non riceve status |
| Reward proporzionata | PASS | reward crate tematiche tossico/fuoco/frost/palude quando `ResourceCrateSystem` e presente |
| Frequenza/cooldown | PASS | cooldown di due wave complete, skip in wave critica/boss e prima wave coperti da smoke |
| Accessibilita visuale | PASS | telegraph verificati con high contrast e reduced motion nello smoke mini-eventi |
| Regressione survival/RPG | PASS | survival wave e roster RPG avanzato verificati in headless |

### Test Milestone 2 eseguiti

| Test | Esito | Note |
|---|---|---|
| `godot --headless --path . --import --quit` | PASS | cache Godot rigenerata prima dei test |
| `tests/random_encounter_smoke_test.gd` | PASS | cooldown/frequenza, reward crate e ID telegraph |
| `tests/biome_mini_events_smoke_test.gd` | PASS | quattro mini-eventi, reward, preset visuali e status evitabile |
| `tests/biome_status_effects_smoke_test.gd` | PASS | regressione status canonici |
| `tests/survival_wave_smoke_test.gd` | PASS | regressione survival, exit code `0` |
| `tests/milestone_rpg_13_new_classes_smoke_test.gd` | PASS | regressione RPG roster/classi avanzate |

### Fix applicati nella Milestone 2

- `game/modes/zombie/random_encounter_system.gd`: i telegraph dei mini-eventi
  usano l'ID evento reale, i mini-eventi avanzati generano reward crate
  tematiche e gli status da warning colpiscono solo chi resta nell'area.
- `game/modes/zombie/resource_crate_system.gd`: le crate gia in `queue_free`
  vengono potate prima della validazione di spacing, evitando falsi blocchi tra
  encounter consecutivi.
- `tests/random_encounter_smoke_test.gd` e
  `tests/biome_mini_events_smoke_test.gd`: copertura estesa su tuning,
  cooldown, reward fisiche, preset visuali e status evitabile.

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
