# Repo Fix Roadmap

Data: 2026-06-20

Questa roadmap parte dai problemi osservati in `repo_status_report.md`. Ogni
milestone e pensata per essere eseguibile come goal separato, con modifiche
piccole e verificabili.

## Milestone 1 - Stabilizzare workflow build/test

Stato: completata il 2026-06-20.

Evidenza:

- `tools/run_tests.ps1 -Filter milestone_rpg_10_balance -SkipImport` ora passa
  con exit code `0`.
- Un test realmente fallito continua a restituire exit code non zero.
- Timeout forzato su test lento viene terminato e segnalato.
- I runner scrivono log persistenti in `build/test_logs/`.
- Le categorie `all`, `fast`, `slow`, `soak` e `visual` sono documentate.

### Obiettivo

Rendere affidabile la validazione locale e separare test veloci, lenti, soak e
visual QA.

### Problemi risolti

- Runner PowerShell che false-fail.
- Suite troppo lenta e non classificata.
- Helper non-`SceneTree` eseguibili per errore.
- Hangs non gestiti su test con errore script.

### Interventi tecnici

- Correggere `tools/run_tests.ps1` per catturare exit code reale, stdout/stderr
  e timeout senza `Start-Process` fragile.
- Assicurare kill del process tree Godot su timeout.
- Allineare comportamento con `tools/run_tests.sh`.
- Aggiungere categorie o filtri documentati: `fast`, `slow`, `soak`, `visual`.
- Escludere helper come `tests/test_scene_lifecycle.gd`.
- Aggiornare `CONTRIBUTING.md` e `.github/workflows/ci.yml` se il contratto
  runner cambia.

### Criteri di completamento

- `tools/run_tests.ps1 -Filter milestone_rpg_10_balance -SkipImport` riporta
  PASS quando il log Godot passa.
- Un test noto fallito continua a restituire exit code non zero.
- Un test in hang viene terminato con log chiaro.
- La suite fast non include visual QA, soak o test ultra-lenti.
- La documentazione spiega i comandi Windows e shell.

### Test manuali

1. Eseguire un test PASS singolo.
2. Eseguire un test FAIL singolo.
3. Eseguire un filtro senza match.
4. Simulare timeout su un test lento con limite basso.
5. Verificare che `build/test_logs/` contenga log leggibili.

### Rischi

- Gestione processi diversa tra PowerShell versioni diverse.
- Possibile divergenza tra runner Windows, shell e CI.

## Milestone 2 - Riallineare survival, mappa e biomi

Stato: completata il 2026-06-20.

Decisione: la survival standard usa la megamappa `3x3` multi-bioma. L'arena
`1x1` resta disponibile solo con context esplicito `single_biome_arena = true`
e non sovrascrive dimensioni mappa passate dal chiamante.

Evidenza:

- `ZombieModeController` non forza piu `biome_map_width = 1` /
  `biome_map_height = 1` per le run standard.
- `tests/zombie_survival_world_contract_smoke_test.gd` copre default `3x3`,
  profilo `1x1` esplicito e override dimensioni.
- `tests/zombie_biome_transition_smoke_test.gd` resta il test end-to-end del
  contratto multi-bioma standard.

### Obiettivo

Stabilire il contratto ufficiale della survival standard e renderlo coerente tra
codice, test e documenti.

### Problemi risolti

- Divergenza tra arena `1x1` runtime e roadmap/documenti `3x3`.
- Test `zombie_biome_transition_smoke_test.gd` fallito.
- Varieta biomi non visibile nella run standard.

### Interventi tecnici

- Decidere se la survival default e `3x3` multi-bioma o `1x1` arena compatta.
- Raccomandazione: usare `3x3` come default survival e mantenere `1x1` come
  profilo quick/test esplicito.
- Modificare `game/modes/zombie/zombie_mode_controller.gd`, sostituendo il
  vecchio override implicito con `_resolve_survival_world_context()`.
