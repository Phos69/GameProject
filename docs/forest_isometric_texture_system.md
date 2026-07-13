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
- `forest_road_border`
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

Le facce di caduta usano inoltre i materiali PNG finali
`cliff_face_texture` e `cliff_lip_texture`. Il resolver continua a scegliere le
14 varianti geometriche per classificazione e fallback, ma nel forestale
`FallZoneBoundaryRuns` rasterizza l'unione dei `fall_zone_rects` e ne estrae
solo i segmenti a contatto con terreno. Due rettangoli adiacenti o sovrapposti
non mantengono quindi un bordo sul lato condiviso. Su questo contorno,
`RectilinearCliffFaceMeshBuilder` sostituisce le facce inclinate per-cell con
pannelli continui orizzontali e verticali. Le UV restano world-space e la
faccia dissolve verso il colore uniforme del void. Queste texture non entrano
nella classificazione terrain.

Il prato base usa il raster seamless finale
`tiles/forest/textures/forest_grass_generated.png`; il lip usa
`edges/cliffs/textures/grass_cliff_edge_generated_v2.png` come raccordo lineare
orizzontale (void verso il basso) e `grass_cliff_edge_vertical_generated.png`
per i lati verticali, campionando solo la fascia rocciosa pura
(`HORIZONTAL_ROCK_UV_START`/`VERTICAL_ROCK_UV_START`) per evitare il seam verde
del muschio di transizione. Il `BiomeTileLayer` tiene il prato solo sulle celle
walkable `ground_to_void_cliff`: le celle `void_*` di transizione restano
fondale void sotto faccia e lip, cosi il terreno non prosegue oltre la cresta;
`IsometricCliffBorderMeshBuilder` segue lo stesso contorno unificato e costruisce
i bordi orizzontali, verticali e i corner dei buchi interni; sui fall perimetrali
disegna solo il lato a contatto con il terreno, evitando una doppia linea verso
il fuori-mappa. Gli angoli non usano una texture sovrapposta: il bordo
orizzontale possiede l'intera giunzione e quello verticale termina esattamente
alla profondita della sua fascia rocciosa. In questo modo non compaiono croci,
blocchi quadrati o doppio campionamento. Entrambi i lati campionano solo la
porzione rocciosa interna al void: il prato esterno resta interamente del ground
mesh e non mostra cap scuri agli estremi.
`RectilinearCliffFaceMeshBuilder` tiene dritte le pareti lontana (nord) e vicina
(sud) ma sghemba quelle laterali (est/ovest) verso l'interno del void
(`LATERAL_VOID_SLOPE`), cosi i lati del fall mostrano il burrone in finta
prospettiva invece di una striscia piatta; la mesh legacy a rombi resta fallback
non forestale. Path, road, wall, void e collisioni restano separati.

Sentiero, strada e bordo strada hanno ancora contratti asset separati
(`forest_dirt_path_generated.png`, `forest_asphalt_generated.png` e
`forest_road_border_defined.png`), ma dal pass `ART-VIS-FIX` del 2026-07-09 le
route visibili della Pianura Infetta usano solo il bordo strada definito. I
tile logici `forest_path`, `forest_road`, `grass_to_path`, `grass_to_road`,
`path_to_road`, `road` e relativi entry/exit restano nel resolver come semantica
di route/passaggio, ma `BiomeTileLayer` usa
`forest_road_border__vertical`/`__horizontal` sui margini e un core strada
derivato dallo stesso PNG negli interni, ruotando il sorgente quando la strada
corre orizzontalmente. Cosi il contatto con il terreno resta un taglio netto con
bordo definito su entrambi gli assi e non si sovrappongono piu texture
terra/asfalto legacy.
Tutti i raster sono seamless, mipmapped e limitati a 512 px in import.

## Regole di risoluzione

`IsometricTileResolver` controlla prima il caso forestale quando il bioma e
`infected_plains`.

- Il floor walkable usa grass e varianti deterministiche in base a seed/cella.
- I blocchi `forest` del layout diventano `forest_tall_grass` tramite
  `ObstacleLayoutGenerator`, ma restano `TERRAIN_WALKABLE`.
- Le strade principali (`main_road`) diventano `forest_road` a livello logico.
- Gli spoke secondari (`broken_street`) diventano `forest_path` a livello
  logico.
- Il contatto tra strada principale e sentiero resta marcato come
  `path_to_road`, ma viene renderizzato con il core strada derivato dal bordo
  definito, non con una patch di bordo verso erba.
- Il contatto con floor non-route produce `grass_to_path` o `grass_to_road`;
  nel rendering diventano varianti orientate di `forest_road_border`.
- I passage `road` e relativi entry/exit mantengono sezione `passage_tiles`,
  ma nel rendering usano le stesse varianti orientate di `forest_road_border`
  sui margini e il core strada derivato all'interno.
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
`forest_void` puro e le celle `void_*` di transizione usano solo fondale void
sotto la geometria cliff, senza rombi o reticoli ripetuti, usando lo stesso
colore del `VoidBackdrop` fuori-mappa. I border perimetrali si fermano sia nei
corner fall sia lungo ogni tratto in cui un `full_void` raggiunge il limite
esterno, lasciando solo il fondale void. Non crea nodi per tile.

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
  erba forestale, tall grass e route con bordo strada definito, non floor
  generico.
- Verificare che solo `forest_road_border__vertical` e
  `forest_road_border__horizontal` piu i core derivati siano renderizzati sulle
  route forestali, senza patch `forest_path`/`forest_road` sovrapposte.
- Attraversare un varco fisico: il passaggio deve restare aperto, senza portali
  o gate visibili, e le pareti laterali devono leggere come montagna/roccia.
- Camminare vicino a void e fall zone: il bordo deve mostrare cliff/depth e
  non deve sembrare pavimento attraversabile.
- Controllare un bordo orizzontale, uno verticale e i quattro angoli: nessuna
  giunzione deve mostrare doppie linee, quadrati, creste interrotte o raccordi
  ambigui.
- Verificare che tall grass, path, road e grass non cambino collisioni: player,
  zombie, crate e spawn restano sulle stesse classi terrain.
- In high contrast e reduced motion, controllare che player, zombie, pickup,
  wall, cliff e road restino separabili a colpo d'occhio.

## Smoke test

```text
godot --headless --path . --script res://tests/forest_isometric_texture_transition_smoke_test.gd
godot --headless --path . --script res://tests/forest_grass_generated_texture_smoke_test.gd
godot --path . --rendering-method gl_compatibility --script res://tests/forest_surface_generated_visual_qa.gd
godot --headless --path . --script res://tests/milestone_10_tile_layer_smoke_test.gd
godot --headless --path . --script res://tools/generate_isometric_environment_assets.gd -- --check
```
