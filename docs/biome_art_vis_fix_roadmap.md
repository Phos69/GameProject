# Biome ART-VIS-FIX Roadmap

> Roadmap completata e conservata come evidenza storica. Le indicazioni di
> proiezione e i path precedenti sono superati da
> `docs/top_down_cardinal_contract.md` e non vanno riutilizzati nei prompt.

Stato: completato 2026-07-03. Tutti e cinque i biomi hanno il pass applicato,
la QA dedicata verde e i guardrail GUT estesi; il review completo
`biome_rendering_review_visual_qa.gd` chiude con exit code `0`. Dal pass di
unificazione strade 2026-07-09 (`docs/biome_road_unification_plan.md`, fasi
0-3 + follow-up edge/core) le celle road-like interne dei temi generated
(`main_road`, `road`, `road_intersection`, edge/curve e passage) renderizzano
il core ritagliato `road_border_defined__core_vertical`/`__core_horizontal`
come base; i margini che toccano terreno non-route ricevono una fascia overlay
`transition_ground_to_road_*__edge_west/east/north/south`. `tile_id` e sezione
`passage_tiles` restano per semantica/collisioni. Restano fuori scope i residui
documentati in fondo a questo file (sezione "Residui e riclassificazioni").

Questo documento spezza `ART-VIS-FIX` in pass piccoli, uno per bioma, per
rendere piu rapido il ciclo agente -> screenshot -> correzione -> QA. La fonte
del backlog resta `TODO.md`; questo file e la checklist operativa per i fix di
rendering dei biomi Survival.

## Obiettivo

Normalizzare il rendering dei cinque biomi Survival senza cambiare regole di
gioco, collisioni, pathfinding, danni, spawn, loot o bilanciamento.

Il pass riguarda:

- armonia di texture ground/path/road/cliff/void;
- riduzione di seam, bordi chiari, checker, pannelli rettangolari e tiling
  dominante;
- transizioni nette e orientabili tra terreno e strade;
- scala, padding, ombra e stile degli oggetti quando il problema e locale al
  bioma;
- QA visuale dedicata per il bioma assegnato.

## Regole Di Pass Per Ogni Bioma

Un bioma puo essere chiuso solo quando tutte queste condizioni sono vere.

- Cambio texture armonico: ground, path, road, cliff e void devono sembrare
  parte dello stesso materiale di bioma, senza stacchi rettangolari evidenti.
- Nessun effetto bordo: niente white matte, bordi chiari residui, alpha sporco,
  checker, griglia ortogonale o ripetizioni visibili a colpo d'occhio.
- Transizione verso strada: non usare una texture intermedia sfumata o una
  fascia generica tra terreno e strada. La transizione deve usare una immagine
  orientabile o tile orientabile, con taglio netto e direzione coerente con la
  strada isometrica.
- Route leggibili: strada, sentiero e crossing devono leggere come superficie
  fisica, non come overlay tecnico.
- Attori leggibili: player, zombie, pickup, hazard, telegraph e crate devono
  restare separabili sopra il bioma a `1280x720` e `960x540`.
- Nessun fallback implicito: se un asset manca, il fallback deve essere
  esplicito nel manifest o nel catalogo e visibile come stato tecnico, non come
  placeholder generico in una cattura di pass.
- Nessuna regressione mondo: `visible_missing_chunks == 0`, cliff/void gia
  coperti da `WORLD-VIS-FIX` restano verdi e le fall zone mantengono la
  semantica attuale.

## Ciclo Iterativo Per Agente

Ogni agente deve lavorare su un solo bioma alla volta.

1. Leggere questo file, `docs/visual_qa_report_2026-07-01.md`,
   `docs/testing/visual_qa.md`, `assets/README.md` e il contratto asset
   rilevante.
2. Eseguire o rigenerare la QA dedicata del bioma assegnato.
3. Aprire le immagini generate sotto `build/qa/` e annotare i difetti reali:
   seed, risoluzione, vista, sintomo, file/sistema probabile.
