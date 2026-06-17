# Isometric Generation Audit Roadmap

Data audit: 2026-06-17.

Scope: migrazione verso biomi, mappe, oggetti, bordi e navigazione
completamente pseudo-isometrici. Questo documento non implementa feature:
fotografa lo stato reale trovato nel codice e trasforma i gap in milestone
eseguibili.

## Stato attuale sintetico

### Sistemi gia presenti

- Generazione mondo seed-based:
  `game/procedural/world_generation/biome_world_generator.gd`,
  `biome_map_generator.gd`, `biome_terrain_generator.gd`,
  `world_generation_seed.gd`.
- Celle bioma `200x200`, grafo connesso e passaggi fisici:
  `biome_cell.gd`, `biome_passage.gd`, `biome_passage_generator.gd`,
  `game/world/world_graph.gd`, `world_region.gd`,
  `world_region_connection.gd`.
- Terrain e classificazione completa:
  `game/modes/zombie/biome_environment_layout.gd`,
  `game/procedural/world_generation/map_validation_system.gd`,
  `tests/isometric_biome_terrain_coverage_smoke_test.gd`.
- Rendering terrain pseudo-isometrico:
  `game/modes/zombie/terrain_generator.gd`,
  `biome_region_ground.gd`, `biome_terrain_patch.gd`,
  `game/main/isometric_playground.gd`.
- Oggetti e ostacoli:
  `game/procedural/world_generation/obstacle_layout_generator.gd`,
  `game/modes/zombie/obstacle_system.gd`,
  `biome_obstacle.gd`,
  `assets/environment/isometric/manifest.json`.
- Hazard, fall zone e recupero:
  `game/procedural/world_generation/fall_boundary_generator.gd`,
  `game/modes/zombie/hazard_system.gd`,
  `biome_fall_zone.gd`, `biome_hazard_zone.gd`.
- Transizioni e runtime mondo:
  `game/modes/zombie/biome_transition_system.gd`,
  `biome_transition_gate.gd`, `game/world/world_runtime.gd`,
  `persistent_world_state.gd`.
- Mappa territori esplorati:
  `game/ui/exploration_map_panel.gd`, `game/ui/hud_manager.gd`,
  `game/world/world_exploration_state.gd`.
- Debug/test:
  `game/procedural/world_generation/biome_map_debug_overlay.gd`,
  `tests/biome_world_generation_smoke_test.gd`,
  `tests/world_graph_connectivity_smoke_test.gd`,
  `tests/open_passage_transition_smoke_test.gd`,
  `tests/fall_boundary_visual_logic_smoke_test.gd`,
  `tests/region_streaming_smoke_test.gd`,
  `tests/isometric_environment_manifest_smoke_test.gd`.

### Cosa funziona

- La survival genera una mappa biomi `5x5` di default, con celle logiche
  `200x200`, seed locale per cella, start nella `Pianura Infetta` e grafo
  connesso tramite spanning tree piu edge extra.
- Ogni cella riceve layout generato con strade, corridoi, passaggi, ostacoli,
  casse, hazard e fall boundary.
- `MapValidationSystem` valida flood-fill, passaggi raggiungibili, casse
  raggiungibili, placement non sovrapposto, fall boundary e classificazione
  completa.
- `BiomeRegionGround` disegna una base pseudo-isometrica estesa su tutta la
  regione logica, separata dai patch decorativi.
- Gli ostacoli sono `StaticBody2D` su layer fisico `1`, entrano nei gruppi
  `environment_obstacles` e `spawn_blockers`, e partecipano a Y-sort nella scena
  principale.
- I lati senza regione adiacente diventano fall zone; i lati collegati hanno
  passaggi aperti; i lati adiacenti ma non collegati vengono bloccati.
- `WorldRuntime` mantiene stato esplorazione, active regions come dati caldi,
  ledger per casse aperte/ostacoli distrutti/encounter completati e save v6.
- L'HUD puo mostrare la mappa territori con unknown, discovered, visited,
  cleared e current.
- Il dodge/roll ha validazione traiettoria e puo attraversare piccoli gap/fall
  zone se la landing e valida; gli hazard ambientali restano bloccanti.

### Cosa e incompleto o ambiguo

- Il rendering non e ancora un tileset isometrico vero: `BiomeRegionGround`
  campiona il layout ogni 8 celle e disegna rombi procedurali; non esiste una
  `TileMap` isometrica o una pipeline tile asset-driven.
- Gli asset ambiente sono ancora procedurali. Il manifest dichiara
  `converted_procedural_isometric`, `procedural_isometric_placeholder`,
  `manifest_placeholder` o `existing_procedural_placeholder`, non asset finali.
- Gli ID generati da `ObstacleLayoutGenerator` sono censiti nel manifest v6
  con categoria esplicita (copertura introdotta in v3) e `object_visuals`
  dedicati (introdotti in v5, estesi in v6 per i border tematici). I mismatch
  rilevati nell'audit erano:
  `ash_barrier`, `broken_walkway`, `burned_car`, `charred_wall`, `dead_tree`,
  `ice_block`, `industrial_fence`, `lab_block`, `lab_wall`, `marsh_log`,
  `pipe_stack`, `snow_cabin`, `snow_wall`, `sunken_house`, `toxic_barrel`.
  Nessuno di questi ID generati usa piu il fallback barriera generico in modo
  implicito.
