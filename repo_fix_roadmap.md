# Repo Fix Roadmap

Data: 2026-06-20

Questa roadmap parte dai problemi osservati in `repo_status_report.md`. Ogni
milestone e pensata per essere eseguibile come goal separato, con modifiche
piccole e verificabili.

## Decisione prodotto aggiornata - Modalita default

Decisione del 2026-06-20 prima della vecchia Milestone 3:

- La modalita gameplay di default diventa `Infinite Arena`: un unico blocco
  `500x500`, senza mappa multi-regione, con mura fisiche intorno al perimetro e
  ondate infinite.
- `Zombie Survival` diventa la modalita dedicata alla mappa con biomi connessi:
  megamappa seed-based, regioni `500x500`, passaggi fisici, streaming regioni,
  esplorazione e biomi avanzati.
- La Milestone 2 completata resta valida come fondazione tecnica del contratto
  multi-bioma di `Zombie Survival`, ma non descrive piu la modalita default.
- Prima di riprendere il lavoro HUD della vecchia Milestone 3, va implementata
  la nuova Milestone 3 qui sotto.

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

Decisione storica: la survival standard e stata riallineata alla megamappa
`3x3` multi-bioma. Dopo la decisione prodotto aggiornata, questo contratto viene
assegnato a `Zombie Survival`, mentre la nuova modalita default sara
`Infinite Arena` con un singolo blocco `500x500` murato.

Evidenza:

- `ZombieModeController` non forza piu `biome_map_width = 1` /
  `biome_map_height = 1` per le run standard.
- `tests/zombie_survival_world_contract_smoke_test.gd` copre default `3x3`,
  profilo `1x1` esplicito e override dimensioni.
- `tests/zombie_biome_transition_smoke_test.gd` resta il test end-to-end del
  contratto multi-bioma standard.

### Obiettivo

Stabilire il contratto multi-bioma di `Zombie Survival` e renderlo coerente tra
codice, test e documenti.

### Problemi risolti

- Divergenza tra arena `1x1` runtime e roadmap/documenti `3x3` per la modalita
  zombie multi-bioma.
- Test `zombie_biome_transition_smoke_test.gd` fallito.
- Varieta biomi non visibile nella run standard.

### Interventi tecnici

- Usare `3x3` come contratto di `Zombie Survival` e mantenere i profili arena
  compatti solo come base tecnica per la nuova `Infinite Arena`.
- Modificare `game/modes/zombie/zombie_mode_controller.gd`, sostituendo il
  vecchio override implicito con `_resolve_survival_world_context()`.
- Verificare `game/procedural/world_generation/biome_map_generator.gd`.
- Aggiornare `README.md`, `ROADMAP.md`, `TODO.md`, `GAME_DESIGN.md` e
  `ARCHITECTURE.md`.
- Aggiornare o confermare `tests/zombie_biome_transition_smoke_test.gd`.

### Criteri di completamento

- Il contratto `Zombie Survival` e scritto in docs e codice.
- Il graph contiene almeno `infected_plains`,
  `toxic_wastes`, `burning_fields`, `frozen_outskirts` e `drowned_marsh`.
- `zombie_biome_transition_smoke_test.gd` passa o viene sostituito da due test
  espliciti: arena quick e survival multi-bioma.

### Test manuali

1. Avviare `Zombie Survival` dal menu.
2. Verificare dimensione/biomi della run con overlay debug o log.
3. Muoversi verso i confini regione.
4. Confermare presenza di passaggi e assenza di teleport legacy.
5. Controllare che spawn player/crate restino su celle walkable.

### Rischi

- Usare `3x3` per `Zombie Survival` puo peggiorare tempi di bootstrap e performance.
- La correzione puo rompere test che assumono arena singola.

## Milestone 3 - Separare Infinite Arena default e Zombie Survival

Stato: completata il 2026-06-20 con validazione mirata.

Evidenza:

- `GameConstants.MODE_INFINITE_ARENA`, `InfiniteArenaMode`, menu, save/continue,
  hotkey `F1`/`F7`, HUD e risultati run distinguono il default arena da
  `Zombie Survival`.
- `Infinite Arena` usa una singola cella `500x500` con
  `arena_boundary_mode = "walled"`, mura fisiche, niente fall boundary,
  niente `WorldRuntime`, region seam, exploration map o streaming multi-regione.
