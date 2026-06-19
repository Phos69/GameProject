# CHANGELOG

## Unreleased

### Added

- Aggiunto `isometric_biome_generation_rewrite_roadmap.md` con audit della
  generazione biomi, stato R1 e prossimo ciclo R2 su pareti/void perimetrale.
- Aggiunto `tests/isometric_biome_generation_rewrite_smoke_test.gd` per coprire
  chunk `500x500`, base void/fall zone, strade larghe 40, sentieri medi larghi
  20, blocchi interni, passaggi fisici e spawn/crate su celle walkable.
- Aggiunto `RegionSeamSystem` per aggiornare la regione survival corrente dalla
  posizione world-space del party e dai `WorldRegionConnection` aperti, senza
  istanziare portali o trigger di transizione. Aggiunto
  `tests/milestone_10_no_portal_transition_smoke_test.gd`.
- Aggiunto `WorldRegionStreamer` per istanziare regione corrente e vicini
  connessi come contenuto gameplay `FULL` con tile layer, ostacoli, hazard/fall
  zone e crate. Aggiunto
  `tests/milestone_10_full_region_streaming_smoke_test.gd`.
- Aggiunto metadata regione per gli zombie (`spawn_region_id`,
  `current_region_id`, `last_seen_player_region_id`) e smoke
  `tests/milestone_10_cross_biome_chase_smoke_test.gd` per il chase
  cross-bioma.
- Aggiunto `tests/milestone_10_legacy_cleanup_smoke_test.gd` per bloccare il
  ritorno di visual legacy nel bootstrap survival asset-driven.
- Aggiunti `tests/milestone_10_isometric_final_visual_qa.gd` e
  `tests/milestone_10_isometric_performance_smoke_test.gd` per chiudere la QA
  visuale/performance finale della roadmap asset isometrica.
- Aggiunto il primo sistema completo di texture isometriche forestali per il
  bioma base `infected_plains`: grass, tall grass, path, road, void, cliff edge,
  mountain wall e transizioni `grass_to_*`, `path_to_road`,
  `ground_to_void_cliff` e `ground_to_mountain_wall`.
- Aggiunto `tests/forest_isometric_texture_transition_smoke_test.gd` per
  validare contratti manifest, asset SVG, transizioni emesse dal layout
  generato, tall grass walkable e dettaglio texture nel `BiomeTileLayer`.
- Aggiunti 14 tile SVG dedicati per i cliff: bordi north/south/east/west,
  angoli interni/esterni e due raccordi diagonali. Il nuovo
  `IsometricCliffMeshBuilder` pre-bake-a faccia verticale, creste, fenditure,
  gradiente profondo sfumato nel void senza creare nodi per-tile.

### Changed

- Corretto il raccordo delle mesh cliff agli angoli: le facce laterali non
  duplicano piu il segmento condiviso e interpolano la profondita verso la
  faccia north/south; anche i tile laterali precedenti vengono limitati alla
  quota del join, eliminando i cunei che invadevano terreno o void. L'underlay
  fra i diamanti cliff e separato dal void puro e usa un grigio neutro coerente
  con l'edge. Rimossi la riga di foschia e il secondo pass shadow, che produceva
  sovrapposizioni simili a un riflesso: la faccia termina ora direttamente nel
  colore del void.
- Character Select ora supporta navigazione griglia a quattro direzioni con
  wrapping su card valide e avvio survival tramite `Start`/`pause` solo quando
  gli slot attivi hanno una selezione completa; lo `Start` di controller non
  attivi continua a servire il join locale.
- L'HUD gameplay separa vita/reload, ora compatti sopra il survivor, dalle
  statistiche slot nelle schede P1-P4 ancorate ai quattro angoli schermo.
- Rimosso dal gameplay il riquadro status persistente, inclusi progresso party,
  stato ondata survival e riepilogo bioma; gli annunci temporanei restano nel
  canale HUD esistente.
- `ObstacleLayoutGenerator` scala la rete bioma: le strade principali passano
  a 40 celle, i sentieri medi a 20 celle e i passaggi fisici generati a 40
  celle, mantenendo il valore storico da 10 come base di scala.
- La generazione biomi survival usa ora chunk logici `500x500` e una megamappa
  default `3x3`; `BiomeMapGenerator` mantiene override di debug per dimensione
  e numero regioni.
- `BiomeEnvironmentLayout` non considera piu walkable ogni cella non occupata:
  il layout parte da void e scava `floor_rects`, strade, passaggi e blocchi
  interni, con cache terrain `PackedByteArray` per query su 250.000 celle.
- `ObstacleLayoutGenerator` genera una rete orizzontale/verticale con strade
  principali larghe 40, sentieri bioma medi larghi 20, blocchi interni
  classificati e fall zone per void/partial void.
- `MapValidationSystem` blocca il void nel flood-fill e verifica che spawn e
  crate siano su terrain walkable; `ZombieSpawner` rifiuta le celle streamate
  non walkable.
- `BiomeTransitionSystem` resta una API legacy/debug per `transition_to()`, ma
  non genera piu `BiomeTransitionGate` nella survival standard; gli smoke di
  open passage e transizione bioma validano ora il contratto senza gate runtime.
- `ZombieModeController` usa lo streamer multi-regione quando
  `enable_multi_region_render` e attivo; `TerrainGenerator`, `ObstacleSystem`,
  `HazardSystem` e `ResourceCrateSystem` registrano i nodi streamati per
  mantenere query, danno da caduta, safe position e ledger crate centralizzati.
- `EnemySystem` assegna la regione di spawn dalla posizione world-space e
  `ZombieSpawner` valida le posizioni camera-edge contro le regioni streamate;
  gli zombie gia vivi non vengono despawnati o resettati al cambio bioma.
- `ZombieModeController` non crea piu `MultiRegionRenderer` durante la
  risoluzione componenti standard: il renderer storico resta fallback/debug
  lazy-only se lo streamer gameplay non e disponibile.
- `IsometricTileResolver` risolve `infected_plains` con tile forestali
  neighbor-aware, mantenendo i passage tile prioritari e senza cambiare
  classificazione terrain, pathfinding, hazard o collisioni.
- `IsometricTileResolver` risolve ora le celle `fall_zone` dal vicinato in
  varianti cliff orientate; `BiomeTileLayer` usa il risultato per separare in
  modo netto terreno calpestabile e caduta anche su angoli e raccordi.
- `BiomeTileLayer` pre-bake-a linee di dettaglio per grass, tall grass, path,
  road, transizioni e cliff, cosi il ground forestale non dipende da
  placeholder piatti o da nodi per-tile.
- `BiomeTileLayer` esclude ora `void_depth` e `forest_void` dalla mesh a rombi
  e dal reticolo: il void resta uniforme, mentre bordo e faccia cliff
  mantengono i dettagli di profondita.
- Il void uniforme usa ora il colore condiviso dal `VoidBackdrop` fuori-mappa;
  il resolver ignora `TERRAIN_BORDER` come sorgente di cliff, i blocchi
  `full_void` che raggiungono il perimetro vengono estesi fino al limite
  esterno e il relativo intervallo viene sottratto dai wall segment.
- Il pass texture forestale usa ora ombre, dettagli e underlay scuri relativi
  al tipo di tile: verde bosco per erba/void/cliff e marrone scuro per
  path/road. Il reticolo sul ground forestale e disattivato per eliminare gli
  spazi neri tra i rombi calpestabili.
- `assets/environment/isometric/manifest.json` v8 punta il tile set base a
  `tiles/forest/forest_tileset.svg` e registra 122 SVG ambiente verificati dalla
  pipeline asset, incluse le transizioni cliff orientate.

### Fixed

- Corretto il QA visuale isometrico: le catture sui biomi remoti ora spostano
  il player su una cella sicura adiacente al focus e azzerano lo smoothing
  camera; una verifica di dettaglio world-space impedisce ai frame neri di
  risultare PASS.
- Corretto il loader runtime degli SVG ambiente isometrici: ora rasterizza il
  contenuto SVG trasparente quando disponibile, scarta import opachi e usa un
  fallback isometrico specifico per categoria oggetto invece della sagoma
  placeholder generica.

### Performance

- Il profilo `balanced` con mondo `3x3`, tre regioni streamate e 28 nemici
  resta nel budget dopo il nuovo cliff pass: 16,59 ms medi su target 35 ms.
