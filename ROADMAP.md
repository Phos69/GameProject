# ROADMAP

Questo documento definisce direzione e categorie di lavoro. Non e una lista di
task dettagliati: i criteri operativi vivono in `TODO.md`, la cronologia
append-only in `CHANGELOG.md`, i contratti runtime in `ARCHITECTURE.md` e le
regole di gioco in `GAME_DESIGN.md`.

## Stato Corrente

Il progetto ha superato il prototipo minimo: le tre modalita principali sono
giocabili, la zombie survival usa il mondo isometrico seed-based con streaming
incrementale di regioni e chunk camera-centrici, il roster RPG e le armi hanno
pass data-driven, UI/audio/settings sono
funzionali e la suite rapida GUT e pulita. Il lavoro attivo ora riguarda polish,
scelte di espansione, QA piu profonda, bilanciamento e release readiness.

## Baseline Archiviata

Queste aree sono considerate chiuse come primo pass stabile. Non vanno riaperte
senza un nuovo goal esplicito e una voce in `TODO.md`.

| Categoria | Stato archiviato | Evidenza principale |
| --- | --- | --- |
| Fondazione runtime | Milestone 0-4: repo, progetto Godot, input, co-op locale, camera, player, combat, health, nemici, drop e pickup. | `README.md`, `ARCHITECTURE.md`, suite GUT core/combat/progression |
| Modalita base | Milestone 5-9: survival a ondate, boss `Wave Warden`, dungeon lineare, tower defense base, save/load, menu, export preset e packaging iniziale. | `ARCHITECTURE.md`, `GAME_DESIGN.md`, `docs/latest_commit_validation_report.md` |
| Visual gameplay e UX base | Milestone 10-21: readability survival, telegraph boss, varianti zombie, visual armi/torri, polish boss, shooter ranged, downed/revive, risultati run, audio mix, secondo boss, arena data-driven, accessibilita e profiling. | `CHANGELOG.md`, `docs/testing/manual_checklist.md` |
| Zombie survival e mondo isometrico | Revamp zombie Z1-Z12, megamappa persistente, regioni `75x75` tile logici (`450x450` equivalenti legacy), survival standard `3x3`, terrain classification, hazard, streaming incrementale senza caricamento ai seam, chase cross-bioma, Infinite Arena con raised cliff `walled` e cleanup legacy. | `ARCHITECTURE.md`, `GAME_DESIGN.md`, suite `world_gen`, `environment`, `modes`, `soak` |
| Asset isometrici e ostacoli | ISO-001, rewrite biomi R1-R3, manifest ambiente v9, tile/terrain/passaggi/cliff asset-driven, footprint slot-based, alberi/rocce 3x3, plateau rocciosi scalabili, cliff PNG seamless e generated biome art per quattro biomi avanzati. | `docs/obstacle_rendering.md`, `docs/forest_isometric_texture_system.md`, `docs/repo_fix_milestone_10_asset_fallback_policy.md` |
| RPG, armi e mercato | RPG Mode M1-M13, classi avanzate, inventario armi, 30 armi catalogo, mercato zombie ricorrente e WVIS W0-W8. | `docs/zombie_market.md`, `docs/weapon_visual_identity_validation_report.md`, `docs/rpg_character_visual_checklist.md` |
| QA, tooling e documentazione | Cutover GUT, cleanup warning headless, server MCP locale read-only e cleanup documentale 2026-07-01. | `tools/mcp-server/README.md`, `docs/documentation_inventory.md`, `CHANGELOG.md` |

## Roadmap Attiva per Categoria

La fonte operativa resta `TODO.md`; questa sezione raggruppa gli stessi item per
evitare sovrapposizioni.

### Presentazione e UX