4. Applicare un fix piccolo e coerente con i sistemi esistenti:
   `BiomeGeneratedArtCatalog`, `GeneratedBiomeTextureTools`,
   `IsometricTileResolver`, manifest, asset generated o object visual locali.
5. Rilanciare la QA dedicata del bioma e i GUT vicini.
6. Ripetere finche le immagini passano. Non chiudere un bioma senza aver visto
   le immagini finali.
7. Se emergono altri miglioramenti evidenti nello stesso bioma, farli nello
   stesso pass solo se restano presentazionali e verificabili. Se toccano piu
   biomi o contratti condivisi, documentare il blast radius e rieseguire QA su
   tutti i biomi impattati.

## QA Dedicata Per Bioma

Il runner esistente `biome_rendering_review_visual_qa.gd` genera 150 immagini
per cinque biomi. Per velocizzare `ART-VIS-FIX`, creare o aggiornare una QA
per-bioma che riusi lo stesso contratto ma limiti il lavoro al bioma assegnato.

Entry point consigliati:

| Bioma | Entry point QA dedicato | Output atteso |
| --- | --- | --- |
| `infected_plains` | `tests/visual_qa/biome_art_infected_plains_visual_qa.gd` | `build/qa/biome_art_fix/infected_plains/` |
| `toxic_wastes` | `tests/visual_qa/biome_art_toxic_wastes_visual_qa.gd` | `build/qa/biome_art_fix/toxic_wastes/` |
| `burning_fields` | `tests/visual_qa/biome_art_burning_fields_visual_qa.gd` | `build/qa/biome_art_fix/burning_fields/` |
| `frozen_outskirts` | `tests/visual_qa/biome_art_frozen_outskirts_visual_qa.gd` | `build/qa/biome_art_fix/frozen_outskirts/` |
| `drowned_marsh` | `tests/visual_qa/biome_art_drowned_marsh_visual_qa.gd` | `build/qa/biome_art_fix/drowned_marsh/` |

Ogni QA dedicata deve catturare almeno:

- seed `641004`, `772031`, `918273`;
- risoluzioni `1280x720` e `960x540`;
- viste `center`, `passage`, `fall_cliff`, `obstacle_hazard`,
  `player_roster`;
- una vista ravvicinata di transizione terrain -> road/path per verificare il
  taglio netto orientabile;
- una vista `resource_crate` quando il pass riguarda scala o identita degli
  oggetti raccoglibili;
- log con `visible_missing_chunks == 0` e world coverage valida.

Comandi minimi durante il lavoro:

```powershell
./tools/run_visual_qa.ps1 -SkipImport -Filter biome_art_toxic_wastes
./tools/run_visual_qa.ps1 -SkipImport -Filter biome_rendering_review
./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/assets
./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/environment
```

Per il primo pass su un nuovo bioma, se la QA dedicata non esiste ancora,
crearla prima del fix o estrarre un helper riusabile da
`biome_rendering_review_visual_qa.gd`. La QA dedicata deve essere abbastanza
veloce da essere rilanciata molte volte durante l'iterazione.

## Test Automatici Da Aggiungere O Rafforzare

Oltre alle catture renderizzate, ogni bioma chiuso deve avere almeno un
guardrail headless vicino al sistema toccato.

- Asset/texture: estendere `tests/suites/assets/generated_texture_test.gd` per
  verificare crop, alpha e assenza di bordo chiaro sugli asset del bioma.
- Resolver/manifest: estendere `tests/suites/assets/manifest_contract_test.gd`
  o test vicino per garantire che road/path transition risolvano tile
  orientabili e non fallback generici.
- Tile layer: estendere suite `environment` quando il fix cambia
  `BiomeTileLayer`, `IsometricTileResolver` o chunk bake.
- World coverage: rilanciare `biome_rendering_review_visual_qa.gd` dopo un
  fix condiviso, non solo la QA del singolo bioma.

## Ordine Consigliato

L'ordine ottimizza la riusabilita: prima si fissa il contratto di transizione
base, poi i biomi con generated art piu problematici.