- Ridotto drasticamente il costo di rendering del terreno isometrico in modalità
  zombie, che era il principale collo di bottiglia del framerate (non il
  caricamento dei tile). Il renderer `gl_compatibility` ridisegna ogni frame
  l'intera command-list di un canvas item, quindi le ≈40.000 celle della griglia
  200x200 producevano ~40.000 `draw_polyline` antialiased + ~40.000
  `draw_colored_polygon` per frame.
  - `BiomeTileLayer` ora pre-cuoce il terreno una sola volta in
    `_rebuild_ground_geometry()`: un'unica `ArrayMesh` vertex-coloured per i
    riempimenti (una sola `draw_mesh`) più una singola `draw_multiline` non
    antialiased per la griglia. Il costo per frame passa da ~80.000 comandi a 2,
    indipendentemente dal numero di tile.
  - `BiomeRegionGround` (ground delle regioni vicine) accorpa i contorni in una
    sola `draw_multiline` non antialiased invece di una `draw_polyline` per cella.

### Documentation

- Consolidato il backlog operativo in `TODO.md`, separando backlog aperto,
  follow-up e reference storiche completate senza riaprire milestone concluse.
- Aggiornato `docs/latest_commit_validation_report.md` con audit documentale
  Milestone 0, baseline test nota e stato del debito shutdown headless.
- Aggiornato il report di validazione con la Milestone 1 di
  `todo_roadmap.md`, inclusi loop shutdown headless, smoke prioritari e residui
  QA visuali fuori scope.
- Aggiornati TODO, roadmap operativa, checklist manuale e report di validazione
  con la chiusura della Milestone 2 di `todo_roadmap.md` sui mini-eventi bioma.
- Aggiornati TODO, roadmap operativa, design, architettura, checklist manuali e
  report di validazione con la chiusura della Milestone 7 di `todo_roadmap.md`
  su tuning melee, super starter e classi RPG avanzate.
- Aggiunto `docs/isometric_generation_audit_roadmap.md` con audit mirato della
  migrazione isometrica, gap analysis su terrain/biomi/asset/connessioni e
  roadmap dedicata tracciata in `TODO.md` come `ISO-001`.
- Chiusa la Milestone 1 della roadmap isometrica con stato aggiornato in
  `docs/isometric_generation_audit_roadmap.md`, `TODO.md` e `ROADMAP.md`.
- Chiusa la Milestone 2 della roadmap isometrica con stato aggiornato in
  `docs/isometric_generation_audit_roadmap.md`, `TODO.md`, `ROADMAP.md` e
  `ARCHITECTURE.md`; aggiunta checklist manuale dedicata e prossimo passo
  `ISO-001` spostato alla Milestone 3 sugli ostacoli/props isometrici.
- Chiusa la Milestone 3 della roadmap isometrica con stato aggiornato in
  `docs/isometric_generation_audit_roadmap.md`, `TODO.md`, `ROADMAP.md`,
  `README.md`, `ARCHITECTURE.md` e checklist manuale; prossimo passo
  `ISO-001` spostato alla Milestone 4 sulle collisioni coerenti.
- Chiusa la Milestone 5 della roadmap isometrica con stato aggiornato in
  `docs/isometric_generation_audit_roadmap.md`, `TODO.md`, `ROADMAP.md`,
  `README.md`, `ARCHITECTURE.md`, `GAME_DESIGN.md` e checklist manuale;
  Milestone 4 resta aperta come recupero sulle collisioni coerenti.
- Chiusa la Milestone 4 della roadmap isometrica con stato aggiornato in
  `docs/isometric_generation_audit_roadmap.md`, `TODO.md`, `ROADMAP.md`,
  `ARCHITECTURE.md` e checklist manuale; prossimo passo `ISO-001` spostato
  alla Milestone 6 sulle connessioni aperte tra biomi.
- Chiusa la Milestone 6 della roadmap isometrica con stato aggiornato in
  `docs/isometric_generation_audit_roadmap.md`, `TODO.md`, `ROADMAP.md`,
  `ARCHITECTURE.md` e checklist manuale; prossimo passo `ISO-001` spostato
  alla Milestone 7 sul grafo biomi completamente connesso.
- Chiusa la Milestone 8 della roadmap isometrica (megamappa persistente) con
  decisione esplicita per la continuita fisica multi-regione; stato aggiornato
  in `docs/isometric_generation_audit_roadmap.md`, `TODO.md`, `ROADMAP.md`,
  `ARCHITECTURE.md` e checklist manuale.
- Chiusa la Milestone 7 della roadmap isometrica (grafo biomi completamente
  connesso) con report di connettivita nel debug overlay e test multi-seed;
  stato aggiornato in `docs/isometric_generation_audit_roadmap.md`, `TODO.md`,
  `ROADMAP.md`, `ARCHITECTURE.md` e checklist manuale.
- Chiusa la Milestone 9 della roadmap isometrica (mappa territori esplorati) con
  marker active regions, passaggi tematizzati e high contrast sulla mappa; stato
  aggiornato in `docs/isometric_generation_audit_roadmap.md`, `TODO.md`,
  `ROADMAP.md`, `ARCHITECTURE.md` e checklist manuale.
- Chiusa la Milestone 10.1 della roadmap asset isometrica con manifest ambiente
  v7, sezioni asset-driven, fallback policy esplicita, documentazione asset e
  report di validazione aggiornati.
- Chiusa la Milestone 10.2 della roadmap asset isometrica con pipeline locale,
  generatore SVG headless, struttura cartelle ambiente e asset base
  asset-driven in-repo.
- Chiusa la Milestone 10.3 della roadmap asset isometrica con `BiomeTileLayer`,
  resolver deterministico per ogni cella `200x200`, tile `void_edge_near`,
  soppressione dei patch terreno legacy in modalita asset e smoke dedicato.
- Chiusa la Milestone 10.4 della roadmap asset isometrica con strade,
  raccordi, entry/exit e passaggi asset-driven, continuita globale tra regioni
  e smoke dedicato sui passaggi.
- Chiusa la Milestone 10.5 della roadmap asset isometrica con oggetti e
  ostacoli slot-based, factory asset-driven, crate su sprite da manifest e
  smoke dedicato sugli object scene.
- Iterato il pass isometrico ambiente: le strade generate usano ora celle route
  diagonali asset-driven (`road_cell_tags`) per diramarsi lungo gli assi
  isometrici invece di corsie orizzontali/verticali; il resolver mantiene i
  rettangoli solo per aperture e compatibilita.
- Rigenerati gli SVG interni ambiente con sfondo trasparente e silhouette
  dedicate per case, cabine, laboratori, recinti, muri, barili, relitti,
  tronchi, ponti e crate, rimuovendo il placeholder unico a forma di casetta
  generica dagli `object_scenes`.
- Chiusa la Milestone 10.11 della roadmap asset isometrica con screenshot QA,
  performance su mappa `7x7`, suite smoke finale e spostamento di `ISO-001` tra
  le reference completate.
- Documentato il sistema texture forestali in
  `docs/forest_isometric_texture_system.md`, con contratto ID, regole di
  risoluzione, procedura per estendere altri biomi, checklist manuale e smoke
  test dedicati.
- Aggiornati TODO, roadmap rewrite isometrico, architettura, design, asset
  README, attribution e report di validazione con la chiusura di `ISO-RW-001`
  e del primo pass forestale.

### Changed

- `TerrainGenerator` usa `BiomeTileLayer` come ground primario asset-driven
  quando `use_asset_tile_layer` e attivo; `BiomeRegionGround` e
  `BiomeTerrainPatch` restano fallback tecnici controllati.
- `IsometricTileResolver` distingue tile terrain e passage per strade,
  curve/edge/intersezioni, entry/exit di passaggio e connector dedicati; i
  connector di passaggio hanno priorita sulle road decorative sovrapposte.
- `BiomeTransitionGate` non comunica piu la direzione con draw runtime: il draw
  resta solo debug opzionale, mentre apertura e direzione sono leggibili dai
  tile di passaggio.
- `ObstacleSystem` istanzia ora gli ostacoli tramite
  `IsometricEnvironmentObjectFactory`: il percorso normale usa
  `IsometricEnvironmentObject` con `Sprite2D`, ombra, anchor, collisione e
  `sort_offset` dal manifest; `BiomeObstacle` resta fallback tecnico esplicito.
