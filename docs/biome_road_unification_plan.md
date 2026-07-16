# Report differenze biomi + piano di unificazione strade

> Piano completato e conservato come evidenza storica. I simboli e i percorsi
> qui citati riflettono il repository prima di `TOPDOWN-001`; il contratto
> cardinale corrente e `docs/top_down_cardinal_contract.md`.
>
> **Nota di supersessione 2026-07-15.** Il contratto runtime core/edge/corner e
> overlay mono-lato descritto in questo piano e stato sostituito dal sistema in
> `docs/terrain_boundary_mask_system.md`: classifier visuale, maschera regionale
> RGBA, superfici full-bleed grass/path/asphalt e divisore di terra in alpha.
> Le fasi e i follow-up seguenti restano una cronologia corretta del lavoro
> eseguito, ma non sono istruzioni per l'implementazione corrente.

Stato: 2026-07-09 — fasi 0-3 eseguite, follow-up edge/core e overlay mono-lato
completati, sorgente strip riportata al PNG madre (vedi note in fondo alle
rispettive sezioni); fasi 4-5 aperte. Il report differenze descrive lo stato
*precedente* alle fasi eseguite.

Fonte del problema percepito ("non si capisce piu niente"): oggi convivono
**tre pipeline di rendering strada diverse** piu una serie di eccezioni
per-tema accumulate dai pass ART-VIS-FIX. Ogni fix locale ha aggiunto una
lista o un branch `if biome_id == ...`, e il risultato e che nessun bioma
genera le strade nello stesso modo di un altro.

## 1. Le tre pipeline attuali

| Pipeline | Biomi | Interno strada | Bordo strada | Path (lane) | Transizione ground→path |
| --- | --- | --- | --- | --- | --- |
| A. Forest manifest | `infected_plains` | core ritagliato dal border PNG (crop 32% dei margini, `_build_forest_road_core_texture`) | `forest_road_border_defined.png` orientato H/V | **stesso materiale della strada** (core) | tile semantico `grass_to_path`, ma renderizzato col materiale road |
| B. Generated themes | `toxic_wastes`, `burning_fields`, `frozen_outskirts`, `drowned_marsh` | **border PNG intero** (`road_border_defined_01`, nessun crop core) | stesso `road_border_defined_01` orientato H/V | `path_variation` dedicata | **disabilitata**: `resolve_runtime_surface_role` riscrive `ground_to_path` → `path` (taglio netto) |
| C. Temi orfani | tema `desert`, tema `forest` in `generated_images/terrain/` | — (desert non ha `road_variation`, forest generato non ha ne path ne road) | — | — | asset presenti ma mai usati a runtime |

Riferimenti codice:

- Ruoli e riscritture: [biome_generated_art_catalog.gd:381-401](game/modes/zombie/biome_generated_art_catalog.gd#L381-L401)
  (`_surface_pool`: `road` → `ground_to_road` per i 4 temi; `path_to_road` → `ground_to_road`),
  [biome_generated_art_catalog.gd:229-244](game/modes/zombie/biome_generated_art_catalog.gd#L229-L244)
  (`ground_to_path` → `path`).
- Declassamenti a `detail`: [biome_generated_art_catalog.gd:473-533](game/modes/zombie/biome_generated_art_catalog.gd#L473-L533)
  (`road_variation` e `transition_ground_to_road` → `ROLE_DETAIL` nei 4 temi;
  ground variation declassate con set diverso per ogni tema).
- Pipeline forest: [biome_tile_layer.gd:1022-1088](game/modes/zombie/biome_tile_layer.gd#L1022-L1088)
  (border + core crop 32% + rotazioni).
- Pipeline generated: [biome_tile_layer.gd:974-1020](game/modes/zombie/biome_tile_layer.gd#L974-L1020)
  (solo border ruotato, nessun core).

## 2. Divergenze rilevate (dettaglio)

### 2.1 Interno strada

- `infected_plains`: core ritagliato dal border → dentro la carreggiata non si
  vedono le strisce di bordo.
- 4 biomi generated: l'interno usa il **PNG di bordo intero**. Su strade
  larghe piu di 1 tile le strisce di bordo si ripetono in mezzo alla
  carreggiata. E la divergenza visiva piu grave.
- Orientamento sorgente incoerente a livello asset: `urban_ruins` e l'unico
  border nativo orizzontale ([biome_generated_art_catalog.gd:36-38](game/modes/zombie/biome_generated_art_catalog.gd#L36-L38),
  `ROAD_BORDER_HORIZONTAL_SOURCE_THEME_IDS`); gli altri tre sono verticali.
  La differenza e gestita a runtime con un caso speciale.

### 2.2 Transizione strada ↔ resto

- Forest: anello semantico `grass_to_road` / `path_to_road` intorno alla
  strada; render col border orientato.
- Generated: celle `road_edge` / `road_curve_*` → border orientato. Ma
  `_resolve_cell_route_tile_data` ([isometric_tile_resolver.gd:702-738](game/modes/zombie/isometric_tile_resolver.gd#L702-L738))
  assegna `TILE_ROAD_EDGE` a **qualsiasi route** che tocca terreno, incluse le
  lane (`service_lane`, `ash_lane`, `packed_snow_path`, `wooden_walkway`):
  risultato, un sentiero ha interno `path_variation` ma bordo con la texture
  **della strada** — materiali mescolati.
- Gli asset `transition_ground_to_road` (2-5 per tema, generati apposta) sono
  declassati a `detail` e nei 4 temi **mai selezionati** (il pool `detail`
  entra nel ground solo per `desert`/`forest`,
  [biome_generated_art_catalog.gd:400-401](game/modes/zombie/biome_generated_art_catalog.gd#L400-L401)):
  asset morti ma caricati in VRAM.

### 2.3 Non-strada (ground/path)

- Campionamento: i 4 temi generated sono in `REGION_COHERENT_SURFACE_SAMPLE_THEMES`
  → **un solo asset per ruolo su tutta la regione** (sample cell fissa a
  `(0,0)`). `desert`/`forest` campionano per macro-cella 8x8 e mescolano i
  `detail` nel ground. Due filosofie opposte nello stesso catalogo, con le
  stesse 4 liste di temi duplicate 3 volte (`COHERENT…`, `REGION_COHERENT…`,
  `ROAD_BORDER_THEME_IDS`) da tenere sincronizzate a mano.
- Post-processing per-tema in [generated_biome_texture_tools.gd](game/modes/zombie/generated_biome_texture_tools.gd):
  ogni bioma ha il suo stack hardcoded via `if biome_id == ...`:
  - `toxic_wastes`: atlas specchiato 2x2 + harmonize bordi;
  - `frozen_outskirts`: tone-down + snow blend route + quilt macro 1024 offset;
  - `drowned_marsh`: route lift caldo + quilt macro + cliff downscale 0.45;
  - `burning_fields`: trim 10px (vs 2 degli altri), blend 40px, ember damping;
  - `infected_plains`: nessuno di questi (pipeline SVG/manifest separata).
- Ground variation declassate a `detail` con criteri diversi per tema
  (frozen: 3 su 4; swamp: 2; volcanic: 3; urban: 2): ogni bioma di fatto usa
  1-2 texture ground, ma la scelta e sparsa in `_surface_role_for_file`.

### 2.4 Semantica resolver

- Il resolver ha **due rami route completi e paralleli**
  (`_resolve_forest_*` vs `_resolve_cell/rect_route_tile_data`,
  [isometric_tile_resolver.gd:590-660](game/modes/zombie/isometric_tile_resolver.gd#L590-L660)),
  con regole diverse per edge, curve, incroci e passage. Le curve
  (`road_curve_*`) esistono solo nel ramo non-forest; `path_to_road` solo nel
  ramo forest.
- La mappa tile→ruolo materiale (`_generated_surface_role`,
  [isometric_tile_resolver.gd:1323-1347](game/modes/zombie/isometric_tile_resolver.gd#L1323-L1347))
  e una terza fonte di verita da tenere allineata alle prime due.

## 3. Piano di unificazione

Obiettivo: **una sola pipeline strada** parametrizzata per tema, con aspetto
coerente su interno, bordo e non-strada. Nessun cambio a collisioni,
pathfinding o semantica dei tile id (vincolo gia stabilito da ART-VIS-FIX).

### Fase 0 — Contratto unico per tema (solo refactor config)

Sostituire le liste parallele del catalogo con **una tabella per tema**:

```gdscript
const THEME_CONTRACTS := {
    &"urban_ruins": {
        sampling = &"region",          # region | macro_cell | per_cell
        road_style = &"border_defined",# border PNG orientabile
        native_border_orientation = &"horizontal",
        ground_variants = [2, 3],      # variation attive come ground
        path_transitions = false,      # taglio netto ground→path
    },
    ...
}
```

Da questa tabella derivano `ROAD_BORDER_THEME_IDS`,
`REGION_COHERENT_SURFACE_SAMPLE_THEMES`, `GROUND_DETAIL_POOL_THEMES`,
`ROAD_BORDER_HORIZONTAL_SOURCE_THEME_IDS` e i declassamenti di
`_surface_role_for_file`. Zero cambi visivi: e il prerequisito per non
impazzire nelle fasi dopo. Guardrail: `validate_catalog()` + snapshot dei
pool per ruolo prima/dopo in `generated_texture_test.gd`.

**Eseguita 2026-07-09.** `THEME_CONTRACTS` in
`biome_generated_art_catalog.gd` con campi `sampling`, `road_style`,
`native_border_orientation`, `ground_detail_in_pool`,
`detail_ground_variations`, `path_transitions`; le quattro liste parallele e
i branch per-tema di `_surface_role_for_file` /
`resolve_runtime_surface_role` sono derivati dal contratto. GUT assets
invariati (65/65).

### Fase 1 — Interno strada unificato (core crop per tutti)

Portare il "core crop" della pipeline forest (crop orizzontale 32% del border
PNG, gia in `_build_forest_road_core_texture`) nella pipeline generated:

- spostare la funzione in `GeneratedBiomeTextureTools` (parametrica su
  margine);
- in `biome_tile_layer`, per ogni `road_border_defined` registrare core,
  varianti orientate e overlay mono-lato (`__edge_west/east/north/south`);
- nel resolver, le celle route **interne** (non a contatto con terreno
  non-route) risolvono il materiale `core`, le celle di bordo il materiale
  `core` piu overlay mono-lato. Il criterio interno/bordo e
  `_route_cell_touches_non_route_surface`.

Risultato: niente piu strisce di bordo ripetute in mezzo alle strade larghe;
`infected_plains` e i 4 generated identici per costruzione.

**Eseguita 2026-07-09.** Crop condiviso in
`GeneratedBiomeTextureTools.crop_road_core_texture` (parametrico su
orientamento sorgente e margine, `ROAD_CORE_CROP_MARGIN_RATIO = 0.32`);
`build_road_core_surface_texture` replica la pipeline surface con il crop
inserito *prima* dell'atlas specchiato (toxic) e degli harmonize per-bioma
(snow blend frozen, route lift swamp, ember damping volcanic). Il tile layer
registra `__core_vertical`/`__core_horizontal` accanto ai border; il resolver
mappa `GENERATED_THEME_ROAD_CORE_TILE_IDS` al core via
`road_core_material_id`. Il core forestale ora usa lo stesso crop condiviso.
Follow-up edge/core: `main_road`, `road`, `road_intersection` e i passage
road-like usano il core come base anche quando toccano terreno non-route; il
bordo visibile e una strip overlay `__edge_*`, non il PNG completo campionato
come cella intera. Il follow-up successivo sostituisce il sorgente della strip:
non piu crop di `road_border_defined`, ma texture di transizione
`grass_to_road` / `transition_ground_to_road`. Verifica: GUT
assets+environment verdi, QA `biome_art_frozen_outskirts` e
`biome_rendering_review` exit 0, ispezione immagini frozen/toxic.

### Fase 2 — Bordi corretti anche per i path

- Introdurre `TILE_PATH_EDGE` (o un flag `route_kind` nel tile data) cosi le
  lane non ereditano `TILE_ROAD_EDGE`: il bordo di un sentiero risolve
  `path_variation` (o un futuro `path_border`), non il border stradale.
- In alternativa minima (senza nuovo tile id): in `_generated_surface_role`
  risolvere `TILE_ROAD_EDGE`/curve al ruolo border **solo se** la route
  sottostante e main road; per le lane restituire `ROLE_PATH`.
- Normalizzare l'orientamento sorgente degli asset: ruotare offline
  `urban_ruins_terrain_27_road_border_defined_01.png` in verticale (una
  tantum) ed eliminare `ROAD_BORDER_HORIZONTAL_SOURCE_THEME_IDS` e il caso
  speciale runtime.

**Eseguita 2026-07-09.** Bordi/incroci lane: nuovo helper pubblico
`IsometricTileResolver.route_cell_uses_lane_surface` — se nessuna strada
principale attraversa la cella, `road_edge`/`road_curve_*`/`road_intersection`
risolvono `ROLE_PATH` (materiale `path_variation`) invece del bordo stradale;
il tile id semantico resta invariato. Asset urban: PNG ruotato 90° CW su disco
(ora nativo verticale come gli altri temi), contratto
`native_border_orientation` aggiornato; il campo resta nel contratto per
eventuali temi futuri, il codice runtime e' gia' generico. Bump
`TileBakeCache.FORMAT_VERSION` 22→23 per invalidare le mappe material bake-ate
con le regole pre-unificazione. Guardrail: probe lane-edge in
`generated_texture_test.gd` (bordo lane = `path_variation`), review QA
lane-aware, board `generated_biome_art` invariata (legge l'orientamento dal
contratto). GUT assets+environment verdi, QA toxic/review/generated_art exit 0.

### Fase 3 — Unificare i due rami del resolver

- Fondere `_resolve_forest_cell/rect_route_tile_data` e
  `_resolve_cell/rect_route_tile_data` in un unico ramo che produce tile
  semantici comuni (interno, edge, curva, incrocio, passage, path, path_edge)
  e lascia al catalogo la scelta del materiale per tema.
- `infected_plains` diventa un tema come gli altri: il suo
  `forest_road_border_defined.png` entra nel contratto tema (Fase 0) e i
  texture id speciali `FOREST_ROAD_*` spariscono dal tile layer.
- I tile id legacy (`forest_road`, `grass_to_road`, ...) restano come
  semantica/QA, solo il mapping materiale cambia.

**Eseguita 2026-07-09** (scope route). Resolver: i rami
`_resolve_forest_cell/rect_route_tile_data` sono fusi in
`_resolve_cell_route_tile_data`/`_resolve_rect_route_tile_data` (ramo unico
con classificazione per-bioma e tile id legacy invariati); la logica passage,
prima quadruplicata, vive in `_resolve_passage_tile_data` +
`_resolve_passage_endpoint/connector_tile_data`. Il materiale route di
`infected_plains` viene assegnato dal resolver (`_apply_forest_route_material`)
con la convenzione dei temi generated: `forest_road_border_defined__vertical`/
`__horizontal`/`__core_vertical`/`__core_horizontal` derivati dal contratto
manifest `forest_road_border`. Tile layer: eliminati i texture id speciali
`FOREST_ROAD_*`, la selezione per-cella duplicata
(`_forest_road_border/core_texture_id_for_cell`,
`_forest_route_cell_touches_non_route`) e le liste route locali (ora
`IsometricTileResolver.FOREST_ROUTE_SURFACE_TILE_IDS`). Bump
`TileBakeCache.FORMAT_VERSION` 23→24 (le mappe material forest ora sono
popolate). Nota di scope: il terreno non-route forestale (grass, tall grass,
mountain wall, transizioni cliff) resta sulla pipeline manifest/SVG dedicata —
la migrazione degli asset forestali sotto `generated_images` non serve
all'obiettivo strade e resta una valutazione di Fase 4. Verifica: GUT
assets+environment verdi, QA `biome_art_infected_plains` e
`biome_rendering_review` exit 0, ispezione board route infected_plains.

**Follow-up edge/core 2026-07-09.** Il resolver espone
`route_cell_uses_road_border_material` e classifica il bordo strada/prato in
base al contatto reale con celle non-route, non alla sola geometria del
rettangolo strada. Gli incroci/hub interni e i passage road-like interni
mantengono il core; perimetri, overlap a contatto col prato e bordi passage
mantengono il core come base e ricevono overlay mono-lato solo sul lato
esposto. `BiomeTileLayer` registra materiali `__edge_west/east/north/south`
alpha-feathered dalle texture `grass_to_road_generated.png` e
`transition_ground_to_road_*` e `IsometricForestGroundMeshBuilder.build_edge_strip_mesh`
usa UV locali sull'asse corto per evitare prato dentro l'asfalto. La strip sta
a cavallo del confine: 0,32 tile sul terreno e 0,32 tile sulla strada,
lasciando core visibile anche sulle strade da un tile. Per i temi generated la
scelta non usa piu l'hash seed: `BiomeGeneratedArtCatalog` preferisce la
variante straight-road per tema (`urban_ruins` 02, `volcanic` 05,
`frozen_tundra` 01, `swamp` 02).
Bump
`TileBakeCache.FORMAT_VERSION` 24->26. Guardrail in
`generated_texture_test.gd` su interni strada, incroci, passage core, passage
edge, uso delle texture di transizione e UV delle strip. Verifica: GUT assets mirato verde e
`biome_rendering_review_visual_qa.gd` exit 0 con PNG rigenerati.

**Pass sorgente strip 2026-07-09 (direzione artistica).** La strip `__edge_*`
del confine strada/prato torna a essere ritagliata dal PNG madre
`road_border_defined` della strada dritta, non dalle texture di transizione
sfumate: le `transition_ground_to_road_*` e `grass_to_road_generated` non sono
piu sorgenti runtime (rimosse le API
`select_ground_to_road_transition_asset_path` /
`get_ground_to_road_transition_asset_paths` e le registrazioni edge dai
transition asset). Per i temi generated il ritaglio avviene pre-atlas con gli
harmonize per-bioma applicati alla striscia
(`GeneratedBiomeTextureTools.build_road_border_side_surface_texture`); per il
forest la striscia viene ritagliata dalla `forest_road_border_defined`
orientata. Fade alpha e geometria della strip invariati
(`_road_border_overlay_asset_path` nel tile layer). La QA
`biome_art_infected_plains` — rimasta ai requisiti pre follow-up (border pieni
come superficie base) — e stata allineata al contratto attuale e spacchettata
in condizioni singole. Verifica: GUT assets+environment verdi, QA dei biomi
generated + infected_plains + review + board generated_art exit 0, ispezione
confine su capture forest e frozen.

**Tuning visibilita' strip 2026-07-09.** La prima resa della strip era
invisibile a schermo: 0,64 tile totali con feather alpha 0,22 per lato
lasciavano opaco solo un filo di pixel e il crop 0,42 comprimeva la banda di
ciottoli. Nuovi valori: `ROAD_BORDER_SIDE_STRIP_RATIO = 0.32` (la strip
mostra esattamente la banda che il core scarta: core + strip ricompongono
l'asset madre), `ROAD_TRANSITION_OVERLAY_FEATHER_RATIO = 0.08` (feather
minimo anti-rettangolo), `ROAD_BORDER_OVERLAY_HALF_WIDTH_TILES = 0.5`
(strip da 1 tile, proporzione della banda nell'asset madre). Verificato con
zoom 2x su frozen (banda ghiaia+neve) e toxic (ghiaia+muschio) e a zoom
naturale su forest (cordolo chiaro): il confine ora legge come nel PNG
sorgente. GUT assets verdi, QA 5 biomi + review exit 0.

**Follow-up asset lineare forest 2026-07-15.** Il nuovo PNG
`forest_road_border_defined.png` mantiene la propria densita' sull'asse corto:
il crop al 32% occupa `FOREST_ROAD_BORDER_OVERLAY_WIDTH_WORLD = 81.92` px world
e termina sul limite della carreggiata, invece di essere compresso e centrato
in una tile. Un materiale canvas armonizza la porzione spaziale esterna del
crop col ground canonico; ghiaia e asfalto non vengono ritinti. Il clamp di
mezzo texel sull'asse corto evita che il repeat ricampioni il prato sul limite
interno; un overlap di 2 px fa terminare il feather sopra il core asfaltato,
mentre il feather forestale viene applicato solo al margine esterno e non rende
trasparente il terminale asfaltato. I biomi generated conservano larghezza e
centraggio precedenti. Verifica: GUT `generated_texture` e Visual QA
`biome_art_infected_plains` verdi.

**Follow-up angoli forest 2026-07-15.** I raster
`forest_road_border_convex.png` e `forest_road_border_concave.png` completano
le strip lineari. `BiomeTileResolver.route_corner_at_vertex` classifica un
vertice in base alle quattro celle adiacenti: una route produce un convesso,
tre route un concavo; rette, diagonali disgiunte e interni pieni restano senza
macro. `BiomeTileLayer` genera le quattro rotazioni dai soli due sorgenti,
ancora ogni macro 256x256 al quadrante speciale e la disegna nello stesso pass
overlay sopra le strip. Il materiale dedicato armonizza la vegetazione senza
ritintare l'asfalto e sfuma il perimetro del quadrato. Verifica mirata: GUT
`generated_texture` 32/32 e Visual QA `biome_art_infected_plains` verde.

Le strip vivono in un canvas figlio con z relativo superiore al terreno base:
la parte che si estende sul prato non viene quindi coperta dal draw di un chunk
adiacente. Il pass separato vale anche per perimetro e raccordi dell'hub
centrale, ma resta sotto cliff, ostacoli e attori.

**Fix copertura survival 2026-07-09.** Nel mondo reale i corridoi passage tra
biomi sorgono sopra spoke di lane carvate dal generatore voidfirst
(`service_lane`/`broken_street` come tag cella sotto rect
`broken_gate`/`snow_pass`/...): `route_cell_uses_lane_surface` vedeva il tag
lane e vetava l'overlay di confine su superfici che renderizzano asfalto
road-like — da qui "strade" con il bordo e altre senza. Ora l'appartenenza a
`passage_rects`/`passage_connector_rects` o un tag passage prevalgono sul tag
lane (le lane pure restano senza bordo, per design Fase 2). Diagnosi con
sonda headless sul mondo survival reale (seed 641004, 3x3): celle route
coperte da overlay 51→147 (infected_plains) e 61→180 (toxic_wastes), gruppi
mancanti residui solo lane pure e celle a ridosso del void. Guardrail GUT
`test_passage_over_lane_spoke_keeps_road_border_overlay`; bump
`TileBakeCache.FORMAT_VERSION` 26→27 (cambiano i material risolti su quelle
celle). GUT assets+environment verdi, review QA exit 0, ispezione zoom sul
corridoio toxic (banda presente su entrambi i lati).

### Fase 4 — Pulizia asset e non-strada

- Decidere il destino degli asset morti: `road_variation_01` dei 4 temi
  (declassato a `detail` mai campionato). Gli asset
  `transition_ground_to_road_*` non sono piu morti: restano nel ruolo detail ma
  vengono usati come sorgente degli overlay mono-lato strada/prato. Opzioni:
  (a) rimuovere solo `road_variation_01` dal caricamento (non piu in
  `get_all_surface_asset_paths` → meno VRAM), (b) eliminarlo dal repo e
  aggiornare `EXPECTED_TOTAL_ASSET_COUNT`/`EXPECTED_ACTIVE_ASSET_COUNT`.
  Consiglio: (a) subito, (b) dopo QA verde.
- Tema `desert` e tema `forest` di `generated_images`: dichiararli
  esplicitamente "shelf" nel contratto (nessun bioma) o rimuoverli; oggi
  falsano il conteggio e la validazione li tratta come attivi a meta.
- Uniformare la politica di variazione ground dietro il campo `sampling` del
  contratto tema: la scelta region-coherent vs macro-cell resta per-tema ma
  diventa un parametro, non una lista.
- I post-processing identitari (tone frozen, lift swamp, ember volcanic,
  atlas urban) restano, ma pilotati dal contratto tema invece che da catene
  `if biome_id == ...` in `normalize_surface_texture`.

### Fase 5 — QA e guardrail

- Estendere `generated_texture_test.gd`: per ogni tema attivo, asserire che
  esistano i materiali strada base (`core` x `H/V`) e overlay (`edge` x 4), e
  che le lane non risolvano materiali border stradali.
- Rilanciare le 5 QA visuali dedicate + `biome_rendering_review_visual_qa.gd`
  (contratto: exit 0, `visible_missing_chunks == 0`), con vista ravvicinata
  interno-strada su carreggiata larga ≥ 2 tile (il difetto Fase 1 si vede solo
  li).
- Aggiornare `docs/biome_art_vis_fix_roadmap.md` (le schede citano il
  comportamento pre-unificazione) e `assets/README.md`.

### Ordine e rischio

| Fase | Rischio visivo | Dipendenze |
| --- | --- | --- |
| 0 | nullo (refactor config) | — |
| 1 | basso, migliorativo | 0 |
| 2 | medio (cambia il look dei bordi lane) | 0, 1 |
| 3 | medio (tocca infected_plains, il bioma di riferimento) | 0-2 |
| 4 | basso | 0 |
| 5 | — | tutte |

Le fasi 1-2 da sole risolvono i tre sintomi lamentati (interno strada,
transizione, non-strada incoerenti); la 3 e quella che elimina davvero la
doppia pipeline; la 4 e igiene.