1. `infected_plains` - baseline forestale, road/path e alberi.
2. `toxic_wastes` - pannelli grigi, texture urban ruins, route e pozze.
3. `frozen_outskirts` - sovraesposizione, griglia neve/ghiaccio, route chiare.
4. `drowned_marsh` - bande verticali, valori scuri, acqua/strada/fango.
5. `burning_fields` - rumore arancio, lava come accento, leggibilita hazard.

## Schede Per Bioma

### infected_plains

Obiettivo: fare della Pianura Infetta il riferimento per le transizioni
ground/path/road e per la scala degli oggetti forestali.

Stato 2026-07-09: quarto pass strada eseguito. Il runtime mantiene i tile ID
`forest_path`, `forest_road`, `grass_to_path`, `grass_to_road`, `path_to_road` e
i passage `road`/entry/exit come semantica del resolver, ma sulle route della
Pianura Infetta renderizza il core `forest_road_border_defined__core_vertical`/
`__core_horizontal` come base e aggiunge `__edge_west/east/north/south` solo
sui lati esposti verso terreno non-route, usando `grass_to_road_generated` come
sorgente della transizione; dalla fase 3 dell'unificazione strade il materiale
e' assegnato dal resolver con la stessa convenzione dei temi generated. Questo
rimuove la
sovrapposizione visiva tra terra,
asfalto legacy e bordo strada definito senza ripetere l'erba dentro la
carreggiata.
Aggiunta QA dedicata in `tests/visual_qa/biome_art_infected_plains_visual_qa.gd`
e variazione deterministica flip/tinta per `forest_tree`; la QA ora include una
strada principale verticale e una orizzontale e fallisce se `forest_path` o
`forest_road` vengono renderizzati sulle route.

File probabili:

- `game/modes/zombie/isometric_tile_resolver.gd`
- `game/modes/zombie/biome_tile_layer.gd`
- `assets/environment/isometric/manifest.json`
- asset forestali sotto `assets/environment/isometric/`
- `docs/forest_isometric_texture_system.md`

Finding da chiudere:

- path e road con scalini o angoli netti;
- `path_to_road` o `grass_to_road` percepiti come fascia sovrapposta;
- `forest_road_border_defined` usato come materiale unico non orientato
  (**chiuso 2026-07-08**);
- ripetizione e scala di `forest_tree`;
- eventuali oggetti forestali con stile troppo diverso dagli attori.

Pass locale:

- transizioni terrain -> road/path basate su immagini orientabili con taglio
  netto;
- road border nativo per lati ovest/est e variante ruotata per lati nord/sud;
- nessun tiling evidente in `forest_surface_generated_visual_qa.gd`;
- alberi meno ripetitivi o con variazione/padding sufficiente.

### toxic_wastes

Stato 2026-07-08: pass completato. Il ground pool usa solo la coppia coerente
di rubble (variation 02/03: lichene chiaro e ghiaia bruna passano a `detail`),
eliminando la scacchiera di pannelli per macro-cella. Le route dei temi
generati usano i PNG `road_border_defined`: core `__core_*` come base per
`main_road`/`road`/incroci e passage `broken_gate`, overlay `__edge_*` per i
margini che toccano terreno non-route e relative entry/exit di perimetro; dal
pass di unificazione strade 2026-07-09 la source `urban_ruins` e' stata ruotata
una tantum a nativa verticale come gli altri temi, quindi non serve piu' il
caso speciale di orientamento. I `path_variation` restano per le lane tematiche,
ora anche sui loro bordi e incroci quando nessuna strada principale attraversa
la cella. Gli edifici generati sono stati
ridisegnati nel pass trasversale (vedi "Residui e riclassificazioni" per le
pozze). QA dedicata:
`tests/visual_qa/biome_art_toxic_wastes_visual_qa.gd`; guardrail esteso in
`generated_texture_test.gd` (contratto pool ground e road border orientato).

