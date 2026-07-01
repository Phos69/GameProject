# Report migrazione scala iso

Data: 2026-07-01.

## Sintesi

La generazione mondo isometrica usa ora un tile logico che rappresenta `3x3`
celle legacy. Le regioni standard passano da `500x500` celle legacy a `150x150`
tile logici: la copertura lineare equivale a `450x450` celle legacy, mentre gli
asset restano caricati e renderizzati alla loro dimensione nativa.

## Contratto

- `IsoGridConfig.LEGACY_TILE_SCALE = 8.0`.
- `IsoGridConfig.LOGICAL_TILE_SCALE = 24.0`.
- `IsoGridConfig.NEW_TILE_SCALE = 3`.
- `IsoGridConfig.BIOME_SIZE = Vector2i(150, 150)`.
- `IsoGridConfig.LEGACY_EQUIVALENT_SIZE_TILES = 450`.
- Strada principale: `14` tile logici.
- Sentiero/strada secondaria: `7` tile logici.
- Passaggio fisico: `14` tile logici, bordo profondo `1` tile.
- Rocce void-first scalabili: `5x5`-`10x10` tile logici.
- `forest_tree`: slot di design `3x3`, footprint runtime `4x4` tile logici.

## Metriche

- Vecchia regione: `500 * 500 = 250000` celle generate.
- Nuova regione: `150 * 150 = 22500` tile generati.
- Riduzione celle generate: `91%`.
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

`WorldSnapshotCodec.FORMAT_VERSION` e `TileBakeCache.FORMAT_VERSION` sono stati
incrementati a `3`: snapshot e tile bake pre-migrazione vengono scartati e
rigenerati. I save persistenti non salvano il layout completo, ma seed, regione
corrente e stato esplorazione; con lo stesso seed la topologia resta
deterministica, mentre la geometria locale viene rigenerata alla nuova scala.

## Validazione

- `./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/world_gen`
- `./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/obstacles`
- `./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/environment`
- `./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/modes -Select zombie_modes`
- `./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/assets -Select texture_cache`
