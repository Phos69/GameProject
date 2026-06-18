# Roadmap Milestone 10 — Riscrittura totale asset e continuità isometrica

Data analisi: 2026-06-17  
Repo analizzata: `Phos69/GameProject`  
Roadmap sorgente: `docs/isometric_generation_audit_roadmap.md`  
Scope: eseguire la **Milestone 10 - Polish grafico e sostituzione placeholder** trasformandola in una roadmap operativa divisa in sotto-milestone.

---

## 0. Stato attuale rilevato

### Già presente

- Pipeline biomi seed-based con celle logiche `200x200`, grafo connesso, passaggi fisici e layout validato.
- Manifest ambiente `assets/environment/isometric/manifest.json` v6 con inventario di terrain tag, obstacle ID, draw mode, collision shape, footprint, blocking flags e sort offset.
- Rendering pseudo-isometrico già coerente ma ancora procedurale:
  - `BiomeRegionGround` disegna rombi campionati, non tile asset-driven.
  - `BiomeTerrainPatch` disegna strade/passaggi procedurali.
  - `BiomeObstacle` disegna ostacoli con `_draw()` procedurale.
  - `BiomeFallZone` disegna cliff/depth procedurale.
- `MultiRegionRenderer` esiste, ma i vicini sono solo ground visuale: gameplay, ostacoli, hazard, crate e spawn restano della sola regione corrente.
- `BiomeTransitionGate` è ancora un `Area2D`/gate di transizione, anche se non teletrasporta il party quando `move_party_on_transition = false`.

### Problemi da chiudere in Milestone 10

- Non esiste ancora un vero tileset isometrico asset-driven.
- Gli asset ambiente sono ancora “procedural/generated/placeholder”, non finali.
- Gli oggetti non sono scene/sprite asset-driven che occupano in modo immediatamente leggibile uno slot isometrico.
- Il vuoto/fall zone è leggibile ma resta procedurale; manca un linguaggio grafico forte con bordo calpestabile, cliff verticale e linee di profondità.
- La megamappa è solo parzialmente continua: i vicini sono sfondo, non regioni gameplay vive.
- I passaggi tra biomi sono ancora gestiti da gate/trigger; la transizione deve diventare continuità world-space senza portali e senza caricamento percepibile.
- Gli zombie devono poter inseguire il player oltre il confine, attraversando il varco tra biomi senza despawn, reset o cambio scena.

---

## 1. Obiettivo finale della Milestone 10

Rendere il mondo survival una megamappa isometrica continua e coerente, con asset ambientali definitivi o comunque asset-driven, eliminando la dipendenza dai placeholder procedurali e dai portali trigger.

Alla fine della milestone:

- ogni bioma ha tile base e varianti persistenti su tutta la griglia `200x200`;
- strade, passaggi, ponti, bordi, muri e cliff sono asset-driven;
- ostacoli, case, barriere, relitti, tronchi, barili e props occupano chiaramente slot isometrici;
- il vuoto è inequivocabile, con bordo calpestabile, cliff verticale e linee di profondità discendenti;
- i passaggi tra biomi sono aperture fisiche dentro una megamappa world-space;
- non esistono più portali/gate/trigger visibili o necessari per cambiare bioma;
- gli zombie continuano il chase attraverso i passaggi tra regioni;
- fallback e bootstrap restano sicuri, ma nessun asset generato principale deve dipendere dal vecchio draw procedurale.

---

# Milestone 10.1 — Contratto asset v7 e inventario finale

Stato: completata il 2026-06-18.

Esito:

- `manifest.json` portato a `version: 7` con sezioni `tile_sets`,
  `tile_variants`, `terrain_tiles`, `edge_tiles`, `void_tiles`,
  `object_scenes`, `passage_tiles`, `biome_asset_sets` e `fallback_policy`.
- `IsometricEnvironmentManifest` espone e valida contratti asset normalizzati
  con fallback esplicito, senza richiedere file esterni per il bootstrap.
- Aggiunto `tests/milestone_10_asset_manifest_v7_smoke_test.gd` per copertura
  v7, generazione `5x5` e asset opzionale mancante dichiarato `needs_asset`.

## Obiettivo

Trasformare il manifest isometrico da inventario di draw procedurali a contratto asset-driven.

## Modifiche tecniche

- Portare `assets/environment/isometric/manifest.json` a `version: 7`.
- Aggiungere sezioni esplicite:
  - `tile_sets`
  - `tile_variants`
  - `terrain_tiles`
  - `edge_tiles`
  - `void_tiles`
  - `object_scenes`
  - `passage_tiles`
  - `biome_asset_sets`
  - `fallback_policy`
