# Biome ART-VIS-FIX Roadmap

Stato: completato 2026-07-03. Tutti e cinque i biomi hanno il pass applicato,
la QA dedicata verde e i guardrail GUT estesi; il review completo
`biome_rendering_review_visual_qa.gd` chiude con exit code `0`. Restano fuori
scope i residui documentati in fondo a questo file (sezione "Residui e
riclassificazioni").

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

Stato 2026-07-02: primo pass eseguito. Il runtime mantiene i tile ID
`grass_to_path`, `grass_to_road` e `path_to_road` come semantica del resolver,
ma non li renderizza piu con texture intermedie: il tile layer usa direttamente
`forest_path` o `forest_road` per ottenere tagli netti. Aggiunta QA dedicata in
`tests/visual_qa/biome_art_infected_plains_visual_qa.gd` e variazione
deterministica flip/tinta per `forest_tree`.

File probabili:

- `game/modes/zombie/isometric_tile_resolver.gd`
- `game/modes/zombie/biome_tile_layer.gd`
- `assets/environment/isometric/manifest.json`
- asset forestali sotto `assets/environment/isometric/`
- `docs/forest_isometric_texture_system.md`

Finding da chiudere:

- path e road con scalini o angoli netti;
- `path_to_road` percepito come fascia sovrapposta;
- ripetizione e scala di `forest_tree`;
- eventuali oggetti forestali con stile troppo diverso dagli attori.

Pass locale:

- transizioni terrain -> road/path basate su immagini orientabili con taglio
  netto;
- nessun tiling evidente in `forest_surface_generated_visual_qa.gd`;
- alberi meno ripetitivi o con variazione/padding sufficiente.

### toxic_wastes

Stato 2026-07-03: pass completato. Il ground pool usa solo la coppia coerente
di rubble (variation 02/03: lichene chiaro e ghiaia bruna passano a `detail`),
eliminando la scacchiera di pannelli per macro-cella. Le route dei temi
generati usano il taglio netto (transition tiles -> path/road). Gli edifici
generati sono stati ridisegnati nel pass trasversale (vedi "Residui e
riclassificazioni" per le pozze). QA dedicata:
`tests/visual_qa/biome_art_toxic_wastes_visual_qa.gd`; guardrail esteso in
`generated_texture_test.gd` (contratto pool ground).

Obiettivo: eliminare il look a blocchi grigi e rendere route, terreno e pozze
tossiche separabili senza aumentare saturazione in modo aggressivo.

Stato 2026-07-02: primo pass terreno/route eseguito. `urban_ruins` mantiene un
materiale stabile per ruolo su tutta la regione, normalizza i raster in atlas
specchiati 2x2 alla densita nativa e usa direttamente path/road sui contatti,
senza texture di transizione intermedia. La QA dedicata copre tre seed, due
risoluzioni e sei viste con zero chunk mancanti. Il bioma resta aperto per il
finding trasversale `VIS-005`: scala e stile di crate/oggetti.

File probabili:

- `game/modes/zombie/biome_generated_art_catalog.gd`
- `game/modes/zombie/generated_biome_texture_tools.gd`
- `game/modes/zombie/isometric_tile_resolver.gd`
- generated art `urban_ruins`

Finding da chiudere:

- rettangoli raster distinguibili;
- grigio uniforme tra strada e terreno;
- pozze verdi troppo piccole o isolate;
- crate/oggetti che sembrano overlay sopra fondale raster.

Pass locale:

- route riconoscibile per silhouette/materiale, non solo colore;
- nessun tile urban ruins con bordo o pannello chiaro;
- hazard tossici leggibili in co-op.

### burning_fields

Stato 2026-07-03: pass completato. Damping selettivo dei pixel brace del
ground (`VOLCANIC_EMBER_THRESHOLD`/`VOLCANIC_EMBER_DAMPING` in
`GeneratedBiomeTextureTools`), route a taglio netto dal fix condiviso, cliff
gia' trimmati/armonizzati e ora anche mipmappati. QA dedicata:
`tests/visual_qa/biome_art_burning_fields_visual_qa.gd`; guardrail
`_assert_volcanic_embers_are_damped` sulla coda calda.

Obiettivo: mantenere identita calda e pericolosa, ma ridurre rumore arancio e
competizione con hazard, telegraph e oggetti piccoli.

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

Pass locale:

- lava come accento o feature, non come ground dominante;
- telegraph e fire hazard leggibili sopra il terreno;
- path/road con taglio orientabile, non fascia sfumata.

### frozen_outskirts

Stato 2026-07-03: pass completato. Tono neutro anti-sovraesposizione sul manto
nevoso (`FROZEN_GROUND_TONE`), blend neve delle route ridotto a `0.10/0.12`
per separare sentieri e ghiaccio dalla neve, harmonize dei bordi contro la
griglia bianca da repeat. QA dedicata:
`tests/visual_qa/biome_art_frozen_outskirts_visual_qa.gd`; guardrail
`_assert_frozen_ground_is_toned_down` + seam score sui bordi.

Obiettivo: ridurre sovraesposizione e griglia bianca mantenendo neve, ghiaccio
e strada distinguibili.

File probabili:

- `game/modes/zombie/generated_biome_texture_tools.gd`
- generated art `frozen_tundra`
- `game/modes/zombie/isometric_tile_resolver.gd`
- palette `frozen_outskirts_palette.tres`

Finding da chiudere:

- road/ice/ground con griglia chiara regolare;
- cliff, ghiaccio e crate chiare senza separazione;
- passaggi neve troppo simili al ground pieno.

Pass locale:

- valori neve piu leggibili ma non sporchi;
- route e ghiaccio separati per shape/materiale;
- nessun bordo bianco nei tile ripetuti.

### drowned_marsh

Stato 2026-07-03: pass completato. Lift caldo di path/road
(`SWAMP_ROUTE_LIFT*`) sopra la banda di luminanza del fango (prima route
54-58 vs fango 59-66), downscale `0.45` delle strip cliff + mipmap contro il
glitter dorato dei bordi chasm, `reed_wall` ridisegnata come canneto verticale
full-canvas (`preserveAspectRatio="none"` nel generator). QA dedicata:
`tests/visual_qa/biome_art_drowned_marsh_visual_qa.gd`; guardrail
`_assert_marsh_routes_are_lifted` + contratto dimensioni cliff con downscale.

Obiettivo: separare fango, acqua profonda, strada e vegetazione palude senza
trasformare il bioma in un pannello scuro uniforme.

File probabili:

- `game/modes/zombie/biome_generated_art_catalog.gd`
- generated art `swamp`
- `game/modes/zombie/isometric_tile_resolver.gd`
- asset/object visuals `reed_wall`, `sunken_house`, crate palude.

Finding da chiudere:

- bande verticali e materiali a pannelli;
- valori troppo scuri e vicini;
- acqua profonda e strada poco distinguibili;
- `reed_wall` e oggetti palude con padding/scala incoerente.

Pass locale:

- acqua profonda leggibile come hazard/ostacolo ambientale;
- road/path non confusi con fango;
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