- Verificare `game/procedural/world_generation/biome_map_generator.gd`.
- Aggiornare `README.md`, `ROADMAP.md`, `TODO.md`, `GAME_DESIGN.md` e
  `ARCHITECTURE.md`.
- Aggiornare o confermare `tests/zombie_biome_transition_smoke_test.gd`.

### Criteri di completamento

- Il contratto default e scritto in docs e codice.
- Se default e `3x3`, il graph contiene almeno `infected_plains`,
  `toxic_wastes`, `burning_fields`, `frozen_outskirts` e `drowned_marsh`.
- Se default resta `1x1`, i test e documenti non promettono multi-bioma nella
  run standard.
- `zombie_biome_transition_smoke_test.gd` passa o viene sostituito da due test
  espliciti: arena quick e survival multi-bioma.

### Test manuali

1. Avviare survival dal menu.
2. Verificare dimensione/biomi della run con overlay debug o log.
3. Muoversi verso i confini regione.
4. Confermare presenza di passaggi e assenza di teleport legacy.
5. Controllare che spawn player/crate restino su celle walkable.

### Rischi

- Aumentare il default a `3x3` puo peggiorare tempi di bootstrap e performance.
- La correzione puo rompere test che assumono arena singola.

## Milestone 3 - Ripulire contratto HUD gameplay

### Obiettivo

Eliminare duplicazioni tra world HUD, corner card e status panel, mantenendo
feedback leggibile per health, ammo, reload, XP, adrenaline e modalita.

### Problemi risolti

- `milestone_10_visual_smoke_test.gd` fallito.
- `milestone_rpg_5_ammo_reload_smoke_test.gd` fallito.
- `milestone_rpg_9_hud_smoke_test.gd` fallito.
- Responsabilita confuse tra `PlayerHudCard`, `PlayerWorldHudVisual` e
  `HUDManager`.

### Interventi tecnici

- Scrivere in `ARCHITECTURE.md` una tabella ownership HUD.
- Modificare `game/ui/player_hud_card.gd` per non creare/esporre duplicati non
  previsti.
- Verificare `game/ui/player_world_hud_visual.gd` per health/reload/ammo/XP.
- Aggiornare `game/ui/hud_manager.gd` solo dove serve per aggregazione stato.
- Mantenere accessibilita reduced motion/high contrast se gia supportate.

### Criteri di completamento

- I tre test HUD falliti passano.
- Nessun dato critico sparisce: HP, ammo, reload e XP restano visibili in almeno
  un punto ufficiale.
- Niente overlap evidente su 1280x720 e 1920x1080.
- `CHANGELOG.md` e docs aggiornati.

### Test manuali

1. Avviare survival.
2. Subire danno e verificare HP.
3. Sparare, ricaricare e cambiare arma.
4. Raccogliere XP/drop e verificare level progress.
5. Verificare HUD vicino al player e corner card.

### Rischi

- Rimuovere nodi usati da altri test o scene.
- Perdere feedback durante reload o low ammo.

## Milestone 4 - Riparare Character Select e menu navigation

### Obiettivo

Rendere di nuovo testabile il flusso character select e migliorare la struttura
del menu senza riscrivere tutto `MainMenu`.

### Problemi risolti

- `milestone_rpg_1_character_select_smoke_test.gd` accede a proprieta
  inesistente e puo restare appeso.
- `MainMenu` concentra troppe responsabilita.
- Input joypad/menu non ha validazione sufficiente.

### Interventi tecnici

- Scegliere il contratto: reintrodurre `character_detail_panel` o aggiornare il
  test al panel/preview attuale.
- Spostare solo se necessario una parte evidente in un componente dedicato,
  per esempio character select view model o navigation helper.
- Aggiungere guardrail nel test per uscire sempre anche su errore.
- Coprire navigazione menu con tastiera e joypad.
- Aggiornare `ARCHITECTURE.md`, `TODO.md` e `CHANGELOG.md`.

### Criteri di completamento