Obiettivo: eliminare il look a blocchi grigi e rendere route, terreno e pozze
tossiche separabili senza aumentare saturazione in modo aggressivo.

Stato 2026-07-02: primo pass terreno/route eseguito. `urban_ruins` mantiene un
materiale stabile per ruolo su tutta la regione, normalizza i raster in atlas
specchiati 2x2 alla densita nativa e usa direttamente path/road generated sui
contatti, senza texture di transizione intermedia. Il secondo pass oggetti ridisegna
`lab_block` e `lab_ruin` con la stessa architettura muta di tetto/porta/
finestre/fondazione degli altri edifici generati, cosi' si distinguono dalle
supply crate senza cambiare footprint o collisioni. La QA dedicata copre tre
seed, due risoluzioni e sette viste, inclusa `resource_crate`, con zero chunk
mancanti. `VIS-005` e chiuso: le evidenze originarie mostravano edifici
laboratorio, mentre le vere crate sono compatte.

File probabili:

- `game/modes/zombie/biome_generated_art_catalog.gd`
- `game/modes/zombie/generated_biome_texture_tools.gd`
- `game/modes/zombie/isometric_tile_resolver.gd`
- generated art `urban_ruins`

Finding da chiudere:

- rettangoli raster distinguibili;
- grigio uniforme tra strada e terreno;
- bordi `road_border_defined` non orientati sui lati nord/sud
  (**chiuso 2026-07-08**);
- pozze verdi troppo piccole o isolate;
- crate/oggetti che sembrano overlay sopra fondale raster.

Pass locale:

- route riconoscibile per silhouette/materiale, non solo colore;
- road border nativo per lati ovest/est e variante ruotata per lati nord/sud;
- nessun tile urban ruins con bordo o pannello chiaro;
- hazard tossici leggibili in co-op.

### burning_fields

Stato 2026-07-08: pass completato. Damping selettivo dei pixel brace del
ground (`VOLCANIC_EMBER_THRESHOLD`/`VOLCANIC_EMBER_DAMPING` in
`GeneratedBiomeTextureTools`), route a taglio netto dal fix condiviso, cliff
gia' trimmati/armonizzati e ora anche mipmappati. Le strade piene e i passage
`burned_road` con relative entry/exit usano `road_border_defined` volcanic:
core `__core_*` come base e overlay `__edge_*` sui margini strada/prato; le lane restano
`path_variation`. QA
dedicata:
`tests/visual_qa/biome_art_burning_fields_visual_qa.gd`; guardrail
`_assert_volcanic_embers_are_damped` sulla coda calda e test asset su road
border orientato.

Obiettivo: mantenere identita calda e pericolosa, ma ridurre rumore arancio e
competizione con hazard, telegraph e oggetti piccoli.

Stato 2026-07-02: primo pass terreno/route eseguito. `volcanic` mantiene un
materiale stabile per ruolo sull'intera regione; il ground pieno usa solo la
base variation 02 piu quieta, mentre 01, 03 e 04 restano detail catalogati.
I raster armonizzano i bordi opposti con periodo world-space `512` e i
contatti usano direttamente path/road generated, senza texture di transizione
intermedia. La QA dedicata copre tre seed, due risoluzioni e sette viste,
inclusa `resource_crate`, con zero chunk mancanti; hazard, telegraph, attori,
cliff e supply crate restano separabili. Il bioma resta aperto per il polish
sulla ripetizione a bassa frequenza del raster ground; `VIS-005` non e piu
assegnato al bioma.

File probabili:

- `game/modes/zombie/biome_generated_art_catalog.gd`
- `game/modes/zombie/generated_biome_texture_tools.gd`
- generated art `volcanic`
- `BiomeHazardCatalog` solo se serve allineare colori presentazionali senza
  cambiare danni.

Finding da chiudere:

- terreno troppo rumoroso;
- lava/detail usati come superficie base;
- crate e hazard che perdono profondita;
- cliff/lip con bordo chiaro residuo.
- bordi `road_border_defined` non orientati sui lati nord/sud
  (**chiuso 2026-07-08**).

