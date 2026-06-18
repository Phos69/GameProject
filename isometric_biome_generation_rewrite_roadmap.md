# Isometric Biome Generation Rewrite Roadmap

Roadmap operativa per riscrivere la generazione isometrica dei biomi senza
limitarsi al vecchio layout `200x200` a pavimento continuo.

## Audit iniziale

Stato al 2026-06-18:

- `BiomeMapGenerator` creava celle di mondo `200x200` e passava la dimensione a
  `BiomeCell`, `WorldGraph` e `WorldRegion`.
- `BiomeEnvironmentLayout` considerava walkable ogni cella non occupata da
  ostacoli, hazard, border o fall zone; quindi il chunk non partiva da void.
- `ObstacleLayoutGenerator` generava due strade diagonali principali e dettagli
  hardcoded su coordinate pensate per `200x200`.
- `FallBoundaryGenerator` copriva solo i lati senza vicino con fall zone.
- `MapValidationSystem` validava pathfinding bloccando ostacoli e fall zone, ma
  non trattava il void logico come non attraversabile.
- `BiomeTileLayer` e `IsometricTileResolver` coprivano tutte le celle, ma
  dipendevano dalla classificazione walkable-by-default del layout.
- `WorldRegionStreamer` istanziava tile, ostacoli, hazard e crate per regione
  corrente e vicini, ma lo spawner zombie verificava solo regione caricata,
  ostacoli e hazard, non la classe terrain della cella.

File principali coinvolti:

- Generazione mondo/chunk: `game/procedural/world_generation/biome_map_generator.gd`,
  `biome_terrain_generator.gd`, `obstacle_layout_generator.gd`,
  `biome_passage_generator.gd`, `fall_boundary_generator.gd`,
  `map_validation_system.gd`.
- Dati layout/biomi: `game/modes/zombie/biome_environment_layout.gd`,
  `biome_definition.gd`, risorse in `game/modes/zombie/biomes/`.
- Rendering isometrico: `game/modes/zombie/biome_tile_layer.gd`,
  `isometric_tile_resolver.gd`, `terrain_generator.gd`,
  `assets/environment/isometric/manifest.json`.
- Collisioni/ostacoli/hazard: `game/modes/zombie/obstacle_system.gd`,
  `hazard_system.gd`, `biome_fall_zone.gd`, `isometric_environment_object*.gd`.
- Streaming/transizioni: `game/world/world_region_streamer.gd`,
  `world_graph.gd`, `world_region.gd`, `world_region_connection.gd`,
  `region_seam_system.gd`, `game/modes/zombie/biome_transition_system.gd`.
- Spawn/pathfinding: `game/modes/zombie/zombie_spawner.gd`, `EnemySystem`,
  `BasicEnemy`.

## Milestone R1 - Chunk 500x500 e base void

Stato: completata in questo ciclo.

Obiettivo:

- Portare il chunk bioma standard a `500x500`.
- Cambiare il modello del layout: il chunk parte da void e il generatore scava
  pavimento, strade, passaggi e blocchi.
- Rendere il void rimanente un rischio fisico tramite fall zone nei blocchi
  interni void/partial void.

Implementato:

- `BiomeEnvironmentLayout.DEFAULT_ZONE_SIZE = Vector2i(500, 500)`.
- `BiomeMapGenerator` usa `500x500` come default e accetta override debug
  `biome_cell_size`, `biome_cell_width`, `biome_cell_height`.
- `BiomeEnvironmentLayout` espone `floor_rects`, `block_rects`,
  `block_kinds`, `add_floor_rect()`, `add_block_rect()` e
  `add_fall_zone_rect()`.
- `get_terrain_class_at_cell()` restituisce `TERRAIN_VOID` per celle non
  scavate, invece di fallback walkable.
- `MapValidationSystem` considera void, fall zone e ostacoli come bloccati nel
  flood-fill e verifica spawn/crate su terrain walkable.
- `BiomePassageGenerator` genera aperture fisiche a larghezza 40.
- `ObstacleLayoutGenerator` genera rete principale orizzontale/verticale a
  larghezza 40, sentieri bioma medi a larghezza 20, blocchi interni
  classificati e void/fall zone interni.
