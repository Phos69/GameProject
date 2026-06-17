# TODO

Questo file contiene solo backlog operativo, follow-up tracciati e reference
storiche consolidate. I dettagli completi delle milestone gia chiuse restano in
`ROADMAP.md`, `CHANGELOG.md`, `docs/milestones/`, nelle roadmap dedicate e nel
report `docs/latest_commit_validation_report.md`.

Regole per nuove voci:

- ogni item aperto deve indicare obiettivo, milestone collegata, file/sistemi,
  criterio di accettazione e test richiesto;
- non riaprire milestone completate senza un nuovo goal esplicito;
- aggiornare questa TODO solo a fine lavoro quando una milestone cambia stato.

## Baseline tecnica - audit Milestone 0 del 2026-06-17

| Area | Stato noto | Evidenza | Prossima azione |
| --- | --- | --- | --- |
| Documentazione principale | Rivista | `README.md`, `ROADMAP.md`, `ARCHITECTURE.md`, `GAME_DESIGN.md`, `TODO.md`, report test e checklist manuale | Mantenere allineata durante le milestone successive |
| Test discovery | 75 runner trovati | `rg --files tests` | Usare come inventario per regressioni future |
| Suite smoke | PASS nella validazione Milestone 1 | `docs/latest_commit_validation_report.md` | Rieseguire dopo modifiche runtime o teardown |
| Build/export Windows | PASS nell'ultima validazione completa disponibile | `docs/latest_commit_validation_report.md` | Rieseguire in Milestone 12 o se cambia packaging |
| Shutdown headless | Risolto nella Milestone 1 | Loop 100 avvii main scene e smoke prioritari senza cleanup warning noti | Monitorare solo come regressione futura |
| Mini-eventi bioma | PASS nella validazione Milestone 2 | `tests/biome_mini_events_smoke_test.gd`, `tests/random_encounter_smoke_test.gd`, `docs/latest_commit_validation_report.md` | Riprendere solo dentro playtest/bilanciamento Milestone 11 |
| Megamappa e streaming regioni | PASS nella validazione Milestone 3 | `tests/region_streaming_smoke_test.gd`, world graph, persistent world, open passage, exploration map, `docs/latest_commit_validation_report.md` | Riprendere in Milestone 4 (asset isometrici) o nel bilanciamento Milestone 11 |
| Asset isometrici ambiente | PASS nella validazione Milestone 4 | `tests/isometric_environment_manifest_smoke_test.gd`, manifest v2, biome obstacle generation, `docs/latest_commit_validation_report.md` | Conversione ad arte esterna definitiva opzionale; QA visuale screenshot nel playtest Milestone 11 |
| Dungeon ramificato/shop | PASS nella validazione Milestone 5 | `tests/dungeon_graph_smoke_test.gd`, `tests/dungeon_smoke_test.gd`, `docs/latest_commit_validation_report.md` | UI shop dedicata e arte bioma dungeon restano follow-up; screenshot tre seed nel playtest Milestone 11 |
| Roadmap storiche | Completate come primo pass o reference | `ROADMAP.md`, `roadmap_*.md`, `docs/milestones/` | Non usarle come backlog attivo se una voce e gia chiusa qui sotto |

Test eseguiti per questo audit: nessun test gameplay. La Milestone 0 richiede
revisione manuale, baseline e consolidamento TODO.

## Backlog aperto prioritizzato

### ASSET-002 - Asset definitivi e animazioni personaggi RPG

- Obiettivo: rifinire qualitativamente i sette personaggi con VFX separati,
  pulizia animazioni, weapon layer e coerenza animabile; `base_complete`
  indica asset base presente, non qualita finale.
- Milestone collegata: `todo_roadmap.md` Milestone 6.
- File/sistemi coinvolti: `assets/characters/`, manifest personaggio,
  `game/rpg/characters/`, `PlayerVisual`, `PlayerHudCard`,
  `docs/rpg_character_visual_checklist.md`.
- Criterio di accettazione: ogni personaggio ha portrait HUD/full,
  idle/run/attack/reload/hurt/death/super, weapon layer e VFX separati
  configurati dai campi `RpgCharacterData`, con fallback funzionante.
- Test richiesto: smoke RPG headless, QA visuale a 1280x720 e 960x540,
  checklist RPG character art completata.

### RPG-001 - Tuning melee RPG e super starter

- Obiettivo: playtestare e tarare timing, knockback, hitstop percepito,
  leggibilita delle super starter e bilanciamento delle hitbox melee.
