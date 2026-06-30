# ROADMAP

Questo documento definisce direzione e categorie di lavoro. Non e una lista di
task dettagliati: i criteri operativi vivono in `TODO.md`, la cronologia
append-only in `CHANGELOG.md`, i contratti runtime in `ARCHITECTURE.md` e le
regole di gioco in `GAME_DESIGN.md`.

## Stato Corrente

Il progetto ha superato il prototipo minimo: le tre modalita principali sono
giocabili, la zombie survival usa il mondo isometrico seed-based con streaming
regioni, il roster RPG e le armi hanno pass data-driven, UI/audio/settings sono
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
| Zombie survival e mondo isometrico | Revamp zombie Z1-Z12, megamappa persistente, regioni `500x500`, survival standard `3x3`, terrain classification, hazard, streaming regioni, chase cross-bioma, Infinite Arena con raised cliff `walled` e cleanup legacy. | `ARCHITECTURE.md`, `GAME_DESIGN.md`, suite `world_gen`, `environment`, `modes`, `soak` |
| Asset isometrici e ostacoli | ISO-001, rewrite biomi R1-R3, manifest ambiente v9, tile/terrain/passaggi/cliff asset-driven, footprint slot-based, alberi/rocce 3x3, plateau rocciosi scalabili e cliff PNG seamless. | `docs/obstacle_rendering.md`, `docs/forest_isometric_texture_system.md`, `docs/repo_fix_milestone_10_asset_fallback_policy.md` |
| RPG, armi e mercato | RPG Mode M1-M13, classi avanzate, inventario armi, 30 armi catalogo, mercato zombie ricorrente e WVIS W0-W8. | `docs/zombie_market.md`, `docs/weapon_visual_identity_validation_report.md`, `docs/rpg_character_visual_checklist.md` |
| QA, tooling e documentazione | Cutover GUT, cleanup warning headless, server MCP locale read-only e cleanup documentale 2026-07-01. | `tools/mcp-server/README.md`, `docs/documentation_inventory.md`, `CHANGELOG.md` |

## Roadmap Attiva per Categoria

La fonte operativa resta `TODO.md`; questa sezione raggruppa gli stessi item per
evitare sovrapposizioni.

### Presentazione e UX

- `UIUX-001`: rifinire menu, HUD, Character Select, status, mappa, boss,
  feedback audio e leggibilita multi-risoluzione senza cambiare regole di gioco.
- Include la decisione sugli asset `final_quality` dei personaggi RPG: o entrano
  nel pass UI/UX, o restano polish opzionale documentato.
- Non include tuning numerico, nuove regole combat o nuove modalita.

### Espansione Gameplay

- `BOSS-001`: scegliere un boss nuovo o un'estensione contenuta dei pattern
  esistenti, usando `BossSystem` e i contratti condivisi.
- `TD-001`: scegliere una sola espansione tower defense tra upgrade, vendita,
  riparazione, nuovi tipi torre o percorsi multipli.
- Le due aree non devono duplicare combat, projectile, drop, boss o sistemi UI
  gia condivisi.

### QA, Bilanciamento e Performance

- `QA-001`: coprire meglio health, multiplayer, wave, save/load, world runtime
  e lifecycle oltre agli smoke gia presenti.
- `BAL-001`: playtest end-to-end, tuning data-driven e profiling su survival,
  dungeon, tower defense, RPG, biomi e boss.
- Le evidenze visuali dei mini-eventi bioma rientrano qui; `BIO-001` non va
  riaperto salvo bug o tuning concreto.

### Release

- `REL-001`: export Windows ripetibile, build smoke, attribuzioni asset e firma
  digitale se certificato/toolchain sono disponibili.
- La firma non e una milestone separata: e un sotto-blocco di release readiness.

## Sequenza Consigliata

1. Chiudere un pass `UIUX-001` piccolo e verificabile, per ridurre rumore
   visuale prima dei playtest.
2. Rafforzare `QA-001` sui sistemi critici che possono rompere piu modalita.
3. Eseguire `BAL-001` con playtest reali e profiling, usando i risultati per
   decidere se prioritizzare `BOSS-001` o `TD-001`.
4. Affrontare `REL-001` quando smoke, QA e attribuzioni sono stabili.

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
