# ROADMAP

Questo documento definisce direzione e categorie di lavoro. Non e una lista di
task dettagliati: i criteri operativi vivono in `TODO.md`, la cronologia
append-only in `CHANGELOG.md`, i contratti runtime in `ARCHITECTURE.md` e le
regole di gioco in `GAME_DESIGN.md`.

## Stato Corrente

Il progetto ha superato il prototipo minimo: le tre modalita principali sono
giocabili, la zombie survival usa il mondo top-down cardinale seed-based con streaming
incrementale di regioni e chunk camera-centrici, il roster RPG e le armi hanno
pass data-driven, UI/audio/settings sono
funzionali e la suite rapida GUT e pulita. Il lavoro attivo ora riguarda polish,
scelte di espansione, QA piu profonda, bilanciamento e release readiness. Il
goal esplicito `WORLD-UNIFY-001` del 2026-07-13 e completato: il contratto
void-first condiviso include ora profili tipizzati, mesa, props casuali e hazard
statici data-driven in tutti i biomi, senza introdurre un secondo generatore.

## Baseline Archiviata

Queste aree sono considerate chiuse come primo pass stabile. Non vanno riaperte
senza un nuovo goal esplicito e una voce in `TODO.md`.

| Categoria | Stato archiviato | Evidenza principale |
| --- | --- | --- |
| Fondazione runtime | Milestone 0-4: repo, progetto Godot, input, co-op locale, camera, player, combat, health, nemici, drop e pickup. | `README.md`, `ARCHITECTURE.md`, suite GUT core/combat/progression |
| Modalita base | Milestone 5-9: survival a ondate, boss `Wave Warden`, dungeon lineare, tower defense base, save/load, menu, export preset e packaging iniziale. | `ARCHITECTURE.md`, `GAME_DESIGN.md`, `docs/latest_commit_validation_report.md` |
| Visual gameplay e UX base | Milestone 10-21: readability survival, telegraph boss, varianti zombie, visual armi/torri, polish boss, shooter ranged, downed/revive, risultati run, audio mix, secondo boss, arena data-driven, accessibilita e profiling. | `CHANGELOG.md`, `docs/testing/manual_checklist.md` |
| Zombie survival e mondo top-down | Revamp zombie Z1-Z12, megamappa persistente, regioni `75x75` tile logici (`450x450` equivalenti legacy), survival standard `3x3`, terrain classification, hazard, streaming incrementale senza caricamento ai seam, chase cross-bioma, Infinite Arena con raised cliff `walled`; `WORLD-UNIFY-001` aggiunge profili per cinque biomi, chasm interni garantiti, mesa tematiche, props pesati e hazard statici avanzati. | `ARCHITECTURE.md`, `GAME_DESIGN.md`, `map_generation_report.md`, suite `world_gen`, `environment`, `modes`, `soak` |
| Asset top-down e ostacoli | `TOPDOWN-001`, rewrite biomi R1-R3, manifest ambiente, tile/terrain/passaggi/cliff asset-driven, footprint slot-based, alberi/rocce 3x3, plateau rocciosi scalabili, cliff PNG seamless, generated biome art e 23 prop SVG cardinali individuali. Il terreno usa assi H/V; il volume prospettico e separato dal footprint. | `docs/top_down_cardinal_contract.md`, `docs/obstacle_rendering.md`, `docs/forest_top_down_texture_system.md` |
| RPG, armi e mercato | RPG Mode M1-M13, classi avanzate, inventario armi, 30 armi catalogo, mercato zombie ricorrente e WVIS W0-W8. | `docs/zombie_market.md`, `docs/weapon_visual_identity_validation_report.md`, `docs/rpg_character_visual_checklist.md` |
| QA, tooling e documentazione | Cutover GUT, cleanup warning headless, server MCP locale read-only e cleanup documentale 2026-07-01. | `tools/mcp-server/README.md`, `docs/documentation_inventory.md`, `CHANGELOG.md` |

