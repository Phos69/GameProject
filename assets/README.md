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

I cliff void usano raster finali in `edges/cliffs/textures/`:
`cliff_face_generated_v2.png`, `grass_cliff_edge_generated_v2.png` per il
raccordo orizzontale (void verso il basso) e
`grass_cliff_edge_vertical_generated.png` per i lati verticali. I bordi
campionano solo la fascia rocciosa pura di questi raster
(`HORIZONTAL_ROCK_UV_START`/`VERTICAL_ROCK_UV_START` in
`IsometricCliffBorderMeshBuilder`), saltando il muschio verde della transizione
erba-roccia per non lasciare un seam verde sul perimetro. Le iterazioni
`cliff_face_generated.png`, `cliff_lip_generated.png` e
`grass_cliff_edge_generated.png` restano conservate come sorgenti di confronto. `RectilinearCliffFaceMeshBuilder` applica il materiale
roccioso a pannelli continui orizzontali e verticali nel forestale; le 14
geometrie di `IsometricCliffMeshBuilder` restano fallback non forestale. Il
raccordo della cresta usa mesh e raster dedicati costruiti da
`IsometricCliffBorderMeshBuilder`; gli angoli hanno ownership orizzontale e non
usano un tile sovrapposto. L'import limita il runtime a 512 px e genera
mipmap; i sorgenti restano conservati per iterazioni.

Infinite Arena riusa inoltre i raster gia finali
`rock_cliff_face_upward_generated.png` e
`rock_plateau_top_generated.png` per il proprio perimetro `raised_cliff`.
`BiomeObstaclePainter` li applica ai segmenti solidi con UV world-space
continui e geometria distinta per lati orizzontali/verticali; non sono
`fall_zone` e non modificano collisioni o danno. Se uno dei due raster non e
disponibile, il runtime conserva il precedente muro isometrico procedurale.

Il prato forestale finale usa
`tiles/forest/textures/forest_grass_generated.png`. `BiomeTileLayer` lo stende
su run continue con UV world-space. La stessa cartella contiene
`forest_dirt_path_generated.png`, `forest_asphalt_generated.png`,
`forest_road_border_defined.png`, `grass_to_path_generated.png`,
`grass_to_road_generated.png` e `path_to_road_generated_v2.png`: i tre asset di
transizione storici restano contratti e materiale di confronto QA, ma il
runtime della Pianura Infetta non li usa piu come texture intermedia.
Le route forestali visibili (`forest_path`, `forest_road`, `grass_to_path`,
`grass_to_road`, `path_to_road`, `road` e relativi entry/exit) vengono
renderizzate con `forest_road_border__vertical` oppure
`forest_road_border__horizontal` sui margini e con un core strada derivato dallo
stesso PNG negli interni, ottenendo un taglio netto con bordo strada definito su
strade verticali e orizzontali senza sovrapporre il vecchio
`forest_dirt_path_generated.png` o `forest_asphalt_generated.png`.
`forest_road_border` resta il sorgente caricato, ma non viene piu usato come
materiale unico non orientato.
Wall e void mantengono i rispettivi materiali e colori.

### Set generati per bioma

I 195 sorgenti raster in `environment/isometric/generated_images/` sono
organizzati per tema e ruolo. Il mapping runtime e:
`toxic_wastes -> urban_ruins`, `burning_fields -> volcanic`,
`frozen_outskirts -> frozen_tundra`, `drowned_marsh -> swamp`.
`desert` e il nuovo `forest` sono puliti e catalogati ma non assegnati.

