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

### Boss zombie

I cutout originali dei cinque boss zombie sono in
`sprites/bosses/zombie/`. Sono raster non pixel-art generati internamente su
chroma key, convertiti in RGBA con bordo morbido e importati con filtro
lineare e size limit a 512 px; prompt, palette e processing sono registrati in
`sprites/bosses/zombie/manifest.json`. Le scene usano il path canonico ma
`ZombieBossVisual` mantiene un fallback procedurale per non rendere l'asset
obbligatorio al bootstrap.

### Personaggi e zombie regolari

I sette pittogrammi gameplay dei personaggi sono PNG RGBA `512x512` sotto
`characters/*/sprites/*_gameplay_pictogram.png`; provenienza, prompt sintetico
e processing sono in `characters/pictogram_manifest.json`. I quattro archetipi
zombie base e le quattro elite usano lo stesso contratto sotto
`sprites/enemies/zombie/`, documentato dal relativo `manifest.json`.
`PlayerVisual` e `ZombieVisual` mantengono fallback procedurali, quindi i raster
non diventano requisiti di bootstrap.

## Compressione

- sprite e UI: lossless;
- normal map: tipo Normal Map;
- audio breve: WAV o OGG senza normalizzazione automatica distruttiva;
- musica lunga: OGG in streaming;
- evitare compressione lossy su icone, testo rasterizzato e pixel art.

## Ambiente top-down cardinale (manifest)

`environment/top_down/manifest.json` e la fonte di verita per gli oggetti
ambientali del bioma (ostacoli, bordi, casse, cliff, passaggi). Il manifest v17
contiene anche il contratto asset-driven per `tile_sets`, `tile_variants`,
`terrain_tiles`, `edge_tiles`, `void_tiles`, `object_scenes`, `passage_tiles`,
`biome_asset_sets` e `fallback_policy`.

Il manifest dichiara `coordinate_system: orthogonal_top_down` e
`volume_style: controlled_perspective`. Ground e route restano allineati agli
assi; cliff, edifici e prop possono mostrare una facciata sud o sottili facce
laterali. Il footprint di placement resta logico, mentre collider e sort anchor
possono avere size/offset espliciti per aderire al contatto a terra. Il contratto completo vive in
`docs/top_down_cardinal_contract.md`.

Per ogni contratto il loader normalizza `asset_path`, `variant_asset_paths`,
`variant_visual_scales`, `variant_collision_size_ratios`,
`variant_collision_offset_ratios`, `status`, `biome_ids`,
`footprint_tiles`, `anchor`, `sort_offset`, `collision_shape`,
`collision_size_ratio`, `collision_offset_ratio`, flag
`blocks_*`, `source`, `license`, `attribution_key` e `fallback_path`.
Gli status ammessi sono `final`, `base_complete`, `needs_polish`,
`procedural_fallback`, `needs_asset` e `deprecated`.

Gli `object_scenes` possono usare SVG generati, PNG/WebP finali oppure risorse
Godot `Texture2D` `.tres` (per esempio `AtlasTexture`) come estensione del
loader. Nessun prop attivo usa attualmente `.tres`: il tool SVG non riscrive
eventuali texture autorate e in `--check` ne verifica comunque la presenza,
mentre trasparenza e copertura sono validate da
`tests/visual_qa/obstacle_asset_visual_qa.gd`.

`forest_tree` usa pool `random_variant_ids_by_context` distinti per `plains`,
`burning_plains` e `frozen_tundra`, ciascuno formato da quattro coppie
adulto/giovane RGBA `444x444`. I fogli RGB `4x2` originali restano sotto
`environment/top_down/source_sheets/`; i crop runtime sono decontaminati dal
checkerboard e mantengono collider circolari separati dalla chioma. Pianura
contiene una sola silhouette alpha connessa sia a `444 px` sia nel campione
nearest-neighbor runtime a circa `298 px`. Burning viene reestratto dal foglio
con matte morbido, edge contraction di `1 px` e despill; la luminosita neutra
premoltiplicata per alpha non puo superare `0,30`. Frozen rende
trasparenti anche i vuoti bianco-neutri tra i rami: parti innevate separate sono
ammesse. Burning e Frozen non ammettono componenti sotto `12 px` nel sorgente o `4 px` a runtime. Dopo aver rigenerato i crop eseguire
`godot --headless --path . --script res://tools/sanitize_tree_assets.gd -- --write`;
senza `--write` lo stesso comando e un check non distruttivo.