## Roadmap Attiva per Categoria

La fonte operativa resta `TODO.md` per gli item aperti; questa sezione registra
anche le milestone completate per evitare sovrapposizioni.

### Presentazione e UX

- `TERRAIN-MASK-001`: **completata 2026-07-15**. Il renderer del terreno usa
  un classificatore condiviso per quattro superfici (`grass`, `path`,
  `asphalt`, `void`) e una maschera regionale RGBA a 8 px/tile: RGB seleziona
  le texture esistenti forestali/generated ai lati del confine, mentre alpha
  applica il nuovo divisore ripetibile di terra compatta. Shader e
  `TerrainSurfaceCanvas` campionano la stessa maschera per ogni chunk e una fase
  world-space continua tra regioni; il void resta uniforme e il contratto cache
  sale a v29. Criterio di accettazione:
  confini generati una sola volta per regione, divisore presente tra superfici
  diverse senza dipendere da core/edge/corner stradali, materiali gameplay e
  semantica del void invariati. Evidenza: test CPU
  `terrain_boundary_mask_test.gd`, suite `assets`/`environment`/`obstacles`/
  `world_gen` e Visual QA `infected_plains` piu review multi-bioma da 210
  capture, tutti PASS.

- `TOPDOWN-001`: **completata 2026-07-15**. Renderer, manifest v12, cache,
  generazione mondo, UI, branding, tooling e documentazione usano il contratto
  `orthogonal_top_down`; movimento e mira restano analogici e il volume di
  cliff, edifici, prop e attori usa `controlled_perspective`. I 23 prop ad
  atlas sono stati sostituiti da 23 SVG cardinali individuali e i 66 materiali
  cliff sono stati normalizzati. Il follow-up ostacoli separa footprint e
  collider alle radici, blocca a zero le rotazioni di ostacoli/hazard/fall zone
  e rende le mesa come nodi
  Y-sorted; firma layout v3, revisione generatore 4 e snapshot v6 rigenerano le
  cache precedenti. La revisione 4 include il margine cliff/route del follow-up
  sui chasm. Il rename del progetto include una migrazione save one-shot.
  Evidenza: GUT, check 131 asset e 66 cliff, Visual QA finale,
  menu e oggetti verdi. Contratto e guardrail vivono in
  `docs/top_down_cardinal_contract.md`.

