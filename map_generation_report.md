# Report - Generazione mondo e piano di unificazione dei biomi

Data analisi: 2026-07-13. Implementazione core: 2026-07-13.

**Stato: `WORLD-UNIFY-001` completata per il contratto runtime core.** Il
documento conserva l'audit storico che ha motivato il lavoro, ma distingue
esplicitamente le lacune iniziali dall'esito implementato.

## Sintesi

La generazione e gia unificata a livello di orchestrazione e di layout:

```text
ZombieModeController
  -> BiomeManager
  -> BiomeWorldGenerator
  -> BiomeMapGenerator
  -> BiomeTerrainGenerator
  -> ObstacleLayoutGenerator.populate_layout_voidfirst()
```

`Zombie Survival` usa una megamappa `3x3`; `Infinite Arena` usa lo stesso
percorso in una cella `1x1`. La differenza corretta tra le due modalita e nel
perimetro e nello streaming, non nel contenuto interno.

Il report precedente del 2026-06-30 non descriveva piu il codice corrente:

- tutti i cinque biomi passano gia da `populate_layout_voidfirst()`;
- i chasm interni sono gia indipendenti da `arena_boundary_mode` e sono attivi
  anche nell'arena murata;
- rendering e gameplay dei cliff leggono gia lo stesso contratto
  `fall_zone_rects`.

L'audit iniziale aveva identificato quattro lacune nel contratto condiviso:

1. vere mesa scalabili in ogni bioma;
2. un pass di oggetti casuali pesato e data-driven;
3. ripristino degli hazard statici tematici esclusi dal percorso attivo;
4. garanzie e test non vacui per cliff, mesa, prop, determinismo e cache.

## Esito implementazione

Il core e ora attivo nello stesso `populate_layout_voidfirst()`:

- cinque `BiomeGenerationProfile` tipizzati configurano mesa, props, chasm e
  hazard senza spostare la responsabilita asset fuori dal manifest;
- ogni bioma genera almeno un chasm interno salvo `disable_internal_void`,
  mesa tematiche (10-16 nella Pianura, 2-4 negli altri) e 10-16 props pesati
  appartenenti ad almeno due categorie;
- Tossico, Infuocato, Neve e Palude generano due hazard statici tematici su
  terreno sicuro; la Pianura mantiene solo le fall zone;
- gli stream RNG `mesa`, `void`, `hazards` e `props` sono derivati
  separatamente dal seed;
- il rendering usa la stessa geometria mesa con profili `forest`,
  `urban_ruins`, `volcanic`, `frozen_tundra` e `swamp`;
- firma canonica `layout-v2`, revisione generatore/cache 2 e snapshot v5
  rifiutano layout obsoleti o alterati;
- i guardrail coprono cinque biomi, 20 seed per bioma, placement, pool,
  determinismo, snapshot e mesh/collisione delle mesa; il fallback prop viene
  inoltre provato senza rejection sampling.

Le tavole concept sono state promosse direttamente a sorgenti runtime senza
ricampionamento: 20 regioni `AtlasTexture` servono 23 ID. Restano fuori dalla
milestone core la valutazione qualitativa manuale, i 18 SVG non rappresentati
e la rimozione del percorso legacy. I playtest lunghi restano esplicitamente
in `BAL-001`.

## Ambito

La milestone riguarda `Infinite Arena` e `Zombie Survival`, che consumano lo
stesso mondo a biomi. Dungeon e Tower Defense restano generatori/modalita
separati e non vanno assorbiti automaticamente.

## Stato implementato per bioma

| Bioma | Cliff nel void | Mesa reale | Oggetti variabili | Hazard statici tematici |
| --- | --- | --- | --- | --- |
| Pianura Infetta | >=1 salvo opt-out | 10-16, profilo `forest` | 10-16 pesati, >=2 categorie | no, oltre alle fall zone |
| Tossico | >=1 salvo opt-out | 2-4, profilo `urban_ruins` | 10-16 pesati, >=2 categorie | 2: pozza tossica e gas |
| Infuocato | >=1 salvo opt-out | 2-4, profilo `volcanic` | 10-16 pesati, >=2 categorie | 2: fuoco e lava |
| Neve | >=1 salvo opt-out | 2-4, profilo `frozen_tundra` | 10-16 pesati, >=2 categorie | 2: ghiaccio e neve alta |
| Palude | >=1 salvo opt-out | 2-4, profilo `swamp` | 10-16 pesati, >=2 categorie | 2: acqua profonda e fango |