- Per ogni asset dichiarare:
  - `asset_path`
  - `status`: `final`, `base_complete`, `needs_polish`, `procedural_fallback`, `deprecated`
  - `biome_ids`
  - `footprint_tiles`
  - `anchor`: `center`, `bottom_center`, `iso_floor_center`, `edge_aligned`
  - `sort_offset`
  - `collision_shape`
  - `blocks_movement`
  - `blocks_projectiles`
  - `source` / `license` / `attribution_key`
- Aggiungere una regola dura: gli ID principali generati da `ObstacleLayoutGenerator`, `BiomeTerrainGenerator`, `BiomePassageGenerator` e `FallBoundaryGenerator` devono avere un asset path finale o un fallback esplicito e tracciato.
- Separare chiaramente fallback tecnico da asset finale: il fallback può esistere, ma non deve essere il percorso normale.

## File probabili

- `assets/environment/isometric/manifest.json`
- `game/modes/zombie/isometric_environment_manifest.gd`
- `assets/README.md`
- `assets/ATTRIBUTION.md`
- `tests/isometric_environment_manifest_smoke_test.gd`
- nuovo `tests/milestone_10_asset_manifest_v7_smoke_test.gd`

## Criteri di accettazione

- Il manifest v7 valida tutte le sezioni nuove.
- Ogni terrain tag, object ID, border ID, passage type e fall zone ha un contratto asset-driven.
- Lo smoke fallisce se un ID generato usa ancora un fallback implicito.
- Gli asset mancanti non rompono il boot, ma vengono segnalati come `procedural_fallback` o `needs_asset`.

## Test

- Smoke manifest v7.
- Smoke generazione `5x5` seed fisso: nessun ID senza contratto.
- Test negativo: rimuovere temporaneamente un asset opzionale e verificare fallback controllato.

---

# Milestone 10.2 — Pipeline asset locale e struttura cartelle

Stato: completata il 2026-06-18.

Esito:

- Creata la struttura `assets/environment/isometric/` per tile, oggetti, edge,
  passaggi e preview.
- Aggiunto `tools/generate_isometric_environment_assets.gd` con `--dry-run`,
  `--write`, `--check`, `--overwrite-generated` e guardia sugli asset `final`.
- Generati 74 SVG testuali interni con metadata `data-generated-by`,
  `data-section` e `data-id`; i contratti v7 passano a `base_complete`.
- Aggiunto `tests/milestone_10_asset_pipeline_smoke_test.gd` per allineamento
  manifest/file system, naming e attribution.

## Obiettivo

Creare una pipeline asset stabile, semplice da iterare con Codex, senza dipendere da asset esterni obbligatori.

## Modifiche tecniche

- Creare struttura:

```text
assets/environment/isometric/
  tiles/
    plains/
    toxic/
    ash/
    snow/
    marsh/
    shared/
  objects/
    buildings/
    barriers/
    rocks/
    trees/
    wrecks/
    barrels/
    bridges/
  edges/
    cliffs/
    walls/
    void/
  passages/
  previews/
  manifest.json
```

- Decidere formato iniziale consigliato:
  - preferenza: SVG/Texture generate in-repo, leggere e versionabili;
  - per Godot: import come `Texture2D` o scene `PackedScene` con `Sprite2D`/`Polygon2D`;
  - evitare per ora dipendenze binarie pesanti o asset pack esterni.
- Introdurre un piccolo tool di generazione placeholder asset-driven:
  - genera SVG coerenti e non più `_draw()` runtime;
  - crea anteprime per manifest;
  - può essere rilanciato senza sovrascrivere asset marcati `final`.
- Aggiornare attribution:
  - asset creati internamente: `internal_generated`;
  - asset esterni: fonte, licenza, autore, URL, eventuale modifica.

## File probabili

- `assets/environment/isometric/**`
- `tools/generate_isometric_environment_assets.gd` oppure `tools/generate_isometric_environment_assets.py`
- `assets/ATTRIBUTION.md`
- `assets/README.md`
- `project.godot` se servono import preset

## Criteri di accettazione

- La cartella asset esiste ed è documentata.
- Ogni asset ha naming stabile: `{biome}_{category}_{id}_{variant}.svg/png/tscn`.
- Nessun asset generato sovrascrive un asset `final`.
- `assets/README.md` spiega come aggiungere nuovi tile/oggetti.