- Milestone collegata: `todo_roadmap.md` Milestone 7.
- File/sistemi coinvolti: `WeaponData`, `MeleeAttack`, `RpgSuperResolver`,
  `GameplayEffects`, `PlayerVisual`, risorse `game/weapons/rpg_*`.
- Criterio di accettazione: ascia resta potente ma rischiosa, spada controllata
  e difensiva, arco/pistola restano leggibili a distanza, e le quattro super
  starter sono riconoscibili in survival.
- Test richiesto: QA manuale survival con i quattro starter a 1280x720 e
  960x540, smoke RPG e `tests/rpg_melee_attack_resolution_smoke_test.gd`.

### RPG-002 - Polish classi RPG avanzate

- Obiettivo: rifinire Mago, Domatrice e Licantropo con VFX telegraph definitivi,
  droni/super di Nina, companion Briciola e trasformazione licantropo completa.
- Milestone collegata: `todo_roadmap.md` Milestone 7.
- File/sistemi coinvolti: `RpgPlayerComponent`, `RpgSuperResolver`,
  `BriciolaCompanion`, `PlayerVisual`, `WeaponData`, `assets/characters/`.
- Criterio di accettazione: le tre classi sono bilanciate contro i quattro
  starter, Briciola aiuta senza giocare da solo e `Notte Bestiale` termina
  sempre con recovery leggibile.
- Test richiesto: `tests/milestone_rpg_13_new_classes_smoke_test.gd`, smoke RPG
  esistenti e checklist RPG character art.

### UIUX-001 - UI, HUD, audio e polish UX trasversale

- Obiettivo: rifinire menu, HUD, Character Select, status, mappa, boss, feedback
  audio e leggibilita senza cambiare regole di gioco.
- Milestone collegata: `todo_roadmap.md` Milestone 8.
- File/sistemi coinvolti: `game/ui/`, `game/audio/`, `assets/audio/`,
  `game/visuals/`, `game/settings/`, `docs/testing/manual_checklist.md`.
- Criterio di accettazione: focus joypad sempre visibile, informazioni critiche
  leggibili senza testo piccolo, nessun SFX esterno obbligatorio e audio
  critico udibile con quattro player e boss wave.
- Test richiesto: QA menu/Character Select/Settings a 1280x720, 1024x768 e
  960x540, QA survival con quattro player, `character_select_ui`,
  `pause_settings` e regressione audio mix.

### BOSS-001 - Boss aggiuntivi e pattern avanzati

- Obiettivo: espandere il registro boss con un nuovo boss o pattern avanzati
  mantenendo il contratto condiviso tra modalita.
- Milestone collegata: `todo_roadmap.md` Milestone 9.
- File/sistemi coinvolti: `game/bosses/`, `game/visuals/`,
  `game/projectiles/`, `game/weapons/`, `game/drops/`, `HUDManager`,
  `BossSystem`.
- Criterio di accettazione: boss richiedibile per ID senza cambiare i chiamanti,
  compatibilita per modalita tipizzata, telegraph leggibile senza danno durante
  il warning e drop tramite `DropSystem`.
- Test richiesto: nuovo smoke boss/pattern, regressione `boss_smoke` e
  `milestone_19_boss_registry_smoke_test.gd`, QA survival/dungeon.

### TD-001 - Tower defense avanzata a scope minimo

- Obiettivo: valutare e implementare una sola espansione controllata tra
  upgrade, vendita, riparazione, nuovi tipi torre o percorsi multipli.
- Milestone collegata: `todo_roadmap.md` Milestone 10.
- File/sistemi coinvolti: `game/modes/tower_defense/`,
  `DefenseTowerVisual`, `game/weapons/`, `HUDManager`,
  `tests/tower_defense_smoke_test.gd`.
- Criterio di accettazione: la tower defense resta giocabile, non duplica
  combat/projectile/boss, ogni nuova azione ha costo e feedback chiari, retry e
  menu puliscono torri, crediti e nemici.
- Test richiesto: estensione `tower_defense_smoke_test`, smoke feature scelta e
  QA tower defense 5 wave con tastiera/joypad.

### QA-001 - Ampliare i test automatici dei sistemi critici

- Obiettivo: coprire meglio health, multiplayer, wave, save/load, world runtime
  e lifecycle oltre agli smoke gia presenti.
- Milestone collegata: `todo_roadmap.md` Milestone 11.
- File/sistemi coinvolti: `tests/`, `HealthSystem`, `LocalMultiplayerManager`,
  `WaveManager`, `SaveManager`, `WorldRuntime`, modalita gameplay.
- Criterio di accettazione: ogni sistema condiviso critico ha almeno uno smoke
  headless o una checklist automatizzabile, e la suite principale resta
  eseguibile con exit code `0`.