`BiomeGeneratedArtCatalog` espone pool tipizzati per ground, path, road,
transizioni, detail e cliff. Nei quattro temi attivi il ruolo `road` e il ruolo
`ground_to_road` selezionano i nuovi PNG `road_border_defined`; i vecchi
`road_variation` e `transition_ground_to_road` restano catalogati come
dettaglio/storico e non sono piu superfici runtime strada. Il manifest registra per ogni set attivo
stato `final`, provenienza `openai_image_generation`, licenza
`Project original` e le liste di ruoli.
Ogni `road_border_defined` resta un solo sorgente PNG, ma il runtime lo espone
come quattro materiali: bordo `__vertical`/`__horizontal` e core interno
`__core_vertical`/`__core_horizontal` (banda centrale ritagliata, senza le
strisce di bordo). Dal pass di unificazione strade tutti i sorgenti sono
nativi verticali (`urban_ruins` e stato ruotato una tantum su disco); la
source orientation resta un campo del contratto tema
(`THEME_CONTRACTS.native_border_orientation`). Le celle route mantengono i
propri tile semantici; cambia solo il materiale di superficie scelto dal
resolver.
La board `generated_biome_art_visual_qa.gd` mostra entrambe le varianti runtime
per `urban_ruins`, `volcanic`, `frozen_tundra` e `swamp`.

I set generati sono materiali di superficie per ground, route e cliff. Nei
quattro biomi con `generated_theme_id`, le celle interne `main_road`/`road`
usano il core `road_border_defined__core_vertical`/`__core_horizontal`,
mentre `road_edge`, `road_curve_*` e `road_intersection` usano il bordo
orientato `__vertical`/`__horizontal`; `service_lane`, `ash_lane`,
`packed_snow_path` e `wooden_walkway` usano `path_variation`, anche sui
propri bordi e incroci quando nessuna strada principale attraversa la cella.
`tile_id` e sezione restano quelli del manifest per semantica, collisioni e
debug, ma `material_asset_id`/`material_asset_path` puntano ai raster generated.
Anche i passage road-like tra biomi (`bridge`, `snow_pass`, `broken_gate`,
`burned_road` e relative entry/exit) conservano sezione `passage_tiles`, ma
renderizzano la strada con `road_border_defined__vertical`/`__horizontal` generated
del bioma invece delle texture manifest.

Nel runtime `frozen_tundra` sceglie un solo materiale per ruolo e regione. Il
ground viene tagliato e composto in una quilt `2x2` da quattro offset periodici
dello stesso raster neve, con raccordo interno/esterno e repeat world-space
`1024`; non usa mirror né varianti tonali diverse. Path e road restano a `512`
e vengono ammorbiditi verso la palette neve. I contatti terrain/path usano path
diretto, mentre i bordi strada usano le varianti orientate di
`road_border_defined`. Gli asset
`transition_ground_*` restano nel catalogo come sorgenti, ma non sono superfici
runtime di `frozen_outskirts`.

`swamp` applica lo stesso contratto regionale senza correzione cromatica. Il
ground compone una quilt `2x2` da quattro offset periodici dello stesso raster,
con raccordo interno/esterno e repeat world-space `1024`; non usa mirror ne
varianti tonali diverse. Path e road mantengono palette, densita e periodo
`512`. I contatti terrain/path usano path diretto, mentre i bordi strada usano
le varianti orientate di `road_border_defined`; gli asset `transition_ground_*`
restano catalogati ma non sono superfici runtime di `drowned_marsh`.

`volcanic` applica selezione regionale, bordi opposti armonizzati e repeat
world-space `512`. Il ground pieno usa solo la base variation 02 piu quieta;
le variation 01, 03 e 04 restano catalogate come detail. I contatti
terrain/path usano path diretto, mentre i bordi strada usano
le varianti orientate di `road_border_defined`; gli asset
`transition_ground_*` non sono superfici runtime di `burning_fields`.

Prima di importare o committare modifiche ai sorgenti:

```text
godot --headless --path . --script res://tools/prepare_generated_biome_assets.gd -- --write
godot --headless --path . --import
godot --headless --path . --script res://tools/prepare_generated_biome_assets.gd -- --check
```