- `SupplyCrateVisual` usa il contratto `object_scenes/supply_crate` e mostra uno
  sprite asset-backed, mantenendo il vecchio draw solo se il loader non riesce a
  produrre una texture.
- `BiomeObstacle` costruisce ora la collisione dal manifest: `collision_shape`
  (`rectangle`/`circle`/`open`) guida shape runtime e `contains_global_position`,
  `blocks_movement`/`blocks_projectiles` guidano i bit di `collision_layer` e
  `is_jumpable_gap_anchor` espone `is_jumpable_obstacle()`. Gli ostacoli che
  bloccano i proiettili stanno sul nuovo collision layer `32`; `projectile.tscn`
  e `boss_projectile.tscn` leggono quel layer e il `Projectile` condiviso si
  ferma sui muri solidi prima di applicare danno.
- `ObstacleSystem` espone le query `is_position_blocked_by_non_jumpable` e
  `is_position_jumpable_obstacle` (il dodge usa la prima per la traiettoria) e
  assegna a ogni ostacolo una chiave stabile via
  `ObstacleSystem.make_obstacle_key()`, pronta per il ledger ostacoli distrutti.
- Aggiunto `tests/milestone_4_obstacle_collision_smoke_test.gd` e aggiornata
  l'assertion layer in `tests/zombie_environment_milestone_smoke_test.gd` al
  controllo bitwise del bit movimento.
- `BiomeTransitionGate` e ora dimensionato e orientato dalla larghezza/lato del
  passaggio e tematizzato per `passage_type` (`road`/`bridge`/`snow_pass`/
  `broken_gate`/`burned_road`) con freccia direzione-aware;
  `BiomeTransitionSystem` propaga tipo e span del passaggio al gate. Aggiunto
  `tests/milestone_6_open_passage_smoke_test.gd` ed esteso
  `tests/open_passage_transition_smoke_test.gd` con l'allineamento gate/passaggio.

### Added

- `MultiRegionRenderer` (`game/world/multi_region_renderer.gd`): prototipo del
  renderer multi-regione che istanzia la regione corrente piu i vicini connessi
  a offset da `WorldRegion.world_origin`, con i vicini come ground visuale e le
  regioni lontane non istanziate. `ZombieModeController` lo invoca a ogni cambio
  regione (gated da `enable_multi_region_render`) e lo pulisce a `stop_run()`.
  Aggiunto `tests/milestone_8_multi_region_smoke_test.gd`.
- `WorldGraph.get_connectivity_report()` e report grafo/active regions in
  `BiomeMapDebugOverlay` (toggle `F8`); aggiunto
  `tests/milestone_7_graph_connectivity_smoke_test.gd` con garanzia di
  connettivita su 100 seed e regola di fog.
- `ExplorationMapPanel` mostra marker per le active/loaded regions, passaggi noti
  tematizzati per `passage_type` e consuma `apply_visual_settings` (high
  contrast); `HUDManager` gli passa le active regions. Esteso
  `tests/exploration_map_smoke_test.gd`.
- `IsometricEnvironmentManifest` legge ora il contratto v7 del manifest
  ambiente: `tile_sets`, `tile_variants`, `terrain_tiles`, `edge_tiles`,
  `void_tiles`, `object_scenes`, `passage_tiles`, `biome_asset_sets` e
  `fallback_policy`, normalizzando ogni asset con path, status, footprint,
  anchor, collisione, blocchi e attribution. Aggiunto
  `tests/milestone_10_asset_manifest_v7_smoke_test.gd`.
- `tools/generate_isometric_environment_assets.gd` genera SVG testuali
  asset-driven dal manifest v7, con dry-run, write, check e guardia anti
  overwrite per asset `final`. Aggiunti 74 SVG ambiente e
  `tests/milestone_10_asset_pipeline_smoke_test.gd`.
- `tests/milestone_10_passage_tile_smoke_test.gd` valida contratti tile
  passaggi, span sui quattro lati, overlap con fall/wall, coordinate globali dei
  connector e serializzazione `WorldRegionConnection`.
- `IsometricEnvironmentObject`, la relativa scena base e
  `IsometricSvgTextureLoader` convertono gli SVG generati in texture runtime
  quando Godot headless non dispone dell'import editor; aggiunto
  `tests/milestone_10_object_asset_smoke_test.gd`.

### Fixed

- I telegraph dei mini-eventi bioma conservano ora l'ID evento reale
  (`toxic_leak`, `fire_breakout`, `whiteout`, `marsh_emergence`) invece di
  riusare ID generici, rendendo QA/debug e preset visuali coerenti.
- `whiteout` e il malus del `cursed_crate` applicano status solo ai player che
  restano dentro l'area annunciata dal telegraph, rendendo il rischio evitabile.
- Le crate di encounter gia in `queue_free` non bloccano piu il posizionamento
  del reward dell'evento successivo nello stesso frame di cleanup/test.
- Stabilizzato lo shutdown headless: `AudioManager` in headless simula fallback
  e stream opzionali senza istanziare player audio runtime, mentre
  `shutdown_audio()` libera voice pool e generatori procedurali.
- Ripulito il lifecycle della generazione biomi: helper procedurali senza scena
  convertiti a `RefCounted`, dati world/celle azzerati tra run e
  `BiomeManager` ripristina i layout base al cleanup.
- Resi cancellabili i telegraph degli encounter casuali tramite `Timer`
  figli tracciati e liberati in cleanup, evitando timer pendenti durante lo
  shutdown dei test.
- Allineati i runner headless piu fragili a teardown esplicito delle scene e a
  un helper condiviso di lifecycle per evitare risorse trattenute a fine test.
- Rimossa la dipendenza statica da `VisualSettingsManager` nei consumer visuali
  isolati, usando sincronizzazione locale dal gruppo quando disponibile.
- Berserker, Spadaccino e Licantropo non usano piu projectile runtime per
  ascia, spada e artigli: i colpi base passano da hitbox melee temporanee
  ruotate nella direzione di mira.
- Resa la Character Select clampata al viewport con safe-area e scroll,
  evitando tagli di card, slot player, dossier e azioni a risoluzioni o aspect
  ratio stretti.
- Uniformato il caricamento preview dei personaggi nel menu: le card usano
  prima portrait HUD/full dedicati, poi `gameplay_sprite_path` e infine un
  fallback procedurale coerente con palette e arma.
- Corretto `SupplyCrate` rinviando l'apertura automatica da `body_entered`,
  evitando errori Godot di modifica dello stato physics durante il flush delle
  query.
- Allineati gli smoke test al flusso corrente: Character Select prima della
  survival, profili RPG avanzati, fall boundary procedurali multipli, runner
  `SceneTree` differiti e proiettili torre che possono essere liberati prima
  delle asserzioni finali.
- Documentata la rigenerazione della cache locale `.godot/` richiesta dopo
  clone o pull su una nuova macchina prima dell'avvio runtime headless.
- Corretto il parse di `RpgCharacterData` rinominando il campo export interno
  `class_name`, riservato da GDScript, e mantenendo invariato il profilo
  pubblico usato da menu e HUD.
- `MeleeAttack` applica ora il `hitstop` configurato in `WeaponData`, mantenendo
  separato il runtime melee dal percorso proiettili.
- Briciola usa valori assistivi bounded per danno/cadenza anche durante
  `Branco di Rottami`, mentre `Notte Bestiale` espone e visualizza una recovery
  leggibile al termine della trasformazione.

### Added

- I mini-eventi bioma avanzati generano reward crate tematiche reali quando
  `ResourceCrateSystem` e disponibile: tossico, fuoco, gelo e palude usano
  loot coerente con il bioma.
- Esteso il manifest ambiente isometrico a v3 con copertura degli
  `obstacle_id` generati proceduralmente e mapping categoria esposto dal
  generatore.
- Esteso `tests/isometric_environment_manifest_smoke_test.gd` con generazione
  `5x5` reale e verifica manifest/categorie per ogni `layout.obstacle_id`.
- Esteso il manifest ambiente isometrico a v4 con sezione `terrain`, tag
  strada/passaggio generati, draw mode procedurali e preset `sample_step` del
  ground.
- `BiomeTerrainPatch` ora usa draw mode dedicati per strade, passaggi,
  ponti, neve, cancelli rotti e strade bruciate, evitando il fallback dirt per
  i tag generati.
- `BiomeRegionGround` supporta `sample_step` configurabile e
  `BiomeMapDebugOverlay` espone conteggi aggregati delle classi terrain.