- Test richiesto: suite headless completa, nuovi smoke mirati e report test
  aggiornato.

### BAL-001 - Bilanciamento, performance e playtest end-to-end

- Obiettivo: affinare valori data-driven e performance dopo playtest reali su
  survival, dungeon, tower defense, RPG, biomi e boss.
- Milestone collegata: `todo_roadmap.md` Milestone 11.
- File/sistemi coinvolti: `game/modes/`, `game/rpg/`, `game/weapons/`,
  `game/enemies/`, `game/bosses/`, `game/visuals/`, `tests/`,
  `docs/testing/manual_checklist.md`.
- Criterio di accettazione: survival 10 wave e soak 10 minuti restano stabili,
  ogni classe RPG ha un motivo chiaro per essere scelta, i biomi avanzati sono
  pericolosi ma non frustranti e il frame time resta nel target documentato o
  viene tracciato come debito.
- Test richiesto: playtest survival 20 minuti con 1-4 player, dungeon con tre
  seed, tower defense 5 wave, profiling e regressione smoke principale.

### REL-001 - Packaging, firma digitale e release readiness

- Obiettivo: preparare una build Windows pubblicabile con export ripetibile,
  build smoke, asset attribuiti e firma digitale se il certificato e
  disponibile.
- Milestone collegata: `todo_roadmap.md` Milestone 12.
- File/sistemi coinvolti: `export_presets.cfg`, `build/`,
  `assets/ATTRIBUTION.md`, `assets/README.md`, `README.md`,
  `docs/latest_commit_validation_report.md`, `BuildRuntimeSmoke`.
- Criterio di accettazione: EXE/PCK generati da checkout pulito, build smoke
  exit code `0`, attribuzioni complete, EXE firmato oppure blocco esterno
  documentato.
- Test richiesto: export release, export pack, build smoke, avvio manuale
  Windows con controller/audio e verifica firma se toolchain disponibile.

### DOC-001 - Documentazione finale e workflow di iterazione

- Obiettivo: chiudere la TODO critica, aggiornare documentazione e lasciare un
  workflow chiaro per futuri goal.
- Milestone collegata: `todo_roadmap.md` Milestone 13.
- File/sistemi coinvolti: `README.md`, `ROADMAP.md`, `TODO.md`,
  `CHANGELOG.md`, `ARCHITECTURE.md`, `GAME_DESIGN.md`, `docs/`, `prompts/`.
- Criterio di accettazione: nessun punto TODO critico resta aperto senza owner
  o decisione, README descrive avvio/test/build/stato reale e i documenti
  tecnici non contraddicono il codice.
- Test richiesto: revisione incrociata documenti, avvio principale e build
  smoke solo se la release e nello scope.

## Follow-up e decisioni aperte

Queste decisioni non avviano lavoro da sole; vanno risolte dentro la milestone
collegata prima di implementare.

- Asset personaggi: decidere se il target finale usa PNG, SVG testuali o
  pipeline mista. Collegata ad `ASSET-002`.
- Dungeon shop: RISOLTA nella Milestone 5 -> usa run credit (valuta di run),
  non denaro party persistente, per non toccare save/progressione. `DUN-001`
  completata.
- Tower defense avanzata: confermare priorita prima di aprire un goal lungo.
  Collegata a `TD-001`.
- Nuovi boss: scegliere nuovo boss o espansione pattern esistenti. Collegata a
  `BOSS-001`.
- Firma digitale: verificare disponibilita certificato e toolchain. Collegata a
  `REL-001`.
- Mini-eventi bioma: durante il playtest end-to-end di `BAL-001`, raccogliere
  screenshot/video reali dei quattro eventi come materiale QA, senza riaprire
  `BIO-001` salvo nuovi bug o tuning richiesti.

## Reference storiche completate

Queste voci sono chiuse come primo pass o prototipo stabile. Restano qui per
evitare reimplementazioni e per indirizzare le regressioni.

- Milestone 0-21 della roadmap principale: completate; riferimento in
  `ROADMAP.md`, `docs/milestones/`, `README.md` e `CHANGELOG.md`.
- Roadmap Revamp Modalita Zombie Z1-Z12: completata; sopravvivono follow-up in
  `MAP-001`, `MAP-002` e `ASSET-001`.
- Roadmap Motore Generazione Mappe e Biomi: completata come primo motore
  procedurale integrato; usare come riferimento per regressioni world/biomi.
- Roadmap Megamappa Persistente Isometrica: completata come primo pass stabile;
  streaming e QA reale (`MAP-001`, `MAP-002`) chiusi nella Milestone 3 di
  `todo_roadmap.md`. Follow-up residui: asset isometrici (`ASSET-001`) e
  profiling/bilanciamento (`BAL-001`).