- I tag di strada/passaggio generati (`main_road`, `road`, `service_lane`,
  `ash_lane`, `packed_snow_path`, `wooden_walkway`, `broken_gate`,
  `burned_road`, `snow_pass`, `bridge`) sono censiti nel manifest corrente con draw
  mode procedurali dedicati. Resta da sostituire il rendering procedurale con
  tile/asset finali.
- `WorldRuntime` scalda come dati la regione corrente e i vicini, ma il gameplay
  istanzia solo la regione corrente; non esiste ancora una megamappa fisica
  continua con piu regioni renderizzate simultaneamente.
- `WorldRegion.world_origin` e `WorldRegionConnection.world_rect` esistono nei
  dati, ma il rendering della regione corrente resta centrato nello spazio
  locale del gameplay.
- `PlayerDodgeComponent` distingue le fall zone dagli hazard ambientali:
  `HazardSystem.is_position_fall_zone()` identifica i gap/cadute
  attraversabili solo se piccoli, mentre lava, gas, acqua profonda e altri
  hazard ambientali bloccano la traiettoria.
- I ledger `destroyed_obstacles` e `completed_encounters` sono persistiti ma non
  hanno ancora trigger gameplay reali.
- Il debug overlay non risulta integrato come UI operativa visibile nella scena;
  il sistema esiste come componente procedurale sotto `BiomeWorldGenerator`.
- La ricerca esplicita di `genomi`, `genome` e `genoma` trova solo
  `prompt.md`: nel codice il termine corretto e `biome`/`biomi`.

## Gap Analysis

### Terrain e tile isometrici

Stato: parziale.

Il terreno copre logicamente `200x200` e viene classificato. La resa visuale e
pseudo-isometrica, ma non usa tile asset-driven. `BiomeRegionGround` disegna
campioni romboidali con preset manifest (`balanced` resta ogni 8 celle) e
`BiomeTerrainPatch` aggiunge decorazioni procedurali. La vecchia
`IsometricPlayground` resta sotto, come arena base centrale, ma il ground
generato copre l'intero territorio attivo.

Gap principali:

- mancano tile asset/tilemap isometrici per terreno base, strade, ponti,
  passaggi, muri e cliff;
- i tag strada/passaggio generati hanno draw mode dedicati nel manifest corrente, ma
  non sono ancora tile asset-driven;
- la classificazione e completa, ma la granularita visuale e piu grossolana
  della griglia logica.

### Oggetti ambientali e props

Stato: parziale.

`ObstacleSystem` genera oggetti fisici, `ResourceCrateSystem` genera crate, e
`SpawnGateVisual`/`ExplosiveBarrel` coprono vecchi props arena. Gli oggetti
ambiente dei biomi sono ancora procedurali, ma gli ostacoli generati dalla
pipeline bioma hanno `draw_mode` dedicati nel manifest v6, inclusi i bordi
tematici, e non ricadono piu nel fallback barriera generico.

Gap principali:

- manifest, generatore e draw mode sono allineati sugli ID reali generati in
  Milestone 1 e 3;
- l'arte resta procedurale e non final asset-driven;
- crate resta un placeholder procedurale; `fall_zone` usa una visuale
  procedurale dedicata cliff/depth ma non ancora asset finale;
- props arena storici restano separati dalla pipeline bioma.

### Ostacoli e collisioni

Stato: funzionale, da rifinire.

Gli ostacoli sono `StaticBody2D`, bloccano movimento/spawn e hanno collisione
rettangolare o circolare. Il manifest contiene footprint e flag, ma il runtime
usa soprattutto `sort_offset` e `blocks_movement`; `collision_shape` e
`footprint_tiles` non guidano ancora direttamente la costruzione dello shape.

Gap principali:

- collisione e visuale condividono posizione/size ma non una silhouette
  isometrica asset-driven;
- `blocks_projectiles` e parte del manifest, ma gli ostacoli stanno su layer
  `1` e il contratto proiettili non risulta integrato al manifest;
- manca persistenza gameplay per ostacoli distrutti, anche se il ledger esiste.

### Biomi e generazione procedurale

Stato: robusto come dati, parziale come arte.

Cinque biomi sono definiti in `.tres`; la pipeline genera `5x5` celle e assegna
biomi per profondita/distanza. Il grafo e connesso e validato. Le wave leggono
il bioma corrente tramite `WaveDirector`.

Gap principali:

- il layout usa ancora pattern deterministici molto regolari;
- la differenziazione visiva si basa su palette, hazard e ostacoli generici;
- la partenza dalla `Pianura Infetta` e corretta, ma la distribuzione biomi su
  mappa resta semplice.

### Bordi, muri, vuoto e caduta

Stato: funzionale, visualmente parziale.

`FallBoundaryGenerator` crea rettangoli di fall zone sui lati esterni, mentre
`ObstacleLayoutGenerator` crea segmenti fisici sui bordi collegati o bloccati
usando l'ID border tematico del bioma (`boundary_fence`,
`toxic_boundary_wall`, `lava_boundary`, `ice_boundary`,
`deep_water_boundary`). `BiomeFallZone` ha visuale procedurale dedicata
cliff/depth con stile per bioma.

Gap principali:

- i bordi e il vuoto sono leggibili e tematici, ma restano procedurali;
- il vuoto non e ancora un sistema di cliff/depth asset-driven con layering
  definitivo;