I cliff void usano raster finali in `edges/cliffs/textures/`:
`cliff_face_generated_v2.png`, `grass_cliff_edge_generated_v2.png` per il
raccordo orizzontale (void verso il basso) e
`grass_cliff_edge_vertical_generated.png` per i lati verticali. I bordi
campionano solo la fascia rocciosa pura di questi raster
(`HORIZONTAL_ROCK_UV_START`/`VERTICAL_ROCK_UV_START` in
`TopDownCliffBorderMeshBuilder`), saltando il muschio verde della transizione
erba-roccia per non lasciare un seam verde sul perimetro. Le iterazioni
`cliff_face_generated.png`, `cliff_lip_generated.png` e
`grass_cliff_edge_generated.png` restano conservate come sorgenti di confronto. `RectilinearCliffFaceMeshBuilder` applica il materiale
roccioso a pannelli continui orizzontali e verticali nel forestale; le 14
geometrie di `TopDownCliffMeshBuilder` restano fallback non forestale. Il
raccordo della cresta usa mesh e raster dedicati costruiti da
`TopDownCliffBorderMeshBuilder`; gli angoli hanno ownership orizzontale e non
usano un tile sovrapposto. L'import limita il runtime a 512 px e genera
mipmap; i sorgenti restano conservati per iterazioni.

Infinite Arena riusa inoltre i raster gia finali
`rock_cliff_face_upward_generated.png` e
`rock_plateau_top_generated.png` per il proprio perimetro `raised_cliff`.
`BiomeObstaclePainter` li applica ai segmenti solidi con UV world-space
continui e geometria distinta per lati orizzontali/verticali; non sono
`fall_zone` e non modificano collisioni o danno. Se uno dei due raster non e
disponibile, il runtime conserva il muro top-down procedurale con volume
controllato.

Le superfici forestali runtime sono raster full-bleed:
`tiles/forest/textures/forest_grass_generated.png` per il canale R della
maschera, `forest_dirt_path_generated.png` per G e
`forest_asphalt_generated.png` per B. `BiomeTileLayer` le campiona in
coordinate world-space tramite `TerrainSurfaceCanvas`, senza ritagli core o
overlay orientati. `terrain_divider_dirt_generated.png` e il raster comune
campionato dal canale alpha e copre il confine tra classi di superficie.
`forest_road_border_defined.png`, i raster di transition e gli eventuali corner
restano materiale storico o di confronto QA, ma non sono richiesti dal
renderer a maschera. Il void usa un colore uniforme quando RGB e nullo; wall,
cliff e lip restano pass separati sopra il canvas terreno.

### Set generati per bioma

I sorgenti raster in `environment/top_down/generated_images/` sono organizzati
per tema e ruolo. Il mapping runtime e:
`toxic_wastes -> urban_ruins`, `burning_plains -> volcanic`,
`frozen_tundra -> frozen_tundra`, `swamp -> swamp`.
`desert` e il nuovo `forest` sono puliti e catalogati ma non assegnati.

`BiomeGeneratedArtCatalog` continua a catalogare pool tipizzati per ground,
path, road, transition, detail e cliff, ma il renderer a maschera richiede al
runtime soltanto i ruoli `ground`, `path` e `road`. I quattro temi attivi usano
`ROAD_STYLE_SURFACE`: `base_ground_variation`, `path_variation` e
`road_variation` vengono trattati come texture full-bleed dei canali R, G e B.
Gli asset `road_border_defined`, `transition_ground_*` e i detail restano nel
catalogo per compatibilita, tooling e QA, senza occupare sampler o VRAM del
terreno runtime. Il manifest conserva stato `final`, provenienza
`openai_image_generation`, licenza `Project original` e liste di ruoli.

