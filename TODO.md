# TODO

Questo file contiene solo backlog operativo aperto e decisioni ancora da
prendere. Le milestone archiviate, le roadmap storiche e le baseline di validazione
sono consolidate in `ROADMAP.md`, `CHANGELOG.md`, nei report specifici sotto
`docs/` e in `docs/documentation_inventory.md`.

Le milestone `UIUX-001`, `BOSS-001`, `BOSS-002`, `TD-001` e `REL-001` sono
completate e archiviate in `CHANGELOG.md` (dettagli in
`docs/latest_commit_validation_report.md` e
`docs/visual_qa_report_2026-07-01.md`).

Regole per nuove voci:

- ogni item aperto deve indicare obiettivo, milestone collegata, file/sistemi,
  criterio di accettazione e test richiesto;
- non riaprire milestone archiviate senza un nuovo goal esplicito;
- spostare gli item conclusi in `CHANGELOG.md` o `ROADMAP.md`, non mantenerli qui;
- aggiornare questa TODO solo a fine lavoro quando una milestone cambia stato.

## Backlog Aperto Prioritizzato

### BAL-001 - Bilanciamento, performance e playtest end-to-end

- Stato 2026-07-08: la parte automatizzabile e' chiusa (suite soak/stress 8/8,
  profilo perf entro budget fino a ~96 mob, QA renderizzata del seam PASS,
  guardrail di nicchia su tutte e 7 le classi RPG); dettagli in
  `docs/latest_commit_validation_report.md`.
- Residuo aperto: **solo i playtest manuali** — Infinite Arena 20 minuti,
  survival multi-bioma 20 minuti con 1-4 player e zoom variabile, dungeon con
  tre seed, tower defense 5 wave con tastiera/joypad, giudizio qualitativo su
  "biomi pericolosi ma non frustranti" e raccolta screenshot dei mini-eventi
  (vedi Decisioni Aperte). Rientrano qui anche l'ascolto reale del mix con
  quattro pad e boss wave e l'ascolto di mix/SFX all'avvio della build
  esportata (`docs/testing/manual_checklist.md`).
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

## Decisioni Aperte

Queste decisioni non avviano lavoro da sole; vanno risolte dentro la milestone
collegata prima di implementare.

- Mini-eventi bioma: durante il playtest end-to-end di `BAL-001`, raccogliere
  screenshot/video reali dei quattro eventi come materiale QA; riaprire
  `BIO-001` solo in presenza di bug o tuning concreto.
