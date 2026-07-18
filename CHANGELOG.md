# CHANGELOG

Registro sintetico delle modifiche principali. I dettagli operativi chiusi sono
consolidati in `README.md`, `ROADMAP.md`, `ARCHITECTURE.md`, `GAME_DESIGN.md`,
`docs/documentation_inventory.md` e nei report tecnici sotto `docs/`.

## Unreleased

### Added

- Importati otto alberi PNG trasparenti in quattro coppie adulto/giovane. Il
  manifest v16 espone pool visuali casuali per contesto e `forest_tree` sceglie
  deterministicamente una variante nella Pianura in base alla cella world-space,
  mantenendo invariati layout e footprint.

- `TERRAIN-PARCELS-001`: nuova pipeline terrain deterministica per regioni
  `75x75`, con route principali, sentieri interni e 7-10 lotti esclusivi
  `mesa/clearing/forest/fall_zone/town`; una mesa e una town sono garantite.
  Aggiunti pass separati di route/partizionamento/contenuto, API lotti nel layout,
  validazione di copertura/rim, town tematizzate con ingressi e vialetti,
  foreste dense, radure alberate e migrazione dei save layout-dependent.
  Validazione: fuzz 20x5 con 3024 assert, suite environment/assets/obstacles,
  smoke main e Visual QA dei cinque biomi.

- MCP server `0.2.0`: aggiunti `read_symbol_context` per leggere finestre
  sorgente attorno alle dichiarazioni GDScript e `changed_context` per mappare
  working tree, sistemi impattati, safe check e documentazione da riesaminare.
- Aggiunti paginazione/cursore a `list_project_files`, letture per intervallo e
  budget aggregato a `read_project_context`, `structuredContent` nelle risposte
  e test dedicati per indice e workflow.

### Fixed

- Le otto varianti `forest_tree` non riusano piu il collider storico da 96 px:
  i giovani usano un cerchio radici da 48 px e gli adulti uno da 72, 80 o 96 px
  secondo la silhouette. Il centro visuale delle radici, ricavato dalla fascia
  opaca inferiore del PNG, coincide ora con il centro del cerchio e con l'anchor
  Y-sort `(0, 24)` anche dopo il flip orizzontale.

- Erba, sentiero e asfalto della Pianura Infetta tornano a ripetere direttamente
  il raster normalizzato originale a periodo 256, senza atlas macro, specchi o
  rotazioni introdotti dalla precedente riscrittura delle superfici. La
  normalizzazione applica ora il crop perimetrale scelto di 40 px e un blend
  stretto di 8 px, eliminando la fascia d'ombra incorporata ai bordi dei PNG.

- La corona tecnica tra una route e una `fall_zone` usa ora la superficie dirt
  tematizzata invece del grass, senza cambiare collisioni o caduta.
- I lotti mesa usano dirt come base su tutte le celle non-route; la corona resta
  opaca fino alla base rocciosa e copre i cut-out degli angoli convessi con la
  stessa segmentazione della mesh, eliminando fasce e raccordi d'erba.
- La schivata diretta dentro una fall zone completa ora sempre la distanza del
  roll invece di fermarsi o usare il fallback corto; al termine il player
  rivaluta il void e avvia normalmente la caduta.
- I safe check MCP `build/test/smoke` su Windows non tentano piu di avviare
  direttamente `npm.cmd` con `shell: false`: usano il runtime Node corrente e
  la CLI npm locale, con fallback allowlisted. Lo smoke `stdio` esegue ora
  davvero `mcp:build` e verifica tool di contesto e blocco traversal.