- `Zombie Survival` resta su megamappa `3x3` multi-bioma con graph connesso,
  passaggi fisici e biomi principali.
- Test mirati passati: `tests/infinite_arena_default_mode_smoke_test.gd`,
  `tests/zombie_survival_world_contract_smoke_test.gd`,
  `tests/milestone_9_smoke_test.gd`, `tests/milestone_17_run_results_smoke_test.gd`
  e `tests/menu_visual_qa.gd` in headless con capture screenshot saltati solo
  per display dummy.

### Obiettivo

Introdurre un contratto esplicito per due modalita distinte:

- `Infinite Arena`: modalita default/quick play, singola arena `500x500` con
  mura perimetrali, wave infinite e nessuna esplorazione multi-bioma.
- `Zombie Survival`: modalita avanzata con mappa, biomi connessi, streaming
  regioni, passaggi fisici e progressione spaziale.

### Problemi risolti

- La modalita default e ancora semanticamente confusa con la survival
  multi-bioma.
- Il profilo arena `1x1` esistente usa bordi fall-to-void, mentre la nuova
  `Infinite Arena` richiede mura intorno.
- Menu, save/continue, hotkey debug, HUD status e test non distinguono ancora in
  modo pulito quick arena e zombie survival multi-bioma.

### Interventi tecnici

- Introdurre o rendere esplicito un mode id `Infinite Arena` in `GameConstants`,
  `GameModeManager`, `MainMenu`, `SaveManager` e `RunResultsScreen`.
- Raccomandazione architetturale: usare un mode id distinto, riusando sistemi
  condivisi (`WaveManager`, `EnemySystem`, `WeaponSystem`, `DropSystem`) invece
  di duplicare la logica survival.
- Configurare `Infinite Arena` con una sola cella `500x500`, niente
  `WorldRuntime`/mappa esplorazione/region seam, e perimetro `walled` invece di
  fall boundary.
- Estendere la generazione mappa o il profilo arena con un context esplicito,
  per esempio `arena_boundary_mode = "walled"`, senza cambiare il contratto
  `Zombie Survival`.
- Mantenere `Zombie Survival` sulla megamappa multi-bioma della Milestone 2:
  graph connesso, region streaming, passaggi fisici e biomi avanzati.
- Aggiornare menu label, default/continue, eventuali hotkey debug e status HUD
  per rendere visibili entrambe le modalita.
- Aggiungere test:
  - `infinite_arena_default_mode_smoke_test.gd`;
  - aggiornamento di `zombie_survival_world_contract_smoke_test.gd`;
  - smoke menu/default/continue per assicurare che la scelta default non apra
    la mappa multi-bioma.
- Aggiornare `README.md`, `ARCHITECTURE.md`, `GAME_DESIGN.md`, `TODO.md` e
  `CHANGELOG.md` solo durante l'implementazione, non in questa revisione di
  roadmap.

### Criteri di completamento

- Dal menu/default si avvia `Infinite Arena`, non `Zombie Survival`.
- `Infinite Arena` genera una sola arena `500x500`.
- Tutti e quattro i lati dell'arena default sono mura fisiche o blocker
  equivalenti, non fall-to-void.
- `Infinite Arena` non crea regioni adiacenti, exploration map, seam transition
  o streaming multi-regione.
- `Zombie Survival` resta accessibile come modalita separata e genera il graph
  multi-bioma con almeno i cinque biomi principali.
- I test nuovi e quelli aggiornati passano nella validazione mirata; il runner
  completo `tools/run_tests.ps1` resta da lanciare prima di merge/release.

### Test manuali

1. Avviare il gioco e scegliere l'azione default/quick play.
2. Verificare che parta `Infinite Arena`, con una sola area `500x500` e mura
   intorno.
3. Provare a raggiungere tutti e quattro i bordi: il player non cade fuori e
   non cambia regione.
4. Avviare `Zombie Survival` dal menu dedicato.
5. Verificare mappa/biomi connessi, passaggi fisici e cambio regione.
6. Tornare al menu, usare continue/retry e verificare che il mode id salvato sia
   coerente.

### Rischi

- Regressioni se `SurvivalMode` viene usato per entrambe le modalita senza un
  confine di profilo chiaro.
- Naming ambiguo tra `survival`, `zombie survival` e `infinite arena`.
- La sostituzione dei fall boundary con mura puo impattare spawner, dodge, safe
  positions e hazard.
