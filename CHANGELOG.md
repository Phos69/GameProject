# CHANGELOG

Registro sintetico delle modifiche principali. I dettagli operativi chiusi sono
consolidati in `README.md`, `ROADMAP.md`, `ARCHITECTURE.md`, `GAME_DESIGN.md`,
`docs/documentation_inventory.md` e nei report tecnici sotto `docs/`.

## Unreleased

### Added

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
    path restano path diretto, mentre bordi e curve strada usano asset
    `road_border_defined` tramite il ruolo `ground_to_road`;
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
    Palude aggiunge la vista `reed_wall`.
  - `TileBakeCache.FORMAT_VERSION` sale progressivamente a `17` mano a mano
    che ogni bioma normalizza i propri `material_asset_id` e i nuovi border
    strada, invalidando le cache persistite obsolete.

- Pianura Infetta non renderizza piu `grass_to_path`, `grass_to_road` e
  `path_to_road` come texture intermedie: `grass_to_path` usa direttamente
  `forest_path`, mentre i contatti verso strada usano `forest_road_border`,
  mantenendo un taglio netto verso il terreno. `forest_tree` applica inoltre flip/tinta
  deterministici per ridurre la ripetizione senza cambiare collisioni o
  footprint.
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