## Pipeline attiva

`BiomeTerrainGenerator.generate_layout_for_cell()` crea un
`BiomeEnvironmentLayout` e chiama sempre:

```text
_carve_passages
_place_mesas
_place_biome_masses
_place_forests
_add_voidfirst_roads
_choose_voidfirst_spawn
_add_voidfirst_paths
_clear_trees_on_routes
_add_connected_border_walls
_line_roads_with_trees
_resolve_void_lottery
_place_voidfirst_theme_hazards
_add_voidfirst_crates
_place_voidfirst_random_props
_update_generation_summary
```

La topologia, i passaggi e la classificazione completa vengono poi validati e
materializzati da `WorldRegionStreamer`, `BiomeTileLayer`, `ObstacleSystem`,
`HazardSystem` e `ResourceCrateSystem`.

Il vecchio `populate_layout()` e ancora nello stesso file come riferimento, ma
non e il percorso runtime. Le responsabilita richieste sono migrate nella
pipeline void-first; la sua rimozione e cleanup fuori dalla milestone core.

## Cliff nel void

### Cosa funziona

- `FallBoundaryGenerator` crea fall zone sui lati esterni `FALL`.
- `_resolve_void_lottery()` converte circa un quarto delle patch residue in
  chasm interni.
- `_internal_void_enabled()` dipende solo da `disable_internal_void`, non dal
  perimetro murato.
- `BiomeTileLayer` costruisce lip e pareti; `BiomeFallZone`/`HazardSystem`
  possiedono caduta, danno e recupero.
- I quattro biomi avanzati possiedono gia set cliff generati e tipizzati.

Va conservata la distinzione semantica:

- `fall_zone`: cliff verso il void, attraversabile solo dal roll valido e
  mortale al contatto;
- `raised_cliff`: parete/mesa solida, blocca movimento e proiettili e non
  applica caduta.

### Gap rilevato nell'audit (risolto)

Prima di `WORLD-UNIFY-001` la presenza di chasm non era un contratto
quantitativo robusto: l'Infinite Arena poteva accettarne zero e un controllo
generico poteva passare grazie al solo cliff perimetrale. Ora il profilo espone
`internal_chasm_min_count = 1`, `_resolve_void_lottery()` applica il minimo e
il fuzz verifica esplicitamente il chasm `internal` su 20 seed per bioma.

Contratto implementato:

- almeno un `internal` chasm per regione, salvo opt-out esplicito di test;
- distanza minima da spawn, passaggi, crate e mesa;
- limite alla frazione non calpestabile e connettivita sempre valida;
- perimetro governato separatamente da `arena_boundary_mode`.

## Mesa

L'audit aveva trovato la mesa vera soltanto nella Pianura Infetta:
`large_rock` era limitata al bioma forestale, `rock_rects` sovraccaricava anche
edifici/barriere e `BiomeTileLayer` costruiva il plateau solo con forest ground.

Il contratto implementato:

- introduce `mesa_rects` e `mesa_profile_ids` separati da
  `rock_rects`/`obstacle_rects`;
- garantisce un range configurabile di mesa in tutti i profili;
- usa il rettangolo come autorita per collisione, blocker e rendering;
- generalizza il builder a tutti i terreni tematici;
- usa il ruolo `ground` per la corona e `cliff_face` per le pareti dei temi
  `urban_ruins`, `volcanic`, `frozen_tundra` e `swamp`;
- lascia il nodo `large_rock` collision-only, evitando sprite/cap duplicati.

In questo modo le mesa possono avere identita coerenti senza duplicare il
renderer: cemento tossico, basalto, ghiaccio e pietra/torba della palude usano
lo stesso volume geometrico e materiali diversi.

## Oggetti casuali

Prima della milestone la pipeline attiva aveva soltanto due forme di
variabilita:

- `_scatter_biome_masses()` randomizza posizione e quantita, ma sceglie gli ID
  con `placed % scatter_ids.size()`;
- `_fill_forests_with_trees()` popola cluster con un solo ID per bioma, fino a
  limiti molto alti.

Il pass generale mancava: `_add_block_props()` esisteva solo nel percorso
legacy e il vecchio test accettava anche `block_rects` vuoto. Ora
`_place_voidfirst_random_props()` lavora sul pavimento finale e registra in
modo esplicito `random_prop_rects`/`random_prop_ids`.

Il pass implementato:

- sceglie da pool pesati del bioma;
- conserva ID e footprint del catalogo oggetti/manifest;
- piazza sul terreno finale, lontano da spawn, route, passaggi, void, mesa,
  hazard e crate;
- impone 10-16 elementi e almeno due categorie tematiche per regione;
- entra nella firma profonda e quindi nelle chiavi stabili di persistenza.

Pool iniziali implementati, tutti basati su ID esistenti:

| Bioma | Landmark/massa | Prop e cover |
| --- | --- | --- |
| Pianura | `ruined_house`, `abandoned_house` | `abandoned_car`, `broken_fence`, `wood_barrier`, `small_rock`, `fallen_log` |
| Tossico | `lab_block`, `lab_ruin` | `pipe_stack`, `chemical_barrel`, `toxic_barrel`, `industrial_fence`, `lab_wall`, `corroded_barrier` |
| Infuocato | `burned_house` | `burned_car`, `metal_wreck`, `charred_wall`, `ash_barrier`, `scorched_barricade` |
| Neve | `snow_cabin` | `ice_rock`, `ice_block`, `snow_wall`, `fallen_log` |
| Palude | `sunken_house` | `sunken_wreck`, `dead_tree`, `marsh_log`, `reed_wall`, `broken_walkway` |

## Hazard statici

L'audit aveva rilevato che `_add_theme_hazards()` era chiamato soltanto da
`populate_layout()` legacy e che il percorso unificato produceva normalmente
solo `fall_zone`. Ora `_place_voidfirst_theme_hazards()` gira dopo la
risoluzione del void e prima di crate/props. I quattro profili avanzati
specificano due ID con relative dimensioni; il placement esclude route,
passaggi, blocker, cliff lip e area protetta dello spawn. La valutazione
qualitativa del budget pericoloso resta nel playtest manuale `BAL-001`.

## Inventario grafico degli oggetti

Il manifest censisce 43 `object_scenes`: 23 usano risorse `AtlasTexture`, due
usano PNG (`forest_tree` e il materiale mesa di `large_rock`) e 18 conservano
SVG. I pool void-first usano gli stessi ID tecnici, quindi la promozione non ha
modificato scena, footprint, anchor, collisione o pesi di generazione.

Le cinque tavole `2x2` con alpha sotto
`assets/environment/isometric/concepts/` sono ora atlas runtime. Le risorse
`objects/generated_props/*.tres` espongono regioni strette con `filter_clip`;
tre coppie tossiche condividono consapevolmente la stessa grafica. Il motivo
palude in basso a destra alimenta soltanto `marsh_log`: `reed_wall` mantiene lo
SVG verticale per non deformare il footprint `1x3`.

Priorita artistica consigliata:

1. valutare manualmente scala, leggibilita e ripetizione dei 23 prop promossi;
2. rifinire, solo se la review lo richiede, i materiali mesa tematici che usano
   gia lo stesso volume della `large_rock`;
3. ampliare i pool con i prop esistenti non ancora usati dal void-first;
4. affrontare dopo hazard, casse, pickup e attori procedurali, che richiedono
   anche un contratto sprite dedicato.

Lo `status` di `large_rock` e dei 23 prop promossi e `final`; le nuove voci
registrano source `openai_image_generation`, licenza e attribution. I 18 SVG
residui conservano `base_complete` finche non esiste arte dedicata verificata.

## Dati e responsabilita

`BiomeDefinition` espone ora un `BiomeGenerationProfile` tipizzato per le
feature unificate. `_voidfirst_palette()` resta come compatibilita per le
regole consolidate di road/cluster e non e autorita sugli asset. Il manifest
resta autorita su path, footprint e rendering; non diventa un secondo
generatore.

Contratto implementato:

```text
BiomeDefinition
  -> BiomeGenerationProfile
       -> mesa rules
       -> weighted prop rules
       -> void rules
       -> hazard rules

manifest.json
  -> asset path, footprint, anchor, collision, blocking, source/licenza
```

Le cinque `Resource` vivono sotto
`game/procedural/world_generation/profiles/` e rendono il tuning delle feature
visibile nell'Inspector. `MesaPlacementPass`, `StaticHazardPlacementPass` e
`RandomPropPlacementPass` vivono sotto
`game/procedural/world_generation/passes/`; l'orchestratore conserva solo
l'ordine della pipeline e le API di compatibilita. Il fallback dei prop prova
ogni ID/footprint a ogni origine legale e puo restare sotto il minimo soltanto
quando non esiste piu spazio fisico valido.