- gli asset finali per muri, cliff e depth restano nello scope della Milestone
  10.

### Connessioni tra biomi

Stato: implementato come passaggi/gate, non come streaming fisico continuo.

`BiomePassageGenerator` produce passaggi condivisi e allineati. Il gate
runtime usa `target_region_id` e non teletrasporta il party se
`move_party_on_transition` resta `false`.

Gap principali:

- il gate e ancora un `Area2D` visuale, non una continuita fisica tra due
  regioni renderizzate nello stesso spazio;
- i passaggi non hanno asset dedicati salvo il placeholder `bridge_passage`;
- la posizione globale delle regioni non viene usata per renderizzare regioni
  adiacenti simultaneamente.

### Megamappa persistente

Stato: dati presenti, rendering/lifecycle limitato alla regione corrente.

`WorldGraph`, `WorldRuntime` e `PersistentWorldState` sono solidi come
contratto dati. `active_regions` tiene corrente e vicini come dati caldi, ma
solo la regione corrente e istanziata da terrain/obstacle/hazard/crate.

Gap principali:

- nessun renderer multi-regione;
- `party_position` e salvata ma non guida ancora un ripristino spaziale globale
  della run;
- `destroyed_obstacles` e `completed_encounters` restano ledger senza trigger.

### Mappa esplorata/UI

Stato: presente.

`ExplorationMapPanel` disegna una mappa isometrica stilizzata dei territori,
con fog e connessioni note. `HUDManager` la apre con `world_map`.

Gap principali:

- la mappa e informativa ma non mostra dettaglio interno della regione;
- non mostra ostacoli, hazard, crate o passaggi esatti;
- non visualizza active regions/streaming per debug.

### Asset e art direction

Stato: placeholder procedurale coerente, non final art.

`assets/environment/isometric/manifest.json` e una buona base di inventario:
copre ID, categorie, terrain e draw mode oggetti/terrain. Gli asset esterni non
sono obbligatori e l'attribution lo conferma.

Gap principali:

- nessuna libreria sprite/tileset ambiente definitiva;
- gli ID generati sono coperti dal manifest v6 e hanno visuale procedurale
  dedicata, inclusi i border tematici;
- l'identita dei biomi e ancora soprattutto palette + hazard, non asset.

### Debug tooling

Stato: parziale.

`BiomeMapDebugOverlay` espone dati del seed e puo rigenerare, ma non risulta
una UI di debug di gioco ricca per vedere classificazione, collisioni, passaggi,
active regions e ledger.

Gap principali:

- l'overlay debug riepiloga le classi terrain, ma manca ancora una vista
  world-space per layer terrain class;
- manca visualizzazione active regions/region id sul mondo;
- il report automatico manifest/generatore e coperto dallo smoke, mentre manca
  una vista debug in game per visualizzare mismatch visuali e classificazioni.

### Performance e compatibilita

Stato: accettabile per prototipo.

Il ground `200x200` campionato ogni 8 celle evita disegnare 40.000 tile visuali
per frame. I test headless coprono molti contratti.

Gap principali:

- un vero renderer multi-regione o tilemap dettagliata richiedera budget
  esplicito;
- Y-sort completo dei player rispetto all'ambiente e una scelta ancora non
  chiusa: oggi i player restano sopra per leggibilita co-op;
- QA visuale reale/screenshot resta rinviato al playtest.

## Lista dei punti persi per strada

