# Report migrazione scala iso

Data: 2026-07-02.

## Sintesi

La generazione mondo isometrica usa ora un tile logico che rappresenta `6x6`
celle legacy. Le regioni standard passano da `150x150` a `75x75` tile logici:
la copertura lineare resta equivalente a `450x450` celle legacy, mentre gli
asset restano caricati e renderizzati alla loro dimensione nativa.

## Contratto

- `IsoGridConfig.LEGACY_TILE_SCALE = 8.0`.
- `IsoGridConfig.LOGICAL_TILE_SCALE = 48.0`.
- `IsoGridConfig.NEW_TILE_SCALE = 6`.
- `IsoGridConfig.BIOME_SIZE = Vector2i(75, 75)`.
- `IsoGridConfig.LEGACY_EQUIVALENT_SIZE_TILES = 450`.
- `IsoGridConfig.GENERATED_TILE_COUNT = 5625`.
- Strada principale: `7` tile logici.
- Sentiero/strada secondaria: `4` tile logici.
- Passaggio fisico: `7` tile logici, bordo profondo `1` tile.
- Rocce void-first scalabili: `3x3`-`5x5` tile logici.
- `forest_tree`: slot di design `3x3`, footprint runtime `2x2` tile logici.
- Chunk visuali: `balanced = 10`, `performance = 13`, `quality = 8`.

## Metriche

- Regione legacy originale: `500 * 500 = 250000` celle generate.
- Regione intermedia: `150 * 150 = 22500` tile generati.
- Regione corrente: `75 * 75 = 5625` tile generati.
- Riduzione celle generate rispetto al legacy originale: `97,75%`.
- Riduzione celle generate rispetto al pass `150x150`: `75%`.
- Copertura legacy equivalente: `450 * 450 = 202500` celle, pari all'`81%`
  dell'area legacy precedente e al `90%` della dimensione lineare precedente.

## Sistemi aggiornati

- Generazione mappa, layout e validazione: `BiomeMapGenerator`,
  `BiomeTerrainGenerator`, `ObstacleLayoutGenerator`, `MapValidationSystem`.
- Passaggi e confini: `BiomePassage`, `BiomePassageGenerator`,
  `FallBoundaryGenerator`, `WorldRegionConnection`, `RegionSeamSystem`.
- Tile/asset runtime: `BiomeEnvironmentLayout`, `BiomeTileLayer`,
  `IsometricTileResolver`, `IsometricEnvironmentManifest`,
  `IsometricEnvironmentObject`, rock mesh/occluder.
- Modalita: `InfiniteArenaMode`, `ZombieModeController` tramite layout generati.
- Cache: `WorldSnapshotCodec` e `TileBakeCache`.

## Compatibilita cache e save

`WorldSnapshotCodec.FORMAT_VERSION` e stato incrementato a `4` e
`TileBakeCache.FORMAT_VERSION` a `10`: snapshot e tile bake pre-migrazione
vengono scartati e rigenerati. I save persistenti non salvano il layout
completo, ma seed, regione corrente e stato esplorazione; con lo stesso seed la
topologia resta deterministica, mentre la geometria locale viene rigenerata alla
nuova scala. Per questo non serve un bump del formato save persistente.

## Validazione

- `./tools/run_gut.ps1 -GutDir res://tests/suites/world_gen`
- `./tools/run_gut.ps1 -GutDir res://tests/suites/environment`
- `./tools/run_gut.ps1 -GutDir res://tests/suites/obstacles`
- `./tools/run_gut.ps1 -GutDir res://tests/suites/modes -Select zombie_modes`
- `./tools/run_gut.ps1 -GutDir res://tests/suites/assets -Select texture_cache`