Pass locale:

- lava come accento o feature, non come ground dominante;
- telegraph e fire hazard leggibili sopra il terreno;
- path/road con taglio orientabile, non fascia sfumata;
- road border nativo per lati ovest/est e variante ruotata per lati nord/sud.

### frozen_outskirts

Stato 2026-07-08: pass strada riletto e corretto. Oltre al tono neutro
anti-sovraesposizione (`FROZEN_GROUND_TONE`), al blend neve delle route ridotto
a `0.10/0.12` e all'harmonize dei bordi contro la griglia bianca da repeat, i
bordi strada `road_border_defined` ora vengono registrati come core base,
mentre gli overlay mono-lato derivano da `transition_ground_to_road_*`. Le
superfici strada usano il core
`road_border_defined__core_*` anche su edge/curve, con overlay solo sui margini
strada/prato, inclusi i passage `snow_pass` e relative entry/exit ai seam. QA
dedicata:
`tests/visual_qa/biome_art_frozen_outskirts_visual_qa.gd`; guardrail
`_assert_frozen_ground_is_toned_down`, seam score sui bordi e test asset su
materiali strada orizzontali/verticali.

Obiettivo: ridurre sovraesposizione e griglia bianca mantenendo neve, ghiaccio
e strada distinguibili.

Stato 2026-07-08: pass locale chiuso. `frozen_tundra` mantiene un materiale
stabile per ruolo sull'intera regione e usa direttamente path/road generated sui
contatti, senza texture di transizione intermedia. Il ground costruisce a
runtime una quilt periodica `2x2` da quattro offset dello stesso raster neve:
le cuciture interne ed esterne sono armonizzate, la densita resta nativa e il
periodo world-space sale a `1024` senza simmetrie specchiate o cambio materiale
a macro-celle. Path e road restano a `512`; le celle `road_edge`/`road_curve_*`
e i bordi passage usano il core strada come base e overlay `road_border_defined`
mono-lato con orientamento coerente al lato esposto. La QA dedicata copre tre
seed, due risoluzioni e sei
viste con zero chunk mancanti.

File probabili:

- `game/modes/zombie/generated_biome_texture_tools.gd`
- generated art `frozen_tundra`
- `game/modes/zombie/isometric_tile_resolver.gd`
- palette `frozen_outskirts_palette.tres`

Finding da chiudere:

- road/ice/ground con griglia chiara regolare;
- cliff, ghiaccio e crate chiare senza separazione;
- passaggi neve troppo simili al ground pieno;
- bordi `road_border_defined` non orientati correttamente sui lati nord/sud
  della strada (**chiuso 2026-07-08**).

Pass locale:

- valori neve piu leggibili ma non sporchi;
- route e ghiaccio separati per shape/materiale;
- nessun bordo bianco nei tile ripetuti;
- road border nativo per lati ovest/est e variante ruotata per lati nord/sud.

### drowned_marsh

Stato 2026-07-08: pass completato. Lift caldo di path/road
(`SWAMP_ROUTE_LIFT*`) sopra la banda di luminanza del fango (prima route
54-58 vs fango 59-66), downscale `0.45` delle strip cliff + mipmap contro il
glitter dorato dei bordi chasm, `reed_wall` ridisegnata come canneto verticale
full-canvas (`preserveAspectRatio="none"` nel generator). Il
`road_border_defined` swamp usa core `__core_*` per strade piene e passage
`bridge`, e overlay `__edge_*` per bordi strada/prato e relative entry/exit di
perimetro; le lane restano `path_variation` generated. QA dedicata:
`tests/visual_qa/biome_art_drowned_marsh_visual_qa.gd`; guardrail
`_assert_marsh_routes_are_lifted` + contratto dimensioni cliff con downscale e
test asset su road border orientato.

Obiettivo: separare fango, acqua profonda, strada e vegetazione palude senza
trasformare il bioma in un pannello scuro uniforme.