| Punto | File coinvolti | Stato | Impatto | Dipendenze | Priorita |
| --- | --- | --- | --- | --- | --- |
| Manifest ambiente non copre tutti gli ID prodotti dal generatore (`pipe_stack`, `burned_car`, `ice_block`, `dead_tree`, `lab_block`, `snow_cabin`, ecc.) | `assets/environment/isometric/manifest.json`, `game/procedural/world_generation/obstacle_layout_generator.gd`, `game/modes/zombie/obstacle_system.gd` | risolto in Milestone 1 | ID/categoria chiusi; draw dedicati chiusi in Milestone 3 | Milestone 10 per asset finali opzionali | chiuso |
| `BiomeObstacle._draw()` non ha draw dedicato per diversi obstacle_id generati | `game/modes/zombie/biome_obstacle.gd`, `obstacle_layout_generator.gd` | risolto in Milestone 3 | resta il pass asset/tile finale | manifest v5 `object_visuals` | chiuso |
| Tag strada/passaggio generati finiscono nel fallback dirt | `game/modes/zombie/biome_terrain_patch.gd`, `obstacle_layout_generator.gd`, `biome_passage_generator.gd` | risolto in Milestone 2 | resta il pass asset/tile finale | Milestone 10 per sostituzione placeholder | chiuso |
| Nessun tileset/tilemap isometrico asset-driven | `terrain_generator.gd`, `biome_region_ground.gd`, `assets/environment/isometric/manifest.json` | mancante | il mondo resta procedurale e non final art | budget performance, pipeline tile/asset | P1 |
| Megamappa fisica non renderizzata in continuita globale | `world_runtime.gd`, `biome_manager.gd`, `terrain_generator.gd`, `biome_transition_system.gd` | parziale | attraversamento percepito come cambio regione locale, non mondo continuo | coordinate globali regioni, streaming visuale | P1 |
| `WorldRegion.world_origin` e `WorldRegionConnection.world_rect` non guidano il rendering runtime | `world_region.gd`, `world_region_connection.gd`, `terrain_generator.gd` | parziale | dati globali presenti ma non visibili nel mondo | renderer multi-regione o offset regione | P1 |
| Fall zone ancora placeholder procedurale | `biome_fall_zone.gd`, `manifest.json`, `fall_boundary_generator.gd` | risolto in Milestone 5 come visuale procedurale cliff/depth | resta il pass asset/tile finale | Milestone 10 per asset cliff/depth definitivi | chiuso |
| Muri/bordi collegati usano `boundary_fence` generico | `obstacle_layout_generator.gd`, `biome_obstacle.gd`, `manifest.json` | risolto in Milestone 5 | border tematici procedurali per bioma; resta asset finale | manifest v6 `object_visuals`, Milestone 10 | chiuso |
| Contratto dodge/gap usa hazard generico, non fall zone esplicita | `game/player/player_dodge_component.gd`, `hazard_system.gd` | risolto in Milestone 5 | fall zone separata dagli hazard ambientali | `is_position_fall_zone()` e smoke dodge/fall | chiuso |
| `blocks_projectiles` nel manifest non e applicato come contratto runtime evidente | `manifest.json`, `biome_obstacle.gd`, `projectile.gd`, `projectile_system.gd` | parziale | proiettili potrebbero non rispettare ostacoli come atteso dal manifest | collision layer/mask projectile, test | P1 |
| Ledger ostacoli distrutti ed encounter completati senza trigger gameplay | `persistent_world_state.gd`, `world_runtime.gd`, `obstacle_system.gd`, `random_encounter_system.gd` | parziale | persistenza pronta ma non percepita dal giocatore | ostacoli distruttibili/encounter region-bound | P2 |
| Mappa esplorata non mostra contenuto interno regione | `exploration_map_panel.gd`, `world_exploration_state.gd` | parziale | navigazione strategica limitata | dati POI/hazard/connection detail | P2 |
| Debug overlay non visualizza layer runtime completi in game | `biome_map_debug_overlay.gd`, `hud_manager.gd`, test debug | parziale | audit e QA visuale piu lenti | UI debug toggle, overlay classi terrain | P2 |
| Vecchio `IsometricPlayground` resta come arena centrale sotto il ground generato | `game/main/isometric_playground.gd`, `terrain_generator.gd`, `main.tscn` | parziale | possibile confusione visuale tra arena legacy e regione generata | decisione su deprecazione o integrazione | P2 |
| QA visuale screenshot dei biomi rinviato | `docs/testing/manual_checklist.md`, `tests/*visual_qa.gd` | mancante | non c'e prova visiva recente della coerenza isometrica | ambiente render non dummy, playtest | P2 |

## Roadmap organica in milestone

### Milestone 1 - Audit tecnico e pulizia nomenclatura

Stato: completata il 2026-06-17.

Esito:

- `assets/environment/isometric/manifest.json` e stato portato a v3 per coprire
  gli `obstacle_id` prodotti da `ObstacleLayoutGenerator` in una generazione
  `5x5`, inclusi gli ID specifici per bioma rilevati dall'audit. Il manifest e
  poi passato a v4 in Milestone 2 per i tag terrain.
- `ObstacleLayoutGenerator.GENERATED_OBSTACLE_CATEGORIES` espone il mapping
  `obstacle_id -> categoria` usato dallo smoke per controllare manifest e
  generatore.
- `tests/isometric_environment_manifest_smoke_test.gd` genera una mappa `5x5`,
  controlla ogni `layout.obstacle_id`, verifica il mapping di categoria e
  fallisce se un nuovo ID generato non e nel manifest.
- La ricerca `genomi`/`genome`/`genoma` resta documentata: fuori da
  `prompt.md` e da questa roadmap non esistono riferimenti nel codice operativo.
- Nessun sistema di gameplay, placement o collisione runtime e stato cambiato.

Obiettivo:
rendere verificabile l'inventario isometrico e allineare nomi tra generatori,
manifest, draw procedural e test.

Modifiche tecniche:

- Aggiungere uno smoke che genera una mappa e confronta tutti gli
  `layout.obstacle_ids` reali con il manifest.
- Aggiungere una tabella o costanti per mapping `obstacle_id -> categoria`.
- Allineare naming tra `ObstacleLayoutGenerator` e manifest, scegliendo se
  rinominare generatori o aggiungere alias nel manifest.
- Cercare e documentare termini ambigui: `genomi` non esiste nel codice,
  usare `biomi`/`biome`.

File probabili:

- `assets/environment/isometric/manifest.json`
- `game/procedural/world_generation/obstacle_layout_generator.gd`
- `game/modes/zombie/isometric_environment_manifest.gd`
- `tests/isometric_environment_manifest_smoke_test.gd`
- `docs/isometric_generation_audit_roadmap.md`

Criteri di accettazione:

- Ogni `obstacle_id` realmente prodotto da una generazione `5x5` e presente
  nel manifest oppure mappato a un alias documentato.
- Il test fallisce se un nuovo ID generato non ha manifest.
- Nessun cambio gameplay o collisione.

Test manuali:

- Revisione manifest vs output generato per seed fisso.
- Controllo di almeno un layout per bioma in debug.