Il tool rimuove le cornici bianche, compatta gutter interni e converte in alpha
solo il matte esterno dei cutout cliff; neve e ghiaccio interni restano opachi.

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
e crate. `lab_block` e `lab_ruin` hanno profili industriali dedicati con
volumi verticali e dettagli tecnici, così non vengono confusi con la
`supply_crate` compatta. `reed_wall` disattiva il letterboxing del viewBox e
usa tutta la canvas nativa `56x136`, coerente con il footprint stretto `1x3`.
Possono essere sostituiti gradualmente con arte
`needs_polish`/`final` senza cambiare il contratto runtime.

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
`forest_road`, `forest_road_border`, `forest_void`, `forest_cliff_edge`,
`forest_mountain_wall` e le transizioni `grass_to_path`, `grass_to_road`,
`grass_to_tall_grass`,
`path_to_road`, `ground_to_void_cliff` e `ground_to_mountain_wall`. Gli asset
vivono in `environment/isometric/tiles/forest/` e nelle cartelle `edges/`.
Per il rendering, i tile di route forestali e i passage `road` mantengono i
propri ID/section per debug, ma selezionano solo il materiale
`forest_road_border_defined` orientato o il suo core strada derivato.

`game/modes/zombie/biome_tile_layer.gd` e il ground primario asset-driven per
`TerrainGenerator`: cache-a tutte le 250.000 celle della regione `500x500`, le
divide in chunk e usa il manifest v9 come contratto per gli asset. I vecchi
`BiomeRegionGround` e `BiomeTerrainPatch` restano fallback tecnici solo quando
la modalita asset viene disattivata.

Nei biomi con `generated_theme_id`, `BiomeTileLayer` usa i PNG generated per le
superfici ampie e per le route principali: `main_road`/`road`/incroci pescano
dal ruolo `road`, che nei temi attivi seleziona `road_border_defined`, e vengono registrati anche come variante ruotata
`__horizontal`, mentre le lane tematiche pescano dal ruolo `path`. I
`passage_tiles` road-like e i relativi entry/exit restano identificati come
sezione/tile (`passage_tiles/bridge_entry`) per preservare semantica e debug,
ma il renderer usa il materiale generated `road_border_defined` orientato per evitare
connettori manifest fuori scala ai bordi regione.

Il generator asset controlla 108 SVG ambiente isometrico dopo il pass texture
forestali, inclusi road connector, entry/exit dei passaggi, object scene per
ostacoli/crate e tile forestali con transizioni.

## Ambiente isometrico (oggetti runtime)

Gli ostacoli generati dal layout usano `IsometricEnvironmentObject` come scena
base slot-based: uno `StaticBody2D` con collisione dal manifest, `Sprite2D`,
ombra a terra, anchor al pavimento, `sort_offset` e footprint debug opzionale.
`BiomeObstacle` resta il fallback tecnico quando il manifest dichiara un
fallback procedurale esplicito.

Le `large_rock` scalabili usano il render mode `tile_layer_rock_area`: il nodo
oggetto conserva collisione e overlay `F9`, mentre `BiomeTileLayer` sostituisce
lo sprite stirato con un plateau rialzato sull'intero `rock_rect` (il void cliff
specchiato verso l'alto). La corona cobble e sollevata e rientra in un mesa, con
tre pareti continue a colonne (fronte sud + due fianchi obliqui) che salgono dal
prato fino al bordo. Visual e collisione derivano dallo stesso rettangolo; il top
e disegnato una sola volta dal tile layer per evitare lastre duplicate o shiftate.
Il top usa
`edges/cliffs/textures/rock_plateau_top_generated.png`; le pareti usano
`rock_cliff_face_upward_generated.png` con shading per lato. Non e una fascia
piatta e non porta linee disegnate: il dettaglio arriva solo dalle texture.

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
La supply crate usa lo stesso percorso tramite `object_scenes/supply_crate`;
`reed_wall` richiede la propria dimensione nativa al loader per conservare
l'altezza visuale prevista dal manifest.

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