## Test

- Script dry-run.
- Verifica che manifest e file system siano allineati.
- Verifica attribution completa.

---

# Milestone 10.3 — Tile base isometrici persistenti per tutto il bioma

Stato: completata il 2026-06-18.

## Obiettivo

Sostituire il ground procedurale campionato con tile base o varianti persistenti su tutta la regione `200x200`.

## Modifiche tecniche

- Introdurre un renderer asset-driven, ad esempio:
  - `BiomeTileLayer`
  - `ChunkedIsometricTileRenderer`
  - oppure `BiomeRegionGround` rifattorizzato in modalità asset.
- Dividere il `200x200` in chunk, per esempio `16x16` o `20x20`, per evitare 40.000 nodi singoli sempre attivi.
- Ogni cella logica deve risolvere un tile deterministico:
  - `floor_base`
  - `floor_variant_01/02/03`
  - `road`
  - `hazard_floor`
  - `border_floor`
  - `void_edge_near`
  - `void_depth`
- La variante deve essere persistente e derivata da seed + cella + biome, non random a ogni redraw.
- Tenere un preset qualità:
  - `performance`: chunk più grossi o varianti ridotte;
  - `balanced`: default;
  - `quality`: più varianti e dettagli.
- Il vecchio `BiomeRegionGround._draw_sample_tile()` rimane solo fallback tecnico, non percorso principale.

## File probabili

- `game/modes/zombie/biome_region_ground.gd`
- nuovo `game/modes/zombie/biome_tile_layer.gd`
- nuovo `game/modes/zombie/isometric_tile_resolver.gd`
- `game/modes/zombie/terrain_generator.gd`
- `assets/environment/isometric/manifest.json`
- `tests/isometric_biome_terrain_coverage_smoke_test.gd`
- nuovo `tests/milestone_10_tile_layer_smoke_test.gd`

## Criteri di accettazione

- Tutto il `200x200` ha tile base visivo, non solo il centro.
- Le varianti tile sono stabili per seed.
- Ogni bioma ha palette e tile riconoscibili.
- Le strade/passaggi non sembrano più patch ovali sopra il terreno, ma parti del tile layer.
- Il frame time resta accettabile grazie a chunk/caching.

## Test

- Smoke: per seed fisso, la stessa cella produce sempre lo stesso tile variant.
- Smoke: nessuna cella walkable senza tile risolto.
- Manuale: screenshot cinque biomi a 1280x720 e 960x540.

## Esito implementato

- `IsometricTileResolver` risolve tile base, varianti, road, hazard, border,
  `void_edge_near` e `void_depth` per ogni cella logica `200x200`.
- `BiomeTileLayer` e il ground primario del bioma attivo: cache 40.000 celle,
  chunk `20x20` in preset balanced, `25x25` performance e `16x16` quality.
- `TerrainGenerator` non genera piu `BiomeTerrainPatch` quando il tile layer
  asset e attivo; `BiomeRegionGround` resta fallback tecnico controllato.
- Aggiunto `void_edge_near` al manifest v7 e generato il relativo SVG.
- Smoke: `tests/milestone_10_tile_layer_smoke_test.gd`; checklist manuale
  aggiornata per screenshot cinque biomi alle due risoluzioni richieste.

---

# Milestone 10.4 — Strade, ponti e passaggi come tile asset-driven

## Obiettivo

Rendere strade e passaggi parte fisica e visiva della mappa, non patch decorative e non gate.

## Modifiche tecniche

- Convertire i terrain tag già censiti in asset tile:
  - `main_road`
  - `road`
  - `service_lane`
  - `ash_lane`
  - `packed_snow_path`
  - `wooden_walkway`
  - `bridge`
  - `snow_pass`
  - `broken_gate`
  - `burned_road`
- Aggiungere tile di raccordo:
  - curva nord/est/sud/ovest;
  - incrocio;
  - bordo strada;
  - ingresso/uscita passaggio;
  - ponte spezzato;
  - rampa su cliff.
- Il `BiomePassageGenerator` deve produrre dati sufficienti per scegliere asset di bordo e raccordo.
- Il passaggio tra biomi deve avere continuità visiva tra due regioni adiacenti, usando coordinate globali e non posizione locale centrata.

## File probabili

- `game/procedural/world_generation/biome_passage_generator.gd`
- `game/procedural/world_generation/obstacle_layout_generator.gd`
- `game/modes/zombie/biome_terrain_patch.gd`
- `game/modes/zombie/biome_region_ground.gd`
- `assets/environment/isometric/manifest.json`
- nuovo `tests/milestone_10_passage_tile_smoke_test.gd`