- `ZombieSpawner` valida la classe terrain della cella nelle regioni streamate,
  impedendo spawn su void non walkable.
- Aggiunto `tests/isometric_biome_generation_rewrite_smoke_test.gd`.

Criteri coperti:

- Chunk `500x500`.
- Strade principali larghe 40.
- Sentieri medi larghi 20.
- Passaggi fisici larghi 40 e walkable.
- Blocchi interni con floor, ostacoli e void/fall zone.
- Spawn player e crate su celle walkable.
- Classificazione completa del chunk.

Test eseguiti:

- `godot --headless --path . --script res://tests/isometric_biome_generation_rewrite_smoke_test.gd` - PASS.
- `godot --headless --path . --script res://tests/biome_world_generation_smoke_test.gd` - PASS.
- `godot --headless --path . --script res://tests/isometric_biome_terrain_coverage_smoke_test.gd` - PASS.
- `godot --headless --path . --script res://tests/milestone_10_tile_layer_smoke_test.gd` - PASS.
- `godot --headless --path . --script res://tests/world_graph_connectivity_smoke_test.gd` - PASS.
- `godot --headless --path . --script res://tests/milestone_7_graph_connectivity_smoke_test.gd` - PASS.
- `godot --headless --path . --script res://tests/milestone_10_no_portal_transition_smoke_test.gd` - PASS.

## Milestone R2 - Pareti perimetrali isometriche e bordo void avanzato

Stato: completata (R2.1 tiling + volume; R2.2 facce verticali rifinite).

Obiettivo:

- Sostituire i segmenti perimetrali generati come ostacoli rettangolari con un
  contratto esplicito di parete verticale isometrica.
- Separare visivamente wall, cliff lip e void depth sui bordi.
- Rendere i varchi tra biomi leggibili come strada o ponte senza portali.

Implementato:

- Prima il perimetro era UN solo ostacolo per lato: a runtime diventava un
  singolo sprite centrato (problema "solo il centro e isometrico" applicato ai
  muri). Inoltre `repair_layout` rimuoveva l'intero muro del lato appena
  toccava una strada principale, lasciando i lati quasi senza pareti.
- `BiomeEnvironmentLayout` ora espone un contratto esplicito di parete:
  `wall_segment_rects`, `wall_segment_sides`, `wall_height_cells`,
  `add_wall_segment()` e `get_wall_segments_for_side()`.
- `ObstacleLayoutGenerator._add_border_segment` piastrella ogni lato in una
  sequenza contigua di segmenti `WALL_SEGMENT_LENGTH = 12` celle, registrando
  il contratto sul layout; cosi l'intera parete e isometrica e continua.
- `_add_connected_border_walls` apre un varco per OGNI passaggio del lato (non
  solo il primo): le connessioni extra-edge non vengono piu sigillate.
- `BiomeObstacle` rende le pareti `border` come volume isometrico estruso
  (`_draw_iso_perimeter_wall`): ombra, facce laterali, faccia frontale, tetto
  illuminato, pilastri verticali e accento per bioma; `is_perimeter_wall()` e
  `get_wall_height()` espongono il contratto alto.
- `IsometricEnvironmentObject` forza il path procedurale per i `border` cosi il
  muro lungo e orientabile invece del singolo sprite tile.
- Bugfix collegato: un blocco interno void poteva cadere sopra il corridoio di
  un passaggio (il fall zone sovrascriveva la strada in classificazione e
  metteva un hazard di caduta sulla strada). Ora i blocchi void/partial-void che
  intersecano `passage_rects`/`passage_connector_rects` diventano `open`.

Criterio di accettazione:

- Ogni lato non fall ha pareti alte, continue e con volume isometrico. OK
- Ogni lato fall mostra bordo, profondita e danno coerente (cliff renderer). OK
- I passaggi tagliano le pareti senza overlap collisioni. OK (test)

Test:

- Nuovo `tests/isometric_perimeter_wall_smoke_test.gd` - PASS.
- `isometric_biome_generation_rewrite_smoke_test.gd` - PASS.
- `biome_world_generation_smoke_test.gd` - PASS (regressione passaggio
  irraggiungibile individuata e risolta).