- `UIUX-001`: **completata 2026-07-07**. UI-VIS-FIX (2026-07-03) ha chiuso
  gerarchia HUD, Character Select e boss HUD; il pass finale del 2026-07-07 ha
  chiuso `WEAPON-VIS-FIX` (`VIS-011`), il main menu (`VIS-012`, fondale
  isometrico nei toni dei biomi, card compatta, lingua italiana, safe area a
  tre risoluzioni) e i residui asset (`VIS-009`/`VIS-008`: fence a canvas
  nativa, large_rock riclassificato, forest_tree confermato hero asset).
  Regressione audio mix e suite GUT completa verdi (238/238). Resta solo
  l'ascolto manuale del mix a quattro pad in
  `docs/testing/manual_checklist.md`.
- `ART-VIS-FIX`: **completato 2026-07-03** su tutti e cinque i biomi
  (`docs/biome_art_vis_fix_roadmap.md`): edifici generati leggibili come
  strutture, ground pool coerenti, route a taglio netto, toni per-bioma
  ribilanciati e QA dedicata per bioma. `VIS-005` e chiuso distinguendo gli
  edifici laboratorio dalle vere supply crate; Neve e Palude chiudono la
  ripetizione del ground con una quilt non specchiata (periodo `1024`,
  path/road a `512`) e la componente Palude di `VIS-009` normalizza
  `reed_wall`. Residui riclassificati: hazard tematici della pipeline
  voidfirst in `BAL-001`, normalizzazione `large_rock`/`broken_fence`/
  `forest_tree` dentro `UIUX-001` (VIS-009).
- Decisione asset `final_quality` dei personaggi RPG: **risolta 2026-07-07** —
  restano polish opzionale documentato, fuori dal backlog attivo; riaprire solo
  con un nuovo goal esplicito e una voce in `TODO.md`.
- Non include tuning numerico, nuove regole combat o nuove modalita.

### Espansione Gameplay

- `BOSS-001`: **completata 2026-07-08** con il pattern avanzato
  `crescent_barrage` del Wave Warden — ventaglio ampio a velocita' sfalsate
  con telegraph dedicato (fronte a mezzaluna che avanza col countdown, nessun
  danno nel warning, warning HUD "CRESCENT BARRAGE - SIDESTEP") in rotazione
  a tre pattern dalla fase due. Contratto registry/ID e drop invariati; un
  eventuale boss nuovo richiede una nuova voce in `TODO.md`.
- `TD-001`: **completata 2026-07-08** con l'upgrade delle torri a tre livelli:
  interact sullo slot occupato, costo per livello (35/50 crediti) con rimborso
  su fallimento, statistiche scalate (danno x1.5, cadenza x1.2, gittata x1.1),
  pip di livello sulla base e prompt "UP n C" sullo slot. Vendita,
  riparazione, nuovi tipi torre e percorsi multipli restano fuori scope.
- Le due aree non duplicano combat, projectile, drop, boss o sistemi UI gia
  condivisi.

### QA, Bilanciamento e Performance

- `QA-001`: **completata 2026-07-08**. Oltre al pass `QA-VIS-FIX` sul tooling
  (2026-07-02), ogni sistema condiviso critico ha ora uno smoke headless
  dedicato: edge case health (`health_edge_test`), join/leave a meta' ondata
  (`multiplayer_midwave_test`), edge di persistenza con backup e salvataggi
  corrotti (`save_edge_test`) e lifecycle multi-modalita' con cleanup
  (`mode_lifecycle_test`). Suite completa 247/247 con exit code `0`; dettagli
  in `docs/latest_commit_validation_report.md`. Nuovi warning o rossi sono
  regressioni, non prosecuzione della milestone.