- Tre criticità a rischio crash dal report `docs/repo_health_report_2026-07-17.md`:
  - `WeaponEffectResolver`: le esplosioni ritardate normalizzano target e
    attaccante liberati durante l'attesa prima di risolvere l'impatto
    (l'`is` su istanza freed errorava a runtime);
  - `ZombieModeController`: l'avvio async del mondo usa un token di
    generazione — `stop_run`/`start_run` durante il caricamento abbandonano
    la coroutine in volo invece di applicare il mondo a una run ferma (il
    worker thread viene comunque sempre raccolto);
  - `GameModeManager`: le hotkey debug F1/F5/F6/F7 di cambio modalità sono
    ora attive solo nelle build di sviluppo (`OS.is_debug_build()`), non
    più nell'eseguibile esportato.
- `SaveManager.save_game` verifica l'esito della scrittura del file
  temporaneo prima del rename atomico: un errore di I/O (es. disco pieno)
  non può più promuovere un save troncato e cancellare il backup valido
  (C4 del report `docs/repo_health_report_2026-07-17.md`).

### Changed

- `BIOME-REDEF-001`: la survival usa quattro ID canonici nella famiglia
  `plains`: `plains`, `burning_plains`, `frozen_tundra` e `swamp`. Pianura
  Ardente assorbe i precedenti band Tossico/Urban e Infuocato/Volcanic; i dati
  tossici restano archiviati ma non registrati. Aggiunti alias legacy,
  `biome_family_id`/`surface_theme_id`, revisione terrain/cache 6, risorse e
  manifest rinominati e QA riallineata ai quattro biomi.
- Il catalogo espone `burning_plains` come tema logico e mantiene un alias
  interno alla directory raster storica `volcanic`, così nessun consumer
  runtime usa più `volcanic` come identità di bioma.

- Nella Pianura tutti i divider dirt del renderer reale riusano ora la
  stessa istanza e scala world-space di `forest_dirt_path_generated.png` dei
  sentieri, inclusi confini del canvas terrain, cliff e contorni mesa; maschere,
  spessori, collisioni e materiali degli altri biomi restano invariati.

- Le town usano edifici con footprint/visuale/collider raddoppiati e 1-3
  veicoli; le mesa sono una montagna unica con angoli convessi arrotondati
  (`0,75` tile, 6 segmenti). Firma layout `v4`, revisione generatore/cache `5`,
  snapshot `v7` e manifest ambiente `v15` invalidano i dati precedenti.
- Rimossi dalla pipeline attiva scatter globale, macchie forestali, lottery del
  void e gruppi di mesa; gli hazard statici sono ora ammessi solo nelle radure.

- L'indice file MCP e condiviso in memoria con TTL breve; area e validazione
  vengono applicate prima della paginazione, le aree sconosciute sono errori
  espliciti e ricerca/simboli riusano metadata senza un secondo `stat`.
- Chiuso il gruppo gameplay 4.6 del repo health report senza cambi di
  bilanciamento: `CombatRewardUtils` assegna XP e kill confirm a nemici/boss,
  `TowerDefenseTargetUtils` risolve l'arrivo al core di raider/Wave Warden,
  `WaveCycle.process_state` guida il dispatch comune delle due macchine wave,
  il resolver tile usa una sola query dei bordi route e
  `EnvironmentAssetManifest` riusa `BiomeTileResolverUtils.asset_path_exists`.
  Import Godot e suite completa GUT verdi: 307/307 test, 30.666 assert.

- Deduplicazione dei gruppi P1 del report `docs/repo_health_report_2026-07-17.md`
  (solo refactor, nessun cambio di comportamento; suite completa 307/307):
  - nuovo `game/core/context_utils.gd` al posto delle copie private di
    `_get_context_bool`/`_get_context_string`/`_has_context_key`;
  - nuovo `game/core/geometry_utils.gd` (`clip_rect`, `inflate_rect`,
    `intersects_any`, `ellipse_points`) al posto di 25 copie private in
    generatori, pass di placement e visual; le query di piazzamento
    condivise (`rect_intersects_route`, `rect_overlaps_passage_corridor`,
    `rect_overlaps_road_cells`) sono ora metodi di
    `BiomeEnvironmentLayout` e l'ancora d'imbocco dei passaggi e'
    `BiomePassage.edge_anchor_cell`;
  - nuova base `BiomeZoneArea` condivisa da `BiomeFallZone` e
    `BiomeHazardZone` (test punto/distanza e collisione rettangolare);
  - nuovo `game/core/quad_mesh_buffers.gd` (create/append_quad/build_mesh)
    al posto delle otto copie del batching quad nei tre mesh builder di
    cliff e rocce (gruppo 4.2); il border builder conserva i wrapper
    rect-based che ora delegano al nucleo condiviso;
  - gruppo 4.5 (UI/audio/visual settings): statics
    `AudioManager.play_ui_focus_in`/`play_ui_confirm_in` per i wrapper dei
    menu, `BossSystem.connect_boss_feedback` per router audio e HUD, le tre
    copie di `_sync_visual_settings` sostituite dall'esistente
    `VisualSettingsManager.sync_consumer`, nuove basi `SettingsAwareVisual`
    e `PatternBossVisual` per tower/boss visual, rimosso
    `_apply_visual_profile` morto dal main menu;
  - chiusi anche i tre residui dopo verifica di equivalenza: la
    `_intersects_route` locale del prop pass e la
    `_rect_overlaps_road_cells` del map validation usano i metodi del
    layout (stesso esito booleano), e la palette cresta dirupo e' la
    statica condivisa `TopDownCliffRenderer.edge_color_for_style`.

- Completato `CHAR-DIR-001` per tutti i sette personaggi: gli atlanti raster
  alpha `4x4` usano righe Sud/Est/Nord/Ovest e colonne
  idle/anticipazione/tuck/recovery. Ogni profilo espone
  `directional_roll_atlas_path`; `PlayerVisual` seleziona la posa senza
  mirroring, sincronizza i tre frame del roll con la durata dodge esistente e
  nasconde il layer arma durante la capriola. Il fallback a pittogramma e
  silhouette procedurale resta disponibile per asset mancanti. Aggiunti
  manifest, validazione asset/GUT e tool Godot ripetibile per chroma key,
  despill, alpha nativo e padding uniforme della griglia.
- Validazione `CHAR-DIR-001`: import Godot e boot headless della scena
  principale PASS; GUT `assets` 79/79 (`11.276` assert) e `progression` 13/13
  (`327` assert) PASS. La checklist manuale copre i sette personaggi nelle
  quattro direzioni con tastiera/joypad, high contrast, reduced motion e 1-4
  player.
- Raddoppiate le dimensioni delle `SupplyCrate`: il manifest porta
  `supply_crate.visual_scale` a `2.30`, la collisione fisica della scena passa
  a `84x68` e il fallback procedurale del visual segue la stessa scala senza
  reintrodurre ombre o cerchi sul floor.
- Rimossa la proiezione di ombre runtime dagli asset ambiente: `EnvironmentObject`
  e il fallback `BiomeObstacle` non disegnano piu ellissi scure sul floor, e
  `SupplyCrateVisual` non aggiunge piu ombra o cerchio/glow intorno alle casse.
  I test asset aggiornano il contratto per impedire il ritorno di queste
  decorazioni.
- Allineate le hitbox ai raster ambientali che superavano il collider: `broken_fence`,
  `wood_barrier` e la variante `infected_plains` di `fallen_log` espandono la
  collisione sull'asse X, mentre `abandoned_car` la espande sull'asse Y. Il
  manifest sale a v14 con `variant_collision_size_ratios`, così il tronco SVG
  usato negli altri biomi conserva il collider precedente. Test asset e Visual
  QA hitbox verificano ora che l'asse corretto segua la silhouette raster.
- Corretta la copertura hitbox dei dieci raster della Pianura Infetta senza
  stretch: `small_rock`, `broken_fence`, `wood_barrier`, `fallen_log` e
  `abandoned_car` ricevono scale uniformi puntuali; quella del tronco resta
  limitata alla variante `infected_plains` e non ingrandisce lo SVG condiviso
  dagli altri biomi. Le casse comune e
  medica condividono un lieve aumento e vengono ancorate usando il bordo del
  contenuto opaco anziche il padding trasparente. Case e vegetazione, gia
  conformi, restano a scala `1.0`. La Visual QA hitbox ora mostra tutti i dieci
  raster e la suite asset verifica copertura X/Y e uguaglianza della scala sui
  due assi.
- Completato il primo pass `BIOME-RASTER-001` sulla Pianura Infetta: otto prop
  ambientali e le due varianti di cassa comune/medica usano ora dieci PNG
  originali con alpha, generati in proiezione top-down cardinale. ID, pool,
  footprint, collisioni, anchor e sort restano invariati. Il nuovo resolver
  `variant_asset_paths` seleziona il tronco raster solo per
  `infected_plains`, conservando lo SVG condiviso per neve e palude finche non
  riceveranno il relativo pass; la crate seleziona invece il raster per tipo.
  Il manifest ambiente sale a v13 e valida anche l'esistenza delle varianti.
- Validazione `BIOME-RASTER-001`: import Godot e generatore ambiente `132/132`
  PASS; GUT `assets` 79/79 (`10.985` assert), `environment` 47/47 (`9.369`
  assert), `obstacles` 27/27 (`1.193` assert) e `world_gen` 59/59 (`2.311`
  assert) PASS. Visual QA `obstacle_asset`, `biome_art_infected_plains`,
  `obstacle_hitbox_alignment` e `top_down_final` PASS; il boot reale della
  scena principale e incluso nelle ultime due verifiche.
- Corretto il rendering finale grass/cliff delle fall zone: il lip conserva ora
  le proporzioni world-space della porzione rocciosa invece di apparire come una
  fascia compressa, le run orizzontali generano i quattro corner convessi reali
  e una mesh sfumata con `terrain_divider_dirt` crea lo stesso stacco organico
  usato ai bordi delle strade. Nel tema forestale la cresta flat rock e stata
  ridotta a circa due quinti del rim; la fascia dirt ora deriva direttamente i
  propri `0,32` tile nominali dalla maschera stradale (`0,12` di nucleo pieno e
  `0,20` di feather esterno), mentre un feather di `0,10` tile ammorbidisce lo
  stacco lato pietra. Lo stesso profilo dirt viene generato sotto il footprint
  di tutte le mesa tematizzate. I corner dirt sono ora rotondi ovunque: la
  maschera delle strade usa distanza euclidea da segmenti indicizzati per cella,
  mentre mesa e fall zone generano raccordi radiali a quarto di cerchio.
  Nei vertici checkerboard, dove due void si toccano solo in diagonale, la flat
  rock resta rettilinea e solo il dirt usa due raccordi compatti da `0,42` tile;
  una patch void centrale comunica che il passaggio senza dodge causa caduta.
  Nei vertici con tre quadranti void la fascia dirt orizzontale termina ora al
  punto di tangenza con quella verticale e un solo quarto di cerchio raccorda
  il quadrante erboso, eliminando la precedente biforcazione a T.
  Collisione e regola di caduta restano invariate.
- Nella Pianura Infetta il tratto roccioso piatto prima del void riusa ora
  `rock_plateau_top_generated.png`, la stessa superficie top delle mesa, con UV
  planari world-space continui fra lati e corner; la parete discendente conserva
  invece `cliff_face_texture`.
- Il rilevamento caduta del player usa ora il baricentro del rettangolo
  `CollisionShape2D` a terra condiviso con le collisioni degli ostacoli: il solo
  contatto del bordo non causa una caduta. L'overlay `F9` include anche tutte le
  fall zone attive/streammate, evidenziate in rosa, con regressione GUT dedicata.
  Corretto inoltre l'anchor delle fall zone con dimensione pari nelle regioni
  dispari: il rettangolo rosa usa ora il centro geometrico dei confini tile e
  non presenta piu mezzo tile di offset sull'asse orizzontale o verticale.
- La mira dello zombie shooter risolve ora lo stesso baricentro della hitzone a
  terra del player, evitando che i proiettili passino sopra il collider dopo il
  suo allineamento ai piedi.
- Raddoppiata la resa runtime di `forest_tree` tramite `visual_scale = 2.0` e
  portato il collider circolare delle radici da 48 a 96 px di diametro. Il
  footprint di generazione resta `2x2` tile logiche, mentre gli alberi adiacenti
  che delimitano una strada ora si toccano fisicamente e non lasciano varchi
  attraversabili; aggiunta regressione GUT dedicata e checklist manuale `F9`.
- Completata `TERRAIN-MASK-001`: il rendering non deriva piu' strip, core e
  corner separati per ogni strada. `TerrainSurfaceClassifier` distingue le
  quattro superfici `grass`, `path`, `asphalt` e `void`; una maschera RGBA
  regionale a 8 px/tile conserva nei canali RGB i pesi delle superfici e in
  alpha il divisore tra celle diverse. Ogni chunk campiona la stessa maschera
  con `TerrainSurfaceCanvas` e uno shader dedicato, riusando le texture
  forestali o generated gia' presenti; il void resta un colore profondo
  uniforme. La fase UV include l'offset della regione streammata e resta
  continua sui seam. `TileBakeCache.FORMAT_VERSION` sale a 29 per invalidare i
  bake del precedente contratto edge/core/corner.
- Validazione `TERRAIN-MASK-001`: GUT `assets`, `environment`, `obstacles` e
  `world_gen` verdi per 201 test e 23.654 assert; import e boot della scena
  principale PASS; generatore top-down `132/132`; Visual QA della Pianura
  Infetta, tavola materiali generated e review completa dei cinque biomi
  (`210` capture) PASS.
- Il collider del player e ora un rettangolo a terra `28x16` centrato sulla sua
  ombra. Il contatto con le mesa conserva la distanza laterale precedente,
  elimina il gap visivo sul bordo sud e allinea correttamente anche il limite
  nord; aggiunta una regressione fisica sui due bordi verticali.
- I chasm interni della pipeline void-first mantengono ora una tile logica di
  distanza da strade e passaggi. Il margine riserva lo spazio del cliff lip e
  impedisce che erba o roccia vengano disegnate sull'asfalto quando una buca
  nasce accanto alla carreggiata. La revisione del generatore sale a 4 per
  invalidare le cache mondo precedenti; aggiunta una regressione GUT dedicata.
- Il manifest ambiente v12 separa footprint di placement e collisione fisica:
  `forest_tree` usa un cerchio di raggio 24 px e `dead_tree` uno di 12 px,
  entrambi centrati sulle radici a offset `(0, 24)`. Rimossa la base quadrata
  permanente dagli oggetti asset-backed; `F9` mostra ora la shape reale e
  player, boss e ostacoli condividono il sort anchor a terra.
- Tutti gli ostacoli, gli hazard e le fall zone ambiente sono bloccati a rotazione
  zero nella generazione attiva, nei percorsi legacy, nei layout manuali, nella
  validazione e come guardia runtime. Il campione RNG storico viene comunque
  consumato per non spostare ID e placement;
  firma layout v3, revisione generatore 3 e snapshot v6 invalidano le cache con
  vecchi angoli.
- Corretto il centro world-space geometrico delle mesa di lato pari: le mesa
  `3x3`-`5x5` hanno ora collider e visual sulla stessa origine anche nelle
  regioni dispari `75x75`.
  Corona e tre facce sono renderizzate dal singolo `large_rock` Y-sorted;
  `BiomeTileLayer` non produce piu il batch mesa a profondita fissa, consentendo
  attori simultaneamente dietro e davanti. Il repeat UV sul nodo impedisce che
  coordinate world-space fuori `0..1` stirino una riga della texture sulla corona.
- Completata `TOPDOWN-001`: definito il contratto `orthogonal_top_down` con
  `controlled_perspective`, assi world-space cartesiani e movimento analogico
  invariato. Documentazione e server MCP puntano ora al manifest
  `assets/environment/top_down/manifest.json`, alle classi projection-neutral
  e al generatore `generate_top_down_environment_assets.gd`; il generatore
  produce ground e route H/V, con facciata sud separata dal footprint per gli
  elementi dotati di volume. Changelog e report antecedenti al 2026-07-15
  restano evidenza storica e non definiscono nuovi asset.
- Sostituito il pass prop ad atlas del manifest v10: i 23 `object_scenes`
  interessati puntano ora a 23 SVG cardinali individuali `final` in
  `objects/generated_props/`, source `project_svg_generator` e attribution
  `environment_top_down_internal`. Rimosse le 23 risorse `AtlasTexture` `.tres`
  e le cinque tavole concept PNG; footprint, collisioni, anchor, sort e pool
  procedurali restano invariati.
- Aggiunto `tools/migrate_top_down_cliff_textures.gd`: normalizza in modo
  deterministico i 66 PNG cliff dei sei temi, separando materiale overhead per
  lip/angoli e materiale di parete per le facce. Il comando predefinito scrive
  la libreria migrata; `--check` valida conteggio e dimensioni senza mutazioni.
- Verifica finale `TOPDOWN-001`: import Godot PASS; GUT completo 286/286 con
  28.914 assert; generatore ambiente 131/131 e cliff 66/66; Visual QA
  `top_down_final`, menu e 31 oggetti campione PASS. Il boot reale di
  `main.tscn`, streaming multi-bioma, salvataggi e UI cardinali sono inclusi
  nelle suite verdi.

### Added

- Aggiunto il raster originale `terrain_divider_dirt_generated.png`, materiale
  di terra compatta ripetibile usato dal canale divisore della maschera. Il
  contratto CPU e coperto da `terrain_boundary_mask_test.gd`; la Visual QA
  `biome_art_infected_plains_visual_qa.gd` e' verde con texture esistenti,
  divisore, void uniforme e capture finale.

- Le boss wave di Survival, Infinite Arena e Tower Defense mantengono ora la
  normale progressione numerica dei minion; il boss viene aggiunto come extra
  invece di sostituire il conteggio con una piccola scorta fissa. Il
  `WaveDirector` applica anche ai minion delle boss wave i normali modificatori
  di bioma e pressione, con regressioni automatiche sulla continuita tra wave
  precedente, boss wave e wave successiva.

- Completata `ROSTER-001`: aggiunti quattro zombie elite tematici dalla wave 5
  (`Toxic Reaver`, `Ember Hound`, `Glacial Bulwark`, `Mire Stalker`) con
  selezione deterministica separata dal roster regolare e profili che
  combinano resistenze, status, emersione e hazard condivisi. Generati e
  integrati sette pittogrammi raster per preview e player world-space e otto
  PNG zombie per archetipi base/elite; `PlayerVisual` carica il path del profilo
  conservando facing, feedback di stato, layer arma e fallback procedurale,
  mentre `ZombieVisual` conserva bob, facing, hit flash e fallback. Manifest e
  attribuzioni registrano prompt e
  chroma-key processing. Verifica: import Godot, GUT assets 74/74 (10.344
  assert), GUT enemies 15/15 (560 assert), world_gen 58/58 (1.904 assert),
  progression 13/13 (297 assert), ui_audio 12/12 (263 assert), Visual QA
  world-space dei sette personaggi e build smoke della scena principale con
  exit code 0.

- Il pass prop del manifest v10 aveva promosso cinque tavole a 20 regioni
  `AtlasTexture` per 23 ID. Quel percorso e ora documentazione storica: il
  manifest v11 usa gli SVG individuali descritti sopra e i relativi `.tres` e
  concept PNG non sono piu presenti. La validazione del pass originale aveva
  chiuso GUT 275/275 (28.521 assert), asset check su 131 contratti, boot
  headless e board multi-bioma con 210 catture.

- Completata `WORLD-UNIFY-001` sul generatore void-first condiviso da Zombie
  Survival e Infinite Arena. Cinque `BiomeGenerationProfile` tipizzati
  configurano mesa, chasm, props e hazard: ogni bioma genera almeno un chasm
  interno salvo opt-out, mesa tematiche (10-16 in Pianura e 2-4 negli altri),
  10-16 props pesati da almeno due categorie e, nei quattro biomi avanzati,
  due hazard statici con placement sicuro. `BiomeEnvironmentLayout` separa
  mesa, masse e props; `MesaPlacementPass`, `StaticHazardPlacementPass` e
  `RandomPropPlacementPass` isolano le nuove responsabilita e quest'ultimo usa
  una scansione esaustiva se il sampling non raggiunge il target. Stream RNG
  dedicati evitano che un pass sposti le feature degli altri. `BiomeTileLayer` rende le mesa con corona `ground` e
  pareti `cliff_face` per i cinque temi. La firma canonica layout-v2, la
  revisione cache/generatore 2 e gli snapshot v5 invalidano dati precedenti o
  alterati. Aggiunti guardrail deterministici multi-bioma, placement e fuzz su
  20 seed x 5 biomi, oltre ai test mesh/collisione mesa e al fallback prop
  forzato. Visual QA verde su 210 catture (tre seed, cinque biomi, due
  risoluzioni e focus cliff/mesa/prop). Il successivo pass v10 aveva promosso
  cinque tavole a sorgenti runtime, poi sostituite nella migrazione v11 dai 23
  SVG cardinali individuali; tavole e ritagli `.tres` sono stati rimossi. Il
  giudizio manuale resta in `BAL-001`, i cui playtest non sono dichiarati
  completati.

- Chiusa `BOSS-002` con cinque boss zombie asset-backed per Infinite Arena e
  Zombie Survival: `Grave Colossus` e `Gore Charger` usano sweep, slam e
  cariche melee; `Plague Spitter` e `Bone Mortar` usano ventagli, anelli e
  raffiche a proiettile; `Carrion Shepherd` alterna bolt e falciata in base
  alla distanza. Ogni boss possiede movimento, due pattern, telegraph e
  warning HUD distinti; Survival li ruota dopo il `Wave Warden` nelle boss
  wave 5-30 e ripete la sequenza. Aggiunti `ZombieBossBase`, targeting melee
  ostile configurabile, `ZombieBossVisual` con fallback procedurale e cinque
  PNG originali generati internamente con alpha. Registry, scene, asset e
  rotazione sono coperti dalle suite GUT dedicate; suite completa verde
  (260/260 test) e boot headless della scena principale riuscito.

- Unificazione strade biomi, copertura bordo in survival
  (`docs/biome_road_unification_plan.md`): i corridoi passage tra biomi
  sorgono sopra spoke di lane del generatore e il tag lane sotto la cella
  vetava l'overlay di confine — strade asfaltate con il bordo solo su alcuni
  lati. Ora passage rect/connector o tag passage prevalgono sul tag lane in
  `route_cell_uses_lane_surface` (le lane pure restano senza bordo). Diagnosi
  con sonda headless sul mondo reale: celle coperte 51→147 (infected_plains)
  e 61→180 (toxic_wastes). Nuovo guardrail
  `test_passage_over_lane_spoke_keeps_road_border_overlay`, bump
  `TileBakeCache.FORMAT_VERSION` 26→27; GUT assets/environment e review QA
  verdi.

- Unificazione strade biomi, sorgente strip confine
  (`docs/biome_road_unification_plan.md`): l'overlay del confine strada/prato
  ora ritaglia la fascia di bordo dal PNG madre `road_border_defined` della
  strada dritta (per i temi generated crop pre-atlas con harmonize per-bioma
  sulla striscia, nuovo
  `GeneratedBiomeTextureTools.build_road_border_side_surface_texture`; per il
  forest dalla `forest_road_border_defined` orientata). Le texture
  `transition_ground_to_road_*` e `grass_to_road_generated` non sono piu'
  sorgenti runtime dell'overlay e le relative API di selezione sono rimosse.
  QA `biome_art_infected_plains` allineata al contratto post follow-up
  (base core + overlay `__edge_*`) e spacchettata in condizioni singole. GUT
  assets/environment e QA visuale (5 biomi, review, board generated_art)
  verdi. Tuning visibilita': strip a 1 tile
  (`ROAD_BORDER_OVERLAY_HALF_WIDTH_TILES` 0.32→0.5), crop allineato al core
  (`ROAD_BORDER_SIDE_STRIP_RATIO` 0.42→0.32, core + strip ricompongono
  l'asset madre) e feather alpha ridotto (0.22→0.08): prima la banda di bordo
  era quasi invisibile a schermo, ora il confine legge come nel PNG sorgente
  (verificato con zoom su frozen, toxic e forest).
- Unificazione strade biomi, fase 3 (`docs/biome_road_unification_plan.md`):
  fusi i rami route forest/generated del resolver in un percorso unico con
  helper passage condivisi (la logica endpoint/connector era quadruplicata);
  il materiale route di `infected_plains` e' ora assegnato dal resolver con la
  convenzione dei temi generated (`forest_road_border_defined__vertical`/
  `__horizontal`/`__core_*` dal contratto manifest `forest_road_border`), i
  texture id speciali `FOREST_ROAD_*` e la selezione per-cella duplicata sono
  rimossi dal tile layer; tile id semantici e resa visiva invariati. Bump
  `TileBakeCache.FORMAT_VERSION` 23→24. GUT assets/environment e QA visuale
  infected_plains/review verdi.
- Unificazione strade biomi, fase 2 (`docs/biome_road_unification_plan.md`):
  i bordi e gli incroci delle lane tematiche (`service_lane`, `ash_lane`,
  `packed_snow_path`, `wooden_walkway`, `broken_street`) renderizzano il
  materiale `path_variation` invece del bordo stradale quando nessuna strada
  principale attraversa la cella (nuovo
  `IsometricTileResolver.route_cell_uses_lane_surface`, tile id semantici
  invariati); il PNG `road_border_defined` di `urban_ruins` e' stato ruotato
  una tantum a nativo verticale come gli altri temi, eliminando il caso
  speciale di orientamento; bump `TileBakeCache.FORMAT_VERSION` 22→23 per
  invalidare le mappe material pre-unificazione. Guardrail lane-edge in
  `generated_texture_test.gd` e review QA lane-aware; GUT assets/environment
  e QA visuale toxic/review/generated_art verdi.
- Unificazione strade biomi, fasi 0-1 (`docs/biome_road_unification_plan.md`):
  `BiomeGeneratedArtCatalog` ora deriva sampling, stile strada, orientamento
  nativo del bordo e declassamenti ground da un contratto unico per tema
  (`THEME_CONTRACTS`), al posto di quattro liste parallele e dei branch
  per-tema; comportamento runtime invariato (fase 0). Le celle interne di
  `main_road`/`road` dei quattro biomi generated renderizzano il nuovo core
  ritagliato dal PNG `road_border_defined` (materiali
  `__core_vertical`/`__core_horizontal`, stesso crop 32% del core forestale,
  con atlas specchiato e harmonize per-bioma preservati), cosi' le strisce di
  bordo non si ripetono piu' in mezzo alle strade larghe; il follow-up
  edge/core estende lo stesso criterio a incroci, edge/curve e passage, mentre
  il bordo strada/prato viene disegnato come overlay mono-lato `__edge_*`
  derivato da `grass_to_road` / `transition_ground_to_road`, invece del PNG
  completo campionato come cella intera. Il crop core forestale
  e' condiviso in `GeneratedBiomeTextureTools.crop_road_core_texture`.
  Guardrail aggiornati in `generated_texture_test.gd` e
  `biome_rendering_review_visual_qa.gd`; GUT assets/environment e QA visuale
  frozen/review verdi.

- Chiusa `REL-001`: export Windows ripetibile da checkout pulito
  (`build/iso_local_sandbox.exe` 99,7 MB + `.pck` 44,4 MB, exit code 0),
  build smoke sull'eseguibile esportato PASS (flusso menu, Character Select,
  Infinite Arena e survival via joypad con controller XInput reale),
  attribuzioni asset complete e firma digitale chiusa come blocco esterno
  documentato (nessun certificato ne' signtool sul sistema). Nota: lanciare
  lo smoke senza `--log-file`; dettagli in
  `docs/latest_commit_validation_report.md`.
- Chiusa `TD-001` con l'upgrade delle torri a tre livelli: lo stesso gesto
  interact sullo slot occupato compra il livello successivo (35 poi 50
  crediti, rimborso se l'effetto non si applica), il danno sale x1.5, la
  cadenza x1.2 e la gittata x1.1 per livello, la base mostra un pip rombo per
  upgrade e lo slot espone il prompt "UP n C" finche' la torre non e' al
  massimo. Segnali dedicati `tower_upgraded`/`tower_upgrade_failed` sul
  `TowerDefenseManager`; nuovo `test_tower_upgrade_flow` in
  `core_modes_test.gd` e QA visuale con L1/L3/L2 affiancate attraverso il
  flusso crediti reale.
- Chiusa `BOSS-001` con il pattern avanzato `crescent_barrage` del Wave
  Warden: ventaglio di 7 proiettili a velocita' sfalsate (fronte a mezzaluna),
  telegraph dedicato che disegna il ventaglio e un fronte che avanza col
  countdown senza infliggere danno, warning HUD "CRESCENT BARRAGE -
  SIDESTEP" e rotazione a tre pattern dalla fase due (la fase uno resta solo
  aimed). Contratto registry/ID, compatibilita' per modalita' e drop
  invariati; copertura estesa in `boss_test.gd` (telegraph innocuo, ampiezza
  del ventaglio, stagger delle velocita', rotazione completa) e cattura
  dedicata nella QA telegraph.
- Aggiunto `test_advanced_class_niches` a
  `tests/suites/balance/weapon_balance_test.gd` (`BAL-001`): nicchie
  data-driven per le tre classi avanzate — mago glass cannon di precisione
  (attack ranged massimo, scatter zero, burst per caricatore, HP minimo del
  roster), domatrice a pressione continua (reload uptime massimo del comparto
  ranged, dispersione dimezzata rispetto alla pistola), licantropo melee
  veloce (cadenza e recupero migliori del comparto, velocita' massima tra i
  melee, HP tra spadaccino e berserker) — piu' il vincolo che nessuna coppia
  delle 7 classi condivida la stessa statline HP/ATK/DEF/SPD.
- Aggiunti gli smoke `QA-001` sui sistemi condivisi critici:
  `tests/suites/combat/health_edge_test.gd` (overkill e clamp, cap di cura,
  invulnerabilita' multipla e bypass, stati downed/dead, revive bounds,
  set_max_health, tracking della sorgente di danno con riferimenti liberati),
  `tests/suites/modes/multiplayer_midwave_test.gd` (join/leave locale a meta'
  ondata: joiner preparato per la run, retarget dei nemici dopo il leave,
  slot 1 non abbandonabile, wave completata con roster cambiato),
  `tests/suites/modes/save_edge_test.gd` (fallback sul .bak, salvataggi
  corrotti rifiutati senza toccare lo stato, write atomico senza residui,
  sanitize del last_mode, roundtrip dei binding join/leave) e
  `tests/suites/modes/mode_lifecycle_test.gd` (cicli menu/run su
  survival/dungeon/tower defense con cleanup di nemici e torri e vita piena a
  ogni nuova run). La suite completa sale a 247 test / 24.731 assert.
- Aggiunte le QA dedicate `ART-VIS-FIX` per i quattro biomi generated art
  (`biome_art_toxic_wastes`, `biome_art_burning_fields`,
  `biome_art_drowned_marsh`, `biome_art_frozen_outskirts`), tutte estese da
  `tests/visual_qa/biome_rendering_review_visual_qa.gd`: mondo streammato
  reale, seed `641004/772031/918273`, risoluzioni `1280x720` e `960x540` e
  viste center/passage/fall_cliff/obstacle_hazard/player_roster/route
  transition, con `resource_crate` per toxic_wastes e burning_fields e
  `reed_wall` per drowned_marsh, con lo stesso contratto di readiness del
  review (zero chunk visibili mancanti, coverage minima).
- Aggiunti cinque asset PNG `road_border_defined` per il rendering delle
  transizioni strada: `forest_road_border` per `infected_plains` e un materiale
  `ground_to_road` dedicato per `urban_ruins`, `volcanic`, `frozen_tundra` e
  `swamp`.
- Aggiunto il filtro `--only=id1,id2` a
  `tools/generate_isometric_environment_assets.gd` per rigenerare una singola
  famiglia di asset senza riscrivere il resto del catalogo.
- Aggiunto `tests/visual_qa/biome_art_infected_plains_visual_qa.gd`, QA
  mirata per `ART-VIS-FIX` che cattura Pianura Infetta con crossing
  road/path, bordo terreno-strada, cliff e cluster di alberi sotto
  `build/qa/biome_art_fix/infected_plains/`.
- Aggiunto `docs/biome_art_vis_fix_roadmap.md`, roadmap operativa per
  `ART-VIS-FIX` con pass per-bioma, QA dedicata, requisiti su texture armoniche
  senza bordi e transizioni terrain/road tramite immagini orientabili a taglio
  netto.
- Aggiunto `tests/visual_qa/helpers/visual_qa_runtime.gd`, contratto condiviso
  per attendere marker scenario, rimozione loading, terreno pronto e zero chunk
  visibili mancanti, con cleanup esplicito di scena e cache statiche.
- Aggiunto `docs/visual_qa_report_2026-07-01.md` con ispezione manuale di 225
  catture, severita, evidenze riproducibili e backlog proposto per UI, mondo,
  asset, armi e affidabilita del runner Visual QA.
- Aggiunto lo streaming visuale incrementale della Zombie Survival: il grafo
  `3x3` viene avviato una volta, mentre `BiomeTileChunkBaker`,
  `BiomeTileChunk` e `WorldChunkVisibilityController` mantengono attorno alla
  camera gli anelli visibile, prefetch e retention senza ricostruire il mondo
  ai seam.
- Aggiunte a `WorldRegionStreamer` le API `start_world`,
  `set_current_region`, `prepare_area`, `is_area_ready`,
  `get_loaded_visual_chunk_keys` e `get_streaming_stats`, con test
  deterministici per mapping camera/chunk, copertura e attraversamento.
- Aggiunto `tests/visual_qa/biome_rendering_review_visual_qa.gd`, harness
  mirato per catturare i cinque biomi Survival con seed fissi, doppia
  risoluzione, focus su centro, passaggi, cliff/void, ostacoli/hazard e roster
  tematico, con controlli leggeri su tile layer, fallback e dettaglio immagine.
- Aggiunto `tools/run_visual_qa.ps1`, runner Windows/PowerShell per i Visual QA
  con filtro per nome, import opzionale e log per script in `build/qa_logs/`.
- Aggiunto `IsoGridConfig` come contratto centrale per la nuova griglia
  isometrica: tile logico `6x6` legacy, scala world `48.0`, biomi `75x75`
  (`450x450` equivalenti legacy) e costanti condivise per strade, passaggi,
  bordi, rocce e conversione footprint.
- Aggiunto `docs/iso_grid_scale_migration_report.md` con metriche della
  migrazione, impatto su cache/snapshot e lista dei test eseguiti.
- Integrati 195 PNG generati e ripuliti sotto
  `assets/environment/isometric/generated_images/`. I quattro biomi Survival
  avanzati usano set tematici per ground, route, transizioni, cliff verso void e
  raised cliff, inclusi i nuovi bordi strada `road_border_defined`; `desert` e
  il nuovo set `forest` restano catalogati ma non assegnati.
  `BiomeGeneratedArtCatalog` assegna ruoli e varianti in modo deterministico.
- Infinite Arena rende i quattro lati `BLOCKED` come cliff rocciosi rialzati di
  due tile logiche. `BiomeEnvironmentLayout` distingue `procedural_wall` e
  `raised_cliff`; i segmenti conservano collisioni e Y-sort ma usano materiali
  world-space continui per parete e plateau. Aggiunti guardrail GUT e QA reale
  in `tests/visual_qa/infinite_arena_cliff_visual_qa.gd`.
- Aggiunto il server MCP locale read-only in `tools/mcp-server/`, separato dal
  runtime Godot. Usa Node.js/TypeScript, `@modelcontextprotocol/sdk` e transport
  `stdio`.
- Aggiunti gli script npm root `mcp:start`, `mcp:dev`, `mcp:build`,
  `mcp:test` e `mcp:smoke`, delegati al package `tools/mcp-server/`.
- Esposti 11 tool MCP: `repo_overview`, `list_project_files`,
  `read_project_context`, `search_project`, `game_system_summary`,
  `roadmap_context`, `run_safe_check`, `asset_inventory`, `codex_task_brief`,
  `git_context` (status/log/diff read-only, solo sottocomandi allowlisted) e
  `find_symbol` (indice a runtime di `class_name`, `extends`, `func`,
  `signal`, `const`, `enum` e classi interne GDScript, per nome e tipo).
- Esposti 5 prompt MCP operativi: `audit_isometric_generation`,
  `improve_zombie_mode`, `implement_roadmap_milestone`,
  `refactor_gameplay_system` e `asset_quality_pass`.
- La root del progetto MCP è rilevata risalendo fino al marker `project.godot`,
  indipendentemente da dove è clonato il repo e dalla profondità del file in
  esecuzione (dev `src/` o build `dist/src/`); la config Codex d'esempio usa
  `--prefix` relativo e un solo placeholder `<REPO_ROOT>` per `cwd`.
- Aggiunto `docs/documentation_inventory.md` come inventario dei Markdown vivi,
  storici e rimossi dopo il cleanup documentale.

### Changed

- Corretto il confine strada/prato dopo il refactor route biomi: le celle
  road-like (`main_road`, `road`, `road_intersection`, edge/curve e passage)
  usano sempre il core `road_border_defined__core_*` come superficie base,
  mentre `BiomeTileLayer` disegna sopra una strip `__edge_west/east/north/south`
  ricavata dalle texture `grass_to_road_generated` /
  `transition_ground_to_road_*`, solo sui lati che toccano terreno non-route.
  La strip sta a cavallo del confine (0,32 tile fuori e 0,32 dentro) e usa
  alpha feather ai margini, cosi le strade strette mantengono asfalto al centro
  e non raddoppiano la transizione sui bordi larghi. La scelta
  `transition_ground_to_road_*` ora preferisce la variante straight-road per
  tema invece dell'hash seed. Il resolver
  espone `route_cell_road_border_sides`, i controlli GUT coprono interni
  strada, incroci, passage core/edge e UV delle strip, e
  `TileBakeCache.FORMAT_VERSION` sale 24->26 per invalidare le mappe material
  obsolete.
- Completato il pass `UI-VIS-FIX` su gerarchia HUD, Character Select e boss
  HUD (finding `VIS-007`/`VIS-010`):
  - la card player e' compatta (240 px) e ad altezza contenuto, piazzata per
    angolo di ancoraggio + grow direction invece di una size fissa 276x184;
  - il faceplate world-space scende a `122x50` (da ~4x a ~2x la larghezza del
    player) mantenendo i contratti del layout snapshot (font >= 10, vita su
    due righe, super verticale >= 80%);
  - barra boss piu' stretta (360x64) e annuncio centrale compatto spostato
    sotto la barra, senza sovrapposizioni alle risoluzioni di riferimento;
  - Character Select interamente in italiano, slot liberi con hint di join
    ("Premi START sul pad per unirti"), fondale decorativo clippato nelle
    card, roster e dossier affiancati senza scrollbar a 1280x720;
  - stabilizzato `test_character_select_ui`: i check di safe-area attendono
    la passata deferred del layout dopo il resize del viewport.
- Completato il pass `ART-VIS-FIX` sui quattro biomi generated art
  (finding `VIS-002`/`VIS-005`, parziali `VIS-006`/`VIS-008`/`VIS-009`):
  - gli edifici generati (`ruined_house`, `lab_ruin`, `burned_house`,
    `abandoned_house`, `snow_cabin`, `sunken_house`, `lab_block`) sono stati
    ridisegnati come strutture con tetto muto, porta/finestre, fondazione
    scura e trim accent minimo; rimossi il tetto a tinta accent piena e i
    chevron da cassa, cosi' non leggono piu' come loot crate giganti;
  - la base occupata degli oggetti usa un bordo scuro invece dell'outline
    color accento che leggeva come marker di selezione;
  - i temi generati renderizzano le route a taglio netto: le transizioni verso
    path restano path diretto, mentre strade piene usano il core derivato da
    `road_border_defined` e bordi/curve aggiungono l'overlay mono-lato
    ground-to-road;
  - `main_road`, `road`, `road_intersection` e i passage road-like dei biomi
    generated art usano ora i PNG `road_border_defined` con core `__core_*`
    come base e overlay runtime `transition_ground_to_road_*__edge_*` solo sui
    margini strada/prato,
    mentre `service_lane`, `ash_lane`,
    `packed_snow_path` e `wooden_walkway` usano `path_variation`; le vecchie
    SVG `passage_tiles/*` e `road_variation` non sono piu la superficie
    runtime delle strade principali;
  - i PNG `road_border_defined` dei generated theme e
    `forest_road_border_defined` della Pianura Infetta vengono registrati come
    due materiali runtime orientati (`__horizontal`/`__vertical`): `urban_ruins`
    usa la sorgente orizzontale per `__horizontal` e la variante ruotata per
    `__vertical`, mentre gli altri generated theme mantengono la sorgente
    verticale nativa;
  - `toxic_wastes`: il ground pool usa solo la coppia coerente di rubble
    (variation 02/03); lichene chiaro e ghiaia bruna passano a `detail`,
    eliminando la scacchiera di pannelli per macro-cella;
  - `frozen_outskirts`: tono neutro anti-sovraesposizione sul manto nevoso,
    blend neve delle route ridotto (`0.10/0.12`) per separare ghiaccio e
    sentieri, harmonize dei bordi contro la griglia bianca da repeat;
  - `drowned_marsh`: lift caldo di path/road sopra la banda di luminanza del
    fango, downscale `0.45` delle strip cliff e `reed_wall` ridisegnata come
    canneto verticale full-canvas (`preserveAspectRatio="none"`);
  - `burning_fields`: damping selettivo dei pixel brace del ground per non
    competere con telegraph e fire hazard;
  - `BiomeTileLayer`/`BiomeTileChunk` usano filtering con mipmap e le texture
    generate normalizzate generano mipmap: elimina lo speckle delle strip
    cliff minificate sui bordi dei chasm.
  - `toxic_wastes` (`urban_ruins`) usa un materiale stabile per regione e
    ruolo, atlas runtime 2x2 specchiati con bordi armonizzati e repeat a
    scala nativa.
  - `frozen_outskirts` (`frozen_tundra`) e `drowned_marsh` (`swamp`) chiudono
    il polish sulla ripetizione del ground componendo a runtime una quilt
    `2x2` da quattro offset periodici dello stesso raster base, con blend
    interno/esterno e periodo world-space `1024`: i dettagli non si duplicano
    piu' ogni `512` e non usano mirror ne' varianti tonali; path e road
    mantengono densita e periodo `512`.
  - Le QA dedicate Tossico e Campi Ardenti aggiungono la vista
    `resource_crate` a conferma che, dopo il redesign di `lab_block`/
    `lab_ruin` (`VIS-005`), le vere supply crate restano compatte; la QA
    Palude aggiunge la vista `reed_wall`; la board
    `generated_biome_art_visual_qa.gd` mostra ora anche `BORDER V`/`BORDER H`
    per i quattro generated theme e ora espone anche `ROAD V`/`ROAD H`.
  - `TileBakeCache.FORMAT_VERSION` sale progressivamente fino a `26` mano a
    mano che ogni bioma normalizza i propri `material_asset_id` e i nuovi
    materiali strada/passage, invalidando le cache persistite obsolete.

- Pianura Infetta non renderizza piu `grass_to_path`, `grass_to_road` e
  `path_to_road` come texture intermedie: route principali, spoke
  `broken_street`, passage `road`/entry/exit e contatti verso terreno usano
  il core strada derivato da `forest_road_border_defined` come base e overlay
  `__edge_*` sui margini, mantenendo un taglio netto verso il terreno su
  entrambi gli assi e senza sovrapporre piu `forest_path` o `forest_road` sulle
  strade. `forest_tree` applica inoltre
  flip/tinta deterministici per ridurre la ripetizione senza cambiare
  collisioni o footprint.
- Ricalibrato il rendering dei cliff verso void per la griglia `6x6`: il lip
  rettilineo resta stretto e termina sulla prima cella di caduta, mentre le
  facce perimetrali scendono nel void senza comprimersi nella fall strip.
- Le celle `void_*` di transizione cliff non ricevono piu materiale terrain o
  underlay prato: il terreno resta sulle celle walkable `ground_to_void_cliff`,
  mentre il lato caduta mostra il fondale void sotto face e lip. Questo evita
  che le texture generated/forest continuino oltre l'edge dopo lo scaling
  `6x6`. `TileBakeCache.FORMAT_VERSION` sale a `11` per rigenerare le mappe
  `material_asset_*` persistite.
- Allineata la conversione `world_to_logical()` di `BiomeEnvironmentLayout`
  alla griglia `75x75`, evitando che il centro delle fall-zone perimetrali
  venga rimappato una tile piu interno rispetto alla collisione.
- I runner Visual QA PowerShell e Bash eseguono ora solo i 25 entry point
  standalone ed escludono i due helper WVIS caricati dall'orchestratore.
- Gli scenari gameplay Visual QA attendono readiness reale invece di un numero
  fisso di frame; il review biomi sospende il seam automatico durante i
  teleport controllati e valida `visible_missing_chunks == 0` a entrambe le
  risoluzioni.
- Il contratto Visual QA attende anche area prefetch pronta e code regioni/
  contenuti drenate; la QA isometrica finale attraversa un seam in 90 frame con
  zoom dinamico fino a `0.68`.
- Ottimizzato lo streaming visuale in movimento: il bake delle superfici
  generated raggruppa le run di tutti i materiali in una sola scansione del
  chunk, riducendo il costo rispetto alla scansione per-materiale.
  La coda viene ora aggiornata dalla camera prima del commit e riprioritizzata
  ogni frame, promuovendo i job che entrano in camera e la direzione di marcia.
- `WorldRegionStreamer.get_streaming_stats()` espone anche chunk visibili
  mancanti e tempi last/max/average dei commit, mentre
  `get_pending_visual_chunk_keys()` rende osservabile l'ordine effettivo della
  coda visuale. `BiomeTileLayer` separa ora conteggio logico totale, cache
  risolta e tile residenti anche mentre un worker e in corso.
- `WorldRegionStreamer` usa ora `WorldRuntime.active_regions` come autorita
  gameplay, aggiunge e rimuove solo il delta di regioni e conserva
  temporaneamente quelle contenenti player, nemici, boss o hazard runtime.
  Ostacoli, hazard, casse e tile layer hanno registrazione e rimozione
  simmetriche; le crate layout conservano il ledger persistente.
- Il bake asincrono di `BiomeTileLayer` produce solo dati CPU nel worker;
  texture, mesh, chunk e scene tree vengono creati sul main thread. Il commit
  visuale e limitato a due chunk e 2 ms per frame, con isteresi di 2 secondi.
- Raddoppiata la tile logica terrain da `3x3` a `6x6` celle legacy: le regioni
  passano da `150x150` a `75x75` tile logici, conservando la copertura
  world-space `450x450` legacy. Strade, passaggi, bordi, ostacoli void-first,
  chunk (`balanced` 10, `performance` 13, `quality` 8) e helper per larghezze
  dispari sono stati riallineati alla nuova scala senza cambiare il formato dei
  save persistenti.
- Incrementati `WorldSnapshotCodec.FORMAT_VERSION` a `4` e
  `TileBakeCache.FORMAT_VERSION` fino a `11`, cosi snapshot e bake tile
  precedenti alla nuova scala o al mapping cliff/void vengono ignorati e
  rigenerati senza cambiare seed o formato save persistente.
- Il loader texture isometrico carica i raster sorgente quando la cache `.ctex`
  locale non e stata importata, mantenendo separata la cache raster dalla cache
  SVG esposta ai test.
- Compattato questo changelog: il delta corrente resta in `Unreleased`, mentre
  la cronologia storica e stata ridotta a baseline archiviate e rimandi ai
  documenti proprietari.
- Riorganizzati README, ROADMAP, TODO e ARCHITECTURE intorno allo stato reale
  post-roadmap: baseline archiviate, backlog aperto minimo, contratti runtime e
  policy di retention documentale.
- Finalizzato il cutover GUT: i wrapper `tools/run_gut.sh` e
  `tools/run_gut.ps1` eseguono la suite rapida completa, mantengono il sottoinsieme
  golden e producono report JUnit in `build/test_logs/`.
- Rafforzato il cleanup delle suite GUT rapide e soak: fixture main scene senza
  cache persistente, teardown espliciti, rilascio cache mondo/manifest/texture e
  minori riferimenti statici nei test pesanti.
- I temi generati `frozen_tundra`, `swamp`, `urban_ruins` e `volcanic` usano
  ora selezione surface coerente a macro-celle anche per path/road/transizioni.
  Neve, palude, tossico e fuoco escludono detail/feature tile dal pool ground
  pieno. `TileBakeCache.FORMAT_VERSION` sale a `8` per rigenerare le mappe
  `material_asset_*` persistite.
- Chiarito il contratto MCP in `README.md` e `ARCHITECTURE.md`: il server lavora
  dentro la root progetto, legge solo contesto testuale, blocca traversal e file
  sensibili, limita ricerche/output e consente solo safe check allowlisted.

### Fixed

- Uniformata la fase UV delle facce cliff ai corner: pareti orizzontali e
  verticali ora usano la stessa proiezione planare world-space `x, y` per ogni
  vertice finale. L'intero seam campiona quindi gli stessi texel su entrambi i
  lati, eliminando lo stacco chiaro/scuro causato dall'illuminazione baked; il
  fade verso il void resta separato nei vertex color. Aggiunti guardrail GUT su
  proiezione e raccordi, piu verifica sulle quattro concavita della Visual QA.
- Spostato il lip roccioso dei chasm sul lato walkable del confine logico: le
  strisce verticali e inferiori non occupano piu celle gia classificate come
  void/fall zone e non suggeriscono false mensole calpestabili. Le pareti
  continuano a partire dal confine e a dissolversi nel void; gli angoli concavi
  conservano la giunzione orizzontale, quelli convessi mantengono entrambi i
  bordi completi. Collisione, danno e recovery dalla caduta restano invariati;
  aggiunti guardrail GUT sui bounds e verifica Visual QA dedicata.
- Uniformata la profondita visuale della parete nord dei chasm interni a `1,75`
  tile: non dipende piu' dal numero di celle void dietro il bordo. Il contorno
  unificato classifica ora i vertici ortogonali e combina in anticipo i drop
  delle due run incidenti: entrambi i quad condividono lo stesso seam profondo,
  senza triangoli corner, mensole, sovrapposizioni o quadranti neri. Il contratto
  e' verificato su L, T, croce e quattro orientamenti specchiati; la board Visual
  QA mostra contemporaneamente i quattro raccordi concavi. Nei corner convessi
  le facce laterali vengono ora clippate fra i bordi profondi delle pareti
  orizzontali, eliminando la fascia verticale che le attraversava; il lip
  verticale resta un underlay e solo quello orizzontale viene composto sopra.
- Allineati gli sprite `floor_center` degli ostacoli asset-backed al centro del
  rispettivo collider fisico. Case e prop non vengono piu' appoggiati per errore
  sul bordo sud del footprint, eliminando il forte offset verticale visibile con
  l'overlay `F9`; aggiunte una regressione GUT su `ruined_house` e una board
  Visual QA comparativa per gli anchor `floor_center`/`bottom_center`.
- Unificato il contorno visuale dei `fall_zone_rects` adiacenti o
  sovrapposti: `FallZoneBoundaryRuns` rasterizza l'unione logica dei void e
  fornisce ai builder solo i segmenti esposti verso terreno. Lip e facce cliff
  non disegnano piu' linee orizzontali o verticali sul lato condiviso fra due
  chasm che costituiscono un unico vuoto; collisioni e classificazione terrain
  restano invariate. Aggiunto un guardrail GUT su un'unione a T che verifica
  l'assenza del seam condiviso e i conteggi delle mesh risultanti.
- Rimosso il cap visuale duplicato delle `large_rock`/mesa: il top cobble viene
  disegnato una sola volta da `BiomeTileLayer` e `IsometricEnvironmentObject`
  non crea piu' `RockAreaOccluderVisual`, eliminando la lastra sovrapposta e
  shiftata senza cambiare collisioni, blocker o classificazione dietro/davanti.
- Rimossi i triangoli neri ai lati e agli angoli inferiori dei pit cliff dopo
  l'ingrandimento del tile base: con il renderer rettilineo attivo, i
  `void_transition` non emettono piu' il diamond flat scuro sottostante e le
  pareti laterali degli scavi interni usano strip verticali clipped tra faccia
  alta e bassa, senza diagonali scure nei corner.
- Ripristinato il rendering asset-backed dei tile semantici nei biomi con
  `generated_theme_id`: `IsometricTileResolver` non sovrascrive piu' `asset_path`
  di route/passaggi manifest (`service_lane`, `ash_lane`, `packed_snow_path`,
  `wooden_walkway`, `bridge`, `snow_pass`, `broken_gate`, `burned_road`,
  entry/exit) con i PNG generated; `BiomeTileLayer` li carica come texture SVG
  `section/tile`, li include nei mesh surface e la tile bake cache sale a v16.
- `HealthSystem.get_last_damage_source` non genera piu' un errore engine
  quando la sorgente dell'ultimo danno e' stata liberata nel frattempo (nemico
  o player despawnato): il check di validita' avviene sul Variant prima del
  cast a `Node`. Scovato dal nuovo `health_edge_test` di `QA-001`.
- Chiuso `WEAPON-VIS-FIX` (`VIS-011`): silhouette ridisegnate per
  `quick_knife` (daga con guardia), `spear` (lancia a foglia) e
  `chain_lightning` (saetta a nastro, anche come proiettile); `fireball` e
  `unstable_void` ora si distinguono per massa e ritmo (cometa con coda vs
  vortice a quattro cuspidi), non solo per palette; il contenitore dei weapon
  pickup e' attenuato con l'arma in scala maggiorata (high contrast
  invariato); lo slash thrust disegna una lama poligonale con glow e speed
  line. Board WVIS con tutte le label, scenario crowded reale nei tre preset e
  suite `combat` 20/20.
- Chiuso il residuo `VIS-009` (con `VIS-008`): `broken_fence` ridisegnato
  full-canvas `99x56` e rasterizzato a dimensione nativa senza
  letterbox/doppio resample (id in `NATIVE_RASTER_OBJECT_IDS`, guardrail in
  `object_asset_test`); `large_rock` riclassificato senza difetto di prodotto
  (in gioco e' l'area plateau dedicata con QA `rock_area_visual_qa`);
  `forest_tree` confermato hero asset raster con variazione flip/tinta
  deterministica.
- Chiuso `VIS-012`: il main menu usa un fondale con gradiente notturno,
  griglia isometrica e tessere diamante nei toni dei cinque biomi
  (`MainMenuBackdrop`, disegno statico compatibile con reduced motion), card
  ad altezza contenuto in stile UI condiviso, lingua uniformata all'italiano e
  layout compatto sotto i 620 px di altezza viewport; card verificata dentro
  il viewport a 1280x720, 1024x768 e 960x540.
- Stabilizzato `test_weapon_tower_visual_identity`
  (`tests/suites/combat/drops_test.gd`), il rosso noto della suite `combat`:
  il bersaglio di test moriva sotto il fuoco della torre stessa durante
  l'attesa (38 HP contro colpi da 16 a fire rate 20), la torre azzerava
  correttamente tracking e feedback sul bersaglio morto e gli assert
  fotografavano lo stato idle; `assert_eq(tower.target, target)` mascherava la
  morte perche' un'istanza liberata confronta uguale a `null`. Il bersaglio usa
  ora `health_multiplier` 100 e un guard assert dedicato fallisce in modo
  esplicito se il bersaglio non sopravvive alla finestra di tracking. Suite
  `combat` 20/20 (1.644 assert).
  minime piu compatte, tab Video/Controls con scroll interno che segue il focus
  e Back sempre fuori dallo scroll, con guardrail a 1280x720, 1024x768 e
  960x540.
- Normalizzato in modo sistematico il caricamento runtime dei cliff PNG
  generati: facce, lip e varianti dei biomi avanzati ora tagliano il bordo
  chiaro, propagano i colori nei pixel alpha e condividono la stessa policy tra
  `BiomeTileLayer` e raised cliff perimetrali, riducendo le strisce bianche tra
  texture cliff di biomi diversi.
- Eliminate le 26 catture principali ferme sul loading: menu, modalita,
  enemy/boss, revive, risultati, accessibilita, WVIS crowded e panoramiche
  bioma verificano ora un marker specifico prima di salvare.
- Ripristinata la QA isometrica finale con generazione sincrona deterministica;
  tutte le cinque viste bioma e la sequenza chase vengono rigenerate senza race
  sul clone della cache mondo.
- Allineato il test cliff Infinite Arena al contratto runtime: vieta fall zone
  sul perimetro `walled`, ma ammette i chasm interni condivisi.
- Stabilizzati revive progress e cliff transition QA, separando il setup
  visuale dal polling input e verificando le transizioni dopo il commit del
  relativo chunk.
- Riallineati i focus Visual QA alla griglia `6x6`: le regioni non iniziali
  inquadrano una cella walkable centrale e i sentieri larghi due tile accettano
  `grass_to_path` come campione runtime quando non esiste un core interno.
- Corretto il falso zero di `visible_missing_chunks` per le regioni visibili
  con tile layer ancora in build; `is_area_ready()` resta falso finche il layer
  non puo fornire i chunk richiesti.
- Eliminata la race residua tra readiness logica e rendering viewport: il
  contratto condiviso prepara il rettangolo della posizione camera target,
  richiede tre frame stabili e attende due `frame_post_draw`. Il review biomi
  rifiuta inoltre immagini con copertura world non-nera inferiore al 30%.
- Rafforzata la validazione mondo: ostacoli fuori regione o sovrapposti alle
  fall zone vengono rifiutati, ogni contatto ground/void deve risolvere a un
  cliff e ogni transizione deve produrre la relativa mesh.
- `boss_telegraph_visual_qa.gd` attende ora che le regioni streaming siano FULL,
  i tile layer abbiano finito il bake e i chunk visibili/prefetch siano residenti
  prima di salvare gli screenshot dei telegraph boss.
- Rimossi i seam bianchi regolari dai biomi Survival con asset generati: le
  surface terrain ripetute vengono caricate con un trim runtime di 2 px sul
  bordo chiaro e le mesh dei run generati usano un piccolo overdraw senza
  spostare gli UV, lasciando invariati collisioni, pathfinding e regole bioma.
- Reso piu armonico `frozen_outskirts`: passaggi e ground non alternano piu
  materiali neve/ghiaccio per-cella o detail decal a piena superficie, riducendo
  i blocchi ad alto contrasto nelle catture QA.
- Rifinito ulteriormente `frozen_outskirts`: il ground pieno usa solo la base
  neve pulita, mentre path e road generated vengono ammorbiditi verso la palette
  neve a runtime. `TileBakeCache.FORMAT_VERSION` sale a `9` per rigenerare le
  mappe materiali persistite.
- Reso piu armonico `drowned_marsh`: il ground runtime non usa piu detail decal
  o tile pieni di muschio/ninfee come superficie base, riducendo il mosaico
  acqua/fango/vegetazione nelle catture QA.
- Reso piu armonico `toxic_wastes`: i detail `urban_ruins` con sfondo chiaro
  non vengono piu usati come ground pieno, eliminando i grandi blocchi bianchi
  tra cemento, strada e cliff nelle catture QA.
- Reso piu armonico `burning_fields`: detail lava e la base a lava fluida non
  vengono piu usati come ground pieno, riducendo i riquadri ad alto contrasto e
  lasciando la lava come accento/feature.
- Rifinito ulteriormente `burning_fields`: surface, cliff face e cliff lip
  vulcanici usano crop runtime piu aggressivo e armonizzazione dei bordi
  opposti, riducendo le strisce chiare prodotte dalla ripetizione dei PNG
  generati senza cambiare collisioni, pathfinding o regole bioma.
- Preservati tile `*_entry` dei passaggi anche con apertura profonda una sola
  cella: il resolver assegna l'entry alla prima cella interna del connector e
  mantiene `*_exit` sul bordo esterno.
- Il carving delle strade void-first non marca piu come strada le celle occupate
  da rocce scalabili dopo la riscalatura.
- Corretto il tentativo di skin swamp su `toxic_wastes`: il bioma usa ora il
  tema `urban_ruins`, i duplicati swamp sono stati rimossi e i test verificano
  materiali realmente consumati da mesh non vuote.
- Chiuso il perimetro `walled` di Infinite Arena anche dove le strade
  decorative raggiungono il bordo: validazione e `repair_layout()` riconoscono i
  wall segment come endpoint solidi e preservano il relativo `BiomeObstacle`.
- Eliminati i residui di shutdown della suite rapida GUT legati a fixture,
  risorse `Script`, children non liberati, cache statiche, dati mondo ciclici,
  UID GUT vendorizzati e proiettili orfani nei test sintetici.
- `tools/run_gut.ps1` preserva l'exit code Godot anche sotto redirezione log,
  evitando falsi fallimenti negli audit warning locali.
- `HUDManager` nasconde subito pannello, barra e warning del boss quando il boss
  viene sconfitto.
- `InfiniteArenaMode` rispetta un override esplicito di `async_world_build`,
  mantenendo async di default nelle run reali e setup sincroni nei test metrici.

### Removed

- Rimossi Markdown storici completati, prompt grezzi, roadmap duplicate e file
  milestone obsoleti. Le informazioni ancora utili sono consolidate in
  `README.md`, `ROADMAP.md`, `ARCHITECTURE.md`, `GAME_DESIGN.md`,
  `CHANGELOG.md`, `docs/documentation_inventory.md` e nei report correnti.
- Ripulito `TODO.md` dalle sezioni chiuse e storiche: resta solo backlog aperto
  con obiettivo, milestone collegata, file coinvolti, criteri di accettazione e
  test richiesti.

### Validation

- `./tools/run_gut.ps1`: 275/275 test, 28.521 assert, passa;
  include fuzz 20 seed x 5 biomi e fallback prop forzato senza sampling.
- `./tools/run_visual_qa.ps1 -SkipImport -Filter biome_rendering_review`: passa;
  rigenerate 210 catture (3 seed x 5 biomi x 7 focus x 2 risoluzioni).
- `./tools/run_visual_qa.ps1 -SkipImport -Filter rock_area`: passa.
- Asset generator `--check`: 131 contratti; boot headless della scena principale
  per 120 frame: exit code 0.
- `./tools/run_gut.ps1 -GutDir res://tests/suites/assets -Select generated_texture`:
  26 test, 2.586 assert, passa.
- `./tools/run_gut.ps1 -GutDir res://tests/suites/assets`: 71 test, 10.236
  assert, passa.
- `./tools/run_gut.ps1 -GutDir res://tests/suites/environment`: 37 test,
  8.954 assert, passa.
- `./tools/run_gut.ps1 -GutDir res://tests/suites/world_gen`: 48 test, 352
  assert, passa.
- `godot --path . --script res://tests/visual_qa/biome_rendering_review_visual_qa.gd`:
  exit code 0, rigenerati i PNG in `build/qa/biome_rendering_review`.
- `./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/assets -Select generated_texture`:
  24 test, 1.953 assert, passa.
- `./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/assets`: 64 test,
  8.801 assert, passa; profilo chunk massimo 14,474 ms.
- `./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/environment`: 37
  test, 8.954 assert, passa; `visible_missing_chunks == 0` e commit massimo
  osservato 5,467 ms.
- `./tools/run_visual_qa.ps1 -SkipImport -Filter biome_art_drowned_marsh`: 1
  Visual QA, passa; rigenerate 42 PNG e ispezionate le viste center, passage e
  route transition a entrambe le risoluzioni.
- `./tools/run_visual_qa.ps1 -SkipImport -Filter biome_rendering_review`: 1
  Visual QA, passa; rigenerate 150 PNG sui cinque biomi.
- `./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/assets -Select generated_texture`:
  24 test, 1.947 assert, passa.
- `./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/assets`: 64 test,
  8.795 assert, passa; profilo chunk massimo 14,265 ms.
- `./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/environment`: 37
  test, 8.954 assert, passa; `visible_missing_chunks == 0` e commit massimo
  osservato 11,315 ms.
- `./tools/run_visual_qa.ps1 -SkipImport -Filter biome_art_frozen_outskirts`:
  1 Visual QA, passa; rigenerate 36 PNG e ispezionate le viste center, passage
  e route transition a entrambe le risoluzioni.
- `./tools/run_visual_qa.ps1 -SkipImport -Filter biome_rendering_review`: 1
  Visual QA, passa; rigenerate 150 PNG sui cinque biomi.
- `godot --headless --path . --script res://tools/generate_isometric_environment_assets.gd -- --check`:
  130 asset controllati, passa.
- `./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/assets -Select object_asset`:
  8 test, 476 assert, passa.
- `./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/assets`: 64 test,
  8.789 assert, passa; profilo chunk massimo 15,336 ms.
- `./tools/run_visual_qa.ps1 -SkipImport -Filter obstacle_asset`: 1 Visual QA,
  passa; `reed_wall` ispezionato.
- `./tools/run_visual_qa.ps1 -SkipImport -Filter biome_art_drowned_marsh`: 1
  Visual QA, passa; rigenerate 42 PNG e ispezionate le 6 viste `reed_wall`.
- `godot --headless --path . --script res://tools/generate_isometric_environment_assets.gd -- --check`:
  130 asset controllati, passa.
- `./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/assets -Select object_asset`:
  8 test, 453 assert, passa.
- `./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/assets`: 64 test,
  8.766 assert, passa; profilo chunk massimo 14,995 ms.
- `./tools/run_visual_qa.ps1 -SkipImport -Filter obstacle_asset`: 1 Visual QA,
  passa; `lab_block` e `lab_ruin` ispezionati.
- `./tools/run_visual_qa.ps1 -SkipImport -Filter biome_art_toxic_wastes`: 1
  Visual QA, passa; rigenerate e ispezionate 42 PNG.
- `./tools/run_visual_qa.ps1 -SkipImport -Filter biome_art_burning_fields`: 1
  Visual QA, passa; rigenerate e ispezionate 42 PNG.
- `./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/assets -Select generated_texture`:
  24 test, 1.941 assert, passa; profilo chunk massimo 19,259 ms.
- `./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/assets`: 64 test,
  8.760 assert, passa; profilo chunk massimo 16,837 ms.
- `./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/environment`: 37
  test, 8.954 assert, passa; il profilo direzionale mantiene
  `visible_missing_chunks == 0` e commit massimo osservato 6,946 ms.
- `./tools/run_visual_qa.ps1 -SkipImport -Filter biome_art_burning_fields`: 1
  Visual QA, passa; rigenerate e ispezionate 36 PNG.
- `./tools/run_visual_qa.ps1 -SkipImport -Filter biome_rendering_review`: 1
  Visual QA, passa; rigenerate 150 PNG sui cinque biomi.
- `./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/assets -Select generated_texture`:
  24 test, 1.821 assert, passa.
- `./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/assets`: 64 test,
  8.640 assert, passa.
- `./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/environment`: 37
  test, 8.954 assert, passa; il profilo direzionale mantiene
  `visible_missing_chunks == 0` e commit massimo osservato 7,237 ms.
- `./tools/run_visual_qa.ps1 -SkipImport -Filter biome_art_drowned_marsh`: 1
  Visual QA, passa; rigenerate e ispezionate 36 PNG.
- `./tools/run_visual_qa.ps1 -SkipImport -Filter biome_rendering_review`: 1
  Visual QA, passa; rigenerate 150 PNG sui cinque biomi.
- `./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/assets -Select generated_texture`:
  24 test, 1.824 assert, passa.
- `./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/assets`: 64 test,
  8.643 assert, passa.
- `./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/environment`: 37
  test, 8.954 assert, passa; il profilo direzionale mantiene
  `visible_missing_chunks == 0` e commit massimo osservato 6,358 ms.
- `./tools/run_visual_qa.ps1 -SkipImport -Filter biome_art_frozen_outskirts`:
  1 Visual QA, passa; rigenerate e ispezionate 36 PNG.
- `./tools/run_visual_qa.ps1 -SkipImport -Filter biome_rendering_review`: 1
  Visual QA, passa; rigenerate 150 PNG sui cinque biomi.
- `./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/ui_audio`: 12
  test, 263 assert, passa.
- `./tools/run_visual_qa.ps1 -SkipImport -Filter visual_accessibility`: 1
  Visual QA, passa; il log conferma safe area Settings a 1280x720, 1024x768 e
  960x540.
- `./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/environment`:
  37 test, 8.954 assert, passa; il profilo movimento/zoom mantiene
  `visible_missing_chunks == 0` e commit massimo osservato 8,271 ms.
- `./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/world_gen`:
  48 test, 352 assert, passa.
- `./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/assets -Select void_cliff`:
  7 test, 594 assert, passa.
- `./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/modes -Select zombie_modes`:
  4 test, 1.616 assert, passa.
- `./tools/run_visual_qa.ps1 -SkipImport`: WORLD-VIS-FIX finale, 25 entry point,
  25 OK e 0 falliti; rigenerati 47 PNG root e 150 PNG review biomi. Tutte le
  150 viste superano la coverage world e i 25 log non contengono failure,
  errori, leak o risorse residue.
- `./tools/run_visual_qa.ps1 -SkipImport`: 25 entry point standalone, 25 OK,
  0 falliti, exit code `0`; rigenerati 47 PNG root e 150 PNG review biomi.
  La contact sheet root non contiene loading e i 25 log non riportano failure,
  errori, leak `ObjectDB` o risorse residue.
- `./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/world_gen -Select world_data_cache`:
  11 test, 34 assert, passa.
- `./tools/run_visual_qa.ps1`: 27 script eseguiti, 22 OK e 5 falliti; esito
  complessivo NON PASS. Due failure sono helper lanciati erroneamente come
  standalone, mentre restano failure reali su cliff Infinite Arena, cache della
  QA isometrica finale e scenario crowded WVIS. L'ispezione manuale rileva che
  26 delle 40 catture principali mostrano ancora il loading; dettagli in
  `docs/visual_qa_report_2026-07-01.md`.
- `./tools/run_visual_qa.ps1 -SkipImport -Filter boss_telegraph`: 1 Visual QA,
  passa.
- `./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/assets -Select generated_texture`:
  21 test, 1680 assert, passa.
- `./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/assets`: 59
  test, 8325 assert, passa.
- `./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/world_gen -Select golden_snapshot_bake`:
  4 test, 20 assert, passa.
- `./tools/run_visual_qa.ps1 -SkipImport -Filter biome_rendering_review`: 1
  Visual QA, passa; rigenerate 150 catture in
  `build/qa/biome_rendering_review/`.
- `godot --version`: `4.6.3.stable.official.7d41c59c4`.
- `godot --headless --path . --import`: passa.
- `godot --headless --path . --script res://tools/prepare_generated_biome_assets.gd -- --check`:
  passa.
- `godot --headless --path . --script res://tools/generate_isometric_environment_assets.gd -- --check`:
  passa, `checked=130`.
- `./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/environment`:
  Godot completa con report JUnit `gut_gutconfig_20260701_183934.xml`, 35 test,
  24705 assert e 0 failure; il wrapper locale e scaduto prima del riepilogo.
- `./tools/run_visual_qa.ps1 -SkipImport -Filter biome`: 3 Visual QA, passa;
  `biome_rendering_review_visual_qa.gd` genera 150 PNG sotto
  `build/qa/biome_rendering_review/`.
- `./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/world_gen`: 48
  test, 350 assert, passa.
- `./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/obstacles`: 16
  test, 424 assert, passa.
- `./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/environment`: 34
  test, 2164 assert, passa.
- `./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/modes -Select zombie_modes`:
  4 test, 1600 assert, passa.
- `./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/assets -Select texture_cache`:
  1 test, 13 assert, passa.
- `npm run mcp:build`: passa.
- `npm run mcp:test`: 5 file test (aggiunti `git_context`, `find_symbol` e
  detection della root via marker `project.godot`); da rieseguire in locale
  dove Node è installato.
- `npm run mcp:smoke`: attesa lista di 11 tool MCP e 5 prompt.
- Nota locale: `npm run mcp:smoke` stampa un warning npm su
  `metrics-registry`; non blocca build, test o smoke.

## Baseline Archiviata

Questa sezione compatta le milestone chiuse. Le regole di gioco vivono in
`GAME_DESIGN.md`, i contratti runtime in `ARCHITECTURE.md`, lo stato attuale in
`README.md`, il backlog aperto in `TODO.md` e la direzione in `ROADMAP.md`.

### Fondazione e Modalita Base

- Inizializzati repository Git, progetto Godot 4.x testuale, scena principale
  pseudo-isometrica, input tastiera/joypad, player controller, camera di gruppo,
  multiplayer locale 1-4 player e HUD slot.
- Completati combat, health, projectile, nemici, drop, loot table, progressione
  party, pickup fisici e inventario armi per-player.
- Completate le tre modalita principali: zombie survival a ondate con boss,
  dungeon procedurale lineare con boss finale e tower defense con core, crediti,
  torri e boss wave.
- Aggiunti menu principale, pausa, settings, save JSON versionati, autosave,
  unlock persistenti, export preset Windows e build smoke.

### Visual Gameplay, UX e Accessibilita

- Completato il primo pass di leggibilita survival: arena desaturata, survivor e
  zombie procedurali, pickup grafici, effetti di sparo/hit/morte/raccolta,
  annunci centrali e HUD per-player.
- Aggiunti telegraph modulari boss, visual dedicati per `Wave Warden` e
  `Rift Architect`, proiettili boss distinti, effetti morte boss e pannello vita
  boss responsive.
- Aggiunti runner, tank e shooter ranged con silhouette, statistiche, loot,
  windup e telegraph.
- Aggiunti downed/revive locale, risultati run condivisi, retry, cambio
  modalita, menu pausa, audio bus/cue/fallback, impostazioni video/controlli e
  preset visuali default/comfort/high contrast.
- Aggiunta pipeline asset con fallback controllati, attribuzioni e QA visuale
  manuale per le aree principali.

### Zombie Survival e Mondo Isometrico

- Completato il revamp zombie con controller dedicato, biomi, wave director,
  spawner camera-edge, transizioni fisiche, hazard, casse e sistemi ambientali.
- Aggiunta megamappa seed-based `3x3` con regioni `500x500`, grafo connesso,
  passaggi fisici, stato esplorazione salvabile, mappa consultabile e streaming
  regione corrente piu vicini.
- Classificato il terreno come walkable, obstacle, hazard, border, void o
  fall zone; dodge/roll attraversa piccoli gap/fall zone ma rifiuta hazard
  ambientali.
- Rimossi i portali legacy `BiomeTransitionGate`, `MultiRegionRenderer` e i
  ground procedurali legacy dal percorso standard; `RegionSeamSystem` e
  `WorldRegionStreamer` sono i contratti runtime attivi.
- Aggiunti layout data-driven per Pianura, Tossico, Infuocato, Neve e Palude,
  undici varianti zombie tematiche, crate tematiche, mini-eventi, status bioma e
  hazard ambientali.

### Asset Isometrici e Ostacoli

- Evoluto `assets/environment/isometric/manifest.json` fino al contratto asset
  v9 con tile set, terrain, edge, void, object scenes, passage tiles, asset set
  di bioma e fallback policy esplicita.
- Resi asset-driven ground, strade, connector, passaggi, cliff, fall zone,
  ostacoli, crate e oggetti ambientali senza rendere obbligatori asset esterni.
- Aggiunti loader SVG runtime, materiali raster generati, cliff seamless,
  texture forestali, plateau rocciosi scalabili, raised cliff per Infinite Arena,
  PNG generati per biomi avanzati, occluder Y-sort e footprint slot-based per
  collisione, spawn blocker e debug `F9`.
- La fallback policy vieta placeholder generici impliciti nel percorso survival
  standard; eventuali fallback tecnici devono essere documentati nel manifest e
  coperti da smoke o asset check.

### RPG, Armi e Mercato

- Aggiunta Character Select pre-run con profili RPG data-driven, nomi propri,
  palette, preview, portrait opzionali e selezione indipendente per giocatore.
- Aggiunti `RpgCharacterData`, `RpgCharacterRegistry`, `RpgPlayerComponent`,
  stat classe, XP per-run, level-up, passive automatiche, adrenalina e super.
- Differenziate le armi base RPG: arco, pistola, ascia, spada, bastone, fionda
  e artigli; ranged usa projectile, melee usa hitbox temporanee con wind-up,
  active window, recovery, trail e anti-multihit.
- Esteso il catalogo a 30 armi drop con identita visuale specifica per pickup,
  held/HUD, projectile, slash e impact. Il pass WVIS W0-W8 e chiuso e validato
  nei preset visuali e nello scenario survival affollato.
- Aggiunto mercato zombie post-boss con offerte arma uniche, acquisti su wallet
  party, refill/cura validati, ready dei player vivi e blocco wave condiviso.

### QA, Tooling e Performance

- Vendorizzato GUT 9.6.0 e migrata la suite da runner legacy `extends SceneTree`
  a un unico processo Godot con suite sotto `tests/suites/**`.
- Completata la migrazione GUT M0-M8: world generation, environment/streaming,
  ostacoli/collisioni, asset/manifest, combat/weapons/drops, enemies/bosses,
  RPG/progression e game modes/waves.
- Aggiunti smoke e guardrail per asset fallback, weapon drop progression,
  balance metrics, ten-wave, soak, world loading, retry con riuso mondo e cache
  texture isometriche.
- Ottimizzato il rendering isometrico: `BiomeTileLayer` pre-cuoce il terreno in
  mesh/linee aggregate, riducendo drasticamente i comandi canvas per frame nei
  profili survival multi-regione.
- Documentati workflow di import Godot, GUT quick/golden/area, soak, visual QA,
  asset check, export PCK/EXE e build smoke.

## Roadmap Aperta

Il backlog operativo resta in `TODO.md`. Le categorie aperte sono:

- `UIUX-001`: polish menu, HUD, Character Select, status, mappa, boss, audio e
  leggibilita multi-risoluzione.
- `BOSS-001`: nuovo boss o estensione contenuta dei pattern esistenti.
- `TD-001`: una sola espansione tower defense a scope minimo.
- `QA-001`: maggiore copertura automatica dei sistemi critici.
- `BAL-001`: playtest end-to-end, tuning data-driven e profiling.
- `REL-001`: export Windows ripetibile, build smoke, attribuzioni e firma
  digitale se toolchain/certificato sono disponibili.