R2.2 implementato:

- Il mondo usa una proiezione obliqua dall'alto (nessuno shear di schermo):
  estrudere in verticale un muro N-S faceva collassare le facce laterali in una
  riga degenere. `_draw_iso_perimeter_wall` ora dispatcha per orientamento:
  `_draw_horizontal_wall` (box estruso) per E-W, `_draw_vertical_wall` (faccia
  laterale con shear up-and-right, depth courses, crest illuminata) per N-S.
- Helper unificati `_draw_wall_grooves`/`_draw_wall_style_accent` operano sul
  bordo della faccia vicina per entrambi gli orientamenti, con accento bioma.

Resta aperto:

- I varchi aperti da `repair_layout` dove una strada principale tocca un lato
  non-passaggio creano un buco singolo nel muro: valutare se chiudere o
  trasformare in uscita esplicita.

Regressioni rivalidate il 2026-06-18:

- `isometric_perimeter_wall_smoke_test.gd` - PASS.
- `fall_boundary_visual_logic_smoke_test.gd` - PASS.
- `milestone_10_void_cliff_asset_smoke_test.gd` - PASS.
- `milestone_10_tile_layer_smoke_test.gd` - PASS.

## Milestone R3 - Asset e blocchi interni finalizzati

Stato: in corso (R3.1 props piccoli avviato).

Obiettivo:

- Raffinare classificazione blocchi in edificio, bosco, rovine, piazza,
  ostacolo grande, partial void e full void.
- Aggiungere props piccoli tematici su griglia isometrica.
- Verificare che ogni bioma usi identita visiva distinta senza placeholder.

R3.1 implementato (props piccoli):

- `ObstacleLayoutGenerator._add_block_props` riempie ogni blocco non-void con
  props piccoli tematici (densita per kind: bosco 6, rovine 5, open 3, altri 2;
  cap globale `MAX_BLOCK_PROPS = 64`). Deterministico dal seed cella.
- `_add_prop_if_clear` posiziona solo su celle libere: mai su strade/route,
  ostacoli, fall zone o hazard -> nessun impatto sul pathfinding.
- Pool props per bioma in `_small_prop_ids` usa SOLO id gia con contratto
  `object_scenes` completo (small_rock, fallen_log/marsh_log, broken_fence,
  toxic_barrel, industrial_fence, ash_barrier, ice_rock, reed_wall), cosi i
  props hanno sempre resa finita. Gli id finiscono nel whitelist bioma via
  `BiomeManager._apply_generated_layouts` (merge di `layout.obstacle_ids`).
- Nuovo `tests/isometric_block_props_smoke_test.gd` - PASS: verifica >=3 props
  dentro i blocchi per bioma, off-route/off-fall, layout ancora valido.

Resta (R3.2+):

- Art dedicata per cespugli/lampioni/casse decorative: richiede nuovi id con
  contratto `object_scenes` completo (asset SVG, source, license, attribution,
  biome_ids, footprint) + draw mode in `OBJECT_DRAW_MODES` + `_draw_*` in
  `biome_obstacle.gd`. Il test v7 impone il contratto, quindi va fatto in blocco.
- Props soft non-collidenti (erba/cespugli a terra): valutare `blocks_movement`
  false nel manifest per i nuovi id, oppure un layer di decorazioni tile-level
  (il `terrain_patch` attuale NON viene renderizzato nello streaming survival).
- Differenziare la classificazione blocchi (piazza vs open) e l'identita visiva
  per bioma con set props piu ampi.

Test richiesto (futuro):

- Smoke su presenza asset per block kind e biome id.
- QA screenshot per i cinque biomi.

## Milestone R4 - Resa void leggibile

Stato: in corso (R4.1 placeholder sgranato rimosso).

Problema riscontrato:

- I blocchi void interni venivano renderizzati come `BiomeFallZone` dimensionati
  sull'intero blocco (es. 800x800 px) che stiracchiavano una singola tile SVG
  `fall_zone.svg` (160x120) -> placeholder sgranato/sfocato che copriva il void e
  parte del contorno. Le strisce void perimetrali (sottili) restavano nitide.