- Il menu potrebbe richiedere un pass extra su Character Select: va deciso se
  `Infinite Arena` usa la stessa selezione personaggi o un profilo quick.

## Milestone 4 - Ripulire contratto HUD gameplay

Stato: completata il 2026-06-20.

### Obiettivo

Eliminare duplicazioni tra world HUD, corner card e status panel, mantenendo
feedback leggibile per health, ammo, reload, XP, adrenaline e modalita.

### Problemi risolti

- `milestone_10_visual_smoke_test.gd` falliva nella baseline.
- `milestone_rpg_5_ammo_reload_smoke_test.gd` falliva nella baseline.
- `milestone_rpg_9_hud_smoke_test.gd` falliva nella baseline.
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

### Evidenza 2026-06-20

- `tests/milestone_10_visual_smoke_test.gd`: PASS.
- `tests/milestone_rpg_5_ammo_reload_smoke_test.gd`: PASS.
- `tests/milestone_rpg_9_hud_smoke_test.gd`: PASS.
- `PlayerHudCard` non istanzia piu `reload_bar` o `xp_bar`; il caricatore,
  reload, EXP e super restano nel `PlayerWorldHudVisual`.

### Test manuali

1. Avviare `Infinite Arena` e poi `Zombie Survival`.
2. Subire danno e verificare HP.
3. Sparare, ricaricare e cambiare arma.
4. Raccogliere XP/drop e verificare level progress.
5. Verificare HUD vicino al player e corner card.

### Rischi

- Rimuovere nodi usati da altri test o scene.
- Perdere feedback durante reload o low ammo.

## Milestone 5 - Riparare Character Select e menu navigation

Stato: completata il 2026-06-20.

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
- Nessuna regressione su avvio `Infinite Arena` e `Zombie Survival` dal menu.

### Evidenza 2026-06-20

- `MainMenu` espone di nuovo `character_detail_panel` come dossier
  `CharacterDetailPanel` aggiornato dal focus della card roster.
- La Character Select usa selezione indipendente per giocatore: tastiera,
  mouse e pad 0 pilotano il focus del Giocatore 1, mentre ogni pad aggiuntivo
  controlla il proprio slot con cursore e conferma autonomi.
- `tests/milestone_rpg_1_character_select_smoke_test.gd` ha un timeout di
  guardrail e passa senza lasciare processi appesi.
- `tests/character_select_ui_smoke_test.gd` copre dossier, layout responsive,
  D-pad, Back joypad, frecce tastiera ed Escape.
- `tests/character_select_independent_smoke_test.gd` copre il pad del
  Giocatore 2 che muove e conferma il proprio slot senza cambiare focus,
  cursore o scelta del Giocatore 1.
- Test passati: `tests/milestone_rpg_1_character_select_smoke_test.gd`,
  `tests/character_select_ui_smoke_test.gd`,
  `tests/character_select_independent_smoke_test.gd`,
  `tests/infinite_arena_default_mode_smoke_test.gd`,
  `tests/milestone_9_smoke_test.gd` e `tests/menu_visual_qa.gd` in headless
  con catture screenshot saltate solo per display dummy.

### Test manuali

1. Aprire menu principale.
2. Navigare con frecce/D-pad.
3. Cambiare personaggio/slot.
4. Entrare e uscire da settings.
5. Avviare `Infinite Arena`, poi `Zombie Survival`, e tornare al menu.

### Rischi

- Refactor troppo ampio di `MainMenu`.
- Perdita focus UI su joypad.

## Milestone 6 - Stabilizzare spawn zombie fuori camera

Stato: completata il 2026-06-20 con validazione mirata.

Evidenza:

- `ZombieSpawner` separa candidate camera-edge, motivo di scarto e fallback
  validati, con report dell'ultimo tentativo per test/debug.
- Il fallback prova prima bordi camera validi, poi celle walkable delle regioni
  streamate, e usa i punti arena solo se superano camera, player distance,
  hazard, fall zone e blocker.
- Test mirati passati: `tests/zombie_spawner_edge_smoke_test.gd`,
  `tests/zombie_revamp_foundation_smoke_test.gd`,
  `tests/biome_world_generation_smoke_test.gd`,
  `tests/milestone_10_cross_biome_chase_smoke_test.gd`,
  `tests/zombie_fall_hazard_smoke_test.gd` e
  `tests/zombie_revamp_ten_wave_smoke_test.gd`.

### Obiettivo