Rischi:

- Rinominare ID gia usati da risorse `.tres` puo rompere compatibilita.
- Alias troppo permissivi possono nascondere asset mancanti.

Sotto-task completati:

1. [x] Generare lista obstacle_id da `BiomeManager.start_run()`.
2. [x] Estendere smoke manifest con ID generati, non solo
   `BiomeDefinition.obstacle_ids`.
3. [x] Decidere naming canonico per ogni mismatch: ID diretti nel manifest v3,
   nessun alias.
4. [x] Aggiornare manifest e generatori.
5. [x] Aggiornare report/documentazione.

### Milestone 2 - Base terrain isometrico 200x200

Stato: completata il 2026-06-17.

Esito:

- `assets/environment/isometric/manifest.json` e stato portato a v4 con sezione
  `terrain`: tag strada/passaggio generati, categoria, `draw_mode` e preset
  `sample_step` `performance`/`balanced`/`quality`.
- `BiomeTerrainPatch` usa draw mode dedicati per `main_road`, `road`,
  `broken_street`, `service_lane`, `ash_lane`, `packed_snow_path`,
  `wooden_walkway`, `bridge`, `snow_pass`, `broken_gate` e `burned_road`.
- `BiomeRegionGround.sample_step` e configurabile tramite preset manifest, con
  default `balanced = 8` equivalente al comportamento precedente.
- `BiomeMapDebugOverlay` espone conteggi aggregati per `walkable`, `obstacle`,
  `hazard`, `border`, `void` e `fall_zone`.
- `tests/isometric_biome_terrain_coverage_smoke_test.gd` verifica manifest,
  draw mode, preset, copertura tag generati e classificazione completa `200x200`.
- Nessuna collisione, classificazione, pathfinding, hazard o regola di gameplay
  e stata cambiata.

Obiettivo:
trasformare la copertura logica `200x200` in una base visuale piu coerente,
con mapping esplicito tra classi terrain e resa.

Modifiche tecniche:

- Introdurre un manifest terrain leggero o una sezione terrain nel manifest
  ambiente.
- Dare draw dedicato a `main_road`, `road`, `broken_street`, `service_lane`,
  `ash_lane`, `packed_snow_path`, `wooden_walkway`, `bridge`, `snow_pass`,
  `broken_gate`, `burned_road`.
- Rendere configurabile `sample_step` di `BiomeRegionGround` con preset
  performance/quality.
- Aggiungere overlay debug per `walkable`, `obstacle`, `hazard`, `border`,
  `void`, `fall_zone`.

File probabili:

- `game/modes/zombie/biome_region_ground.gd`
- `game/modes/zombie/biome_terrain_patch.gd`
- `game/modes/zombie/terrain_generator.gd`
- `assets/environment/isometric/manifest.json`
- `tests/isometric_biome_terrain_coverage_smoke_test.gd`

Criteri di accettazione:

- Tutti i tag terrain generati hanno resa dedicata o fallback documentato.
- La regione `200x200` resta completamente classificata.
- I passaggi sono leggibili come passaggi, non come dirt generico.

Test manuali:

- Avviare survival con seed fisso e verificare cinque biomi.
- Screenshot 1280x720 e 960x540 per terreno e passaggi.

Rischi:

- Aumentare dettaglio visuale puo impattare frame time.
- Troppi colori possono ridurre leggibilita degli attori.

Sotto-task completati:

1. [x] Inventariare `terrain_patch_tags` generati.
2. [x] Definire stile visuale per strade/passaggi.
3. [x] Aggiornare draw procedural.
4. [x] Aggiungere smoke sui tag coperti.
5. [x] Eseguire QA automatico headless; QA screenshot reale resta nel playtest.

### Milestone 3 - Oggetti e ostacoli isometrici

Stato: completata il 2026-06-17.

Esito:

- `assets/environment/isometric/manifest.json` e stato portato a v5 con
  `object_visuals`: ogni ostacolo generato ha `draw_mode` e
  `dedicated_draw` espliciti.
- `IsometricEnvironmentManifest` espone `get_object_draw_mode()`,
  `object_has_dedicated_draw()` e valida i draw mode oggetto.
- `BiomeObstacle` legge il draw mode dal manifest e aggiunge visuali
  procedurali dedicate per pipe stack, auto bruciate, blocchi di ghiaccio,
  alberi morti, blocchi laboratorio, cabine neve, case sommerse, barili tossici,
  muri/barriere tematiche, log e walkway.
- Collisioni, layer, gruppi `environment_obstacles`/`spawn_blockers` e sort
  offset restano invariati.
- `tests/isometric_environment_manifest_smoke_test.gd` verifica che nessun ID
  generato usi fallback generico implicito e che ogni ostacolo abbia il
  contratto ombra/base.
- `tests/biome_obstacle_generation_smoke_test.gd` verifica almeno due categorie
  di ostacolo per bioma e draw dedicati nei layout esistenti.

Obiettivo:
dare identita isometrica dedicata agli ostacoli di ogni bioma mantenendo
fallback procedurale.

Modifiche tecniche:

- Aggiungere draw dedicato o scene opzionali per gli ID generati che oggi
  restano procedurali/generici:
  `pipe_stack`, `burned_car`, `ice_block`, `dead_tree`, `lab_block`,
  `snow_cabin`, `sunken_house`, `toxic_barrel`, e gli altri ID specifici.