Gli stream indipendenti `mesa`, `void`, `hazards` e `props` derivano da
`cell.seed`. Aggiungere o ritoccare un prop non sposta quindi mesa o cliff dello
stesso seed; l'eventuale separazione futura di road/cluster/crate e cleanup,
non requisito aperto della milestone core.

## Determinismo, snapshot e cache

L'audit iniziale aveva trovato firme basate soprattutto su topologia e conteggi,
incapaci di proteggere il contenuto profondo. La migrazione ha aggiunto la firma
canonica `layout-v2`, che normalizza e include:

- `road_cell_tags`, floor e chasm;
- mesa e relativi profili;
- ID/rect/rotazione degli ostacoli;
- hazard, crate e side dei bordi;
- contenuto della revisione generativa.

`BiomeCell` incorpora la firma profonda, `WorldDataCache.GENERATOR_REVISION`
vale ora 2 e `WorldSnapshotCodec.FORMAT_VERSION` vale 5. I test di round-trip
rifiutano sia snapshot della revisione precedente sia firme archiviate
manomesse.

## Piano di implementazione

### Fase 0 - Guardrail e baseline — completata

- Aggiunti seed sentinella per i cinque biomi e l'arena `1x1`.
- Aggiunto `unified_biome_features_test.gd` con feature non vuote.
- Rafforzati firma profonda e test determinismo.
- Portate la revisione generatore/cache a 2 e la snapshot a v5.

### Fase 1 - Profilo tipizzato e stream RNG — completata per il core

- Creati `BiomeGenerationProfile` e regole pesate in cinque `.tres`.
- Spostate nei profili le regole di mesa, prop, chasm e hazard; la palette
  consolidata road/cluster resta compatibilita interna.
- Separati gli stream RNG delle quattro feature casuali nuove.
- Dichiarata l'incompatibilita dell'output tramite revisione e formato.

### Fase 2 - Mesa condivise — completata

- Separati `mesa_rects`/`mesa_profile_ids` dalle masse generiche.
- Generalizzati `RectilinearRockAreaMeshBuilder`/`BiomeTileLayer` ai cinque
  temi.
- Garantite mesa per profilo senza bloccare hub, passaggi o pathfinding.
- Estratto `MesaPlacementPass` e aggiunto il test mesh/collisione.

### Fase 3 - Void e hazard — completata

- Reso il minimo chasm esplicito e garantito almeno un interno.
- Migrati gli hazard in `StaticHazardPlacementPass`, condiviso e data-driven.
- Validati placement sicuro e raggiungibilita con guardrail automatici; resta
  manuale il giudizio qualitativo sul budget di pericolo.

### Fase 4 - Random props — completata

- Aggiunto il placement dedicato sul terreno finale.
- Migrati i pool esistenti con min/max, weight e clearance.
- Resa esplicita l'appartenenza dei props nel layout senza duplicare la
  responsabilita degli oggetti runtime.
- Estratto `RandomPropPlacementPass`; rejection sampling e fallback scan
  esaustivo proteggono quote obbligatorie e almeno due categorie.

### Fase 5 - QA visuale e promozione asset completate

- Promosse le cinque tavole a sorgenti atlas runtime: 20 regioni alpha per 23
  ID, con footprint, pivot e fallback tecnici invariati.
- Estesi loader, asset check, suite e Visual QA alle risorse Texture2D `.tres`.
- Eseguita la board biomi su tre seed, cinque biomi e due risoluzioni con focus
  distinti `fall_cliff`, `mesa` e `random_props`: 210 catture, runner verde.

La promozione automatizzata e i focus QA sono completati; giudizio qualitativo
manuale e nuova arte per i 18 SVG residui richiedono un nuovo goal artistico o
il playtest `BAL-001` pertinente.

### Fase 6 - Cleanup — differita fuori dal core

- Rimuovere `populate_layout()` e helper legacy solo dopo parita e test verdi.
- Mantenere aggiornati contratti runtime e regole di gioco.
- Rilanciare soak/streaming e completare il playtest manuale in `BAL-001`.

Il percorso legacy resta intenzionalmente disponibile; la nuova firma e il
formato snapshot sono gia attivi. Nessun soak o playtest manuale viene chiuso
da questa milestone.

## Criteri di accettazione

Per ogni bioma e per entrambe le modalita che consumano il generatore:

- almeno un chasm interno con cliff verso il void;
- almeno una mesa esplicita, non simulata da edifici o barriere;
- numero di prop entro i limiti del profilo e almeno due categorie tematiche;
- hazard statici presenti solo dove previsti dal profilo;
- nessun overlap con spawn, route, passaggi, void, mesa, hazard o crate;
- spawn, crate e passaggi raggiungibili;
- stesso seed = stessi ID, rettangoli, rotazioni e ordine normalizzato;
- seed diverso = variazione effettiva di ogni feature casuale;
- unload/reload non duplica ne sposta oggetti;
- zero asset mancanti, placeholder o fallback generici impliciti;
- budget streaming e frame time di `BAL-001` invariati.

I criteri strutturali e deterministici sopra sono coperti dai guardrail
automatici della milestone. L'ultimo criterio prestazionale e il giudizio su
leggibilita/densita richiedono i playtest manuali ancora aperti in `BAL-001`;
non sono usati per dichiarare conclusi quei playtest.

## Matrice test

| Livello | Copertura | Stato milestone |
| --- | --- | --- |
| GUT world-gen | 5 biomi x seed sentinella: chasm, mesa, prop, hazard e validazione | verde |
| GUT determinismo | firma profonda identica per stesso seed e diversa per seed alternativo | verde |
| GUT placement | pool corretto, quote non vacue, zero overlap e terreno valido | verde |
| GUT modalita | Survival e Arena condividono il contenuto e differiscono per perimetro/runtime | verde |
| GUT asset | manifest, footprint, anchor e copertura degli ID generati | verde |
| GUT cache | round-trip v5, firma alterata e snapshot precedente rifiutati | verde |
| Fuzz | 20 seed x 5 biomi senza layout invalido | verde |
| Visual QA | 3 seed x 5 biomi x 2 risoluzioni, focus cliff/mesa/prop | runner verde; giudizio manuale residuo |
| Soak | attraversamento biomi, ritorno e streaming senza crescita o duplicati | resta in `BAL-001` |
| Manuale | collisione/Y-sort, leggibilita e densita non frustrante | resta in `BAL-001` |

Baseline storica verificata prima dell'implementazione:

```text
./tools/run_gut.ps1 -GutDir res://tests/suites/world_gen
48/48 test passati, 352 assert, exit code 0

./tools/run_gut.ps1 -GutDir res://tests/suites/assets
70/70 test passati, 9545 assert, exit code 0

godot --headless --path . --script res://tools/generate_isometric_environment_assets.gd -- --check
131 contratti verificati, exit code 0
```

Dopo l'implementazione, le suite mirate hanno incluso
`unified_biome_features_test.gd`, `layout_signature_snapshot_test.gd` e
`mesa_rendering_test.gd`: il primo esegue il fuzz richiesto su 20 seed per
ognuno dei cinque biomi e forza anche il fallback prop senza sampling; gli
altri proteggono firma/snapshot e geometria mesa.

Validazione finale del 2026-07-13:

```text
./tools/run_gut.ps1
275/275 test passati, 28.521 assert, exit code 0

godot_console --path . --rendering-method gl_compatibility --script res://tests/visual_qa/biome_rendering_review_visual_qa.gd
210 catture (3 seed x 5 biomi x 7 focus x 2 risoluzioni), exit code 0

godot --headless --path . --script res://tools/generate_isometric_environment_assets.gd -- --check
131 contratti verificati, exit code 0

godot --headless --path . --quit-after 5
scena principale avviata, exit code 0
```

## File principali coinvolti

- `game/procedural/world_generation/biome_terrain_generator.gd`
- `game/procedural/world_generation/obstacle_layout_generator.gd`
- `game/procedural/world_generation/profiles/biome_generation_profile.gd`
- `game/procedural/world_generation/profiles/*.tres`
- `game/procedural/world_generation/passes/*.gd`
- `game/procedural/world_generation/world_data_cache.gd`
- `game/procedural/world_generation/world_snapshot_codec.gd`
- `game/modes/zombie/biome_definition.gd`
- `game/modes/zombie/biome_environment_layout.gd`
- `game/modes/zombie/biome_tile_layer.gd`
- `game/modes/zombie/rocks/rectilinear_rock_area_mesh_builder.gd`
- `assets/environment/isometric/manifest.json`
- `tests/suites/world_gen/`, `environment/`, `obstacles/`, `assets/`, `modes/`
- `tests/suites/world_gen/unified_biome_features_test.gd`
- `tests/suites/world_gen/layout_signature_snapshot_test.gd`
- `tests/suites/obstacles/mesa_rendering_test.gd`
- `tests/visual_qa/biome_rendering_review_visual_qa.gd`