Garantire spawn preview e spawn effettivi fuori camera, preservando vincoli di
walkability, hazard, blocker e region streaming.

### Problemi risolti

- `zombie_spawner_edge_smoke_test.gd` fallito.
- `zombie_revamp_foundation_smoke_test.gd` fallito.
- Contratto ambiguo tra candidate edge e fallback validato.
- Le wave avanzate potevano cadere su fallback generico quando la camera era
  vicina a regioni non generate dal layout corrente.

### Interventi tecnici

- Separato in `game/modes/zombie/zombie_spawner.gd`:
  - generazione candidate edge;
  - validazione camera;
  - validazione walkable/hazard/blocker;
  - fallback.
- Aggiunti `get_spawn_rejection_reason()`,
  `get_last_spawn_rejection_reason()` e `get_last_spawn_attempt_report()` per
  capire perche un candidato viene scartato.
- Conservato rifiuto di player overlap, fall zone e blocker.
- Aggiornati gli smoke per distinguere spawn edge valido, hazard, blocker e
  regressione multi-bioma a 10 wave.

### Criteri di completamento

- `zombie_spawner_edge_smoke_test.gd` passa.
- `zombie_revamp_foundation_smoke_test.gd` passa.
- I nemici non spawnano su void o blocker.
- Le wave continuano a spawnare in regioni streamate.
- La regressione 10 wave attraversa tutti e cinque i biomi senza spawn
  `fallback` generici.

### Test manuali

1. Avviare `Infinite Arena` e `Zombie Survival` in una scena con camera standard.
2. Restare fermo durante la prima wave.
3. Verificare che i nemici arrivino da fuori camera.
4. Avvicinarsi a void/cliff e verificare che spawn non avvengano su celle
   invalide.
5. Cambiare regione e ripetere.

### Rischi

- Candidati fuori camera ma non raggiungibili.
- Spawn troppo lontani che rallentano il ritmo wave.

## Milestone 7 - Stato modalita e Tower Defense HUD

Stato: completata il 2026-06-20 con validazione mirata.

Evidenza:

- `HUDManager` mostra il pannello status persistente solo in
  `TowerDefenseMode`, con titolo modalita, core, crediti, wave e nemici.
- Il pannello e ancorato al centro alto sotto l'eventuale boss HUD e il test
  verifica che non intersechi le card player agli angoli.
- `Zombie Survival` e `Infinite Arena` continuano a nascondere il pannello
  persistente; gli annunci/wave standard restano nel canale temporaneo.
- Durante la validazione e stato corretto anche il profilo `Infinite Arena`
  murato: la pipeline void-first non genera piu fall zone interne quando
  `arena_boundary_mode = "walled"`.
- Test mirati passati: `tests/tower_defense_smoke_test.gd`,
  `tests/milestone_10_visual_smoke_test.gd`,
  `tests/survival_wave_smoke_test.gd`, `tests/dungeon_smoke_test.gd`,
  `tests/zombie_survival_world_contract_smoke_test.gd` e
  `tests/infinite_arena_default_mode_smoke_test.gd`.

### Obiettivo

Rendere coerente il feedback HUD delle modalita, partendo da Tower Defense.

### Problemi risolti

- `tower_defense_smoke_test.gd` fallito sullo stato HUD.
- `HUDManager._refresh()` nascondeva sempre il panel status.
- Contratto modalita/HUD poco esplicito.
- Il profilo `Infinite Arena` murato poteva ancora ereditare chasm/fall zone
  interne dal void-first starter.

### Interventi tecnici

- Deciso che lo stato Tower Defense appare nel `StatusPanel` persistente,
  mentre Survival/Infinite Arena mantengono il pannello nascosto.
- Aggiornati `game/ui/hud_manager.gd` e `tests/tower_defense_smoke_test.gd`.
- Aggiornata la pipeline world generation per passare il context anche a
  `populate_layout_voidfirst()` e disattivare la void lottery nel profilo
  arena murata.
- Verificata integrazione con survival, dungeon e Infinite Arena.
- Documentato il contratto in `ARCHITECTURE.md`, `GAME_DESIGN.md`, `README.md`,
  `TODO.md`, `ROADMAP.md` e `CHANGELOG.md`.

### Criteri di completamento