## Criteri di accettazione

- Ogni `passage_type` ha tile dedicati.
- Le aperture ai bordi sono leggibili senza frecce o testo.
- Il tile del passaggio è allineato al varco e ai muri/cliff laterali.
- Nessun passaggio usa più `BiomeTransitionGate._draw()` per comunicare direzione.

## Test

- Smoke: passaggi sui quattro lati con span coerente.
- Smoke: nessun tile passaggio sovrapposto a fall zone o muro.
- Manuale: attraversare almeno otto confini con seed fisso.

## Esito implementato

- Il manifest v7 contiene contratti asset per terrain route, curve
  nord/est/sud/ovest, intersezioni, road edge, entry/exit di ogni
  `passage_type`, `bridge_broken` e `cliff_ramp`; il generator controlla 93 SVG.
- `IsometricTileResolver` emette route tile specifici, entry/exit sui varchi di
  bordo e connector `passage_tiles` con priorita sulle road decorative
  sovrapposte.
- `BiomePassage` e `WorldRegionConnection` conservano rettangoli local/global,
  connector source/target e tile entry/exit per garantire continuita visuale
  tra regioni adiacenti.
- `BiomeTransitionGate._draw()` non comunica piu direzione o apertura: resta
  solo debug opzionale con `show_debug_visual`.
- Smoke: `tests/milestone_10_passage_tile_smoke_test.gd`; checklist manuale
  aggiornata per traversare almeno otto confini con seed fisso.

---

# Milestone 10.5 — Oggetti e ostacoli come scene isometriche slot-based

Stato: completata il 2026-06-18.

Esito:

- Aggiunti `isometric_environment_object.tscn` e
  `isometric_environment_object.gd`: scena `StaticBody2D` slot-based con
  `Sprite2D`, ombra, anchor, sort, collisione da manifest, footprint debug
  opzionale e hook per overlay danneggiato futuro.
- `ObstacleSystem` usa `IsometricEnvironmentObjectFactory` per istanziare scene
  asset-backed dagli `object_scenes`; `BiomeObstacle` resta fallback tecnico
  solo quando il contratto lo consente.
- `IsometricSvgTextureLoader` converte gli SVG generati in `ImageTexture`
  runtime quando l'import editor non e disponibile in headless.
- `SupplyCrateVisual` legge `object_scenes/supply_crate` e usa lo sprite
  asset-backed mantenendo collisione/apertura invariata.
- Smoke: `tests/milestone_10_object_asset_smoke_test.gd`, con regressioni su
  collision layer, factory runtime, crate, manifest, tile/passaggi e bootstrap
  survival.

## Obiettivo

Sostituire il draw procedurale degli ostacoli con scene/sprite asset-driven, leggibili come oggetti che occupano slot isometrici.

## Modifiche tecniche

- Creare una scena base:
  - `IsometricEnvironmentObject.tscn`
  - script `isometric_environment_object.gd`
- Ogni oggetto deve dichiarare:
  - sprite/texture;
  - ombra;
  - footprint isometrico opzionale debug;
  - anchor al pavimento;
  - collisione da manifest;
  - `sort_offset`;
  - categoria;
  - eventuale overlay danneggiato/distrutto futuro.
- `BiomeObstacle` diventa adapter/fallback o viene sostituito da factory:
  - legge manifest;
  - istanzia scena asset se presente;
  - applica collisione, gruppi, layer, sort;
  - usa draw procedurale solo se il manifest lo dichiara esplicitamente.
- Asset minimi per ogni categoria:
  - case/edifici: `ruined_house`, `burned_house`, `snow_cabin`, `sunken_house`, `lab_block`;
  - barriere: `boundary_fence`, `toxic_boundary_wall`, `lava_boundary`, `ice_boundary`, `deep_water_boundary`, `industrial_fence`, `charred_wall`, `snow_wall`, `ash_barrier`;
  - props: `pipe_stack`, `burned_car`, `ice_block`, `dead_tree`, `marsh_log`, `broken_walkway`, `toxic_barrel`, `chemical_barrel`;
  - crate: `supply_crate`.
- Gli oggetti grandi devono comunicare chiaramente lo slot occupato:
  - base romboidale o ombra isometrica;
  - altezza verticale coerente;
  - Y-sort stabile;
  - collisione non fuorviante.

## File probabili