- Rifinire il manifest solo se draw/scene opzionali richiedono nuovi `status`
  o asset path; la copertura ID/categoria e gia chiusa in v3.
- Validare che ogni ostacolo grande abbia ombra e base coerente.

File probabili:

- `game/modes/zombie/biome_obstacle.gd`
- `game/modes/zombie/obstacle_system.gd`
- `assets/environment/isometric/manifest.json`
- `tests/isometric_environment_manifest_smoke_test.gd`
- `tests/biome_obstacle_generation_smoke_test.gd`

Criteri di accettazione:

- Nessun `obstacle_id` generato usa il fallback generico senza scelta esplicita.
- Ogni bioma mostra almeno due categorie di ostacolo distinguibili.
- Collisioni e spawn blocker restano invariati.

Test manuali:

- QA cinque biomi con seed fisso.
- Verifica player/zombie davanti e dietro ostacoli con Y-sort.

Rischi:

- Visual piu alto puo coprire player in co-op se lo z-order non e calibrato.
- Scene asset opzionali possono diventare dipendenze obbligatorie per errore.

Sotto-task completati:

1. [x] Usare manifest v3/v5 come base dati degli ID generati.
2. [x] Implementare draw per categorie mancanti.
3. [x] Estendere smoke su fallback vietato per ID canonici.
4. [x] Verificare sort offset per edifici e muri.
5. [x] Confermare che non arrivano asset non procedurali, quindi attribution
   invariata.

### Milestone 4 - Collisioni coerenti con props e strutture

Obiettivo:
far coincidere footprint visuale, collisione, spawn blocker e proiettili per
ostacoli e strutture.

Modifiche tecniche:

- Usare `collision_shape` e `footprint_tiles` del manifest nella costruzione
  runtime quando disponibili.
- Definire come `blocks_projectiles` si traduce in layer/mask.
- Aggiungere query dedicate per ostacoli jumpable/non jumpable.
- Preparare chiavi stabili per ostacoli distruttibili futuri.

File probabili:

- `game/modes/zombie/biome_obstacle.gd`
- `game/modes/zombie/obstacle_system.gd`
- `assets/environment/isometric/manifest.json`
- `game/projectiles/projectile.gd`
- `game/player/player_dodge_component.gd`
- `tests/biome_obstacle_generation_smoke_test.gd`

Criteri di accettazione:

- Collisione creata da manifest per almeno rectangle/circle/open.
- Spawn e crate validation usano la stessa footprint del player.
- Proiettili rispettano o ignorano ostacoli secondo flag documentati.

Test manuali:

- Sparare contro muri, case e ostacoli piccoli.
- Provare kiting attorno a edifici grandi e corridoi.

Rischi:

- Cambiare collision mask puo rompere combat esistente.
- Bloccare proiettili su troppi props puo alterare bilanciamento.

Sotto-task:

1. Documentare layer/mask attuali.
2. Applicare manifest alle collisioni.
3. Estendere smoke projectile vs obstacle.
4. Verificare player/zombie pathing.
5. Aggiornare ARCHITECTURE se cambia il contratto collisioni.

### Milestone 5 - Bordi del bioma, muri, vuoto e caduta

Stato: completata il 2026-06-17.

Esito:

- `ObstacleLayoutGenerator` usa border ID tematici per i lati collegati o
  bloccati: `boundary_fence`, `toxic_boundary_wall`, `lava_boundary`,
  `ice_boundary` e `deep_water_boundary`.
- `assets/environment/isometric/manifest.json` e stato portato a v6 con
  `object_visuals` e draw mode dedicati per i border tematici; `fall_zone` e
  marcata come visuale procedurale cliff/depth.
- `BiomeObstacle` disegna muri/bordi tematici per tossico, lava, ghiaccio e
  acqua profonda senza cambiare collisioni o spawn blocker.
- `BiomeFallZone` espone `fall_style` e disegna profondita/cliff procedurali
  con stile per bioma.
- `HazardSystem` separa `is_position_fall_zone()` e
  `is_position_environment_hazard()`, mantenendo `is_position_hazardous()` come
  query aggregata per spawn/sicurezza.
- `PlayerDodgeComponent` tratta solo le fall zone come gap attraversabili; gli
  hazard ambientali come lava, gas e acqua profonda bloccano traiettoria e
  landing.
- Smoke aggiornati: manifest v6, fall boundary visual logic, fall/hazard
  runtime e dodge/gap.

Obiettivo:
rendere i bordi del territorio leggibili e tematici, distinguendo bordo
bloccato, passaggio aperto e vuoto/caduta.

Modifiche tecniche:

- Aggiungere border asset/draw per bioma invece del solo `boundary_fence`.
- Dare visuale dedicata a cliff/fall zone e profondita.
- Separare query `is_position_fall_zone()` da hazard generico.
- Aggiornare dodge per riconoscere fall zone come gap e non ogni hazard.

File probabili:

- `game/procedural/world_generation/fall_boundary_generator.gd`
- `game/procedural/world_generation/obstacle_layout_generator.gd`
- `game/modes/zombie/biome_fall_zone.gd`
- `game/modes/zombie/hazard_system.gd`
- `game/player/player_dodge_component.gd`
- `tests/fall_boundary_visual_logic_smoke_test.gd`
- `tests/player_dodge_gap_smoke_test.gd`