Stato 2026-07-03: pass locale chiuso. `swamp` mantiene un materiale stabile per
ruolo sull'intera regione e usa direttamente path/road generated sui contatti, senza
texture di transizione intermedia. Il ground compone a runtime una quilt `2x2`
da quattro offset periodici dello stesso raster base, raccordati sulle cuciture
interne ed esterne con periodo world-space `1024`: i dettagli non si duplicano
piu ogni `512`, senza mirror o variazioni tonali. Path e road mantengono densita
e periodo `512`. Il pass oggetti normalizza inoltre `reed_wall`: il profilo SVG
usa l'intera canvas verticale `56x136` e il runtime lo rasterizza alla
dimensione nativa del contratto, senza cambiare footprint, collisione o
placement. La QA dedicata copre tre seed, due risoluzioni e sette viste,
incluso il focus `reed_wall`, con zero chunk mancanti. La componente Palude di
`VIS-009` e il polish sulla ripetizione ground sono chiusi.

File probabili:

- `game/modes/zombie/biome_generated_art_catalog.gd`
- generated art `swamp`
- `game/modes/zombie/isometric_tile_resolver.gd`
- asset/object visuals `reed_wall`, `sunken_house`, crate palude.

Finding da chiudere:

- bande verticali e materiali a pannelli;
- valori troppo scuri e vicini;
- acqua profonda e strada poco distinguibili;
- bordi `road_border_defined` non orientati sui lati nord/sud
  (**chiuso 2026-07-08**);
- `reed_wall` e oggetti palude con padding/scala incoerente (**chiuso per
  `reed_wall` il 2026-07-03**).

Pass locale:

- acqua profonda leggibile come hazard/ostacolo ambientale;
- road/path non confusi con fango;
- road border nativo per lati ovest/est e variante ruotata per lati nord/sud;
- vegetazione e oggetti non sembrano canvas vuoti o sottoscala.

## Template Di Handoff Per Ogni Agente

Usare questo blocco nel messaggio iniziale o nella PR del singolo bioma.

```text
Biome:
Goal:
Finding di partenza:
File/sistemi toccati:
Screenshot prima:
Fix applicati:
Screenshot dopo:
QA dedicata:
GUT:
Rischi residui:
Prossimo bioma consigliato:
```

## Residui e Riclassificazioni

- Pozze tossiche "troppo piccole" (scheda toxic_wastes): le pozze visibili
  nell'audit erano in realta' le resource crate tematiche. I theme hazard
  (`toxic_puddle`, `gas_cloud`, ecc.) non vengono piazzati dalla pipeline
  voidfirst del mondo streammato standard (`_add_theme_hazards` esiste solo
  nel path legacy): aggiungerli cambierebbe spawn e danni, quindi e' una
  decisione di gameplay da valutare nei playtest `BAL-001`, non un fix
  presentazionale.
- Pass trasversale edifici (VIS-005): i sette edifici generati e la base
  occupata sono normalizzati; le vere supply crate (64x48 world) erano gia'
  proporzionate al player e non sono state toccate.
- VIS-009 ridotto ma non chiuso: `reed_wall` e gli edifici sono normalizzati;
  restano `large_rock` (texture quadrata), `broken_fence` (sfocato) e la
  densita' fotografica di `forest_tree`, da valutare in un eventuale pass
  asset dedicato dentro `UIUX-001`.
- I seam tra biomi diversi ai confini di regione restano a taglio netto:
  sono un contratto del mondo (RegionSeamSystem), non un difetto del pass
  per-bioma.

## Definition Of Done

Un task bioma e completo quando:

- la QA dedicata del bioma passa;
- l'agente ha aperto e ispezionato le immagini finali;
- almeno il GUT vicino al sistema toccato passa;
- `biome_rendering_review_visual_qa.gd` passa se il fix tocca resolver,
  cataloghi, texture tools o manifest condivisi;
- `CHANGELOG.md` registra il fix;
- questo documento aggiorna lo stato del bioma se il pass e completo;
- `TODO.md` resta coerente con `ART-VIS-FIX` aperto o chiuso.
