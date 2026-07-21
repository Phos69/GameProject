# TODO

Questo file contiene solo backlog operativo aperto e decisioni ancora da
prendere. Le milestone archiviate, le roadmap storiche e le baseline di validazione
sono consolidate in `ROADMAP.md`, `CHANGELOG.md`, nei report specifici sotto
`docs/` e in `docs/documentation_inventory.md`.

Le milestone `UIUX-001`, `BOSS-001`, `BOSS-002`, `TD-001`, `REL-001`,
`WORLD-UNIFY-001`, `TERRAIN-PARCELS-001` e `TOPDOWN-001` sono completate e archiviate in `ROADMAP.md` e
`CHANGELOG.md` (dettagli in `map_generation_report.md`,
`docs/latest_commit_validation_report.md` e
`docs/visual_qa_report_2026-07-01.md`).

Regole per nuove voci:

- ogni item aperto deve indicare obiettivo, milestone collegata, file/sistemi,
  criterio di accettazione e test richiesto;
- non riaprire milestone archiviate senza un nuovo goal esplicito;
- spostare gli item conclusi in `CHANGELOG.md` o `ROADMAP.md`, non mantenerli qui;
- aggiornare questa TODO solo a fine lavoro quando una milestone cambia stato.

## Backlog Aperto Prioritizzato

### PLAINS-ROCK-001 - Consegna e cutover atlas rocciosi Plains

- Stato 2026-07-21: contratto manifest v18, prompt, chroma-key, resolver,
  `AtlasTexture`, geometria continua e regole Plains/Infinite Arena sono
  implementati. I due PNG sorgente restano intenzionalmente assenti; il runtime
  usa un fallback roccioso condiviso e non produce sostituti raster.
- Obiettivo: generare esternamente e consegnare
  `plains_dark_fantasy_wall_atlas.png` e
  `plains_dark_fantasy_top_atlas.png`, quindi promuovere il kit da `needs_asset`
  a `final` solo dopo la convalida visiva e topologica.
- Milestone collegata: polish ambiente post-`TOPDOWN-001`.
- File/sistemi coinvolti: `assets/environment/top_down/rock_cliffs/plains/`,
  manifest ambiente, `RockCliffAtlasSet`, renderer mesa/void/perimetro,
  `BiomeTileLayer`, Visual QA cliff e suite `assets`, `environment`,
  `obstacles`, `world_gen`, `modes`.
- Criterio di accettazione: due atlas RGBA `2048x2048` esatti, 32 regioni
  uniche e connesse, nessun materiale non roccioso, bordi repeatable, top non
  flat leggibile a `48x48`; nessun consumer runtime del vecchio raster upward.
- Test richiesto: import Godot, check alpha/chroma e atlas, suite GUT mirate,
  tavola completa e scene mesa/void/bordo/arena a `1280x720` e `960x540`,
  multi-seed Plains e verifica `F9` di collider, fall-zone e Y-sort multiplayer.

### BIOME-RASTER-002 - Raster ambientali delle tre varianti avanzate

- Stato 2026-07-20: integrati i primi 16 raster contestuali del follow-up,
  quattro coppie adulto/giovane per Pianura Ardente e Tundra Gelata. Restano i
  prop ambientali non-albero dei tre biomi e il set dedicato della Palude.
  Stato 2026-07-21: tutte le 24 varianti albero integrate sono state ripulite
  dalle isole alpha staccate; negli otto Frozen anche il matte bianco tra i rami
  e ora trasparente, mentre gli otto Burning sono stati reestratti con matte
  morbido e despill per eliminare gli highlight bianchi. I difetti sono protetti da check automatico; i
  lotti forestali palustri continuano a usare il fallback condiviso gia pulito finche non sara
  disponibile il set raster dedicato della Palude.
- Obiettivo: sostituire gli SVG ambientali ancora attivi in Pianura Ardente,
  Tundra Gelata e Palude con raster originali trasparenti coerenti con il
  pass completato per la Pianura, senza modificare gameplay o layout.
- Milestone collegata: polish asset post-`TOPDOWN-001`, successiva a
  `BIOME-RASTER-001`.
- File/sistemi coinvolti: `assets/environment/top_down/objects/`, manifest v13,
  `EnvironmentAssetManifest`, `EnvironmentObject`, Visual QA bioma e suite
  `assets`/`environment`/`obstacles`/`world_gen`.
- Criterio di accettazione: ogni prop visibile nelle tre varianti usa un PNG con
  alpha e silhouette cardinale leggibile; varianti condivise sono risolte per
  bioma; ID, footprint, collider, sort, probabilita e seed layout restano
  invariati; attribuzione e prompt sono registrati.
- Test richiesto: import Godot, check generatore ambiente, suite GUT mirate,
  boot della scena principale e Visual QA dedicata a ciascun bioma a
  `1280x720` e `960x540`, con controllo manuale `F9` di collider e Y-sort.

### BAL-001 - Bilanciamento, performance e playtest end-to-end

- Hardening streaming 2026-07-20: chiuso il crash nativo nell'unload regione,
  rimossi refresh/load first-use duplicati, introdotti residency near-world
  (corrente + solo varco vicino, non tutti i vicini di grafo), worker pool,
  finalizzazione geometrica a fasi, ownership per regione, retirement a budget,
  autosave asincrono, pooling terrain, eviction chunk a unita singola e
  deregistrazione batch lineare, firma/maschera CPU su worker e cue seam
  pre-generato. Il retirement ora avanza anche sotto carico continuo e una
  black box persistente registra memoria/frame/ObjectDB/code; il nuovo soak con
  streaming reale copre otto attraversamenti oltre la banda del varco e drain
  completo. Regressioni streaming 9/9, world graph 8/8, audio 1/1,
  integrazione 11/11 e tile layout 10/10 PASS; resta nel
  residuo manuale la misura p95/max renderizzata sul percorso ripetuto
  attraverso i seam.
- Stato 2026-07-08: la parte automatizzabile e' chiusa (suite soak/stress 8/8,
  profilo perf entro budget fino a ~96 mob, QA renderizzata del seam PASS,
  guardrail di nicchia su tutte e 7 le classi RPG); dettagli in
  `docs/latest_commit_validation_report.md`.
- Residuo aperto: **solo i playtest manuali** — Infinite Arena 20 minuti,
  survival multi-bioma 20 minuti con 1-4 player e zoom variabile, dungeon con
  tre seed, tower defense 5 wave con tastiera/joypad, giudizio qualitativo su
  "biomi pericolosi ma non frustranti", leggibilita/densita delle feature
  `WORLD-UNIFY-001` e raccolta screenshot dei mini-eventi (vedi Decisioni
  Aperte). Rientrano qui anche l'ascolto reale del mix con quattro pad e boss
  wave e l'ascolto di mix/SFX all'avvio della build esportata
  (`docs/testing/manual_checklist.md`).
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
  art attiva e zoom variabile, verifica manuale di collisione, Y-sort e densita
  di lotti/mesa/town/foreste/fall zone/hazard, dungeon con tre seed, tower defense 5 wave,
  leggibilita delle quattro elite zombie tra 20-28 mob, profiling renderizzato
  dello streaming chunk e regressione smoke principale.

## Decisioni Aperte

Queste decisioni non avviano lavoro da sole; vanno risolte dentro la milestone
collegata prima di implementare.

- Mini-eventi bioma: durante il playtest end-to-end di `BAL-001`, raccogliere
  screenshot/video reali dei quattro eventi come materiale QA; riaprire
  `BIO-001` solo in presenza di bug o tuning concreto.