R4.1 implementato:

- `BiomeFallZone._is_large_void()` (lato minore >= `LARGE_VOID_MIN = 110` px)
  distingue le fosse interne dalle strisce di bordo.
- Per le fosse grandi `IsometricCliffRenderer.configure(..., disable_assets)`
  salta gli sprite SVG stiracchiati (niente placeholder sgranato).
- `BiomeFallZone._draw_large_void()` rende una fossa pulita: base scura piena,
  banding di profondita, cornice/ombra interna che la fa leggere come incassata,
  rim luminoso sul bordo del pavimento e linee verticali di profondita che
  partono dal pavimento e sfumano nel colore del void (`_draw_faded_line`).
- Le strisce perimetrali sottili continuano a usare il cliff renderer SVG.
- `milestone_10_void_cliff_asset_smoke_test.gd` aggiornato: per le fosse interne
  grandi verifica il path procedurale pulito, per le perimetrali il renderer
  asset. Resta FAIL 2 PRE-ESISTENTE (`fall_side` "internal" normalizzato a
  north/west vs metadata layout) non collegato a questo lavoro.

R4.2 implementato (placeholder rimosso anche dai bordi + esterno void):

- Ora TUTTE le fall zone disattivano gli sprite SVG (`_configure_cliff_renderer`
  passa sempre `disable_assets = true`): niente piu placeholder sgranato neanche
  sui bordi esterni della mappa. Le strisce perimetrali usano il cliff
  procedurale pulito (`_draw_procedural_cliff`), le fosse interne `_draw_large_void`.
- `ZombieModeController` dipinge un backdrop a tutto schermo
  (`CanvasLayer.layer = -100` + `ColorRect` full-rect) col colore void del bioma
  attivo (`palette.background_color.darkened(0.68)`, stesso shade di
  `TILE_VOID_DEPTH`): tutto cio che sta oltre i bordi del chunk e ora void.
  Backdrop aggiornato a ogni cambio bioma e liberato in `stop_run`.
- `milestone_10_void_cliff_asset_smoke_test.gd` aggiornato: le fall zone runtime
  usano il void procedurale (niente asset renderer); i contratti void restano
  comunque validati a livello manifest. Le 2 asserzioni pre-esistenti sul
  `fall_side` interno erano gia state risolte in R4.1. Test verde.

R4.3 implementato (void = solo colore + confini, niente immagine):

- `BiomeFallZone` non disegna piu alcuna "immagine" del void (rimossi outline
  jagged, depth band, streak, fading lines, cliff lip). Il colore void e fornito
  dal tile layer (celle void) e dal backdrop off-map; la fall zone disegna solo
  il confine del mondo.
- `_draw_world_edges`: per le strisce perimetrali una sola linea di confine sul
  lato pavimento (orientata per `fall_side`), per le fosse interne il contorno
  completo. Ogni confine e un crest luminoso sul bordo pavimento/void + ombra
  scalettata nel void, cosi il limite della mappa (es. lato alto) si legge come
  un muro/ciglio.
- Tile layer: `TILE_VOID_EDGE_NEAR` e `TILE_VOID_DEPTH` ora hanno lo STESSO
  colore (`background_color.darkened(0.68)`, uguale al backdrop): il void e
  uniforme dentro e fuori la mappa, senza la banda piu chiara che lo distingueva.
- Rimosso codice morto: `_draw_large_void`, `_draw_procedural_cliff`,
  `_jagged_outline`, `_draw_cliff_lip`, `_draw_depth_streaks`, ecc.

Resta (R4.4+):

- Le celle `TERRAIN_VOID` non coperte da una fall zone non hanno linea di
  confine: valutare se aggiungerla o se sono sempre adiacenti a fall zone.
- Eventuale spessore/altezza del confine differenziato per bioma.

## Milestone R5 - Pulizia render legacy

Stato: in corso.

R5.1 implementato (playground arena obsoleto al centro):

- `IsometricPlayground` (`game/main/isometric_playground.gd`) disegnava una
  griglia di tile diamante + barricate + marker + corsie all'origine del mondo
  (centro mappa): elementi puramente visivi (nessuna collisione) ormai obsoleti
  perche il tile layer streamato dipinge tutto il chunk, ma restavano visibili.
