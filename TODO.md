# TODO

Questo file contiene solo backlog operativo aperto e decisioni ancora da
prendere. Le milestone archiviate, le roadmap storiche e le baseline di validazione
sono consolidate in `ROADMAP.md`, `CHANGELOG.md`, nei report specifici sotto
`docs/` e in `docs/documentation_inventory.md`.

Il cleanup documentale del 2026-07-01 ha rimosso prompt grezzi, roadmap
storiche archiviate, file milestone duplicati e vecchie sezioni TODO. Le
informazioni ancora utili sono consolidate nei documenti correnti.

Regole per nuove voci:

- ogni item aperto deve indicare obiettivo, milestone collegata, file/sistemi,
  criterio di accettazione e test richiesto;
- non riaprire milestone archiviate senza un nuovo goal esplicito;
- spostare gli item conclusi in `CHANGELOG.md` o `ROADMAP.md`, non mantenerli qui;
- aggiornare questa TODO solo a fine lavoro quando una milestone cambia stato.

## Backlog Aperto Prioritizzato

### UIUX-001 - UI, HUD, audio e polish UX trasversale

- Stato 2026-07-01: il faceplate world-space usa livello/EXP al posto di P1-P4,
  vita cromatica sulle due righe superiori, super verticale blu con glow e testi
  HP/ammo piu leggibili. Restano menu, HUD globale, audio e QA completa
  multi-risoluzione.
- Audit visuale 2026-07-01: `docs/visual_qa_report_2026-07-01.md` rileva
  Settings tagliato a 1280x720, HUD sovradimensionato, Character Select
  incompleto, scale crate/ostacoli incoerenti e leggibilita disomogenea delle
  armi. Le priorita `UI-VIS-FIX`, `ART-VIS-FIX` e `WEAPON-VIS-FIX` restano
  aperte dentro questa milestone.
- Obiettivo: rifinire menu, HUD, Character Select, status, mappa, boss, feedback
  audio e leggibilita senza cambiare regole di gioco.
- Milestone collegata: post-roadmap UI/UX Milestone 8.
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
- Milestone collegata: post-roadmap boss Milestone 9.
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
- Milestone collegata: post-roadmap tower defense Milestone 10.
- File/sistemi coinvolti: `game/modes/tower_defense/`,
  `DefenseTowerVisual`, `game/weapons/`, `HUDManager`,
  `tests/tower_defense_smoke_test.gd`.
- Criterio di accettazione: la tower defense resta giocabile, non duplica
  combat/projectile/boss, ogni nuova azione ha costo e feedback chiari, retry e
  menu puliscono torri, crediti e nemici.
- Test richiesto: estensione `tower_defense_smoke_test`, smoke feature scelta e
  QA tower defense 5 wave con tastiera/joypad.

### QA-001 - Ampliare i test automatici dei sistemi critici

- Stato Visual QA 2026-07-02: `QA-VIS-FIX` completato. Il runner esegue solo i
  25 entry point standalone, ogni scenario gameplay attende marker e chunk
  visibili pronti, la QA isometrica finale passa e la suite completa chiude con
  exit code `0`. I finding visuali di prodotto restano nelle milestone
  `UIUX-001` e `BAL-001`; dettagli in
  `docs/visual_qa_report_2026-07-01.md`.
- Obiettivo: coprire meglio health, multiplayer, wave, save/load, world runtime
  e lifecycle oltre agli smoke gia presenti.
- Milestone collegata: post-roadmap QA Milestone 11.
- File/sistemi coinvolti: `tests/`, `HealthSystem`, `LocalMultiplayerManager`,
  `WaveManager`, `SaveManager`, `WorldRuntime`, modalita gameplay.
- Criterio di accettazione: ogni sistema condiviso critico ha almeno uno smoke
  headless o una checklist automatizzabile, e la suite principale resta
  eseguibile con exit code `0`.
- Test richiesto: suite headless completa, nuovi smoke mirati e report test
  aggiornato.

### BAL-001 - Bilanciamento, performance e playtest end-to-end

- Stato WORLD-VIS-FIX 2026-07-02: chiusi i finding `VIS-003`/`VIS-004`.
  Infinite Arena distingue raised cliff e chasm, ogni contatto ground/void ha
  coverage cliff automatica, ostacoli/crate non possono occupare fall zone e il
  profilo renderizzato attraversa un seam con zoom variabile mantenendo zero
  chunk visibili mancanti. Restano tuning, soak e playtest lunghi di `BAL-001`.
- Obiettivo: affinare valori data-driven e performance dopo playtest reali su
  survival, dungeon, tower defense, RPG, biomi e boss.
- Milestone collegata: post-roadmap bilanciamento Milestone 11.
- File/sistemi coinvolti: `game/modes/`, `game/rpg/`, `game/weapons/`,
  `game/enemies/`, `game/bosses/`, `game/visuals/`, `tests/`,
  `docs/testing/manual_checklist.md`.
- Criterio di accettazione: survival 10 wave e soak 10 minuti restano stabili,
  i guardrail M12 restano verdi, ogni classe RPG ha un motivo chiaro per essere
  scelta, i biomi avanzati sono pericolosi ma non frustranti. In Zombie
  Survival a 1280x720, preset balanced, generated art, 4 player e 28 nemici:
  p95 normale <= 33,3 ms, frame massimo al seam <= 50 ms, zero chunk mancanti
  in camera e nessuna crescita di chunk/memoria dopo percorsi di ritorno.
- Test richiesto: playtest `Infinite Arena` 20 minuti, playtest survival
  multi-bioma 20 minuti con 1-4 player, attraversamento dei biomi con generated
  art attiva e zoom variabile, dungeon con tre seed, tower defense 5 wave,
  profiling renderizzato dello streaming chunk e regressione smoke principale.

### REL-001 - Packaging, firma digitale e release readiness

- Obiettivo: preparare una build Windows pubblicabile con export ripetibile,
  build smoke, asset attribuiti e firma digitale se il certificato e
  disponibile.
- Milestone collegata: post-roadmap release Milestone 12.
- File/sistemi coinvolti: `export_presets.cfg`, `build/`,
  `assets/ATTRIBUTION.md`, `assets/README.md`, `README.md`,
  `docs/latest_commit_validation_report.md`, `BuildRuntimeSmoke`.
- Criterio di accettazione: EXE/PCK generati da checkout pulito, build smoke
  exit code `0`, attribuzioni complete, EXE firmato oppure blocco esterno
  documentato.
- Test richiesto: export release, export pack, build smoke, avvio manuale
  Windows con controller/audio e verifica firma se toolchain disponibile.

## Decisioni Aperte

Queste decisioni non avviano lavoro da sole; vanno risolte dentro la milestone
collegata prima di implementare.

- Tower defense avanzata: scegliere una sola espansione prioritaria tra upgrade,
  vendita, riparazione, nuovi tipi torre o percorsi multipli. Collegata a
  `TD-001`.
- Nuovi boss: scegliere se aggiungere un boss nuovo o estendere pattern
  esistenti. Collegata a `BOSS-001`.
- Firma digitale: verificare disponibilita certificato e toolchain. Collegata a
  `REL-001`.
- Mini-eventi bioma: durante il playtest end-to-end di `BAL-001`, raccogliere
  screenshot/video reali dei quattro eventi come materiale QA; riaprire
  `BIO-001` solo in presenza di bug o tuning concreto.
- Arte personaggi RPG: decidere se produrre asset `final_quality`
  per-personaggio nel pass `UIUX-001` o lasciarli come polish opzionale.