Le celle route mantengono tile ID, section e ruolo semantico. Il classifier
assegna `service_lane`, `ash_lane`, `packed_snow_path` e `wooden_walkway` a
`path`; `main_road`, `road`, incroci, curve e passage road-like tra biomi a
`asphalt`. La maschera regionale seleziona il raster sui due lati e il canale
alpha applica il divisore di terra comune, quindi non servono orientamento,
core, edge o corner specifici del tema.

Nel runtime `frozen_tundra` sceglie un solo materiale per ruolo e regione. Il
ground viene composto in una quilt `2x2` da offset periodici dello stesso
raster neve, con repeat world-space `1024`; path e road restano a `512`.
`swamp` usa lo stesso periodo `1024` per il ground e `512` per path/road.
`volcanic` usa repeat world-space `512`; il ground pieno usa la base variation
02 e mantiene le variation 01, 03 e 04 come detail catalogati. In tutti i casi
i contatti fra superfici sono responsabilita della maschera e del divisore,
non dei raster di transition.

Prima di importare o committare modifiche ai sorgenti:

```text
godot --headless --path . --script res://tools/prepare_top_down_biome_assets.gd -- --write
godot --headless --path . --import
godot --headless --path . --script res://tools/prepare_top_down_biome_assets.gd -- --check
```

Il tool rimuove le cornici bianche, compatta gutter interni e converte in alpha
solo il matte esterno dei cutout cliff; neve e ghiaccio interni restano opachi.

- Il loader `game/modes/zombie/environment_asset_manifest.gd` legge e valida
  il manifest; `ObstacleSystem` lo usa per `sort_offset` e flag di blocco e,
  dalla Milestone 10.5, passa gli `object_scenes` a
  `EnvironmentObjectFactory`.
- `visual_scene` che punta a uno script `.gd` resta il fallback tecnico legacy.
  Nel contratto v14 il fallback normale e dichiarato da `fallback_path` e
  `fallback_policy`; nessun file esterno e obbligatorio per il bootstrap.
- La suite asset verifica che ogni
  `obstacle_id` dei biomi sia descritto, che nessun oggetto richieda asset
  esterni e che collisione/footprint/Y-sort restino coerenti.
- `tests/suites/assets/asset_fallback_test.gd` e
  `manifest_contract_test.gd` verificano che gli ID generati da ostacoli,
  terrain, passaggi e fall zone abbiano un contratto v14 esplicito e che un
  asset pianificato ma assente resti sicuro tramite `needs_asset` e
  `fallback_path`.
- Per convertire un oggetto in arte esterna: aggiungere la risorsa al nodo
  presentazionale mantenendo il fallback dichiarato, aggiornare `asset_path` e
  `status` nel manifest e registrare la licenza in `ATTRIBUTION.md`.

## Ambiente top-down cardinale (asset generati)

`tools/generate_top_down_environment_assets.gd` genera SVG testuali interni
dai contratti v14. Il tool lavora in modo conservativo:

```text
godot --headless --path . --script res://tools/generate_top_down_environment_assets.gd -- --dry-run
godot --headless --path . --script res://tools/generate_top_down_environment_assets.gd -- --write
godot --headless --path . --script res://tools/generate_top_down_environment_assets.gd -- --check
godot --headless --path . --script res://tools/generate_top_down_environment_assets.gd -- --write --overwrite-generated --migrate-projection
```

- default: dry-run, nessuna scrittura;
- `--write`: crea solo asset mancanti;
- `--check`: fallisce se un `asset_path` SVG/raster/Texture2D del manifest non esiste;
- `--overwrite-generated`: rigenera asset esistenti non marcati `final`;
- `--overwrite-generated --migrate-projection`: unico percorso autorizzato per
  riscrivere anche asset `final` durante un cutover esplicito della proiezione.