- `game/modes/zombie/biome_obstacle.gd`
- nuovo `game/modes/zombie/isometric_environment_object.gd`
- nuovo `game/modes/zombie/isometric_environment_object_factory.gd`
- `game/modes/zombie/obstacle_system.gd`
- `game/drops/supply_crate.gd`
- `assets/environment/isometric/objects/**`
- `assets/environment/isometric/manifest.json`
- `tests/biome_obstacle_generation_smoke_test.gd`
- nuovo `tests/milestone_10_object_asset_smoke_test.gd`

## Criteri di accettazione

- Ogni ostacolo generato istanzia un asset scene/sprite o un fallback dichiarato.
- Footprint, collisione e ombra sono allineate.
- Player e zombie possono passare davanti/dietro oggetti senza effetto piatto.
- Gli oggetti non sembrano più rettangoli o poligoni procedurali scollegati dal terreno.

## Test

- Smoke: tutti gli `obstacle_id` generati hanno `asset_path` o fallback esplicito.
- Smoke: collision layer movimento e proiettili invariati.
- Manuale: kiting attorno a case grandi, muri, auto, tronchi e barili.

---

# Milestone 10.6 — Vuoto, cliff e danno da caduta asset-driven

Stato: completata il 2026-06-18.

Esito:

- Creato `IsometricCliffRenderer` con sprite asset-driven per fall_zone,
  void_edge_near, void_depth, void_vertical_lines e cliff_lip orientati.
- `BiomeFallZone` ora usa renderer e legge side metadata da layout per
  selezionare cliff lip nord/sud/est/ovest.
- Linee verticali seeded determiniache partono dal bordo calpestabile verso
  la profondità, con colori specifici per bioma (toxic/lava/ice/marsh).
- Manifest v7 esteso: void_tiles include cliff_lip_north/south/east/west e
  void_vertical_lines per ogni bioma asset set.
- Aggiunto `tests/milestone_10_void_cliff_asset_smoke_test.gd` per copertura
  manifest contracts, instance setup per-side, layout metadata propagation,
  hazard system integration e line determinism.

## Obiettivo

Rendere i punti vuoti immediatamente riconoscibili come caduta pericolosa, non come terreno scuro.

## Modifiche tecniche

- Sostituire `BiomeFallZone._draw()` procedurale con asset/tiles orientati:
  - `cliff_lip_north/south/east/west`
  - `cliff_corner_inner/outer`
  - `void_depth_tile`
  - `void_vertical_lines`
  - `biome_specific_depth_overlay`
- Le linee verticali devono partire dal confine calpestabile verso il basso/profondità:
  - densità deterministica per seed;
  - colore per bioma;
  - layering sotto il bordo calpestabile;
  - leggibili anche a 960x540.
- `FallBoundaryGenerator` deve produrre informazioni di orientamento/side sufficienti:
  - lato esterno;
  - segmento di bordo;
  - coordinate del lip;
  - profondità visuale;
  - eventuali corner.
- Distinguere chiaramente:
  - lato senza regione = vuoto/cliff/danno da caduta;
  - lato con regione ma senza edge = muro/barriera;
  - lato con edge = apertura/passaggio.
- Aggiungere debug overlay opzionale per mostrare il bordo fall zone e la landing valida del dodge.

## File probabili

- `game/procedural/world_generation/fall_boundary_generator.gd`
- `game/modes/zombie/biome_fall_zone.gd`
- nuovo `game/modes/zombie/isometric_cliff_renderer.gd`
- `game/modes/zombie/hazard_system.gd`
- `game/player/player_dodge_component.gd`
- `assets/environment/isometric/edges/cliffs/**`
- `assets/environment/isometric/manifest.json`
- `tests/fall_boundary_visual_logic_smoke_test.gd`
- `tests/player_dodge_gap_smoke_test.gd`
- nuovo `tests/milestone_10_void_cliff_asset_smoke_test.gd`

## Criteri di accettazione

- Il vuoto è visivamente diverso da hazard ambientali come lava, gas, acqua profonda.
- Ogni fall zone ha bordo calpestabile + profondità + linee verticali.
- I passaggi non vengono coperti da linee/cliff.
- Camminare nel vuoto continua a produrre danno/recupero come prima.
- Il dodge attraversa piccoli gap validi ma non hazard ambientali.

## Test

- Smoke: fall zone su tutti e quattro i lati esterni.
- Smoke: nessun cliff tile dentro passaggi collegati.
- Manuale: camminare verso il vuoto in cinque biomi e verificare che sia evidente prima del danno.