- `milestone_rpg_1_character_select_smoke_test.gd` passa e termina pulitamente.
- Character select mostra dati personaggio coerenti.
- Conferma/back funzionano con tastiera e joypad.
- Nessuna regressione su avvio survival dal menu.

### Test manuali

1. Aprire menu principale.
2. Navigare con frecce/D-pad.
3. Cambiare personaggio/slot.
4. Entrare e uscire da settings.
5. Avviare survival e tornare al menu.

### Rischi

- Refactor troppo ampio di `MainMenu`.
- Perdita focus UI su joypad.

## Milestone 5 - Stabilizzare spawn zombie fuori camera

### Obiettivo

Garantire spawn preview e spawn effettivi fuori camera, preservando vincoli di
walkability, hazard e region streaming.

### Problemi risolti

- `zombie_spawner_edge_smoke_test.gd` fallito.
- `zombie_revamp_foundation_smoke_test.gd` fallito.
- Contratto ambiguo tra candidate edge e fallback validato.

### Interventi tecnici

- Separare in `game/modes/zombie/zombie_spawner.gd`:
  - generazione candidate edge;
  - validazione camera;
  - validazione walkable/hazard/blocker;
  - fallback.
- Aggiungere logging/test helper per capire perche un candidato viene scartato.
- Conservare rifiuto di player overlap, fall zone e blocker.
- Aggiornare test se devono distinguere preview da spawn finale.

### Criteri di completamento

- `zombie_spawner_edge_smoke_test.gd` passa.
- `zombie_revamp_foundation_smoke_test.gd` passa.
- I nemici non spawnano su void o blocker.
- Le wave continuano a spawnare in regioni streammate.

### Test manuali

1. Avviare survival in una scena con camera standard.
2. Restare fermo durante la prima wave.
3. Verificare che i nemici arrivino da fuori camera.
4. Avvicinarsi a void/cliff e verificare che spawn non avvengano su celle
   invalide.
5. Cambiare regione e ripetere.

### Rischi

- Candidati fuori camera ma non raggiungibili.
- Spawn troppo lontani che rallentano il ritmo wave.

## Milestone 6 - Stato modalita e Tower Defense HUD

### Obiettivo

Rendere coerente il feedback HUD delle modalita, partendo da Tower Defense.

### Problemi risolti

- `tower_defense_smoke_test.gd` fallito sullo stato HUD.
- `HUDManager._refresh()` nasconde sempre il panel status.
- Contratto modalita/HUD poco esplicito.

### Interventi tecnici

- Decidere dove appare lo stato modalita: `status_label`, banner temporaneo o
  panel dedicato.
- Aggiornare `game/ui/hud_manager.gd` e test coerentemente.
- Verificare integrazione con survival, pause, run results e down/revive.
- Documentare il contratto in `ARCHITECTURE.md`.

### Criteri di completamento

- `tower_defense_smoke_test.gd` passa.
- Survival non mostra stato Tower Defense.
- Il panel non copre HUD critico.
- Modalita future hanno un punto unico per aggiornare lo stato.

### Test manuali

1. Avviare Tower Defense.
2. Verificare nome modalita e wave/status.
3. Piazzare torre, attendere wave, verificare credits/core.
4. Tornare al menu o cambiare modalita.
5. Avviare survival e verificare assenza di stato errato.

### Rischi

- Riattivare un panel nascosto puo creare overlap.
- Test e design potrebbero aspettarsi UI diverse.

## Milestone 7 - Refactor architetturale mirato

### Obiettivo

Ridurre hotspot oltre 1000 LOC e duplicazioni senza riscrivere sistemi
funzionanti.

### Problemi risolti

- File troppo grandi.
- Responsabilita sparse.
- Difficolta a modificare sistemi centrali.

### Interventi tecnici

- Partire da un file per goal, non da una riscrittura globale.
- Candidati:
  - `game/ui/main_menu.gd`;
  - `game/procedural/world_generation/obstacle_layout_generator.gd`;
  - `game/weapons/weapon_visual_renderer.gd`;
  - `game/modes/zombie/isometric_tile_resolver.gd`;
  - `game/modes/zombie/isometric_svg_texture_loader.gd`;
  - `game/modes/zombie/biome_obstacle.gd`.