Gli SVG generati includono metadata `data-generated-by`, `data-section`,
`data-id` e `data-footprint-slots` per rendere il controllo manifest/file system
ripetibile. Gli asset base sono originali del progetto: i terrain/passaggi
espongono superfici rettangolari e route H/V, mentre gli `object_scenes` usano
sprite trasparenti distinti per case, barriere, barili, relitti, tronchi, ponti
e crate. I profili SVG residui restano fallback sostituibili; `lab_block` e
`lab_ruin` usano due SVG individuali distinti, entrambi separati dalla
`supply_crate` compatta. `reed_wall` disattiva il letterboxing del viewBox e
usa tutta la canvas nativa `56x136`, coerente con il footprint stretto `1x3`.
Possono essere sostituiti gradualmente con arte
`needs_polish`/`final` senza cambiare il contratto runtime.

I 66 materiali cliff generati vengono normalizzati separatamente dal tool di
migrazione: le facce verticali mantengono soltanto materiale di parete, mentre
lip e angoli ricevono materiale overhead senza silhouette inclinata.

```text
godot --headless --path . --script res://tools/migrate_top_down_cliff_textures.gd
godot --headless --path . --script res://tools/migrate_top_down_cliff_textures.gd -- --check
```

## Ambiente top-down cardinale (tile layer runtime)

`game/modes/zombie/biome_tile_resolver.gd` mappa ogni cella logica del
`BiomeEnvironmentLayout` in un tile asset-backed deterministico: `floor_base`,
varianti floor, route tile (`main_road`, road tematiche, curve, edge e
intersezioni), passage tile (`road`, `bridge`, `snow_pass`, `broken_gate`,
`burned_road`, entry/exit), `hazard_floor`, `border_floor`, `void_edge_near` o
`void_depth`. Le route generate usano segmenti orizzontali e verticali, curve e
incroci fra lati cardinali; i rettangoli definiscono le aperture. La variante
floor deriva da seed, cella e bioma.

Per `plains`, il resolver usa il set forestale dedicato:
`forest_grass`, varianti grass, `forest_tall_grass`, `forest_path`,
`forest_road`, `forest_road_border`, `forest_void`, `forest_cliff_edge`,
`forest_mountain_wall` e le transizioni `grass_to_path`, `grass_to_road`,
`grass_to_tall_grass`,
`path_to_road`, `ground_to_void_cliff` e `ground_to_mountain_wall`. Gli asset
vivono in `environment/top_down/tiles/forest/` e nelle cartelle `edges/`.
Per il rendering, i tile di route forestali e i passage `road` mantengono i
propri ID/section per semantica e debug. `TerrainSurfaceClassifier` li riduce a
grass, path, asphalt o void e `TerrainBoundaryMaskBuilder` registra il risultato
nella maschera regionale RGBA; il divisore alpha sostituisce border, edge e
corner orientati.

`game/modes/zombie/biome_tile_layer.gd` e il ground primario asset-driven per
`TerrainGenerator`: cache-a tutte le 5.625 celle della regione `75x75`, genera
una maschera a 8 pixel per tile e la espone ai chunk come sottorettangoli UV. Il
manifest v14 resta il contratto degli asset. I vecchi `BiomeRegionGround` e
`BiomeTerrainPatch` sono stati rimossi: il tile layer e l'unico produttore del
ground.

Nei biomi con `generated_theme_id`, `BiomeTileLayer` usa i PNG generated per le
superfici ampie e per le route principali: `main_road`/`road`/incroci e
`passage_tiles` road-like pescano dal ruolo full-bleed `road`; le lane tematiche
pescano dal ruolo `path` e il resto del floor da `ground`. I `passage_tiles` e i
relativi entry/exit restano identificati come sezione/tile
(`passage_tiles/bridge_entry`) per preservare semantica e debug, mentre la
maschera e il divisore comune gestiscono ogni contatto tra superfici.

Il generator asset controlla tutti i path unici del manifest, inclusi il
divisore terrain, road connector, entry/exit dei passaggi, object scene per
ostacoli/crate e tile forestali.

## Ambiente top-down cardinale (oggetti runtime)

