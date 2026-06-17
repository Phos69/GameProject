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
| Test discovery | 73 runner trovati | `rg --files tests` | Usare come inventario per Milestone 1 e regressioni future |
| Suite smoke | PASS nell'ultima validazione completa disponibile | `docs/latest_commit_validation_report.md` | Rieseguire dopo modifiche runtime o teardown |
| Build/export Windows | PASS nell'ultima validazione completa disponibile | `docs/latest_commit_validation_report.md` | Rieseguire in Milestone 12 o se cambia packaging |
| Shutdown headless | Aperto e consolidato in `TECH-001` | Warning `ObjectDB/resources still in use` in 34 test nel report precedente | Affrontare in Milestone 1 |
| Roadmap storiche | Completate come primo pass o reference | `ROADMAP.md`, `roadmap_*.md`, `docs/milestones/` | Non usarle come backlog attivo se una voce e gia chiusa qui sotto |

Test eseguiti per questo audit: nessun test gameplay. La Milestone 0 richiede
revisione manuale, baseline e consolidamento TODO.

## Backlog aperto prioritizzato

### TECH-001 - Debito shutdown headless e lifecycle test

- Obiettivo: terminare la suite senza leak report `ObjectDB`, risorse ancora in
  uso o access violation intermittenti in shutdown.
- Milestone collegata: `todo_roadmap.md` Milestone 1.
- File/sistemi coinvolti: runner in `tests/`, lifecycle di `game/main/`,
  `game/modes/`, `game/audio/`, `game/projectiles/`, `game/drops/` e
  `game/debug/build_runtime_smoke.gd`.
- Criterio di accettazione: 100 avvii e shutdown consecutivi della scena
  principale passano con exit code `0`; gli smoke prioritari terminano senza
  warning noti oppure ogni residuo e isolato, riproducibile e documentato come
  limite engine-level.
- Test richiesto: loop dedicato di shutdown, suite headless completa e
  regressioni combat, survival, dungeon, tower defense, pause/settings,
  Character Select RPG e mini-eventi bioma.

### BIO-001 - QA mini-eventi bioma, status e encounter

- Obiettivo: validare con gameplay reale ritmo, reward, frequenza e leggibilita
  di `toxic_leak`, `fire_breakout`, `whiteout`, `marsh_emergence` e degli
  encounter survival biome-based.
- Milestone collegata: `todo_roadmap.md` Milestone 2.
- File/sistemi coinvolti: `RandomEncounterSystem`, `HazardSystem`,
  `BiomeStatusRuntime`, `ResourceCrateSystem`, `WaveDirector`, HUD annunci,
  debug overlay e checklist manuale.
- Criterio di accettazione: ogni evento resta evitabile, non blocca passaggi,
  casse o spawn validi, assegna reward proporzionata e resta leggibile in
  default, high contrast e reduced motion.
- Test richiesto: QA manuale 10 wave con seed fisso, screenshot o video dei
  quattro mini-eventi, `tests/biome_mini_events_smoke_test.gd`,
  `tests/random_encounter_smoke_test.gd` e regressione survival/RPG.

### MAP-001 - QA attraversamento continuo della megamappa

- Obiettivo: validare su schermo reale passaggi fisici aperti, fall boundary,
  mappa esplorazione e dodge/gap attraversando territori multipli.
- Milestone collegata: `todo_roadmap.md` Milestone 3, parte QA.
- File/sistemi coinvolti: `WorldRuntime`, `BiomeTransitionSystem`,
  `TerrainGenerator`, `ExplorationMapPanel`, `PlayerDodgeComponent`,
  `HazardSystem`.
- Criterio di accettazione: il party attraversa almeno otto regioni con seed
  fisso senza teletrasporti percepiti, senza passaggi ostruiti e con mappa
  leggibile in default e high contrast.
- Test richiesto: checklist manuale 20 minuti survival con seed fisso,
  screenshot mappa, verifica dodge su gap piccolo e smoke world graph,
  persistent world, open passage, terrain coverage, fall boundary, dodge e
  exploration map.

### MAP-002 - Streaming visuale delle regioni lontane

- Obiettivo: rendere `WorldRuntime` proprietario della regione corrente e dei
  vicini N/E/S/W precaricati, lasciando le regioni lontane solo come dati.
- Milestone collegata: `todo_roadmap.md` Milestone 3, parte implementativa.
- File/sistemi coinvolti: `WorldRuntime`, `ZombieModeController`,
  `TerrainGenerator`, `ObstacleSystem`, `ResourceCrateSystem`, `HazardSystem`,
  `SaveManager`.
- Criterio di accettazione: le regioni lontane non restano istanziate; rientrare
  in una regione non ricrea casse gia aperte, encounter completati o ostacoli
  distrutti; mappa e save v6 restano coerenti.
- Test richiesto: smoke headless load/unload regioni, profiling manuale con
  griglia almeno `7x7` e regressioni world/survival.

