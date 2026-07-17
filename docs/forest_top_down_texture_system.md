# Forest Top-down Texture System

Stato: contratto runtime a maschera attivo per il bioma base
`infected_plains`, usato come foresta di partenza della survival.

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

I contratti semantici vivono in `assets/environment/top_down/manifest.json`.
I raster full-bleed sono in `assets/environment/top_down/tiles/forest/textures/`;
gli asset cardinali restano in `tiles/forest/` e in
`edges/{cliffs,void,walls}/`. Tutte le superfici seguono
`coordinate_system: orthogonal_top_down`; le facciate cliff applicano
`volume_style: controlled_perspective` senza alterare il footprint.

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
`TopDownCliffBorderMeshBuilder` segue lo stesso contorno unificato e costruisce
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
(`LATERAL_VOID_SLOPE`), cosi i lati del fall mostrano il burrone con volume
prospettico controllato invece di una striscia piatta. Ogni fallback usa top
rettangolari e lati N/E/S/W. Path, road, wall, void e collisioni restano
separati.

Il terreno forestale usa tre raster full-bleed:
`forest_grass_generated.png`, `forest_dirt_path_generated.png` e
`forest_asphalt_generated.png`. `TerrainSurfaceClassifier` converte ogni tile
risolto in `grass`, `path`, `asphalt` o `void`; `TerrainBoundaryMaskBuilder`
genera poi una maschera RGBA8 dell'intera regione a 8 pixel per tile. R, G e B
selezionano le tre superfici, RGB nullo lascia il colore uniforme del void e A
contiene il divisore lungo i confini fra classi diverse. Nella Pianura Infetta
il renderer associa quel canale alla stessa istanza runtime normalizzata di
`forest_dirt_path_generated.png` usata dai sentieri, con identico periodo
world-space; lo stesso alias alimenta le mesh dirt di cliff e mesa. Gli altri
biomi continuano a usare `terrain_divider_dirt_generated.png` come materiale
condiviso. `TerrainSurfaceCanvas` campiona il sottorettangolo regionale di ogni
chunk con UV world-space e lo shader compone il divisore sopra le texture.
Non servono piu core, edge, rotazioni o corner raster per unire path, road ed
erba. I tre raster di superficie vengono ripetuti nel loro orientamento
originale, senza atlas, specchi o rotazioni. Prima delle mipmap il runtime
ritaglia 40 px per lato per rimuovere la vignettatura scura incorporata nei PNG
e armonizza gli 8 px esterni dei bordi opposti; i relativi asset storici
restano solo per confronto e QA.

## Regole di risoluzione

`BiomeTileResolver` controlla prima il caso forestale quando il bioma e
`infected_plains`.

- Il floor walkable usa grass e varianti deterministiche in base a seed/cella.
- I blocchi `forest` del layout diventano `forest_tall_grass` tramite
  `ObstacleLayoutGenerator`, ma restano `TERRAIN_WALKABLE`.
- Le strade principali (`main_road`) diventano `forest_road` a livello logico e
  alimentano il canale B/asphalt della maschera.
- Gli spoke secondari (`broken_street`) diventano `forest_path` a livello
  logico e alimentano il canale G/path.
- Il contatto tra strada principale e sentiero resta marcato come
  `path_to_road`; le superfici restano sui rispettivi canali e il confine viene
  coperto dal divisore del canale alpha.
- Il contatto con floor non-route produce `grass_to_path` o `grass_to_road`;
  questi ID restano semantici, mentre il renderer usa R sul lato grass e G/B
  sul lato route senza asset di bordo orientati.
- I passage `road` e relativi entry/exit mantengono sezione `passage_tiles`,
  ma nel rendering alimentano la stessa classe B/asphalt delle strade
  principali.
- Il contatto tra erba bassa e tall grass produce `grass_to_tall_grass`.
- Il contatto con void/fall zone produce `ground_to_void_cliff`.
- Il contatto con border o wall segment produce `ground_to_mountain_wall`.
- Le celle fall/void del bioma usano `forest_cliff_edge` vicino al terreno e
  RGB nullo con colore uniforme come profondita.