- Estrarre helper piccoli in cartelle coerenti.
- Conservare API pubbliche dove possibile.
- Aggiungere test smoke mirati prima di ogni estrazione rischiosa.

### Criteri di completamento

- Ogni refactor ha commit/goal separato.
- Nessun file estratto introduce nuova responsabilita duplicata.
- I test gia esistenti del sistema passano prima e dopo.
- `ARCHITECTURE.md` descrive il nuovo confine.

### Test manuali

Dipendono dal sistema refactorato. Per ogni estrazione eseguire almeno:

1. Scena principale.
2. Test smoke del sistema.
3. Una sessione manuale breve sul flusso utente toccato.

### Rischi

- Refactor meccanici troppo ampi.
- Rompere dipendenze Godot via scene/exported NodePath.

## Milestone 8 - Ridurre lookup globali e dipendenze implicite

### Obiettivo

Ridurre l'uso di `get_first_node_in_group` nei percorsi critici e rendere piu
esplicite le dipendenze tra sistemi.

### Problemi risolti

- Circa 204 lookup globali nel codice di gioco.
- Bootstrap e runtime order fragili.
- Difficolta a testare sistemi isolati.

### Interventi tecnici

- Censire i lookup per area: player, HUD, mode controller, spawner, world.
- Usare o estendere pattern gia presenti come `PlayerQuery`.
- Introdurre registry o injection solo dove riduce complessita reale.
- Non toccare lookup innocui o editor-only nella prima passata.

### Criteri di completamento

- Numero di lookup ridotto nei sistemi selezionati.
- Nessun nuovo service locator generico senza contratto.
- Test player/HUD/spawner passano.
- Documentazione aggiornata.

### Test manuali

1. Avviare main scene.
2. Cambiare modalita o tornare al menu.
3. Avviare survival e Tower Defense.
4. Verificare che player, HUD e spawner trovino i riferimenti corretti.

### Rischi

- Spostare dipendenze implicite in configurazioni scene non testate.
- Aumentare coupling se il registry diventa troppo generico.

## Milestone 9 - Asset, isometria e fallback policy

### Obiettivo

Portare asset, terreno, ostacoli, void, cliff e fallback a un contratto visuale
verificabile.

### Problemi risolti

- Fallback/legacy ancora diffusi.
- Asset procedural/SVG da validare visualmente.
- Occupazione griglia di ostacoli/cliff/void da controllare in build reale.

### Interventi tecnici

- Classificare fallback in necessari, temporanei e rimovibili.
- Aggiungere test contro fallback generici nei percorsi standard.
- Eseguire visual QA per:
  - terreno multi-bioma;
  - ostacoli e blocker;
  - void/fall zone;
  - cliff/mountain wall;
  - pickup weapon e projectile.
- Aggiornare manifest asset e documenti QA.

### Criteri di completamento

- Asset check continua a passare.
- Visual QA genera screenshot leggibili.
- Nessun percorso standard usa placeholder generico non documentato.
- Occupazione griglia coincide con collisioni principali.

### Test manuali

1. Avviare survival in almeno due biomi.
2. Verificare leggibilita terreno/ostacoli.
3. Camminare vicino a cliff e void.
4. Raccogliere armi e osservare pickup/projectile.
5. Salvare screenshot QA.

### Rischi

- Test logici passano ma resa visiva resta scarsa.
- Rimozione fallback puo causare asset mancanti.

## Milestone 10 - Armi, drop, progressione e feedback

### Obiettivo

Confermare che il sistema weapon/inventory/ammo/drop/progressione sia coerente
nel gameplay reale, non solo nei test isolati.

### Problemi risolti

- Feedback HUD collegato ad ammo/reload/XP.
- Rischio regressioni su catalogo armi.
- Bilanciamento drop e progressione da validare in run.