Gli ostacoli generati dal layout usano `EnvironmentObject` come scena
base slot-based: uno `StaticBody2D` con collisione dal manifest, `Sprite2D`,
anchor al pavimento e collider debug opzionale. Gli asset non aggiungono ombre
o cerchi runtime sul floor; eventuale profondita deve vivere nel PNG/SVG stesso.
Un wrapper
Y-sorted usa il punto di contatto a terra, mentre il body conserva il centro del
placement; la rotazione runtime e sempre zero.
`BiomeObstacle` resta il fallback tecnico quando il manifest dichiara un
fallback procedurale esplicito.

Le `large_rock` scalabili usano il render mode `y_sorted_mesa`: ogni nodo
oggetto conserva collisione, overlay `F9` e la propria mesh locale, mentre
`BiomeTileLayer` non disegna un batch duplicato a profondita fissa. Il plateau
occupa l'intero `mesa_rect` (il void cliff specchiato verso l'alto). La corona
cobble e sollevata e rientra in un mesa, con
tre pareti continue a colonne (fronte sud + due fianchi obliqui) che salgono dal
prato fino al bordo. Visual e collisione derivano dallo stesso rettangolo; il top
e disegnato una sola volta dal nodo `large_rock` per evitare lastre duplicate o
shiftate.
Il top usa
`edges/cliffs/textures/rock_plateau_top_generated.png`; le pareti usano
`rock_cliff_face_upward_generated.png` con shading per lato. Non e una fascia
piatta e non porta linee disegnate: il dettaglio arriva solo dalle texture.

Gli slot ostacolo misurano `4x4` celle logiche. I formati piccoli vivono in
cartelle per categoria (`rocks/`, `fences/`, `debris/`, `trees/`, `wrecks/`) e
riportano la dimensione nel filename; le case vivono in `objects/houses/`.
`visual_height_tiles` aggiunge altezza solo sopra la base. La procedura completa
e la checklist sono in `docs/obstacle_rendering.md`.

Gli asset correnti sono misti: SVG generati in-repo e PNG finali. La Pianura
Infetta usa dieci raster originali in
`objects/generated_raster/plains/`: sette prop esclusivi, il tronco
contestuale e le casse `common`/`medical`. Gli altri biomi conservano per ora
gli SVG cardinali dedicati in `objects/generated_props/`, con source
`project_svg_generator` e attribution `environment_top_down_internal`. In runtime headless
`EnvironmentTextureLoader` rasterizza gli SVG trasparenti quando manca la
cache import, mentre carica i PNG tramite `ResourceLoader`. I PNG mantengono
scala X/Y uniforme; i `visual_scale`/`variant_visual_scales` puntuali del
manifest regolano la dimensione senza deformare l'asset, mentre
`collision_size_ratio` e `variant_collision_size_ratios` allineano `F9` alla
silhouette quando il raster reale supera il footprint.
La supply crate usa lo stesso percorso tramite `object_scenes/supply_crate` e
risolve la variante dal tipo di cassa; il manifest applica `visual_scale = 2.30`
e la scena usa una collisione `84x68` per mantenerla coerente con la dimensione
raddoppiata;
`reed_wall` richiede la propria dimensione nativa al loader per conservare
l'altezza visuale prevista dal manifest.

### Prop cardinali generati

`environment/top_down/concepts/` conserva soltanto il README di migrazione: le
cinque tavole raster precedenti sono state rimosse e non sono sorgenti runtime.
Anche le 23 risorse `AtlasTexture` `.tres` ritagliate da quelle tavole sono
state eliminate. Gli SVG individuali in `objects/generated_props/` restano le
sorgenti cardinali per i biomi non ancora migrati; il manifest v14 sostituisce
quelli della Pianura con raster e supporta varianti contestuali. Il
cutover ha conservato i contratti fisici; il follow-up rende espliciti l'anchor e il collider alle
radici di `dead_tree`. Il `reed_wall` resta uno SVG verticale `1x3` indipendente;
mapping e guardrail sono documentati nel README della cartella `concepts/`.

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