- `TerrainGenerator.begin_streaming_run` ora nasconde il playground
  (`_set_legacy_playground_visible(false)`); `start_run` (modalita arena
  non-streaming) lo tiene visibile, `stop_run` lo ripristina. Cosi in survival
  il centro mappa non mostra piu lo sfondo/oggetti legacy.

## Pass F1 - Texture isometriche foresta base

Stato: completato.

Obiettivo:

- Implementare un primo sistema completo di texture isometriche per il bioma
  base foresta, mappato sull'ID gameplay `infected_plains`.
- Separare visivamente grass, tall grass, path, road, void, cliff edge,
  mountain wall e transizioni.
- Mantenere gameplay, collisioni, pathfinding, spawn e danno da caduta
  invariati.

Implementato:

- `assets/environment/isometric/tiles/forest/` contiene tile SVG dedicati per
  `forest_grass`, varianti, `forest_tall_grass`, `forest_path`, `forest_road` e
  transizioni.
- `assets/environment/isometric/edges/` contiene `forest_void`,
  `forest_cliff_edge` e `forest_mountain_wall`.
- `assets/environment/isometric/manifest.json` collega `infected_plains` al
  tile set forestale e registra i nuovi contratti in `terrain_tiles`,
  `edge_tiles`, `void_tiles`, `biome_asset_sets` e `terrain.tags`.
- `ObstacleLayoutGenerator` marca i blocchi `forest` del bioma base come
  `forest_tall_grass`; il terrain resta walkable.
- `BiomeEnvironmentLayout.get_floor_tag_at_cell()` espone i floor tag al
  resolver senza cambiare la classificazione terrain.
- `IsometricTileResolver` applica regole neighbor-aware per `grass_to_path`,
  `grass_to_road`, `grass_to_tall_grass`, `path_to_road`,
  `ground_to_void_cliff` e `ground_to_mountain_wall`.
- `BiomeTileLayer` pre-bake-a linee di dettaglio per erba, tall grass, path,
  road, transizioni, cliff e void.
- `BiomeTerrainPatch` e `BiomeObstacle` hanno fallback procedurali coerenti
  per i nuovi draw mode forestali.
- Aggiunto `tests/forest_isometric_texture_transition_smoke_test.gd`.
- Documentato il contratto in `docs/forest_isometric_texture_system.md`.

Test eseguiti:

- `forest_isometric_texture_transition_smoke_test.gd` - PASS.
- `milestone_10_tile_layer_smoke_test.gd` - PASS.
- `isometric_environment_manifest_smoke_test.gd` - PASS.
- `milestone_10_asset_pipeline_smoke_test.gd` - PASS.
- `isometric_biome_terrain_coverage_smoke_test.gd` - PASS.
- `isometric_biome_generation_rewrite_smoke_test.gd` - PASS.
- `isometric_perimeter_wall_smoke_test.gd` - PASS.
- `milestone_10_void_cliff_asset_smoke_test.gd` - PASS.
- `fall_boundary_visual_logic_smoke_test.gd` - PASS.
- `tools/generate_isometric_environment_assets.gd -- --check` - PASS
  (`checked=108`).

## Note tecniche e rischi

- `tests/zombie_biome_transition_smoke_test.gd` FALLISCE (FAIL 15) gia dal commit
  pre-sessione 96caf51: asserisce conteggi esatti single-region
  (`get_active_obstacles().size() == layout.obstacle_positions.size()`)
  incompatibili con lo streaming multi-region introdotto dalla riscrittura
  500x500. PRE-ESISTENTE, non collegato al lavoro di questa sessione.

- `500x500` aumenta la cache tile da 40.000 a 250.000 celle per regione. Il
  renderer usa gia mesh pre-baked, ma va rivalidato con `milestone_10_isometric_performance_smoke_test.gd`.
- Le risorse base `.tres` storiche restano reference/fallback; il runtime
  survival usa layout generati dal seed.
- La vecchia roadmap isometrica cancellata nella worktree non e stata
  ripristinata.
