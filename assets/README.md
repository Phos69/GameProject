# Asset Pipeline

Questa cartella contiene solo asset distribuibili con origine e licenza
documentate in `ATTRIBUTION.md`. Il prototipo deve continuare a funzionare
quando una risorsa esterna manca: visual, audio e font mantengono sempre un
fallback procedurale o di engine.

## Struttura

```text
assets/
  audio/       musica e SFX
  fonts/       font runtime
  sprites/     attori, armi, props ed effetti
  tilesets/    tile, atlas e materiali ambiente
  ui/          pannelli, icone e cursori
```

## Naming

- file e cartelle in `snake_case`;
- suffissi consigliati: `_diffuse`, `_normal`, `_emission`, `_icon`;
- atlas: `{sistema}_{variante}_atlas.png`;
- animazioni: `{attore}_{stato}_{direzione}_{frame}.png`;
- nessuno spazio, versione o nome autore nel filename;
- la provenienza vive in `ATTRIBUTION.md`, non nel nome.

## Sprite e Atlas

- mantenere il pivot logico coerente tra frame;
- usare dimensioni potenza di due per atlas quando non aumenta lo spreco;
- evitare padding trasparente non necessario;
- lasciare almeno 2 pixel di separazione tra regioni interpolate;
- importare pixel art senza filtro e senza mipmap;
- per artwork scalabile non pixel-art, documentare l'eccezione nel `.import`
  e verificare il risultato a 1280x720.

## Compressione

- sprite e UI: lossless;
- normal map: tipo Normal Map;
- audio breve: WAV o OGG senza normalizzazione automatica distruttiva;
- musica lunga: OGG in streaming;
- evitare compressione lossy su icone, testo rasterizzato e pixel art.

## Ambiente isometrico (manifest)

`environment/isometric/manifest.json` e la fonte di verita per gli oggetti
ambientali del bioma (ostacoli, bordi, casse, cliff, passaggi). Dal manifest v9
contiene anche il contratto asset-driven per `tile_sets`, `tile_variants`,
`terrain_tiles`, `edge_tiles`, `void_tiles`, `object_scenes`, `passage_tiles`,
`biome_asset_sets` e `fallback_policy`.

Per ogni contratto il loader normalizza `asset_path`, `status`, `biome_ids`,
`footprint_tiles`, `anchor`, `sort_offset`, `collision_shape`, flag
`blocks_*`, `source`, `license`, `attribution_key` e `fallback_path`.
Gli status ammessi sono `final`, `base_complete`, `needs_polish`,
`procedural_fallback`, `needs_asset` e `deprecated`.

Gli `object_scenes` possono usare SVG generati oppure PNG/WebP finali. Il tool
SVG non riscrive i raster autorati: in `--check` ne verifica comunque la
presenza, mentre trasparenza e copertura sono validate da
`tests/obstacle_asset_visual_qa.gd`.

I cliff void usano due raster finali in `edges/cliffs/textures/`:
`cliff_face_generated_v2.png` e `grass_cliff_edge_generated.png`. Le iterazioni
`cliff_face_generated.png` e `cliff_lip_generated.png` restano conservate come
sorgenti di confronto. Non rappresentano
orientamenti separati: `IsometricCliffMeshBuilder` applica i materiali seamless
con UV world-space alle 14 geometrie risolte dal tile layer. L'import limita il
runtime a 512 px e genera mipmap; i sorgenti restano conservati per iterazioni.

Il prato forestale finale usa
`tiles/forest/textures/forest_grass_generated.png`. `BiomeTileLayer` lo stende
su run continue con UV world-space. La stessa cartella contiene
`forest_dirt_path_generated.png`, `forest_asphalt_generated.png`,
`grass_to_path_generated.png`, `grass_to_road_generated.png` e
`path_to_road_generated_v2.png`: il tile layer assegna una mesh distinta a ogni
classe e usa un periodo UV piu corto per le fasce di transizione. Wall e void
mantengono i rispettivi materiali e colori.

- Il loader `game/modes/zombie/isometric_environment_manifest.gd` legge e valida
  il manifest; `ObstacleSystem` lo usa per `sort_offset` e flag di blocco e,
  dalla Milestone 10.5, passa gli `object_scenes` a
  `IsometricEnvironmentObjectFactory`.
- `visual_scene` che punta a uno script `.gd` resta il fallback tecnico legacy.
  Nel contratto v9 il fallback normale e dichiarato da `fallback_path` e
  `fallback_policy`; nessun file esterno e obbligatorio per il bootstrap.
- Lo smoke `tests/isometric_environment_manifest_smoke_test.gd` verifica che ogni
  `obstacle_id` dei biomi sia descritto, che nessun oggetto richieda asset
  esterni e che collisione/footprint/Y-sort restino coerenti.
- Lo smoke `tests/milestone_10_asset_manifest_v7_smoke_test.gd` verifica che gli
  ID generati da ostacoli, terrain, passaggi e fall zone abbiano un contratto v7
  esplicito e che un asset pianificato ma assente resti sicuro tramite
  `needs_asset` + `fallback_path`.
- Per convertire un oggetto in arte esterna: aggiungere la risorsa al nodo
  presentazionale mantenendo il fallback dichiarato, aggiornare `asset_path` e
  `status` nel manifest e registrare la licenza in `ATTRIBUTION.md`.