---

# Milestone 10.7 — Eliminazione totale dei portali/gate/trigger di transizione

## Obiettivo

Rimuovere il concetto di portale di transizione: il cambio bioma deve derivare dalla posizione world-space del party dentro una megamappa continua.

## Modifiche tecniche

- Deprecare `BiomeTransitionGate` come oggetto runtime.
- Sostituire `BiomeTransitionSystem` con un sistema senza gate, ad esempio:
  - `RegionSeamSystem`
  - oppure `WorldRegionPositionTracker`
- Il sistema deve:
  - leggere `WorldRegion.world_origin`, `zone_size`, `WorldRegionConnection` e passaggi;
  - determinare la regione corrente dalla posizione globale del player/party;
  - cambiare `current_region_id` quando il party attraversa fisicamente un varco valido;
  - non creare `Area2D` di transizione;
  - non disegnare frecce, portali, rettangoli o trigger.
- I passaggi sono solo terreno + apertura fisica + continuità collisioni.
- Il cambio regione aggiorna HUD, mappa, bioma corrente e wave director senza reload percepibile.
- Mantenere un cooldown logico anti-flapping solo sui cambi di `current_region_id`, non sui portali.

## File probabili

- `game/modes/zombie/biome_transition_system.gd`
- `game/modes/zombie/biome_transition_gate.gd`
- nuovo `game/world/world_region_position_tracker.gd`
- nuovo `game/world/region_seam_system.gd`
- `game/modes/zombie/zombie_mode_controller.gd`
- `game/modes/zombie/biome_manager.gd`
- `game/world/world_runtime.gd`
- `tests/open_passage_transition_smoke_test.gd`
- nuovo `tests/milestone_10_no_portal_transition_smoke_test.gd`

## Criteri di accettazione

- Durante survival non esistono nodi nel gruppo `biome_transition_gates`.
- Nessun `Area2D` di transizione viene istanziato per passare di bioma.
- Entrando fisicamente nel territorio vicino attraverso un varco, `current_region_id` cambia.
- Attraversare un bordo senza edge non cambia regione e resta bloccato da muro o caduta.
- Nessuna schermata di caricamento, teleport o snap del party.

## Test

- Smoke: `get_tree().get_nodes_in_group("biome_transition_gates")` è vuoto.
- Smoke: crossing world-space est/ovest/nord/sud aggiorna regione corrente.
- Smoke: crossing su bordo non connesso fallisce.
- Manuale: camminare tra almeno otto regioni senza vedere portali/gate.

---

# Milestone 10.8 — Streaming gameplay multi-regione reale

## Obiettivo

Passare dal prototipo “vicini solo ground” a regioni adiacenti vive, con collisioni, ostacoli, hazard e oggetti gameplay già presenti prima dell’attraversamento.

## Modifiche tecniche

- Estendere `MultiRegionRenderer` o creare `WorldRegionStreamer`:
  - current region = `FULL`;
  - connected neighbors entro raggio 1 = `FULL_LIGHT` o `FULL` senza duplicare spawn aggressivi;
  - regioni oltre raggio = `DATA_ONLY`;
  - cleanup deterministico quando una regione esce dal ring attivo.
- Istanziare per ogni regione attiva:
  - tile layer;
  - ostacoli;
  - hazard/fall zone;
  - crate persistenti;
  - passaggi/muri/cliff;
  - props decorativi.
- Evitare duplicati usando chiavi stabili:
  - `region_id + obstacle_key`
  - `region_id + crate_id`
  - `region_id + hazard_id`
- Gli spawn zombie devono restare controllati:
  - spawn dai bordi camera, non da tutta la megamappa;
  - nessuno spawn in regioni lontane non visibili;
  - zombie esistenti possono muoversi oltre la regione corrente.
- Camera e coordinate devono restare world-space: niente recentramento locale distruttivo.

## File probabili

- `game/world/multi_region_renderer.gd`
- nuovo `game/world/world_region_streamer.gd`
- `game/modes/zombie/zombie_mode_controller.gd`
- `game/modes/zombie/terrain_generator.gd`
- `game/modes/zombie/obstacle_system.gd`
- `game/modes/zombie/hazard_system.gd`
- `game/modes/zombie/resource_crate_system.gd`
- `game/modes/zombie/zombie_spawner.gd`
- `game/world/world_runtime.gd`
- `tests/milestone_8_multi_region_smoke_test.gd`
- nuovo `tests/milestone_10_full_region_streaming_smoke_test.gd`