- Le celle `fall_zone` sul confine vengono ulteriormente risolte in tile
  neighbor-aware: quattro bordi, quattro angoli interni, quattro angoli esterni
  e raccordi d'angolo cardinali condivisi tra i biomi. Il tile layer ne pre-bake-a
  faccia verticale, cresta, fenditure, ombra e foschia.
- Le pareti perimetrali usano `forest_mountain_wall`, mantenendo collisioni e
  varchi fisici esistenti.

`BiomeTileLayer` mantiene il rendering chunked ma genera una sola maschera per
la regione `75x75`. Ogni `BiomeTileChunk` crea un `TerrainSurfaceCanvas` e
campiona solo il proprio UV rect della maschera; le tre texture restano
full-bleed e ripetibili in coordinate world-space. Il `forest_void` puro e le
celle `void_*` di transizione hanno RGB nullo e usano lo stesso colore uniforme
del `VoidBackdrop`, senza reticoli. Facce cliff e lip vengono disegnati in pass
separati sopra il canvas superficie: il divisore di terra non sostituisce il
bordo di caduta. Il sistema non crea nodi per tile.

## Estendere ad altri biomi

1. Registrare tre raster full-bleed ripetibili per i ruoli `ground`, `path` e
   `road`; riusare `terrain_divider_dirt` salvo un override artistico esplicito.
2. Inserire asset, metadati e ruoli nel manifest o nel
   `BiomeGeneratedArtCatalog`, mantenendo transition e detail fuori dal set
   runtime della superficie.
3. Mappare i tile semantici sulle quattro classi condivise del
   `TerrainSurfaceClassifier`, evitando branch per-bioma quando la semantica e
   gia esprimibile come grass, path, asphalt o void.
4. Conservare cliff, lip, wall e collisioni nei sistemi dedicati sopra il
   `TerrainSurfaceCanvas`.
5. Aggiungere uno smoke che verifichi classificazione, canali RGBA, dimensione
   della maschera, determinismo del seed e assenza di asset runtime mancanti.
6. Aggiornare `assets/ATTRIBUTION.md` solo se entrano asset esterni.

## Checklist manuale

- Avviare survival con seed `772031` e confermare che la regione base mostri
  erba, sentieri e asfalto forestali full-bleed, non floor generico.
- Verificare che il divisore di terra sia continuo sui contatti grass/path,
  grass/asphalt e path/asphalt, inclusi curve, incroci e confini di chunk.
- Controllare tre repeat verticali consecutivi di erba e sentiero: il contatto
  fra bordo inferiore e superiore non deve mostrare una fascia d'ombra.
- Confrontare sentiero e divisore della Pianura Infetta: terra, pietre, scala e
  densita dei dettagli devono coincidere anche attorno a cliff e mesa.
- Verificare che core, edge e corner del vecchio bordo strada non compaiano e
  che ai lati del divisore non ci siano buchi o texture sovrapposte.
- Attraversare un varco fisico: il passaggio deve restare aperto, senza portali
  o gate visibili, e le pareti laterali devono leggere come montagna/roccia.
- Camminare vicino a void e fall zone: il bordo deve mostrare cliff/depth e
  non deve sembrare pavimento attraversabile; sotto cliff e lip il void deve
  restare un colore uniforme.
- Controllare un bordo orizzontale, uno verticale e i quattro angoli: nessuna
  giunzione deve mostrare doppie linee, quadrati, creste interrotte o raccordi
  ambigui.
- Verificare che tall grass, path, road e grass non cambino collisioni: player,
  zombie, crate e spawn restano sulle stesse classi terrain.
- In high contrast e reduced motion, controllare che player, zombie, pickup,
  wall, cliff e road restino separabili a colpo d'occhio.

## Smoke test

```text
./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/assets
./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/environment
./tools/run_visual_qa.ps1 -SkipImport -Filter forest_surface_generated
godot --headless --path . --script res://tools/generate_top_down_environment_assets.gd -- --check
```