## Ambiente isometrico (asset generati)

`tools/generate_isometric_environment_assets.gd` genera SVG testuali interni
dai contratti v9. Il tool lavora in modo conservativo:

```text
godot --headless --path . --script res://tools/generate_isometric_environment_assets.gd -- --dry-run
godot --headless --path . --script res://tools/generate_isometric_environment_assets.gd -- --write
godot --headless --path . --script res://tools/generate_isometric_environment_assets.gd -- --check
```

- default: dry-run, nessuna scrittura;
- `--write`: crea solo asset mancanti;
- `--check`: fallisce se un `asset_path` SVG del manifest non esiste;
- `--overwrite-generated`: rigenera asset esistenti non marcati `final`;
- gli asset con `status: final` non vengono mai sovrascritti dal tool.

Gli SVG generati includono metadata `data-generated-by`, `data-section`,
`data-id` e `data-footprint-slots` per rendere il controllo manifest/file system
ripetibile. Gli asset base sono originali del progetto: i terrain/passaggi
espongono silhouette isometriche di route, mentre gli `object_scenes` usano
sprite trasparenti distinti per case, barriere, barili, relitti, tronchi, ponti
e crate. Possono essere sostituiti gradualmente con arte `needs_polish`/`final`
senza cambiare il contratto runtime.

## Ambiente isometrico (tile layer runtime)

`game/modes/zombie/isometric_tile_resolver.gd` mappa ogni cella logica del
`BiomeEnvironmentLayout` in un tile asset-backed deterministico: `floor_base`,
varianti floor, route tile (`main_road`, road tematiche, curve, edge e
intersezioni), passage tile (`road`, `bridge`, `snow_pass`, `broken_gate`,
`burned_road`, entry/exit), `hazard_floor`, `border_floor`, `void_edge_near` o
`void_depth`. Le route generate usano `road_cell_tags` diagonali per seguire gli
assi isometrici; i rettangoli restano per aperture e compatibilita. La variante
floor deriva da seed, cella e bioma.

Per `infected_plains`, il resolver usa il set forestale dedicato:
`forest_grass`, varianti grass, `forest_tall_grass`, `forest_path`,
`forest_road`, `forest_void`, `forest_cliff_edge`, `forest_mountain_wall` e le
transizioni `grass_to_path`, `grass_to_road`, `grass_to_tall_grass`,
`path_to_road`, `ground_to_void_cliff` e `ground_to_mountain_wall`. Gli asset
vivono in `environment/isometric/tiles/forest/` e nelle cartelle `edges/`.

`game/modes/zombie/biome_tile_layer.gd` e il ground primario asset-driven per
`TerrainGenerator`: cache-a tutte le 250.000 celle della regione `500x500`, le
divide in chunk e usa il manifest v9 come contratto per gli asset. I vecchi
`BiomeRegionGround` e `BiomeTerrainPatch` restano fallback tecnici solo quando
la modalita asset viene disattivata.

Il generator asset controlla 108 SVG ambiente isometrico dopo il pass texture
forestali, inclusi road connector, entry/exit dei passaggi, object scene per
ostacoli/crate e tile forestali con transizioni.

## Ambiente isometrico (oggetti runtime)

Gli ostacoli generati dal layout usano `IsometricEnvironmentObject` come scena
base slot-based: uno `StaticBody2D` con collisione dal manifest, `Sprite2D`,
ombra a terra, anchor al pavimento, `sort_offset` e footprint debug opzionale.
`BiomeObstacle` resta il fallback tecnico quando il manifest dichiara un
fallback procedurale esplicito.

Gli slot ostacolo misurano `4x4` celle logiche. I formati piccoli vivono in
cartelle per categoria (`rocks/`, `fences/`, `debris/`, `trees/`, `wrecks/`) e
riportano la dimensione nel filename; le case vivono in `objects/houses/`.
`visual_height_tiles` aggiunge altezza solo sopra la base. La procedura completa
e la checklist sono in `docs/obstacle_rendering.md`.

Gli asset correnti sono SVG generati in-repo. In runtime headless Godot puo non
avere la cache import editor per caricarli direttamente come `Texture2D`; per
questo `IsometricSvgTextureLoader` rasterizza il contenuto SVG trasparente
quando possibile, scarta gli import con canvas opaco e produce una
`ImageTexture` fallback per categoria oggetto usando `data-section`/`data-id`.
La supply crate usa lo stesso percorso tramite `object_scenes/supply_crate`.

## Sostituzione Placeholder

1. Conservare controller, collisioni e timing esistenti.
2. Aggiungere la risorsa visuale opzionale al nodo presentazionale.
3. Mantenere il draw procedurale come fallback.
4. Verificare silhouette, telegraph e contrasto con tutti i profili M21.
5. Registrare autore, URL, licenza e modifiche in `ATTRIBUTION.md`.

## Checklist Import

- filtering coerente con il tipo di asset;
- mipmap disattivate per pixel art e UI;
- compressione lossless per sprite gameplay;
- dimensioni e pivot verificati;
- nessun asset esterno obbligatorio per il bootstrap;
- licenza compatibile con distribuzione e modifica;
- QA default, reduced motion e high contrast completata.