- `tower_defense_smoke_test.gd` passa.
- `Infinite Arena` e `Zombie Survival` non mostrano stato Tower Defense.
- Il panel non copre HUD critico.
- Modalita future hanno un punto unico per aggiornare lo stato.
- `Infinite Arena` resta una cella `500x500` murata e senza fall zone interne.

### Test manuali

1. Avviare Tower Defense.
2. Verificare nome modalita e wave/status.
3. Piazzare torre, attendere wave, verificare credits/core.
4. Tornare al menu o cambiare modalita.
5. Avviare `Infinite Arena` e `Zombie Survival` e verificare assenza di stato errato.

### Rischi

- Riattivare un panel nascosto puo creare overlap.
- Test e design potrebbero aspettarsi UI diverse.

## Milestone 8 - Refactor architetturale mirato

Stato: completata il 2026-06-21.

Evidenza:

- Primo hotspot trattato: `game/weapons/weapon_visual_renderer.gd`.
- `WeaponVisualRenderer` e stato ridotto da 1235 a 460 LOC mantenendo le API
  statiche pubbliche usate dai consumer visuali.
- Le geometrie procedurali statiche sono state estratte in
  `game/weapons/weapon_visual_shape_library.gd` (`WeaponVisualShapeLibrary`,
  808 LOC), senza introdurre logica combat o nuovi consumer diretti.
- Test smoke passati prima e dopo la refactor:
  `weapon_visual_catalog_smoke_test.gd`,
  `weapon_pickup_visual_identity_smoke_test.gd`,
  `weapon_held_hud_visual_identity_smoke_test.gd`,
  `weapon_projectile_vfx_identity_smoke_test.gd` e
  `weapon_melee_visual_identity_smoke_test.gd`.

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

## Milestone 9 - Ridurre lookup globali e dipendenze implicite

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

## Milestone 10 - Asset, isometria e fallback policy

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

1. Avviare `Infinite Arena`, poi `Zombie Survival` in almeno due biomi.
2. Verificare leggibilita terreno/ostacoli.
3. Camminare vicino a cliff e void.
4. Raccogliere armi e osservare pickup/projectile.
5. Salvare screenshot QA.

### Rischi

- Test logici passano ma resa visiva resta scarsa.
- Rimozione fallback puo causare asset mancanti.

## Milestone 11 - Armi, drop, progressione e feedback

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

1. Avviare `Infinite Arena`.
2. Raccogliere almeno 3 armi.
3. Consumare ammo e ricaricare.
4. Uccidere nemici e raccogliere XP/drop.
5. Sbloccare un level up/passive.
6. Verificare che HUD e audio/feedback siano chiari.

### Rischi

- Bilanciamento troppo facile/difficile maschera bug di progressione.
- Modifiche HUD possono rompere test ammo/reload.

## Milestone 12 - Zombie, nemici e bilanciamento modalita

### Obiettivo

Validare ritmo, spawn, boss, varianti e cross-bioma nelle due modalita zombie:
`Infinite Arena` come loop infinito compatto e `Zombie Survival` come run
multi-bioma.

### Problemi risolti

- Spawn e biomi non coerenti.
- Bilanciamento `Infinite Arena` non verificato come default.
- Bilanciamento `Zombie Survival` non verificato in run multi-bioma.
- Rischio che test soak passino ma gameplay sia poco leggibile.

### Interventi tecnici

- Rieseguire ten-wave, soak, boss e cross-biome test.
- Aggiungere metriche leggere per wave duration, nemici vivi, drop e danni.
- Verificare boss registry, loop infinito arena e varianti enemy nei biomi
  avanzati.
- Aggiornare `GAME_DESIGN.md` con pacing e criteri bilanciamento.

### Criteri di completamento

- Test zombie principali passano.
- Run manuale 20 minuti in `Infinite Arena` senza softlock.
- Run manuale multi-bioma in `Zombie Survival` senza softlock.
- Spawn restano fuori camera e raggiungibili.
- Il player incontra varieta nemici/biomi prevista.

### Test manuali

1. Avviare `Infinite Arena`.
2. Sopravvivere 10 wave senza lasciare il blocco `500x500`.
3. Avviare `Zombie Survival` e attraversare regioni/biomi.
4. Affrontare boss o evento equivalente.
5. Annotare tempi wave, drop, difficolta e morti.

### Rischi

- Performance peggiora con multi-bioma.
- Spawn troppo lontani o troppo vicini alterano il pacing.

## Milestone 13 - Documentazione, release e continuita Codex

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