Criteri di accettazione:

- Lato senza regione: fall zone visiva e dannosa.
- Lato con regione ma senza edge: muro/barriera fisica, non fall.
- Lato con edge: apertura visibile e attraversabile.
- Dodge attraversa piccoli gap/fall zone ma non lava/gas/acqua profonda salvo
  scelta esplicita.

Test manuali:

- Camminare su tutti e quattro i lati di regioni edge e interne.
- Provare caduta, recupero e roll su gap piccolo.

Rischi:

- Separare hazard/fall puo introdurre regressioni nello spawner.
- Confini troppo decorati possono nascondere passaggi.

Sotto-task completati:

1. [x] Aggiungere API hazard per fall zone.
2. [x] Aggiornare `PlayerDodgeComponent`.
3. [x] Aggiungere border draw per bioma.
4. [x] Estendere smoke fall/dodge.
5. [x] QA automatico headless su default; QA screenshot/high contrast resta nel
   playtest Milestone 11.

### Milestone 6 - Connessioni aperte tra biomi

Obiettivo:
rendere i passaggi tra regioni leggibili come aperture fisiche coerenti, non
solo gate trigger.

Modifiche tecniche:

- Aggiungere visuali per `road`, `bridge`, `snow_pass`, `broken_gate`,
  `burned_road`.
- Dimensionare `BiomeTransitionGate` dal `BiomePassage.width`.
- Mostrare target/direzione senza testo obbligatorio.
- Sincronizzare passaggio terrain, bordo e trigger.

File probabili:

- `game/procedural/world_generation/biome_passage_generator.gd`
- `game/modes/zombie/biome_transition_gate.gd`
- `game/modes/zombie/biome_transition_system.gd`
- `game/modes/zombie/biome_terrain_patch.gd`
- `tests/open_passage_transition_smoke_test.gd`

Criteri di accettazione:

- Ogni passaggio generato ha terreno visivo coerente e gate allineato.
- Il trigger non occupa aree chiuse da muro/fall zone.
- La transizione conserva la posizione del party entro il comportamento
  documentato.

Test manuali:

- Attraversare almeno otto regioni con seed fisso.
- Verificare passaggi nei quattro lati.

Rischi:

- Gate troppo grandi possono attivare transizioni involontarie.
- Gate troppo piccoli possono sembrare bug di collisione.

Sotto-task:

1. Legare gate size a passage width.
2. Aggiungere draw per passage type.
3. Testare lato nord/sud/est/ovest.
4. Aggiornare smoke su allineamento gate/passage.
5. Documentare il comportamento no-teleport.

### Milestone 7 - Grafo biomi completamente connesso

Obiettivo:
rafforzare la garanzia di grafo connesso e renderla leggibile nel debug e nella
mappa.

Modifiche tecniche:

- Esporre report di connessione e unreachable nel debug overlay/HUD debug.
- Verificare edge extra e loop su set di seed.
- Mostrare region id, biome id e active regions in overlay.

File probabili:

- `game/procedural/world_generation/biome_map_generator.gd`
- `game/world/world_graph.gd`
- `game/procedural/world_generation/biome_map_debug_overlay.gd`
- `game/ui/exploration_map_panel.gd`
- `tests/world_graph_connectivity_smoke_test.gd`

Criteri di accettazione:

- 100 seed generano grafi connessi.
- Debug mostra corrente, vicini, edge e regioni non caricate.
- La mappa esplorazione non rivela regioni unknown fuori regola.

Test manuali:

- Aprire mappa dopo piu transizioni.
- Confrontare debug overlay e mappa HUD.

Rischi:

- Debug troppo invasivo puo interferire con UI gameplay.

Sotto-task:

1. Aggiungere test multi-seed.
2. Estendere debug overlay.
3. Integrare toggle debug non invasivo.
4. QA mappa con fog.
5. Aggiornare documentazione debug.

### Milestone 8 - Megamappa persistente

Obiettivo:
decidere e implementare il prossimo passo tra "dati persistenti a regione
corrente" e "continuita fisica multi-regione".

Modifiche tecniche:

- Formalizzare se il progetto vuole renderer multi-regione o cambio regione
  locale.
- Se multi-regione: usare `world_origin` per istanziare current + vicini con
  offset, scaricando lontani.
- Se cambio locale: rinominare/documentare meglio il contratto per evitare
  ambiguita.
- Collegare `party_position` a save/restore se resta nel contratto.

File probabili:

- `game/world/world_runtime.gd`
- `game/world/persistent_world_state.gd`
- `game/modes/zombie/terrain_generator.gd`
- `game/modes/zombie/zombie_mode_controller.gd`
- `game/modes/zombie/biome_manager.gd`
- `tests/region_streaming_smoke_test.gd`

Criteri di accettazione:

- Contratto scelto documentato in `ARCHITECTURE.md`.
- Se multi-regione: corrente e vicini possono essere istanziati senza duplicare
  casse/hazard e senza spawn in regioni lontane.
- Se locale: UI/test non promettono continuita fisica globale non presente.

Test manuali:

- Attraversamento otto regioni con ritorno a regione precedente.
- Verifica crate aperte persistenti.

Rischi:

- Multi-regione aumenta complessita di camera, spawn, cleanup e performance.
- Cambiare contratto puo invalidare smoke esistenti.