- Esteso `tests/isometric_biome_terrain_coverage_smoke_test.gd` per validare
  manifest terrain, draw mode, preset, tag generati e classificazione `200x200`.
- Esteso il manifest ambiente isometrico a v5 con `object_visuals`, draw mode
  procedurali dedicati per gli ostacoli generati e validazione del fallback
  generico esplicito.
- `BiomeObstacle` ora legge il draw mode dal manifest e disegna varianti
  dedicate per pipe stack, auto bruciate, blocchi di ghiaccio, alberi morti,
  edifici/baite/case sommerse, barili tossici, muri/barriere tematiche, log e
  walkway senza cambiare collisioni o spawn blocker.
- Estesi `tests/isometric_environment_manifest_smoke_test.gd` e
  `tests/biome_obstacle_generation_smoke_test.gd` per vietare fallback generici
  impliciti sugli ID generati e verificare categorie distinguibili per bioma.
- Esteso il manifest ambiente isometrico a v6 con border tematici generati,
  `fall_zone` procedurale cliff/depth e draw mode dedicati per
  `toxic_boundary_wall`, `lava_boundary`, `ice_boundary` e
  `deep_water_boundary`.
- `BiomeObstacle` disegna border tematici per tossico, lava, ghiaccio e acqua
  profonda, mentre `BiomeFallZone` espone stili cliff/depth per bioma.
- `HazardSystem` espone query separate `is_position_fall_zone()` e
  `is_position_environment_hazard()` mantenendo `is_position_hazardous()` come
  query aggregata.
- Estesi gli smoke `isometric_environment_manifest`, `fall_boundary_visual_logic`,
  `player_dodge_gap` e `zombie_fall_hazard` per coprire manifest v6, border
  tematici, fall query e hazard ambientali non attraversabili.
- Estesa la copertura smoke di `random_encounter` e `biome_mini_events` con
  cooldown/frequenza, reward crate, high contrast, reduced motion e status
  evitabile.
- Aggiunto `tests/headless_shutdown_loop_test.gd` per verificare 100 cicli di
  istanza/free della scena principale in headless.
- Aggiunto `tests/test_scene_lifecycle.gd` come helper di teardown differito
  riusabile dai runner headless.
- Esteso `WeaponData` con `attack_type`, campi melee (`melee_shape`,
  `melee_range`, `melee_width`, `melee_arc_degrees`, `windup_time`,
  `active_time`, `recovery_time`, `knockback`, `trail_style`, `effect_key` e
  `sound_key`) e helper di risoluzione.
- Aggiunto `MeleeAttack`, un runtime world-space per swing melee con wind-up,
  finestra attiva, anti-multihit per bersaglio, knockback leggero e trail
  procedurale.
- Aggiunto `tests/rpg_melee_attack_resolution_smoke_test.gd` per verificare
  che arco generi projectile mentre ascia e spada danneggiano senza emettere
  `projectile_spawned`.
- Estesa la copertura smoke RPG su rischio/beneficio starter, recovery super,
  frenzy di Briciola e VFX super distinti per starter e classi avanzate.
- Character Select e dossier mostrano ora il tipo di attacco arma
  projectile/melee e la preview gameplay disegna micro-feedback dedicati per
  arco, pistola, ascia e spada.
- `GameplayEffects`, `PlayerVisual` e `AudioEventRouter` consumano i segnali
  melee per slash trail, impatti dedicati, shake leggero e cue procedurali
  distinti.
- Aggiunto `MenuNavigationController` riusabile per focus circolare,
  input D-pad/stick con cooldown, Back/B e cambio tab LB/RB nei menu.
- Settings ora supporta LB/RB per cambiare tab in modo circolare e rifocalizza
  un controllo valido della tab attiva.
- La preview gameplay della Character Select carica ora l'asset indicato da
  `gameplay_sprite_path` quando disponibile, mantenendo il fallback
  procedurale se il file non e leggibile.
- Character Select RPG rifatta come schermata completa con card grafiche,
  quattro slot player, pannello dossier, preview gameplay procedurale,
  barre stat HP/ATK/DEF/SPD/RNG, highlight focus/hover e conferma esplicita
  `Start Zombie Survival`.
- Aggiunti i controlli UI `CharacterSelectCard`,
  `CharacterDetailPanel` e `CharacterGameplayPreview`, piu il campo
  `style_description` e il path `gameplay_sprite_path` nei profili
  `RpgCharacterData` per sostituire in futuro preview e sprite con asset
  definitivi senza cambiare menu o gameplay.
- Aggiunto `tests/character_select_ui_smoke_test.gd` per validare struttura,
  preview e selezione della nuova Character Select anche senza avviare la
  scena principale.
- Character Select ora mostra una griglia di icone personaggio e quattro slot
  player: ogni slot attivo conserva il proprio personaggio, portrait,
  statistiche, passiva e super prima di avviare la survival.
- `SurvivalMode` accetta `context.character_ids_by_slot` per applicare profili
  RPG diversi ai player locali, mantenendo `context.character_id` come fallback
  compatibile con debug e test esistenti.
- Spostati e collegati i portrait PNG di `Mira Vento`, `Bruna Spaccaferro`,
  `Nina Bullone` e `Rocco Lunastorta` in `assets/characters/<id>/rendered/`
  per l'uso data-driven nel Character Select.
