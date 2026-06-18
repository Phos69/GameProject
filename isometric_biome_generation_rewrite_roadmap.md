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
- `BiomePassageGenerator` genera aperture fisiche a larghezza 10.
- `ObstacleLayoutGenerator` genera rete principale orizzontale/verticale a
  larghezza 10, sentieri bioma a larghezza 4, blocchi interni classificati e
  void/fall zone interni.
- `ZombieSpawner` valida la classe terrain della cella nelle regioni streamate,
  impedendo spawn su void non walkable.
- Aggiunto `tests/isometric_biome_generation_rewrite_smoke_test.gd`.

Criteri coperti:

- Chunk `500x500`.
- Strade principali larghe 10.
- Sentieri larghi 4.
- Passaggi fisici larghi 10 e walkable.
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

Stato: prossima.

Obiettivo:

- Sostituire i segmenti perimetrali generati come ostacoli rettangolari con un
  contratto esplicito di parete verticale isometrica.
- Separare visivamente wall, cliff lip e void depth sui bordi.
- Rendere i varchi tra biomi leggibili come strada o ponte senza portali.

Criterio di accettazione:

- Ogni lato non fall ha pareti alte e asset-driven.
- Ogni lato fall mostra bordo, profondita e danno coerente.
- I passaggi tagliano le pareti senza overlap collisioni.

Test richiesto:

- Estendere `isometric_biome_generation_rewrite_smoke_test.gd`.
- Rieseguire `fall_boundary_visual_logic`, `milestone_10_passage_tile` e
  `milestone_10_void_cliff_asset`.

## Milestone R3 - Asset e blocchi interni finalizzati

Stato: aperta.

Obiettivo:

- Raffinare classificazione blocchi in edificio, bosco, rovine, piazza,
  ostacolo grande, partial void e full void.
- Aggiungere props piccoli tematici su griglia isometrica.
- Verificare che ogni bioma usi identita visiva distinta senza placeholder.

Test richiesto:

- Smoke su presenza asset per block kind e biome id.
- QA screenshot per i cinque biomi.

## Note tecniche e rischi

- `500x500` aumenta la cache tile da 40.000 a 250.000 celle per regione. Il
  renderer usa gia mesh pre-baked, ma va rivalidato con `milestone_10_isometric_performance_smoke_test.gd`.
- Le risorse base `.tres` storiche restano reference/fallback; il runtime
  survival usa layout generati dal seed.
- La vecchia roadmap isometrica cancellata nella worktree non e stata
  ripristinata.