## Criteri di accettazione

- Le regioni adiacenti connesse sono già fisicamente presenti prima di attraversarle.
- Ostacoli e hazard del vicino bloccano correttamente anche quando il player è ancora nella regione corrente.
- Le crate aperte/distrutte restano persistenti quando si torna indietro.
- Non vengono duplicati oggetti al cambio regione.
- Nessun frame hitch evidente all’attraversamento.

## Test

- Smoke: active ring contiene current + vicini connessi con content level gameplay.
- Smoke: crate aperta nel vicino resta aperta dopo uscita/rientro.
- Smoke: obstacle key stabile non duplica nodi.
- Manuale: attraversare regioni avanti/indietro con 4 player.

---

# Milestone 10.9 — Zombie chase cross-bioma

## Obiettivo

Garantire che gli zombie che inseguono il giocatore continuino a farlo attraverso il passaggio tra biomi.

## Modifiche tecniche

- Rendere gli enemy node world-space, non vincolati alla regione corrente.
- Aggiornare AI/pathing per attraversare varchi:
  - collisioni di passaggio aperte;
  - muri/fall zone bloccanti;
  - target player globale;
  - niente despawn al cambio `current_region_id`.
- Il `WaveDirector` può cambiare bioma corrente per nuove ondate/spawn, ma gli zombie già vivi mantengono comportamento e target.
- Aggiungere metadata runtime opzionali:
  - `current_region_id` derivata dalla posizione;
  - `spawn_region_id`;
  - `last_seen_player_region_id`.
- Se uno zombie esce dal ring attivo ma sta ancora inseguendo un player, non deve sparire immediatamente: usare distanza/camera/tempo come criterio di cleanup, non confine bioma.

## File probabili

- `game/enemies/basic_enemy.gd`
- `game/enemies/enemy_system.gd`
- `game/modes/zombie/zombie_spawner.gd`
- `game/modes/zombie/wave_director.gd`
- `game/modes/zombie/wave_manager.gd`
- `game/world/world_runtime.gd`
- `game/world/region_seam_system.gd`
- nuovo `tests/milestone_10_cross_biome_chase_smoke_test.gd`

## Criteri di accettazione

- Uno zombie in chase non viene despawnato quando il player attraversa un varco.
- Lo zombie attraversa lo stesso passaggio se il percorso è aperto.
- Lo zombie non attraversa muri, fall zone o bordi senza edge.
- Il cambio di bioma non resetta target, health, status effect o knockback.
- Nuovi spawn usano il bioma corrente/camera, mentre nemici vivi restano indipendenti.

## Test

- Smoke: enemy chase target oltre seam mantiene stato `chase`.
- Smoke: enemy path attraversa passaggio aperto.
- Smoke: enemy non attraversa bordo non connesso.
- Manuale: attirare un gruppo di zombie da una regione alla successiva e tornare indietro.

---

# Milestone 10.10 — Rimozione legacy e fallback controllato

## Obiettivo

Eliminare confusione tra arena legacy, placeholder procedurali e nuova pipeline isometrica.

## Modifiche tecniche

- Audit di:
  - `IsometricPlayground`
  - vecchi gate arena
  - spawn gate visual legacy
  - vecchie patch decorative non usate
  - fallback procedural non dichiarati.
- Decidere per ogni elemento:
  - rimuovere;
  - rinominare come debug/fallback;
  - integrare nella nuova pipeline asset-driven.
- Nessun codice deve istanziare asset legacy sopra/sotto il nuovo tile layer senza scelta esplicita.
- Aggiornare documentazione:
  - `ARCHITECTURE.md`
  - `ROADMAP.md`
  - `docs/isometric_generation_audit_roadmap.md`
  - `docs/testing/manual_checklist.md`

## File probabili

- `game/main/isometric_playground.gd`
- `game/modes/zombie/terrain_generator.gd`
- `game/modes/zombie/zombie_mode_controller.gd`
- `game/modes/zombie/biome_transition_gate.gd`
- `game/modes/zombie/biome_transition_system.gd`
- `ARCHITECTURE.md`
- `ROADMAP.md`
- `docs/isometric_generation_audit_roadmap.md`
- `docs/testing/manual_checklist.md`

## Criteri di accettazione

- Nessun visual legacy appare nella survival isometrica standard.
- I fallback procedurali sono solo fallback espliciti, non percorso principale.
- La documentazione descrive il nuovo flusso world-space.
- La roadmap segna Milestone 10 completata solo dopo QA visivo e smoke verdi.