- `UIUX-001`: **completata 2026-07-07**. UI-VIS-FIX (2026-07-03) ha chiuso
  gerarchia HUD, Character Select e boss HUD; il pass finale del 2026-07-07 ha
  chiuso `WEAPON-VIS-FIX` (`VIS-011`), il main menu (`VIS-012`, fondale
  top-down nei toni dei biomi, card compatta, lingua italiana, safe area a
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
  `reed_wall`. Gli hazard tematici della pipeline void-first sono stati
  implementati da `WORLD-UNIFY-001`; in `BAL-001` resta solo il giudizio
  qualitativo sul loro bilanciamento. La normalizzazione
  `large_rock`/`broken_fence`/`forest_tree` e chiusa dentro `UIUX-001`
  (VIS-009).
- Decisione asset `final_quality` dei personaggi RPG: **risolta 2026-07-07** —
  restano polish opzionale documentato, fuori dal backlog attivo; riaprire solo
  con un nuovo goal esplicito e una voce in `TODO.md`.
- Non include tuning numerico, nuove regole combat o nuove modalita.

### Espansione Gameplay

- `ROSTER-001`: **completata 2026-07-14**. Il roster regolare survival passa
  da 11 a 15 profili tematici con `Toxic Reaver`, `Ember Hound`,
  `Glacial Bulwark` e `Mire Stalker`. Le elite entrano dalla wave 5 tramite il
  gate deterministico di `BiomeDefinition`, riusano `BasicEnemy` e combinano
  resistenza, status, emersione e hazard gia condivisi. Il pass artistico
  aggiunge sette pittogrammi personaggio, ora consumati anche da `PlayerVisual`
  nel gameplay world-space, e otto zombie PNG con alpha, mantenendo i fallback
  procedurali. Accettazione coperta da import, GUT assets/enemies/progression,
  board Visual QA e build smoke della scena principale.

- `BOSS-001`: **completata 2026-07-08** con il pattern avanzato
  `crescent_barrage` del Wave Warden — ventaglio ampio a velocita' sfalsate
  con telegraph dedicato (fronte a mezzaluna che avanza col countdown, nessun
  danno nel warning, warning HUD "CRESCENT BARRAGE - SIDESTEP") in rotazione
  a tre pattern dalla fase due. Contratto registry/ID e drop invariati.
- `BOSS-002`: **completata 2026-07-13**. Obiettivo: ampliare la rotazione
  survival con almeno cinque boss zombie senza duplicare combat condiviso.
  Aggiunti `Grave Colossus`, `Gore Charger`, `Plague Spitter`, `Bone Mortar`
  e `Carrion Shepherd`, ciascuno con movimento, due pattern, telegraph e
  sprite alpha distinti; la sequenza wave 5-30 resta deterministica e si
  ripete. Coinvolti `BossSystem`, `SurvivalMode`, `ZombieBossBase`, melee,
  projectile, visual/HUD e asset boss. Accettazione: scene registrate e
  caricabili, compatibilita limitata a Infinite Arena/Survival, warning senza
  danno e asset con fallback; verificata con GUT enemies/assets, import e
  smoke della scena principale.
- `TD-001`: **completata 2026-07-08** con l'upgrade delle torri a tre livelli:
  interact sullo slot occupato, costo per livello (35/50 crediti) con rimborso
  su fallimento, statistiche scalate (danno x1.5, cadenza x1.2, gittata x1.1),
  pip di livello sulla base e prompt "UP n C" sullo slot. Vendita,
  riparazione, nuovi tipi torre e percorsi multipli restano fuori scope.
- Le due aree non duplicano combat, projectile, drop, boss o sistemi UI gia
  condivisi.

### Mondo procedurale

- `WORLD-UNIFY-001`: **completata 2026-07-13**. I cinque
  `BiomeGenerationProfile` tipizzati governano mesa, chasm, props pesati e
  hazard; ogni layout ha almeno un chasm interno salvo opt-out, mesa tematiche
  (10-16 in Pianura, 2-4 nei biomi avanzati) e 10-16 props da almeno due
  categorie. Tossico, Infuocato, Neve e Palude ricevono due hazard statici
  sicuri. Stream RNG separati, firma profonda layout-v3, revisione cache 4 e
  snapshot v6 rendono esplicita l'invalidazione. Rendering mesa e guardrail
  multi-bioma/fuzz 20 seed x 5 biomi coprono il contratto; i tre pass dedicati
  tengono mesa, hazard e prop fuori dall'orchestratore e il fallback prop e
  testato senza sampling. La board Visual QA ha prodotto 210 catture verdi.
  Analisi ed esito in `map_generation_report.md`.
- La promozione cardinale richiesta e completata: i 23 ID dei pool attivi
  usano 23 SVG individuali `final`, dichiarati dal manifest con source
  `project_svg_generator` e attribution `environment_top_down_internal`. Le 23
  risorse `.tres` e le cinque tavole concept raster del percorso precedente
  sono state rimosse; resta aperto soltanto il giudizio qualitativo manuale gia
  incluso in `BAL-001`. La chiusura non
  riapre genericamente `BIO-001` o il pass artistico archiviato.

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
   attribuzioni; firma = blocco esterno documentato).
5. ~~Implementare `WORLD-UNIFY-001` per fasi~~ — fatto il 2026-07-13 con
   profili tipizzati, guardrail/versionamento e contenuto condiviso. Restano i
   playtest manuali di `BAL-001`, non dichiarati completati.

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
