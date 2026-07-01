# CHANGELOG

Registro sintetico delle modifiche principali. I dettagli operativi chiusi sono
consolidati in `README.md`, `ROADMAP.md`, `ARCHITECTURE.md`, `GAME_DESIGN.md`,
`docs/documentation_inventory.md` e nei report tecnici sotto `docs/`.

## Unreleased

### Added

- Integrati 191 PNG generati e ripuliti sotto
  `assets/environment/isometric/generated_images/`. I quattro biomi Survival
  avanzati usano set tematici per ground, route, transizioni, cliff verso void e
  raised cliff; `desert` e il nuovo set `forest` restano catalogati ma non
  assegnati. `BiomeGeneratedArtCatalog` assegna ruoli e varianti in modo
  deterministico.
- Infinite Arena rende i quattro lati `BLOCKED` come cliff rocciosi rialzati di
  sette celle. `BiomeEnvironmentLayout` distingue `procedural_wall` e
  `raised_cliff`; i segmenti conservano collisioni e Y-sort ma usano materiali
  world-space continui per parete e plateau. Aggiunti guardrail GUT e QA reale
  in `tests/visual_qa/infinite_arena_cliff_visual_qa.gd`.
- Aggiunto il server MCP locale read-only in `tools/mcp-server/`, separato dal
  runtime Godot. Usa Node.js/TypeScript, `@modelcontextprotocol/sdk` e transport
  `stdio`.
- Aggiunti gli script npm root `mcp:start`, `mcp:dev`, `mcp:build`,
  `mcp:test` e `mcp:smoke`, delegati al package `tools/mcp-server/`.
- Esposti 9 tool MCP: `repo_overview`, `list_project_files`,
  `read_project_context`, `search_project`, `game_system_summary`,
  `roadmap_context`, `run_safe_check`, `asset_inventory` e `codex_task_brief`.
- Esposti 5 prompt MCP operativi: `audit_isometric_generation`,
  `improve_zombie_mode`, `implement_roadmap_milestone`,
  `refactor_gameplay_system` e `asset_quality_pass`.
- Aggiunto `docs/documentation_inventory.md` come inventario dei Markdown vivi,
  storici e rimossi dopo il cleanup documentale.

### Changed

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
- Chiarito il contratto MCP in `README.md` e `ARCHITECTURE.md`: il server lavora
  dentro la root progetto, legge solo contesto testuale, blocca traversal e file
  sensibili, limita ricerche/output e consente solo safe check allowlisted.

### Fixed

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

- `npm run mcp:build`: passa.
- `npm run mcp:test`: passa con 4 file test e 13 test totali.
- `npm run mcp:smoke`: passa e lista 9 tool MCP e 5 prompt.
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