## Test

- Ricerca testuale: nessun riferimento runtime obbligatorio a gate/portal legacy.
- Smoke bootstrap survival.
- Manuale: avvio run, cambio regioni, ritorno menu, retry.

---

# Milestone 10.11 — QA visuale, performance e checklist finale

## Obiettivo

Verificare che la milestone non sia solo tecnicamente verde ma visivamente convincente.

## Checklist manuale obbligatoria

Per ogni bioma:

- tile base visibili su tutto il `200x200`;
- almeno 3 varianti tile persistenti;
- strade/passaggi leggibili;
- muri e bordi distinguibili da cliff/vuoto;
- vuoto evidente prima di prendere danno;
- oggetti grandi con slot/ombra/altezza chiari;
- player e zombie leggibili davanti/dietro oggetti;
- passaggio a bioma vicino senza portale e senza caricamento;
- zombie in chase attraversano il passaggio;
- mappa territori coerente con regione corrente.

## Screenshot richiesti

- `plains_full_region.png`
- `toxic_void_edge.png`
- `ash_passage_crossing.png`
- `snow_objects_slots.png`
- `marsh_bridge_void.png`
- `cross_biome_chase_sequence_01.png`
- `cross_biome_chase_sequence_02.png`

## Test automatici minimi

- `milestone_10_asset_manifest_v7_smoke_test.gd`
- `milestone_10_tile_layer_smoke_test.gd`
- `milestone_10_passage_tile_smoke_test.gd`
- `milestone_10_object_asset_smoke_test.gd`
- `milestone_10_void_cliff_asset_smoke_test.gd`
- `milestone_10_no_portal_transition_smoke_test.gd`
- `milestone_10_full_region_streaming_smoke_test.gd`
- `milestone_10_cross_biome_chase_smoke_test.gd`
- regressioni esistenti:
  - `isometric_environment_manifest_smoke_test.gd`
  - `isometric_biome_terrain_coverage_smoke_test.gd`
  - `fall_boundary_visual_logic_smoke_test.gd`
  - `player_dodge_gap_smoke_test.gd`
  - `milestone_8_multi_region_smoke_test.gd`
  - `open_passage_transition_smoke_test.gd` da aggiornare o deprecare.

## Criteri di completamento Milestone 10

- Tutti gli smoke principali verdi.
- Nessun portale/gate/trigger visibile o necessario alla transizione bioma.
- Almeno cinque biomi visualmente distinguibili.
- Nessun placeholder procedurale nei percorsi principali.
- Cross-biome chase funzionante.
- Performance accettabile su preset `balanced`.
- Documentazione e manual checklist aggiornate.

---

# Ordine consigliato di esecuzione in modalità Goal

1. Manifest v7 e pipeline asset.
2. Tile base chunked per il `200x200`.
3. Strade/passaggi asset-driven.
4. Oggetti/ostacoli scene-based.
5. Cliff/vuoto asset-driven con linee verticali.
6. Rimozione gate/trigger e passaggio a region seam world-space.
7. Streaming gameplay completo delle regioni adiacenti.
8. Zombie chase cross-bioma.
9. Cleanup legacy.
10. QA visuale e performance.

---

# Prompt breve per Codex — esecuzione iterativa

```text
Leggi docs/isometric_generation_audit_roadmap.md e milestone_10_isometric_asset_rewrite_roadmap.md. Lavora in modalità goal sulla Milestone 10, senza saltare i test. Obiettivo: trasformare l'ambiente survival in una megamappa isometrica continua asset-driven, eliminando placeholder procedurali e portali/gate/trigger di transizione. Procedi per piccoli passaggi verificabili: manifest v7, tile base 200x200 persistenti, passaggi/strade asset-driven, oggetti slot-based, vuoto/cliff con linee verticali, transizione world-space senza portali, streaming gameplay delle regioni adiacenti e zombie chase cross-bioma. Dopo ogni passaggio aggiorna roadmap/checklist, aggiungi o aggiorna smoke test e mantieni fallback controllati solo dove dichiarati esplicitamente.
```

---

# Nota di rischio

Questa milestone tocca rendering, collisioni, streaming, AI e UX. La parte più rischiosa non è generare asset, ma cambiare il contratto runtime da “regione corrente + gate” a “coordinate world-space continue”. Per questo la rimozione dei portali deve arrivare dopo tile/oggetti/passaggi e prima del chase cross-bioma, con smoke dedicati per impedire regressioni.
