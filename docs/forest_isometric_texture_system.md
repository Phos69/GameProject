# Forest Isometric Texture System

Stato: primo pass completo per il bioma base `infected_plains`, usato come
foresta di partenza della survival.

## Contratto runtime

Il bioma base continua a usare l'ID gameplay `infected_plains`; il layer
visuale lo risolve come set forestale per non cambiare wave, pathfinding,
spawn o save esistenti.

Tile principali:

- `forest_grass`, `forest_grass_variant_01`, `forest_grass_variant_02`
- `forest_tall_grass`
- `forest_path`
- `forest_road`
- `forest_void`
- `forest_cliff_edge`
- `forest_mountain_wall`

Transizioni:

- `grass_to_path`
- `grass_to_road`
- `grass_to_tall_grass`
- `path_to_road`
- `ground_to_void_cliff`
- `ground_to_mountain_wall`

I contratti vivono in `assets/environment/isometric/manifest.json`. Gli SVG
sono in `assets/environment/isometric/tiles/forest/` e in
`assets/environment/isometric/edges/{cliffs,void,walls}/`.

## Regole di risoluzione

`IsometricTileResolver` controlla prima il caso forestale quando il bioma e
`infected_plains`.

- Il floor walkable usa grass e varianti deterministiche in base a seed/cella.
- I blocchi `forest` del layout diventano `forest_tall_grass` tramite
  `ObstacleLayoutGenerator`, ma restano `TERRAIN_WALKABLE`.
- Le strade principali (`main_road`) diventano `forest_road`.
- I sentieri (`broken_street`) diventano `forest_path`.
- Il contatto tra strada principale e sentiero diventa `path_to_road`.
- Il contatto con floor non-route produce `grass_to_path` o `grass_to_road`.
- Il contatto tra erba bassa e tall grass produce `grass_to_tall_grass`.
- Il contatto con void/fall zone produce `ground_to_void_cliff`.
- Il contatto con border o wall segment produce `ground_to_mountain_wall`.
- Le celle fall/void del bioma usano `forest_cliff_edge` vicino al terreno e
  `forest_void` come profondita.
- Le celle `fall_zone` sul confine vengono ulteriormente risolte in tile
  neighbor-aware: quattro bordi, quattro angoli interni, quattro angoli esterni
  e due raccordi diagonali condivisi tra i biomi. Il tile layer ne pre-bake-a
  faccia verticale, cresta, fenditure, ombra e foschia.
- Le pareti perimetrali usano `forest_mountain_wall`, mantenendo collisioni e
  varchi fisici esistenti.

`BiomeTileLayer` mantiene il rendering chunked, aggiunge un underlay forestale
pre-baked colorato per tipo tile e disattiva il reticolo sul bioma base. In
questo modo gli spazi tra i rombi calpestabili non mostrano nero: erba/cliff
usano verdi scuri, path/road marroni scuri. Le linee di dettaglio pre-baked
restano sopra erba, tall grass, path, road, transizioni e cliff; il
`forest_void` puro usa solo l'underlay uniforme, senza rombi o reticoli
ripetuti, usando lo stesso colore del `VoidBackdrop` fuori-mappa. I border perimetrali
si fermano sia nei corner fall sia lungo ogni tratto in cui un `full_void`
raggiunge il limite esterno, lasciando solo il fondale void. Non crea nodi per
tile.

## Estendere ad altri biomi

1. Aggiungere i nuovi SVG sotto una cartella dedicata in
   `assets/environment/isometric/tiles/<biome>/` e, se necessario, in
   `edges/`.
2. Registrare ogni ID in `terrain_tiles`, `edge_tiles` o `void_tiles`, con
   `asset_path`, `biome_ids`, `fallback_path`, `source`, `license` e
   `attribution_key`.
3. Inserire gli ID nel relativo `biome_asset_sets`.
4. Aggiungere i draw mode in `IsometricEnvironmentManifest` e i fallback in
   `BiomeTerrainPatch` solo se il tile layer asset-driven viene disattivato.
5. Estendere `IsometricTileResolver` con una funzione specifica del bioma,
   mantenendo priorita a passage tile e connector.
6. Aggiornare o aggiungere uno smoke che verifichi manifest, asset presenti,
   transizioni emesse dal layout generato e nessun asset mancante nel
   `BiomeTileLayer`.
7. Aggiornare `assets/ATTRIBUTION.md` solo se entrano asset esterni; gli SVG
   generati internamente restano sotto la riga "Asset ambiente SVG generati".

## Checklist manuale

- Avviare survival con seed `772031` e confermare che la regione base mostri
  erba forestale, tall grass, sentieri e strada, non floor generico.
- Verificare che `forest_path` e `forest_road` siano leggibili anche quando si
  incrociano o toccano erba.
- Attraversare un varco fisico: il passaggio deve restare aperto, senza portali
  o gate visibili, e le pareti laterali devono leggere come montagna/roccia.
- Camminare vicino a void e fall zone: il bordo deve mostrare cliff/depth e
  non deve sembrare pavimento attraversabile.
- Controllare un bordo per ciascuna direzione e almeno un angolo: nessuna
  giunzione deve mostrare buchi neri, creste interrotte o raccordi ambigui.
- Verificare che tall grass, path, road e grass non cambino collisioni: player,
  zombie, crate e spawn restano sulle stesse classi terrain.
- In high contrast e reduced motion, controllare che player, zombie, pickup,
  wall, cliff e road restino separabili a colpo d'occhio.

## Smoke test

```text
godot --headless --path . --script res://tests/forest_isometric_texture_transition_smoke_test.gd
godot --headless --path . --script res://tests/milestone_10_tile_layer_smoke_test.gd
godot --headless --path . --script res://tools/generate_isometric_environment_assets.gd -- --check
```
