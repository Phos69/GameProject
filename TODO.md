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

La milestone `UIUX-001` e' **completata il 2026-07-07** (UI-VIS-FIX,
ART-VIS-FIX, WEAPON-VIS-FIX, main menu `VIS-012`, asset residui `VIS-009` e
regressione audio mix; dettagli in `CHANGELOG.md` e
`docs/visual_qa_report_2026-07-01.md`). L'unico controllo non automatizzabile
- l'ascolto reale del mix con quattro pad e boss wave - resta una voce di
`docs/testing/manual_checklist.md`.

Le milestone `BOSS-001` e `TD-001` sono **completate il 2026-07-08**:
`BOSS-001` con il pattern avanzato `crescent_barrage` del Wave Warden
(telegraph dedicato senza danno nel warning, rotazione a tre pattern in fase
due, contratto registry/ID invariato) e `TD-001` con l'upgrade delle torri a
tre livelli (stesso gesto interact sullo slot, costo per livello con rimborso,
pip di livello sul visual, prompt UP sullo slot, pulizia gia' coperta dal
lifecycle). Dettagli in `CHANGELOG.md` e
`docs/latest_commit_validation_report.md`; la QA manuale 5 wave con
tastiera/joypad rientra nei playtest gia' elencati in `BAL-001`.

### BAL-001 - Bilanciamento, performance e playtest end-to-end

- Stato 2026-07-08: **chiusa la parte automatizzabile**. Suite soak/stress
  8/8 (dieci wave multi-bioma, soak 10 minuti simulati, arena stress,
  lifecycle loop 100 cicli, perf bottleneck). Profilo perf rimisurato in
  finestra (RTX 2070S, vsync off): a 24 mob render 3,7/4,6 ms e frame medio
  16,5 ms; a 96 mob — 3,4 volte il profilo di accettazione da 28 nemici — il
  worst frame resta 28,9 ms, sotto il budget p95 di 33,3 ms; il tetto si
  supera solo verso ~192 mob (45,2 ms), fuori dall'envelope reale (wave 10 =
  21 nemici, wave 20 = 41). Il residuo "raster mob a schermo" e' chiuso come
  tetto accettato e documentato: il baking degli archetipi in sprite resta
  opzione futura solo se il contenuto superera' ~100 mob visibili
  simultanei. QA renderizzata del seam con zoom variabile PASS (zero chunk
  visibili mancanti, commit max 4,5 ms). Guardrail di nicchia esteso a tutte
  e 7 le classi RPG con statline uniche
  (`tests/suites/balance/weapon_balance_test.gd::test_advanced_class_niches`).
  Dettagli in `docs/latest_commit_validation_report.md`.
- Stato WORLD-VIS-FIX 2026-07-02: chiusi i finding `VIS-003`/`VIS-004`.
  Infinite Arena distingue raised cliff e chasm, ogni contatto ground/void ha
  coverage cliff automatica, ostacoli/crate non possono occupare fall zone e il
  profilo renderizzato attraversa un seam con zoom variabile mantenendo zero
  chunk visibili mancanti.
- Residuo aperto: **solo i playtest manuali** — Infinite Arena 20 minuti,
  survival multi-bioma 20 minuti con 1-4 player e zoom variabile, dungeon con
  tre seed, tower defense 5 wave con tastiera/joypad, giudizio qualitativo su
  "biomi pericolosi ma non frustranti" e raccolta screenshot dei mini-eventi
  (vedi Decisioni Aperte).
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

- Tower defense avanzata: **risolta il 2026-07-08** — scelta l'espansione
  "upgrade delle torri" (loop di spesa naturale sul flusso crediti esistente,
  nessuna duplicazione di combat/projectile). Vendita, riparazione, nuovi tipi
  torre e percorsi multipli restano fuori scope salvo nuova voce.
- Nuovi boss: **risolta il 2026-07-08** — estesi i pattern del Wave Warden
  (`crescent_barrage`) invece di aggiungere un boss nuovo; il registry resta
  pronto per un boss futuro con una nuova voce esplicita.
- Firma digitale: verificare disponibilita certificato e toolchain. Collegata a
  `REL-001`.
- Mini-eventi bioma: durante il playtest end-to-end di `BAL-001`, raccogliere
  screenshot/video reali dei quattro eventi come materiale QA; riaprire
  `BIO-001` solo in presenza di bug o tuning concreto.
- Hazard tematici nel mondo streammato: **risolta il 2026-07-08** — i theme
  hazard (`toxic_puddle`, `gas_cloud`, `lava_crack`, ...) restano fuori dal
  layout voidfirst e affidati agli encounter dinamici. Il layout streammato ha
  gia' pericolo spaziale coperto da guardrail (chasm/fall zone della void
  lottery) e scaling nemici per bioma; hazard di danno statici cambierebbero
  spawn e bilanciamento richiedendo un re-bake dei golden snapshot durante i
  playtest. Riaprire con una nuova voce solo se i playtest manuali giudicano i
  biomi avanzati poco pericolosi.
- Arte personaggi RPG: **risolta il 2026-07-07** — gli asset `final_quality`
  per-personaggio restano polish opzionale documentato (vedi `ROADMAP.md`),
  non backlog attivo; riaprire solo con un nuovo goal esplicito.