- MAP-001 QA attraversamento megamappa e MAP-002 streaming regioni: completati
  nella Milestone 3 di `todo_roadmap.md`; contratto `active_regions` formalizzato,
  persistenza runtime per regione (casse aperte non ricompaiono) e round-trip save
  v6 coperti da `tests/region_streaming_smoke_test.gd` e dalle regressioni world
  graph/persistent world/open passage/exploration map. Cattura screenshot reale
  rinviata al playtest Milestone 11. Ledger pronto per ostacoli distruttibili ed
  encounter region-bound futuri (oggi senza trigger di gioco).
- ASSET-001 pass asset isometrici ambiente: completato nella Milestone 4 di
  `todo_roadmap.md`; il manifest `assets/environment/isometric/manifest.json` (v2)
  e ora letto da `IsometricEnvironmentManifest` e copre i 21 obstacle_id reali con
  collisione/footprint/sort coerenti; `BiomeObstacle` ha ombra a terra e
  `sort_offset` data-driven; Y-sort abilitato in scena. Rendering procedurale
  (nessun asset esterno obbligatorio); conversione ad arte esterna definitiva e
  screenshot per bioma restano follow-up opzionali (playtest Milestone 11).
  Coperto da `tests/isometric_environment_manifest_smoke_test.gd`.
- DUN-001 dungeon ramificato, shop e biomi dedicati: completato nella Milestone 5
  di `todo_roadmap.md`; `DungeonGenerator` produce un grafo con ramo reale e boss
  sempre raggiungibile, `DungeonMode` gestisce scelta stanza, run credit, shop
  (reward via `DropSystem`) e rest room, `DungeonRoom` ha doppia uscita e theming
  per kind. Decisione: shop su run credit, non denaro party. UI shop dedicata e
  arte bioma dungeon restano follow-up. Coperto da
  `tests/dungeon_graph_smoke_test.gd` e `tests/dungeon_smoke_test.gd`.
- Roadmap RPG Mode M1-M13 e classi avanzate: completate come pass
  data-driven; tuning e polish sono tracciati in `ASSET-002`, `RPG-001` e
  `RPG-002`.
- Menu pausa, Settings condivisi, navigazione gamepad e Character Select RPG:
  completati come polish post-roadmap; regressioni in `UIUX-001`.
- Pass personaggi RPG distinguibili e melee reali: completato; regressioni in
  `RPG-001` e smoke RPG.
- BIO-001 mini-eventi bioma, status e encounter: completato nella Milestone 2
  di `todo_roadmap.md`; telegraph, reward crate, cooldown, high contrast,
  reduced motion e status evitabile sono coperti da smoke, con checklist
  manuale aggiornata per acquisire evidenza visuale durante playtest futuri.
- Iterazione survival biome-based status, ostacoli, roster ed encounter:
  completata come primo pass; regressioni future passano dai test
  `biome_mini_events`, `random_encounter`, status e survival.
- Ammo survival anti-frustrazione, boss registry, audio mix, risultati run,
  downed/revive, arena survival e accessibilita: completati; usare i test
  elencati in README e nel report di validazione.
- TECH-001 shutdown headless e lifecycle test: completato nella Milestone 1 di
  `todo_roadmap.md`; regressioni future da verificare con
  `tests/headless_shutdown_loop_test.gd` e smoke prioritari.

## Mappatura dalle vecchie sezioni TODO

- `Prossima iterazione biomi zombie survival` -> `BIO-001` completata,
  `MAP-001`/`MAP-002` completate nella Milestone 3, `ASSET-001` completata nella
  Milestone 4, follow-up residuo in `BAL-001`.
- `Megamappa persistente isometrica - follow-up` -> `MAP-001`, `MAP-002` e
  `ASSET-001` completate (Milestone 3 e 4).
- Duplicato storico sulla manutenzione headless dei test -> `TECH-001`.
- `Espandere il dungeon oltre il percorso lineare` -> `DUN-001` completata
  (Milestone 5).
- `Asset definitivi` generico -> `ASSET-001` completata (Milestone 4, ambiente),
  restano `ASSET-002` e `UIUX-001`.
- `Ampliare i test automatici` -> `QA-001`.
- `Asset definitivi personaggi RPG - futuro` -> `ASSET-002`.
- `Tuning melee RPG e super - futuro` -> `RPG-001`.
- `Polish classi RPG avanzate - futuro` -> `RPG-002`.
- `Firma digitale dell'eseguibile Windows` -> `REL-001`.