- `BAL-001`: parte automatizzabile **chiusa il 2026-07-08** — soak/stress
  8/8, profilo perf rimisurato in finestra (a 96 mob worst frame 28,9 ms,
  sotto il budget p95 di 33,3 ms; tetto raster mob accettato e documentato,
  baking archetipi solo come opzione futura oltre ~100 mob visibili), seam
  renderizzato senza chunk mancanti e guardrail di nicchia per tutte e 7 le
  classi RPG. Restano i playtest manuali lunghi (Infinite Arena e survival 20
  minuti, dungeon tre seed, TD 5 wave) e il giudizio qualitativo sui biomi.
  Il profilo Zombie Survival `1280x720`, balanced/generated art, 4 player e
  28 nemici resta il riferimento: p95 normale <= 33,3 ms, seam <= 50 ms e
  nessun chunk mancante in camera.
- Il pass `WORLD-VIS-FIX` e completato: raised cliff e fall zone hanno semantica
  distinta, placement e contatti ground/void sono coperti da guardrail e il
  profilo movimento/zoom non perde chunk visibili. Soak e tuning restano aperti.
- Le evidenze visuali dei mini-eventi bioma e dei set generated biome art
  rientrano qui; `BIO-001` non va riaperto salvo bug o tuning concreto.

### Release

- `REL-001`: **completata 2026-07-08** — export Windows ripetibile da checkout
  pulito (EXE 99,7 MB + PCK 44,4 MB, exit 0), build smoke PASS
  sull'eseguibile esportato con controller reale, attribuzioni complete e
  firma chiusa come blocco esterno documentato (nessun certificato/toolchain
  sul sistema; riaprire con una nuova voce quando disponibili).
- La firma non e una milestone separata: e un sotto-blocco di release readiness.

## Sequenza Consigliata

1. ~~Chiudere un pass `UIUX-001` piccolo e verificabile~~ — fatto il
   2026-07-07 (la milestone e' chiusa per intero).
2. ~~Rafforzare `QA-001` sui sistemi critici~~ — fatto il 2026-07-08 (smoke
   health/multiplayer/save/lifecycle, suite 247/247).
3. ~~Decidere e implementare `BOSS-001`/`TD-001`~~ — fatte il 2026-07-08
   (pattern `crescent_barrage` + upgrade torri); di `BAL-001` restano i
   playtest manuali lunghi, che ora coprono anche le due espansioni.
4. ~~Affrontare `REL-001`~~ — fatta il 2026-07-08 (export + build smoke +
   attribuzioni; firma = blocco esterno documentato). L'unico lavoro aperto
   sono i playtest manuali di `BAL-001`.

## Ridondanze e Conflitti Risolti

- Dungeon ramificato, shop e biomi dedicati non sono piu backlog aperto: il
  primo pass `DUN-001` e archiviato. UI shop e arte dungeon possono rientrare in
  `UIUX-001` solo se diventano scope esplicito.
- "Asset definitivi" non e una roadmap autonoma: asset personaggi RPG
  `final_quality` appartengono a `UIUX-001`, asset/fallback ambiente seguono la
  policy M10 e le attribuzioni release stanno in `REL-001`.
- "Ulteriori pass di bilanciamento" e assorbito da `BAL-001`; non deve comparire
  come voce generica separata.
- "Ulteriori boss e pattern avanzati" e assorbito da `BOSS-001`; non va duplicato
  nei prossimi obiettivi.
- "Firma digitale" e assorbita da `REL-001`; non e un goal isolato.
- `Infinite Arena` e `Zombie Survival` non sono in conflitto: Infinite Arena e
  quick play `1x1` murato senza world runtime, Zombie Survival standard usa la
  megamappa `3x3` streamata. Nel profilo `walled`, Infinite Arena rende i bordi
  bloccati come raised cliff solidi senza creare varchi, fall zone o cambio di
  collisioni.
- Asset-driven e fallback procedurale non sono in conflitto: gli asset esterni
  non sono obbligatori, ma ogni fallback deve essere esplicito nel manifest e
  non ricadere su placeholder generici impliciti.
- Il cleanup GUT/TESTWARN e chiuso: eventuali nuovi warning sono regressioni o
  nuovi task QA, non prosecuzione del piano storico.