- Completata la Roadmap Megamappa Persistente Isometrica come primo pass integrato.
- Aggiunto `game/world/` con `WorldGraph`, `WorldRegion`, `WorldRegionConnection`, `WorldExplorationState`, `PersistentWorldState` e `WorldRuntime`.
- `BiomeMapGenerator` ora genera una griglia seed-based `5x5` di territori `200x200` tramite spanning tree ed edge extra, garantendo grafo connesso e percorsi alternativi.
- Aggiunti passaggi fisici aperti tra regioni confinanti, target region sugli edge e transizioni senza teletrasporto nel flusso standard.
- Aggiunta classificazione completa del terreno `200x200` per walkable, obstacle, hazard, border, void e fall zone, con validazione grafo/passaggi/classificazione in `MapValidationSystem`.
- Aggiunti `BiomeRegionGround`, fall boundary esterni coerenti con lati senza vicino e blocchi fisici sui lati con regione adiacente non collegata.
- Aggiunta mappa esplorazione HUD con unknown/fog, discovered, visited, cleared, marker regione corrente e input `M`/joypad `Back`.
- Esteso il save alla versione 6 con stato mondo/esplorazione persistente.
- Aggiunto `PlayerDodgeComponent` con input `Shift`/`Ctrl` e joypad `B`, cooldown, invulnerabilita breve, blocco fuoco durante roll e validazione gap/landing.
- Aggiunto manifest iniziale `assets/environment/isometric/manifest.json` per censire ostacoli, props, hazard, passaggi e fall boundary da convertire in asset isometrici.
- Aggiunti smoke test per connettivita grafo, persistenza mondo, passaggi aperti, copertura terreno, fall boundary, dodge/gap e mappa esplorazione.
- Aggiunti `PauseMenu`, `SettingsPanel` e `VideoSettingsManager`: `Start`/`P` apre la pausa durante una run, il main menu espone Settings con tab Audio/Video/Controls, video supporta fullscreen/borderless/risoluzione/VSync/FPS e i controlli joypad sono rimappabili e persistiti in save v5.
- Aggiunto smoke test `tests/pause_settings_smoke_test.gd` per pausa, settings condivisi, persistenza video e binding joypad.
- Convertiti gli asset personaggio RPG da PNG binari a SVG testuali, aggiornando manifest e profili `.tres` per rendere la PR compatibile con ambienti che non accettano file binari.
- Aggiunto primo set asset completo per `Licantropo` / `Rocco Lunastorta`: portrait rendered, portrait HUD, sprite isometrico, sprite sheet animabile, icone artigli/passiva/super e manifest in `assets/characters/licantropo/`.
- Aggiornato l'indice personaggi per marcare tutti i personaggi RPG come `base_complete` e proporre `ranger_quality_pass` come primo miglioramento qualitativo.
- Aggiunto primo set asset completo per `Domatrice` / `Nina Bullone`: portrait rendered, portrait HUD, sprite isometrico, sprite sheet animabile, icone fionda/passiva/super, Briciola visuale e manifest in `assets/characters/domatrice/`.
- Aggiornato l'indice personaggi per marcare `domatrice` come `base_complete` e proporre `licantropo` come prossimo pass asset.
- Aggiunto primo set asset completo per `Mago` / `Elio Braciastella`: portrait rendered, portrait HUD, sprite isometrico, sprite sheet animabile con cast, icone bastone/passiva/super e manifest in `assets/characters/mago/`.
- Aggiornato l'indice personaggi per marcare `mago` come `base_complete` e proporre `domatrice` come prossimo pass asset.
- Aggiunto primo set asset completo per `Spadaccino` / `Kael Guardia`: portrait rendered, portrait HUD, sprite isometrico, sprite sheet animabile, icone spada/passiva/super e manifest in `assets/characters/spadaccino/`.
- Aggiornato l'indice personaggi per marcare `spadaccino` come `base_complete` e proporre `mago` come prossimo pass asset.
- Aggiunto primo set asset completo per `Berserker` / `Bruna Spaccaferro`: portrait rendered, portrait HUD, sprite isometrico, sprite sheet animabile, icone ascia/passiva/super e manifest in `assets/characters/berserker/`.
- Aggiornato l'indice personaggi per marcare `berserker` come `base_complete` e proporre `spadaccino` come prossimo pass asset.
- Aggiunto primo set asset completo per `Pistoliere` / `Dante Ferraglia`: portrait rendered, portrait HUD, sprite isometrico, sprite sheet animabile, icone pistola/passiva/super e manifest in `assets/characters/pistoliere/`.
- Aggiornato l'indice personaggi per marcare `pistoliere` come `base_complete` e proporre `berserker` come prossimo pass asset.
- Aggiunto primo set asset completo per `Ranger` / `Mira Vento`: portrait rendered, portrait HUD, sprite isometrico, sprite sheet animabile, icone arma/abilita e manifest in `assets/characters/ranger/`.
- Creato indice generale `assets/characters/index.json` per tracciare copertura asset e prossimo personaggio consigliato.
- Iterazione sulla generazione biomi zombie survival: aggiunti corridoi secondari, cover, strettoie e ostacoli grandi specifici per Pianura Infetta, Tossico, Infuocato, Neve e Palude nella pipeline seed-based.
- La validazione layout ora segnala anche spawn player e casse sovrapposti a ostacoli, hazard o fall zone; lo smoke test dei biomi verifica identita navigazionale e placement validi.
- Iterazione sugli encounter zombie survival: gli encounter casuali ora rispettano seed mondo, cooldown per ondata, stato critico/boss, posizioni validate e reward crate reali per survivor cache/cursed crate.
- Esteso `BiomeMapDebugOverlay` con riepilogo runtime di bioma corrente, validazione, conteggi ostacoli/hazard/casse e ultimo encounter; aggiunto smoke test dedicato.
- Aggiunti telegraph world-space per `cursed_crate` e `hazard_burst`, con warning accessibile prima di status/hazard e snapshot debug del numero di telegraph pendenti.
- Aggiunto tuning threat/reward agli encounter: party size, conteggi nemici/hazard, durata/raggio hazard, moltiplicatori elite e crate reward ora derivano da bioma, wave e threat score.
- Aggiunti mini-eventi encounter specifici per bioma avanzato: `toxic_leak`, `fire_breakout`, `whiteout` e `marsh_emergence`, riusando telegraph, hazard, status e spawn nemici esistenti.
- Aggiunto smoke test `biome_mini_events_smoke_test.gd` per verificare mini-eventi, telegraph, threat score e tuning dei quattro biomi avanzati.
- Completata la Roadmap Motore di Generazione Mappe e Biomi come primo motore procedurale integrato.
- Aggiunti `WorldGenerationSeed`, `BiomeWorldGenerator`, `BiomeMapGenerator`, `BorderGenerator`, `BiomePassageGenerator`, `BiomeTerrainGenerator`, `ObstacleLayoutGenerator`, `FallBoundaryGenerator` e `MapValidationSystem`.
- La zombie survival genera a inizio run una mappa globale seed-based con celle bioma `200x200`, bordi con passaggi condivisi, fall boundary sui lati esterni e layout interni validati.
- I layout bioma generati includono strade, corridoi, case/ostacoli grandi, casse, hazard tematici e dati di validazione flood-fill.
- `BiomeManager` espone seed, firma di generazione, cella corrente e mappa generata; `BiomeTransitionSystem` usa i passaggi generati per creare i gate runtime.
- Aggiunto `BiomeMapDebugOverlay` con seed corrente, riepilogo celle e richieste di rigenerazione stesso/nuovo seed.
- Aggiunto smoke test `tests/biome_world_generation_smoke_test.gd` per determinismo, confini, fall zone, validazione e integrazione survival.
- Completata integralmente la Roadmap Revamp Modalita Zombie fino alla Milestone Z12.
- Aggiunti quattro layout data-driven avanzati per Tossico, Infuocato, Neve e Palude, con terreno, ostacoli, casse, hazard e confini fisici dedicati.
- Aggiunti `BiomeTransitionSystem` e `BiomeTransitionGate` per attraversare in sequenza tutti i cinque biomi durante la stessa run.
- Esteso `HazardSystem` con danno periodico, rallentamenti, status temporanei e hazard runtime, preservando la fall zone da 20 HP.
- Aggiunti undici profili `BiomeEnemyProfile` per zombie tossici, infuocati, ghiacciati e paludosi senza duplicare l'AI condivisa.
- Aggiunte casse comuni, mediche, militari e tematiche con loot tag, visuali e feedback HUD specifici.
- Esteso `WaveDirector` con scaling per party, tempo sopravvissuto, distanza dal bioma iniziale e modificatore drop.
- Aggiunti HUD, annunci, cue audio ed effetti per cambio bioma, pericoli ambientali e status attivi.
- Aggiunti smoke test per transizioni, zombie tematici, dieci ondate, soak da dieci minuti simulati e QA visuale dei cinque biomi.
- Completata Roadmap Revamp Modalita Zombie Milestone Z5 con fall zone, danno ambientale e recupero sicuro.
- Aggiunto `BiomeFallZone`, generato dal layout della Pianura Infetta e registrato come hazard/spawn blocker.
- `HazardSystem` salva l'ultima posizione sicura, applica 20 HP, riposiziona il player e concede invulnerabilita temporanea dedicata.
- `HealthComponent` supporta sorgenti di invulnerabilita componibili e `HealthSystem` puo ignorarle solo su richiesta esplicita.
- Aggiunti feedback visuali, camera shake e cue audio `player_fell`.
- Aggiunto `zombie_fall_hazard_smoke_test.gd` per danno, respawn, invulnerabilita, feedback, spawn validation e cleanup.
- Completata Roadmap Revamp Modalita Zombie Milestone Z4 con terreno, casse e ostacoli nella Pianura Infetta.
- Aggiunto `BiomeEnvironmentLayout` per placement data-driven di patch terreno, ostacoli e casse.
- `TerrainGenerator` applica la palette bioma e genera decorazioni non collidenti.
- `ObstacleSystem` genera rocce, recinti, barriera, rudere e confine parziale come `StaticBody2D` e spawn blocker.
- `ResourceCrateSystem` genera casse comuni e mediche con loot table dedicate tramite i sistemi drop esistenti.
- Aggiunto `zombie_environment_milestone_smoke_test.gd` per layout, collisioni, corridoi, casse, pathing minimo e cleanup.
- Completata Roadmap Revamp Modalita Zombie Milestone Z3 con verifica dei biomi dati e delle wave contestuali.
- Aggiunto `zombie_biome_wave_director_smoke_test.gd` per validare cinque biomi, partenza nella Pianura Infetta e modificatori tossici su wave/roster/scaling.
- Completata Roadmap Revamp Modalita Zombie Milestone Z2 con smoke test dello spawn dai bordi camera.
- `ZombieSpawner` espone parametri per gruppo, tick, ritardo gruppi, helper `is_position_outside_camera_view()` e validazione fuori camera.
- `ObstacleSystem` e `HazardSystem` riconoscono zone leggere `Node2D` con metadata `zone_radius` per validare spawn blocker e fall zone.
- Aggiunto `zombie_spawner_edge_smoke_test.gd` per bordi nord/sud/est/ovest, distanza dal player, hazard, ostacoli e fallback.
- Avviata Roadmap Revamp Modalita Zombie con Milestone Z1: fondamenta modulari.
- Aggiunti `ZombieModeController`, `BiomeManager`, `BiomeDefinition`, `WaveDirector`, `ZombieSpawner` e stub ambientali per terreno, casse, ostacoli e hazard.
- Aggiunte definizioni dati per Pianura Infetta, Tossico, Infuocato, Neve e Palude con palette, roster, risorse, ostacoli e moltiplicatori iniziali.
- `WaveManager` ora delega composizione wave e spawn position ai componenti zombie, mantenendo fallback ai punti arena esistenti.
- Aggiunto smoke test `zombie_revamp_foundation_smoke_test.gd`.
- Completata Roadmap RPG Mode Milestone 12 con feedback polish per level-up e super.
- `GameplayEffects` ora genera effetti dedicati `rpg_level_up` e `rpg_super` dai segnali RPG.
- `AudioEventRouter` collega level-up e super RPG a cue procedurali dedicati.
- Aggiunto smoke test `milestone_rpg_12_feedback_smoke_test.gd`.
- Completata Roadmap RPG Mode Milestone 11 con configurazione personaggi data-driven.
- Aggiunto `RpgCharacterData` e quattro risorse in `game/rpg/characters/`.
- `RpgCharacterRegistry` ora carica i profili dalle risorse mantenendo la stessa API pubblica.
- Aggiunto smoke test `milestone_rpg_11_data_driven_smoke_test.gd`.
- Completata Roadmap RPG Mode Milestone 10 con primo pass di bilanciamento classi/armi.
- Aggiustati profili e armi RPG per rendere Ranger, Pistoliere, Berserker e Spadaccino piu distinti.
- Aggiunto smoke test `milestone_rpg_10_balance_smoke_test.gd` con criteri relativi di identita classe.
- Completata Roadmap RPG Mode Milestone 9 con HUD RPG piu grafico e leggibile.
- Aggiunto `RpgHudIcon` procedurale per ritratto classe e icona super senza asset esterni.
- `PlayerHudCard` ora mostra ritratto personaggio, icona super ready, HP, ammo pips, XP, adrenalina e buff passivi in una scheda stabile.
- Aggiunto smoke test `milestone_rpg_9_hud_smoke_test.gd`.
- Completata Roadmap RPG Mode Milestone 8 con adrenalina e super per le quattro classi.
- `RpgPlayerComponent` ora gestisce adrenalina, ready state, attivazione super e timer dedicati.
- Aggiunto `RpgSuperResolver` per Pioggia di Frecce, Scarica Finale, Terremoto di Sangue e Lama Fantasma.
- `HealthSystem`, kill XP e reward wave alimentano l'adrenalina da hit, danno subito, kill e fine ondata.
- Aggiunto input super con `Q` per tastiera e joypad `Y`.
- Le schede HUD mostrano barra adrenalina e stato della super.
- Aggiunto smoke test `milestone_rpg_8_adrenaline_super_smoke_test.gd`.
- Completata Roadmap RPG Mode Milestone 7 con passive automatiche per le quattro classi.
- `RpgPlayerComponent` ora applica Occhio del Predatore, Mano Veloce, Furia di Sangue e Guardia Perfetta.
- `WeaponSystem` legge il moltiplicatore fire rate temporaneo del Pistoliere dopo il reload.
- Le schede HUD mostrano il buff passivo attivo quando entra in funzione.
- Aggiunto smoke test `milestone_rpg_7_passives_smoke_test.gd`.
- Completata Roadmap RPG Mode Milestone 6 con XP al killer e XP di fine ondata.
- `HealthSystem` conserva la sorgente dell'ultimo danno per assegnare XP on-kill.
- Zombie e boss assegnano XP direttamente al `RpgPlayerComponent` del killer.
- `WaveManager` assegna XP wave uguale ai player RPG vivi.
- Rimosso il drop XP fisico dalle loot table zombie survival.
- Aggiunto smoke test `milestone_rpg_6_xp_level_smoke_test.gd`.
- Completata Roadmap RPG Mode Milestone 5 con ammo/reload leggibili per arma.
- Le schede HUD ora mostrano pips ammo grafici e una barra reload stabile.
- `WeaponSystem` espone `get_reload_ratio()` e applica `reload_speed` del profilo RPG.
- Aggiunto smoke test `milestone_rpg_5_ammo_reload_smoke_test.gd`.
- Completata Roadmap RPG Mode Milestone 4 con hitbox arma configurabili.
- Esteso `WeaponData` con `hitbox_type`, `hitbox_size` e `max_hit_count`.
- `Projectile` ora crea shape circle, rectangle, capsule o arc separate dal visual.
- Ascia e spada supportano colpi multi-hit tramite `max_hit_count`.
- Aggiunto smoke test `milestone_rpg_4_hitbox_smoke_test.gd`.
- Completata Roadmap RPG Mode Milestone 3 con armi base differenziate per le quattro classi.
- Aggiunti `rpg_bow`, `rpg_pistol`, `rpg_axe` e `rpg_sword` come `WeaponData` con range, scatter, danno, ammo e reload distinti.
- Esteso `WeaponData` con `max_range` e `scatter_degrees`, applicati da `WeaponSystem` e `Projectile`.
- Aggiunti profili visuali procedurali per arco, pistola, ascia e spada.
- Aggiunto smoke test `milestone_rpg_3_weapons_smoke_test.gd`.
- Completata Roadmap RPG Mode Milestone 2 con statistiche classe, progressione per-run e formule danno.
- Esteso `RpgPlayerComponent` con livello, XP, HP/attacco/difesa scalati e risoluzione danni.
- Collegati `HealthSystem`, proiettili e attacchi nemici alla sorgente del danno.
- Estese le schede HUD player con livello, classe, XP bar e riga ATK/DEF/SPD.
- Aggiunto smoke test `milestone_rpg_2_stats_smoke_test.gd`.
- Avviata roadmap RPG Mode con Milestone 1: selezione personaggio pre-run per la survival.
- Aggiunti `RpgCharacterRegistry` e `RpgPlayerComponent` come contratto iniziale per classi, arma base, passiva e super.
- Aggiunto pannello `Character Select` nel menu prima dell'avvio zombie survival.
- Aggiunto smoke test `milestone_rpg_1_character_select_smoke_test.gd`.
- Completata Milestone 21 con accessibilita, profiling e pipeline asset.
- Aggiunto `VisualSettingsManager` con preset default, comfort e contrast.
- Aggiunti controlli menu per flash, glow, trail, shake e scala testo HUD.
- Aggiunti high contrast, reduced motion e marker geometrici player.
- Esteso il save alla versione 4 con round-trip delle impostazioni visuali.
- Collegati proiettili, effetti, camera, HUD, telegraph e visual ai profili.
- Aggiunti documenti import/fallback e registro attribuzioni in `assets/`.
- Aggiunti smoke test M21, profiling affollato e quattro QA a 1280x720.
- Completata Milestone 20 con arena survival, biomi e props data-driven.
- Aggiunti `BiomePalette`, `SurvivalArenaProfile` e `SurvivalArenaManager`.
- Aggiunti layout `Industrial Crossroads` e `Rift Foundry`.
- Aggiunti gate spawn non collidenti con impulso sugli spawn reali.
- Aggiunti barili esplosivi con collisione proiettile, warning e danno ad area.
- Estesi projectile ed effetti per props damageable e detonazioni ambientali.
- Aggiunti smoke, stress test e QA M20 a quattro player.
- Completata Milestone 19 con secondo boss e registro configurabile.
- Aggiunto `Rift Architect` con fase 2, lane sweep e cross burst.
- Aggiunti compatibilita boss per modalita e rifiuti tipizzati.
- Aggiunti `Rift Repeater`, loot dedicato e HUD boss generico.
- Aggiunti smoke test registry e QA dei due telegraph Rift.
- Completata Milestone 18 con bus audio, cue sostituibili e mix persistente.
- Aggiunti `AudioCueData`, `AudioVoicePool` e `AudioEventRouter`.
- Aggiunti bus UI, armi, nemici, boss, ambiente, musica e SFX.
- Aggiunti fallback distinti, pitch variation, priorita e limite voci.
- Aggiunti cue per shooter, wave, downed, revive e risultati.
- Esteso il menu con slider Master, Music e SFX.
- Esteso il save alla versione 3 con impostazioni audio.
- Aggiunti smoke test M18 e QA menu a 1280x720.
- Completata Milestone 17 con risultati condivisi e flussi di fine run.
- Aggiunto `RunSessionTracker` per durata, XP, denaro e unlock della sessione.
- Aggiunto `RunResultsScreen` con retry, cambio modalita e menu.
- Esteso `GameModeManager` con stato risultati, context di retry e cambio modalita.
- Aggiunto salvataggio sincrono prima del ritorno al menu.
- Aggiunti smoke test M17 e QA visuale a 1280x720.
- Completata Milestone 16 con stato downed e revive locale.
- Esteso `HealthComponent` con downed opzionale, revive e stato incapacitated.
- Aggiunto `ReviveSystem` con raggio, input tenuto, progresso e interruzione.
- Aggiunti posa downed, anello world-space e stato dedicato nelle schede HUD.
- Estese le condizioni di sconfitta party a survival, dungeon e tower defense.
- Aggiunti smoke test M16 e QA visuale a quattro player.
- Completata Milestone 15 con lo zombie ranged `Shooter`.
- Aggiunto `RangedEnemy` con distanza preferita, ritirata, windup e mira bloccata.
- Aggiunto telegraph world-space con corsia e countdown prima del proiettile.
- Aggiunti silhouette shooter, loot dedicato e profilo proiettile verde/ciano.
- Estesa la composizione survival con shooter deterministici dalla wave 4.
- Aggiunti smoke test M15 e QA visuale a quattro player.
- Completata Milestone 14 come chiusura del visual gameplay pass.
- Aggiunto `WaveWardenVisual` segmentato e animato per fase, mira, hit e carica.
- Aggiunti profili aimed/radial con glow e trail per i proiettili del boss.
- Aggiunto effetto world-space dedicato alla morte del `Wave Warden`.
- Aggiunto `CombatAnnouncement` per wave, reward, boss, overdrive e fine run.
- Aggiunto pannello boss centrato e responsive.
- Aggiunti smoke test M14 e QA finale in quattro tavole a 1280x720.
- Completata Milestone 13 con identita grafica data-driven per armi e torri.
- Aggiunto `WeaponVisualData` per condividere profilo tra arma, HUD, proiettile e muzzle flash.
- Aggiunti profili distinti per `Starter Pistol`, `Prototype Blaster`, `Wave Cannon` e torre.
- Aggiunte icone HUD arma generate dal profilo equipaggiato.
- Aggiunti forma, scala, glow e trail configurabili per i proiettili player e torre.
- Aggiunto `DefenseTowerVisual` con base esagonale, doppia canna, tracking, idle scan e rinculo.
- Aggiunti smoke test M13 e QA visuale per armi/player e torri a 1280x720.
- Completata Milestone 12 con varianti zombie runner e tank.
- Aggiunte scene enemy data-driven con statistiche, collisioni e loot dedicati.
- Esteso `ZombieVisual` con silhouette basic, runner e tank.
- Aggiunta composizione deterministica delle ondate survival per archetipo.
- Aggiunti smoke test varianti e QA couch multiplayer a 1280x720.
- Completata Milestone 11 con telegraph modulari del `Wave Warden`.
- Aggiunti warning world-space con countdown per raffica mirata e radiale.
- Aggiunti avvisi HUD e cue audio per pattern boss e cambio fase.
- Aggiunto impulso visuale per la fase 2 e direzione mirata bloccata al warning.
- Aggiunti smoke test telegraph e QA visuale a 1280x720.
- Completata Milestone 10 come primo pass di leggibilita visuale della survival.
- Aggiunta arena pseudo-isometrica desaturata con usura, corsie e barricate.
- Aggiunti visual modulari e animati proceduralmente per survivor e zombie.
- Sostituite le etichette dei pickup e della supply crate con icone grafiche.
- Aggiunte schede HUD per-player con vita, arma e munizioni.
- Aggiunto `GameplayEffects` per sparo, hit, morte e raccolta.
- Aggiunti smoke test visuale e QA survival a 1280x720.
- Aggiunta `Starter Pistol` con riserva infinita, caricatore e reload invariati.
- Esteso `WeaponSystem` con fallback permanente e stato separato dell'arma speciale.
- Aggiunto fallback shot automatico quando una speciale esaurisce caricatore e riserva.
- Aggiunta distribuzione completa dei pickup ammo alle speciali di tutti i player vivi.
- Aggiunte supply crate configurabili via `LootTable` con ammo e cura.
- Aggiunto `SurvivalAmmoDirector` con soglia low-ammo, cooldown e fonte garantita boss.
- Aggiunti feedback HUD/audio per low ammo, reload, fallback e ammo condivisa.
- Estesi gli smoke test combat, drop, survival e boss per il nuovo contratto ammo.
- Inizializzato repository Git.
- Creato progetto Godot 4.x testuale.
- Creata struttura cartelle per core, input, multiplayer, player, camera, combat, modalita, drop, progressione, UI, audio e salvataggi.
- Aggiunta scena principale pseudo-isometrica.
- Aggiunto player controllabile con movimento fluido.
- Aggiunto input manager con supporto tastiera e joypad player 1.
- Aggiunta camera che segue il gruppo player.
- Aggiunti stub modulari per sistemi futuri: armi, projectile system, health system, nemici, boss, wave, dungeon, tower defense, drop, loot table e progressione.
- Creata documentazione iniziale di repository, architettura, design, roadmap e workflow IA.
- Completata Milestone 2 come prototipo minimo di multiplayer locale 1-4 player.
- Aggiunto join/leave locale con `Start`/`Back` joypad e fallback debug `F2`-`F4`.
- Collegato `PlayerManager` agli slot attivi per spawn/despawn dinamico.
- Aggiunti colori per slot player e HUD con slot locali attivi.
- Aggiornata documentazione di roadmap, architettura, design, README, TODO e checklist manuale.
- Completata Milestone 3 come prototipo minimo di combat.
- Aggiunta risorsa `WeaponData` e pistola base configurabile.
- Aggiunti caricatore, riserva munizioni e ricarica indipendenti per-player.
- Aggiunto input ricarica con `R` e pulsante joypad `X`.
- Collegati proiettili, collisioni, danni, `HealthSystem` e `HealthComponent`.
- Aggiunti bersagli statici damageable con barra vita nella scena principale.
- Esteso HUD con vita e munizioni per ogni player.
- Aggiunto smoke test headless per combat e regressione multiplayer a due player.
- Aggiornata documentazione per stato Milestone 3, contratti combat e backlog futuro.
- Completata Milestone 4 come prototipo minimo di nemici e drop.
- Aggiunto `BasicEnemy` melee con stati idle, chase, attack e dead.
- Aggiunti targeting del player vivo piu vicino e retarget su join/leave.
- Esteso `EnemySystem` con spawn, contenitore, registro e segnale morte.
- Integrati attacchi nemici e morte con `HealthSystem` e `HealthComponent`.
- Aggiunti `DropEntry` e loot table tipizzate configurabili.
- Aggiunti pickup fisici per esperienza, denaro, munizioni, vita e armi.
- Centralizzata in `DropSystem` l'applicazione delle ricompense party e per-player.
- Aggiunto `Prototype Blaster` come primo drop arma equipaggiabile.
- Aggiunti due nemici iniziali alla scena principale.
- Aggiunto smoke test headless enemy/drop con regressione multiplayer locale.
- Aggiornata documentazione per stato Milestone 4, contratti enemy/drop e prossima Milestone 5.
- Completata Milestone 5 come prototipo minimo zombie survival.
- Trasformato `WaveManager` in una macchina a stati con intermissione, spawn, combat e reward.
- Aggiunti spawn scaglionato, conteggio crescente e tracking dei nemici della wave.
- Aggiunto scaling configurabile di vita, velocita e danno per ondata.
- Aggiunte boss wave ogni cinque ondate con zombie potenziati e richiesta al `BossSystem`.
- Collegati `SurvivalMode` e `GameModeManager` per avvio e arresto della modalita.
- Aggiunta condizione di sconfitta quando tutti i player attivi sono morti.
- Aggiunte ricompense di denaro, munizioni e cura tra le ondate.
- Esteso HUD con countdown, indice ondata, boss marker, nemici rimasti e ricompense.
- Rimossi gli spawn dimostrativi statici dalla scena principale in favore del loop survival.
- Aggiunto smoke test headless su tre ondate con scaling, reward, boss hook e join multiplayer.
- Aggiornata documentazione per stato Milestone 5 e prossima Milestone 6.
- Completata Milestone 6 come prototipo minimo boss system.
- Aggiunto boss `Wave Warden` con targeting multiplayer e movimento a distanza.
- Aggiunte fase 1 con raffiche mirate e fase 2 con raffiche radiali alternate.
- Aggiunta scena proiettile boss ostile integrata con `ProjectileSystem` e `HealthSystem`.
- Esteso `BossSystem` con scena predefinita, contenitore, boss attivo e notifica sconfitta.
- Integrato il boss reale nella quinta ondata survival con due zombie di scorta.
- Esteso `WaveManager` per contare e attendere il boss prima di completare la wave.
- Aggiunta barra vita boss con nome, fase e valori correnti.
- Aggiunta loot table boss con drop garantito `Wave Cannon`.
- Aggiunto smoke test headless boss con due player, pattern, fase, HUD, drop e prosecuzione.
- Aggiornata documentazione per stato Milestone 6 e prossima Milestone 7.
- Completata Milestone 7 come prototipo minimo dungeon procedurale.
- Reso `DungeonGenerator` deterministico da seed con celle uniche e link sequenziali.
- Aggiunta `DungeonRoom` riusabile con pareti, spawn party e portale bloccabile.
- Esteso `DungeonMode` con start, combat, loot e boss room.
- Aggiunti spawn e scaling progressivi dei nemici nelle stanze combat.
- Aggiunta loot table dungeon garantita per XP, denaro, munizioni e vita.
- Integrato il boss finale dungeon tramite `GameModeManager` e `BossSystem`.
- Esteso HUD con seed, stanza corrente, stato uscita e nemici rimasti.
- Aggiunte hotkey debug `F1` survival e `F5` dungeon.
- Corretto lo stop di survival per ripulire nemici e boss prima del cambio modalita.
- Aggiunto smoke test headless dungeon su generazione, transizioni, combat, loot, boss e ritorno a survival.
- Aggiornata documentazione per stato Milestone 7 e prossima Milestone 8.
- Completata Milestone 8 come prototipo minimo tower defense.
- Aggiunta arena dedicata con percorso a waypoint, core da difendere e tre slot costruzione.
- Aggiunto `TowerDefenseEnemy` con scaling, danno al core, health e drop condivisi.
- Esteso `EnemySystem` con registrazione di scene nemico per ID.
- Esteso `TowerDefenseManager` con reset run, crediti e acquisto centralizzato delle torri.
- Aggiunti `TowerBuildSlot` e input `interact` con `E`/joypad `A`.
- Aggiunta `DefenseTower` con targeting automatico e sparo tramite `ProjectileSystem`.
- Implementato ciclo ondate tower defense con spawn progressivo, ricompense e sconfitta core.
- Estratta la macchina a stati in `TowerDefenseWaveController` per mantenere modulare la modalita.
- Integrato il `Wave Warden` nelle boss wave tower defense tramite percorso opzionale.
- Aggiunti hotkey `F6` e stato HUD per core, crediti, wave e nemici.
- Reso differito lo spawn dei drop da morte per evitare modifiche al physics server durante le collisioni.
- Aggiunto smoke test headless tower defense e verificata l'intera suite Milestone 3-8.
- Aggiornata documentazione per stato Milestone 8 e prossima Milestone 9.
- Avviata Milestone 9 con stato iniziale `menu` al posto dell'avvio automatico survival.
- Aggiunto menu principale navigabile da tastiera e joypad per survival, dungeon e tower defense.
- Aggiunti `Continue`, ritorno al menu con `Esc` e sospensione input gameplay nel menu.
- Implementato `SaveManager` JSON versionato con autosave, validazione e ultima modalita.
- Esteso `ProgressionManager` con serializzazione e ripristino controllato.
- Aggiunto feedback audio UI procedurale senza asset esterni.
- Aggiunto preset export `Windows Desktop`.
- Generato e avviato headless `build/iso_local_sandbox.pck`.
- Aggiunto smoke test Milestone 9 per menu, save/load, autosave, dati non validi e selezione modalita.
- Aggiornati i test survival, boss e dungeon per il nuovo bootstrap da menu.
- Verificata la suite headless Milestone 3-9 con Godot `4.6.3`.
- Tentato export Windows; la generazione e bloccata dai template export Godot `4.6.3` assenti nell'ambiente.
- Installati i template export Windows Godot `4.6.3` dopo verifica SHA-512 ufficiale.
- Generata la build release `build/iso_local_sandbox.exe` con PCK separato.
- Aggiunto `BuildRuntimeSmoke` avviabile dalla release con `--build-smoke`.
- Aggiunto QA visuale ripetibile per menu, focus joypad, survival e ritorno al menu.
- Corretto il menu aggiungendo joypad `A` all'azione globale `ui_accept`.
- Esteso `AudioManager` con segnale e conteggio delle frame audio generate.
- Verificati controller XInput reale, driver audio WASAPI e feedback focus/conferma.
- Esclusi `tests/` e `build/` dal pacchetto release.
- Verificata la suite headless Milestone 3-9 e lo smoke della build con exit code `0`.
- Completata Milestone 9 come prototipo minimo.
- Aggiunto unlock persistente `Field Kit` al livello party 2 con 20 HP bonus a inizio run.
- Esteso il save JSON alla versione 2 con lista unlock e migrazione compatibile dei save v1.
- Aggiunto reset salute idempotente per nuove run e player entrati durante il gameplay.
- Aggiunto `GameModeManager.game_mode_started` per coprire anche il restart della stessa modalita.
- Aggiunto feedback audio procedurale condiviso per sparo, impatto valido e pickup.
- Estesi `Projectile` e `ProjectileSystem` con il contratto di impatto risolto.
- Mostrato lo stato unlock nel menu principale.
- Estesi smoke test Milestone 9, combat, drop e survival per i nuovi contratti.
- Verificata nuovamente la suite headless completa Milestone 3-9.
- Rigenerati EXE/PCK Windows e completato lo smoke della release con exit code `0`.
- Ripetuto il QA visuale del menu a 1280x720 con controller XInput e audio WASAPI.