### ASSET-001 - Pass asset isometrici ambiente

- Obiettivo: sostituire progressivamente placeholder ambientali con oggetti
  isometrici coerenti senza rendere obbligatori asset esterni.
- Milestone collegata: `todo_roadmap.md` Milestone 4.
- File/sistemi coinvolti: `assets/environment/isometric/manifest.json`,
  `assets/README.md`, `assets/ATTRIBUTION.md`, `BiomeObstacle`,
  `TerrainGenerator`, `ObstacleSystem`, `BiomeFallZone`, `game/visuals/`.
- Criterio di accettazione: ogni categoria convertita ha visual scene,
  collision shape, shadow, sort offset, footprint tiles e flag di blocco
  coerenti; sorting Y e silhouette non coprono player, zombie o pickup in modo
  errato.
- Test richiesto: QA visuale a 1280x720 e 960x540, verifica default/reduced
  motion/high contrast, smoke collisioni/footprint e test manifest.

### DUN-001 - Dungeon ramificato, shop e biomi dedicati

- Obiettivo: espandere il dungeon oltre il percorso lineare con diramazioni,
  scelta stanza, shop minimo, biomi dedicati e mappa percorso essenziale.
- Milestone collegata: `todo_roadmap.md` Milestone 5.
- File/sistemi coinvolti: `DungeonGenerator`, `DungeonMode`, `DungeonRoom`,
  scene dungeon, `HUDManager`, UI mappa/scelta stanza, `DropSystem`,
  `BossSystem`.
- Criterio di accettazione: almeno un seed produce una scelta reale tra due
  stanze, il percorso al boss resta sempre raggiungibile, shop e loot non
  duplicano progressione/drop e la run termina correttamente nei risultati.
- Test richiesto: estensione `tests/dungeon_smoke_test.gd` su seed multipli,
  smoke grafo dungeon con branch/shop e checklist manuale con tastiera/joypad.

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
- Dungeon shop: decidere valuta di run, denaro party persistente o modello
  ibrido. Collegata a `DUN-001`.
- Tower defense avanzata: confermare priorita prima di aprire un goal lungo.
  Collegata a `TD-001`.
- Nuovi boss: scegliere nuovo boss o espansione pattern esistenti. Collegata a
  `BOSS-001`.
- Firma digitale: verificare disponibilita certificato e toolchain. Collegata a
  `REL-001`.

## Reference storiche completate

Queste voci sono chiuse come primo pass o prototipo stabile. Restano qui per
evitare reimplementazioni e per indirizzare le regressioni.

- Milestone 0-21 della roadmap principale: completate; riferimento in
  `ROADMAP.md`, `docs/milestones/`, `README.md` e `CHANGELOG.md`.
- Roadmap Revamp Modalita Zombie Z1-Z12: completata; sopravvivono follow-up in
  `BIO-001`, `MAP-001`, `MAP-002` e `ASSET-001`.
- Roadmap Motore Generazione Mappe e Biomi: completata come primo motore
  procedurale integrato; usare come riferimento per regressioni world/biomi.
- Roadmap Megamappa Persistente Isometrica: completata come primo pass stabile;
  streaming e QA reale sono tracciati in `MAP-001` e `MAP-002`.
- Roadmap RPG Mode M1-M13 e classi avanzate: completate come pass
  data-driven; tuning e polish sono tracciati in `ASSET-002`, `RPG-001` e
  `RPG-002`.
- Menu pausa, Settings condivisi, navigazione gamepad e Character Select RPG:
  completati come polish post-roadmap; regressioni in `UIUX-001`.
- Pass personaggi RPG distinguibili e melee reali: completato; regressioni in
  `RPG-001` e smoke RPG.
- Iterazione survival biome-based status, ostacoli, roster ed encounter:
  completata come primo pass; playtest e tuning restano in `BIO-001`.
- Ammo survival anti-frustrazione, boss registry, audio mix, risultati run,
  downed/revive, arena survival e accessibilita: completati; usare i test
  elencati in README e nel report di validazione.

## Mappatura dalle vecchie sezioni TODO

- `Prossima iterazione biomi zombie survival` -> `BIO-001`.
- `Megamappa persistente isometrica - follow-up` -> `MAP-001`, `MAP-002`,
  `ASSET-001`.
- Duplicato storico sulla manutenzione headless dei test -> `TECH-001`.
- `Espandere il dungeon oltre il percorso lineare` -> `DUN-001`.
- `Asset definitivi` generico -> `ASSET-001`, `ASSET-002`, `UIUX-001`.
- `Ampliare i test automatici` -> `QA-001`.
- `Asset definitivi personaggi RPG - futuro` -> `ASSET-002`.
- `Tuning melee RPG e super - futuro` -> `RPG-001`.
- `Polish classi RPG avanzate - futuro` -> `RPG-002`.
- `Firma digitale dell'eseguibile Windows` -> `REL-001`.