Sotto-task:

1. Decisione architetturale esplicita.
2. Aggiornamento documento contratti.
3. Prototipo minimo o rinomina/documentazione.
4. Smoke streaming aggiornato.
5. QA performance.

### Milestone 9 - Mappa territori esplorati

Obiettivo:
rendere la mappa coerente con il contratto di navigazione scelto e piu utile
per l'orientamento.

Modifiche tecniche:

- Mostrare direzioni/passaggi noti per regione visibile.
- Aggiungere marker per active region, corrente e regioni caricate come dati.
- Opzionale: mostrare POI astratti, non tile interni completi.
- Aggiungere high contrast/reduced motion checks.

File probabili:

- `game/ui/exploration_map_panel.gd`
- `game/ui/hud_manager.gd`
- `game/world/world_exploration_state.gd`
- `game/world/world_runtime.gd`
- `tests/exploration_map_smoke_test.gd`

Criteri di accettazione:

- Unknown non rivela topologia completa.
- Current e discovered sono leggibili a 960x540.
- I passaggi noti corrispondono al grafo.

Test manuali:

- Aprire/chiudere mappa durante survival.
- Verificare controller Back/Select e tastiera `M`.

Rischi:

- Troppi dettagli possono coprire HUD o rompere leggibilita couch.

Sotto-task:

1. Estendere dati visualizzati.
2. Aggiornare smoke.
3. QA tre risoluzioni.
4. Verificare high contrast.
5. Aggiornare checklist manuale.

### Milestone 10 - Polish grafico e sostituzione placeholder

Obiettivo:
sostituire gradualmente placeholder procedurali con asset o scene dedicate,
mantenendo fallback e nessun asset esterno obbligatorio.

Modifiche tecniche:

- Definire pipeline asset environment: naming, licenze, import, fallback.
- Sostituire uno o due biomi pilota con asset completi prima di scalare.
- Aggiornare manifest status (`final`, `base_complete`, `procedural_fallback`).
- Aggiornare `assets/ATTRIBUTION.md`.

File probabili:

- `assets/environment/isometric/manifest.json`
- `assets/ATTRIBUTION.md`
- `assets/README.md`
- `game/modes/zombie/biome_obstacle.gd`
- `game/modes/zombie/terrain_generator.gd`

Criteri di accettazione:

- Asset mancanti non rompono il bootstrap.
- Ogni asset ha attribution.
- Almeno un bioma ha set visuale coerente oltre il fallback.

Test manuali:

- QA visuale cinque biomi.
- Verifica fallback rimuovendo temporaneamente asset opzionale.

Rischi:

- Asset pesanti possono rallentare import e build.
- Stili diversi possono rompere coerenza visiva.

Sotto-task:

1. Scegliere bioma pilota.
2. Definire stati manifest.
3. Inserire asset opzionali.
4. Aggiornare attribution.
5. QA visuale e smoke fallback.

### Milestone 11 - Test, debug overlay e regressioni

Obiettivo:
chiudere la migrazione isometrica con test automatici, checklist manuale e
debug tooling adatto ai goal futuri.

Modifiche tecniche:

- Aggiungere smoke multi-seed per manifest/generatore/terrain/grafo.
- Aggiungere overlay per terrain class, collisioni, hazard, fall, passaggi e
  active regions.
- Aggiornare checklist manuale con screenshot richiesti.
- Eseguire suite smoke prioritaria e survival 10 wave.

File probabili:

- `tests/`
- `game/procedural/world_generation/biome_map_debug_overlay.gd`
- `game/ui/hud_manager.gd`
- `docs/testing/manual_checklist.md`
- `docs/latest_commit_validation_report.md`

Criteri di accettazione:

- Tutte le regressioni isometriche principali hanno test o checklist.
- Debug overlay mostra mismatch visuali/classificazioni senza modificare
  gameplay.
- Suite mirata passa con exit code `0`.

Test manuali:

- QA cinque biomi, passaggi, fall zone, mappa, dodge/gap.
- Screenshot 1280x720, 1024x768, 960x540.

Rischi:

- Test visuali headless non sostituiscono QA reale.
- Overlay debug puo dipendere da nodi runtime non sempre presenti.

Sotto-task:

1. Inventariare test esistenti.
2. Aggiungere test mancanti.
3. Creare overlay debug.
4. Aggiornare checklist/report.
5. Eseguire regressione mirata.

## Prompt iterativo per continuare la roadmap

Usare questo prompt una milestone alla volta:

```text
Esegui la prossima milestone non completata di docs/isometric_generation_audit_roadmap.md. Prima leggi AGENTS.md, README.md, ROADMAP.md, TODO.md, ARCHITECTURE.md, GAME_DESIGN.md e la roadmap isometrica. Lavora solo su quella milestone, mantieni modifiche piccole e verificabili, aggiorna CHANGELOG.md/TODO.md e gli altri documenti solo se cambiano contratti o backlog, poi esegui gli smoke test indicati o documenta perche non sono eseguibili. Non iniziare milestone successive.
```

Per partire dalla prima milestone:

```text
Esegui Milestone 1 di docs/isometric_generation_audit_roadmap.md: audit tecnico e pulizia nomenclatura della migrazione isometrica. Allinea manifest, generatori, test e documentazione senza cambiare gameplay.
```