### Changed

- Il roll/dodge considera attraversabili solo piccoli gap/fall zone; hazard
  ambientali come lava, gas e acqua profonda bloccano traiettoria e landing.
- Le transizioni bioma della survival usano ora passaggi aperti e aggiornamento regione; il teletrasporto resta solo come fallback esplicito.
- `BiomeMapGenerator` mantiene celle `200x200` ma produce topologia a grafo connesso invece della progressione percepita come sequenza di portali.
- Allineati i runner boss e stress a un teardown esplicito delle scene.
- Aggiunta chiusura idempotente dei player audio e degli stream procedurali.
- Documentato il crash headless intermittente di Godot 4.6.3 gia presente nel
  commit di partenza e separato dalle regressioni funzionali M15-M21.
- Aggiornata `ROADMAP_VISUAL_GAMEPLAY.md` con stato e risultati del ciclo
  completato M15-M21.
- Sostituiti i poligoni statici del `Wave Warden` con un visual modulare.
- Gli annunci importanti mantengono precedenza sull'intermissione successiva.
- Sostituito il visual statico della torre con un componente animato senza cambiare targeting o bilanciamento.
- Il flash di volata usa colore e dimensione del profilo del proiettile generato.
- Nascosti i bersagli combat debug durante il gameplay normale.
- Ridotta la saturazione dello sfondo survival per aumentare il contrasto degli attori.
- I drop ammo sostengono solo le armi speciali; la fallback non dipende dai drop.
- Le ricompense ammo survival vengono applicate agli slot speciali dei player vivi.
- Ridotto il fire rate della `Starter Pistol` da 7 a 6 colpi al secondo.
- Aumentato il fire rate del `Prototype Blaster` da 4 a 4,5 colpi al secondo.
- Ogni nuova run ripristina la vita dei player prima di applicare gli unlock persistenti.
- Aggiunti nomi propri, palette e path artistici data-driven ai quattro profili RPG zombie survival.
- Aggiornati Character Select, HUD e visual procedurale player per distinguere Mira, Dante, Bruna e Kael senza cambiare meccaniche.
- Aggiunta checklist visuale per validare silhouette, palette e sostituzione asset definitivi.
- Aggiunte tre classi RPG avanzate: Mago, Domatrice con Briciola e Licantropo trasformabile.
- Aggiunti weapon data, palette placeholder, passive e super prototipali per Elio, Nina e Rocco.