### Interventi tecnici

- Rieseguire test weapon inventory/catalog/visual dopo milestone HUD.
- Aggiungere o aggiornare un test end-to-end che copra:
  - pickup arma;
  - cambio slot;
  - ammo/reload;
  - kill zombie;
  - drop/XP;
  - level/passive.
- Verificare bilanciamento iniziale in `GAME_DESIGN.md`.
- Evitare nuove armi finche il loop base non e validato.

### Criteri di completamento

- Test weapon e RPG progressione passano.
- Feedback visuale di pickup, ammo, reload, XP e level up e leggibile.
- Drop non duplica armi esaurite e non rompe inventory persistente.
- Manual playtest di almeno 10 minuti senza blocchi.

### Test manuali

1. Avviare survival.
2. Raccogliere almeno 3 armi.
3. Consumare ammo e ricaricare.
4. Uccidere nemici e raccogliere XP/drop.
5. Sbloccare un level up/passive.
6. Verificare che HUD e audio/feedback siano chiari.

### Rischi

- Bilanciamento troppo facile/difficile maschera bug di progressione.
- Modifiche HUD possono rompere test ammo/reload.

## Milestone 11 - Zombie, nemici e bilanciamento survival

### Obiettivo

Validare ritmo, spawn, boss, varianti e cross-bioma nella modalita zombie dopo
il riallineamento mappa.

### Problemi risolti

- Spawn e biomi non coerenti.
- Bilanciamento survival non verificato in run multi-bioma.
- Rischio che test soak passino ma gameplay sia poco leggibile.

### Interventi tecnici

- Rieseguire ten-wave, soak, boss e cross-biome test.
- Aggiungere metriche leggere per wave duration, nemici vivi, drop e danni.
- Verificare boss registry e varianti enemy nei biomi avanzati.
- Aggiornare `GAME_DESIGN.md` con pacing e criteri bilanciamento.

### Criteri di completamento

- Test zombie principali passano.
- Run manuale 20 minuti senza softlock.
- Spawn restano fuori camera e raggiungibili.
- Il player incontra varieta nemici/biomi prevista.

### Test manuali

1. Avviare survival standard.
2. Sopravvivere 10 wave.
3. Attraversare regioni/biomi.
4. Affrontare boss o evento equivalente.
5. Annotare tempi wave, drop, difficolta e morti.

### Rischi

- Performance peggiora con multi-bioma.
- Spawn troppo lontani o troppo vicini alterano il pacing.

## Milestone 12 - Documentazione, release e continuita Codex

### Obiettivo

Chiudere il ciclo con documenti aggiornati, checklist ripetibili e build/export
verificabile.

### Problemi risolti

- Documenti non allineati al runtime.
- Mancanza di checklist release/manual QA.
- Necessita di contesto chiaro per goal Codex successivi.

### Interventi tecnici

- Aggiornare `README.md`, `ROADMAP.md`, `TODO.md`, `ARCHITECTURE.md`,
  `GAME_DESIGN.md` e `CHANGELOG.md`.
- Creare o aggiornare checklist manuale in `docs/`.
- Validare export preset Windows se richiesto dalla release.
- Documentare comandi standard per:
  - import Godot;
  - test fast;
  - test slow;
  - visual QA;
  - asset check;
  - export build.
- Archiviare report di validazione aggiornato in `docs/`.

### Criteri di completamento

- Documenti non promettono feature assenti.
- Ogni milestone completata ha test e checklist registrati.
- Il comando di export/build documentato funziona o il blocco e esplicito.
- Un nuovo goal Codex puo partire da roadmap e report senza rileggere tutto da
  zero.

### Test manuali

1. Seguire README da checkout pulito locale.
2. Eseguire import e test fast.
3. Eseguire asset check.
4. Avviare build o main scene.
5. Verificare che docs e comportamento coincidano.

### Rischi

- Aggiornare docs senza ricontrollare il runtime crea nuova divergenza.
- Export puo richiedere template o configurazione locale non presente.
