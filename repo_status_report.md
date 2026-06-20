# Repo Status Report

Data analisi: 2026-06-20

Repository locale: `C:\Git\GameProject`

## 1. Executive summary

Il progetto e molto piu avanzato di un prototipo iniziale: la scena principale
esiste, l'import Godot funziona, la modalita survival/zombie ha generazione
isometrica, streaming regioni, weapon catalog, inventario, drop, progressione,
boss, HUD, menu, test smoke e asset procedurali. La pipeline asset isometrica
controlla 124 asset e passa.

La fragilita principale non e l'assenza di sistemi, ma la divergenza tra
contratti. Nell'audit iniziale alcuni documenti e test descrivevano una
survival standard multi-bioma `3x3`, mentre il runtime avviava una singola arena
`1x1` con `infected_plains`; la Milestone 2 ha riallineato questo contratto.
Alcuni test HUD e Character Select sono ancora legati a contratti precedenti.
Il runner PowerShell locale classificava come fallito anche un test che passa;
la Milestone 1 ha corretto quel workflow.

La base e lavorabile, ma prima di aggiungere feature conviene completare la
stabilizzazione di HUD, Character Select, spawner fuori camera e stato HUD della
modalita Tower Defense. Dopo questi punti il debito principale diventa
architetturale: file molto grandi, accessi globali tramite gruppi e
fallback/legacy ancora diffusi.

## 2. Architettura attuale

### Game loop

Entrypoint configurato in `project.godot`: `res://game/main/main.tscn`.
La scena principale coordina bootstrap, menu, modalita e sistemi globali. I
test confermano che molte modalita partono in headless, incluso survival,
tower defense e diversi smoke milestone.

### Rendering/isometria

La parte isometrica vive soprattutto sotto `game/procedural/`,
`game/modes/zombie/` e sistemi collegati a tile, texture SVG, layer, ostacoli,
void, cliff e streaming. I test milestone 10 su streaming, tile layer,
performance, transizioni e cleanup legacy passano, ma sono lenti.

Hotspot principali:

- `game/modes/zombie/isometric_tile_resolver.gd`
- `game/modes/zombie/isometric_svg_texture_loader.gd`
- `game/procedural/world_generation/obstacle_layout_generator.gd`
- `game/modes/zombie/biome_obstacle.gd`

### Generazione biomi/mappa

Esistono generatore mappa biomi, regioni, connessioni, streaming e test per
multi-regione. Dopo la Milestone 2, la survival standard usa il default `3x3` di
`BiomeMapGenerator`; l'arena compatta `1x1` resta solo un profilo esplicito con
context `single_biome_arena = true`.

### Player e controlli

Il player controller e integrato con movimento, dodge, danni, down/revive,
void fall e query centralizzate tramite `PlayerQuery`. La presenza di
`PlayerQuery` e delle costanti layer in `GameConstants` rende superate alcune
critiche dei report precedenti. Restano molti accessi tramite gruppi nel codice
di gioco, quindi il lookup dei sistemi non e ancora pienamente tipizzato.

### Armi e combattimento

Il sistema armi e piuttosto ricco: catalogo, istanze arma, inventory player,
munizioni, reload, cooldown, melee, projectile, effetti visuali, pickup e drop.
I test del catalogo weapon e dei profili visuali passano. Il rischio residuo e
piu di integrazione UI/feedback che di assenza del sistema.

### Zombie/nemici

Sono presenti spawner, wave director, boss, varianti nemici, chasing
cross-bioma, soak test e test ten-wave. La logica base funziona, ma lo spawner
ha un contratto fragile per le preview ai bordi camera: le posizioni candidate
vengono validate contro walkability/regioni e possono rientrare tramite
fallback, facendo fallire i test che si aspettano spawn preview fuori camera.

### HUD/GUI

HUD gameplay, world HUD, player corner card, menu principale, character select,
settings e pause panel sono presenti. La responsabilita e sparsa: `MainMenu` e
molto grande e gestisce troppi sottosistemi, mentre `PlayerHudCard`,
`PlayerWorldHudVisual` e `HUDManager` non sono allineati su chi debba mostrare
health, reload, ammo, XP e stato modalita.

### Asset grafici

Gli asset sono in gran parte procedurali/SVG con manifest e check dedicati.
`tools/generate_isometric_environment_assets.gd -- --check` passa con 124 asset
controllati. La qualita asset e migliore di una fase placeholder pura, ma
serve ancora validazione visuale con screenshot e build grafica reale per
coerenza isometrica, occupazione griglia e leggibilita.

### Drop/progressione

XP, level, passives, drop, inventory e run results sono coperti da smoke test.
I problemi emersi sono soprattutto di rappresentazione HUD: XP e reload sono
ancora visibili/duplicati nella corner card, mentre i test recenti li vogliono
nel world HUD.

### Modalita di gioco

Sono presenti almeno survival/zombie, tower defense, dungeon/exploration e
menu/character select. Le modalita partono in test, ma non tutte espongono lo
stesso contratto HUD. Tower Defense fallisce sulla stringa/stato HUD, pur
proseguendo con arena, wave, enemy, tower, boss, credits, core e cleanup.

## 3. Problemi principali

### 1. Runner test PowerShell non affidabile

File coinvolti:

- `tools/run_tests.ps1`
- `tools/run_tests.sh`
- `.github/workflows/ci.yml`
- `CONTRIBUTING.md`

Descrizione: con Godot 4.6.3 su Windows, `tools/run_tests.ps1` marca come
fallito un test che nel log stampa `PASS`. Il valore `$proc.ExitCode` risulta
vuoto dopo `Start-Process`, quindi la summary riporta `0 passati, 1 falliti`.

Impatto sul gioco: impedisce una validazione locale affidabile prima dei
commit. Le regressioni reali si confondono con falsi negativi del runner.

Rischio tecnico: alto. Senza runner affidabile ogni fix successivo costa piu
tempo e puo introdurre regressioni.

Proposta: sostituire il lancio `Start-Process` con una chiamata che catturi in
modo deterministico exit code, stdout/stderr, timeout e process tree. Separare
suite fast/slow/visual e documentare filtri supportati.

Nota post-fix 2026-06-20: Milestone 1 completata. `tools/run_tests.ps1` usa ora
un lancio `System.Diagnostics.Process` con log persistenti, timeout e categorie
test; il falso fallimento su `milestone_rpg_10_balance` non si riproduce piu.

### 2. Contratto survival/biomi divergente

File coinvolti:

- `game/modes/zombie/zombie_mode_controller.gd`
- `game/procedural/world_generation/biome_map_generator.gd`
- `tests/zombie_biome_transition_smoke_test.gd`
- `README.md`
- `ROADMAP.md`
- `TODO.md`

Descrizione: il codice forza una singola arena self-contained se il contesto
non passa dimensioni esplicite. I documenti e alcuni test invece si aspettano
una mappa standard multi-bioma `3x3` con biomi avanzati.

Impatto sul gioco: la modalita zombie standard non espone la varieta biomi
documentata. La progressione spaziale e il valore dei sistemi cross-bioma sono
ridotti.

Rischio tecnico: alto. Il progetto puo evolvere in due direzioni incompatibili:
arena compatta o megamappa multi-bioma.

Proposta: decidere il contratto ufficiale. Raccomandazione: ripristinare o
esplicitare la run survival standard `3x3` e tenere l'arena `1x1` solo come
profilo test/quickstart.

Nota post-fix 2026-06-20: Milestone 2 completata. La survival standard usa ora
il default `3x3` di `BiomeMapGenerator`; l'arena `1x1` richiede il context
esplicito `single_biome_arena = true`.

### 3. HUD con responsabilita duplicate

File coinvolti:

- `game/ui/player_hud_card.gd`
- `game/ui/player_world_hud_visual.gd`
- `game/ui/hud_manager.gd`
- `tests/milestone_10_visual_smoke_test.gd`
- `tests/milestone_rpg_5_ammo_reload_smoke_test.gd`
- `tests/milestone_rpg_9_hud_smoke_test.gd`

Descrizione: la corner card mantiene ancora righe/barre per health, reload,
ammo, XP/adrenaline. I test recenti richiedono che questi dati non siano
duplicati nella corner card perche appartengono al world HUD o ad altri elementi
dedicati.

Impatto sul gioco: HUD piu rumoroso, leggibilita ridotta, regressioni test.

Rischio tecnico: medio-alto. Cambiare HUD senza contratto chiaro puo rompere
feedback critici come ammo/reload, down/revive e progressione.

Proposta: definire una matrice ownership HUD: cosa appare sopra il player, cosa
nel corner card, cosa nel panel modalita. Poi rimuovere o nascondere i duplicati
e aggiornare i test se il design scelto e diverso.

### 4. Character Select smoke non allineato al menu attuale

File coinvolti:

- `game/ui/main_menu.gd`
- `game/ui/character_detail_panel.gd`
- `tests/milestone_rpg_1_character_select_smoke_test.gd`

Descrizione: il test accede a `main_menu.character_detail_panel`, proprieta non
presente in `MainMenu`. Il test genera errore script e in alcuni casi non esce
pulitamente.

Impatto sul gioco: impedisce di validare una parte centrale del flusso menu e
blocca suite piu larghe.

Rischio tecnico: medio. Potrebbe essere un test obsoleto o una feature rimossa
senza aggiornare il contratto.

Proposta: scegliere se reintrodurre un `CharacterDetailPanel` dedicato o
aggiornare il test al contratto UI corrente. Separare gradualmente `MainMenu`,
che oggi concentra menu, settings bridge, navigazione, slot e contesto
survival.

### 5. ZombieSpawner non garantisce preview ai bordi camera

File coinvolti:

- `game/modes/zombie/zombie_spawner.gd`
- `tests/zombie_spawner_edge_smoke_test.gd`
- `tests/zombie_revamp_foundation_smoke_test.gd`

Descrizione: `get_spawn_position()` sceglie un candidato edge ma lo valida
contro walkability, hazard e regioni. In main scene alcuni candidati vengono
scartati e il fallback non preserva il requisito "fuori camera" atteso dai
test.

Impatto sul gioco: gli spawn possono risultare meno prevedibili e piu vicini
alla vista del giocatore durante il preview/early wave.

Rischio tecnico: medio. Una correzione superficiale potrebbe far spawnare nemici
su void, blocker o regioni non streammate.

Proposta: separare generazione candidato edge, validazione gameplay e fallback.
I test devono distinguere preview deterministic fuori camera da spawn finale
walkable.

### 6. Stato HUD Tower Defense non aggiornato come atteso

File coinvolti:

- `game/ui/hud_manager.gd`
- `tests/tower_defense_smoke_test.gd`
- `game/modes/tower_defense/`

Descrizione: il test si aspetta che `status_label.text` includa `Tower Defense`
dopo lo start. In `HUDManager._refresh()` lo `status_panel` viene nascosto e il
contratto visibile dello stato modalita non e chiaro.

Impatto sul gioco: feedback modalita poco affidabile e regressione smoke.

Rischio tecnico: medio-basso. La logica Tower Defense passa diversi controlli,
quindi il problema sembra concentrato su UI/status.

Proposta: aggiornare `HUDManager` per esporre in modo stabile lo stato modalita
oppure aggiornare il test al nuovo elemento UI ufficiale.

### 7. File troppo grandi e responsabilita concentrate

File coinvolti principali:

- `game/procedural/world_generation/obstacle_layout_generator.gd` circa 1540 LOC
- `game/ui/main_menu.gd` circa 1277 LOC
- `game/weapons/weapon_visual_renderer.gd` circa 1235 LOC
- `game/modes/zombie/biome_obstacle.gd` circa 1149 LOC
- `game/modes/zombie/isometric_tile_resolver.gd` circa 1089 LOC
- `game/modes/zombie/isometric_svg_texture_loader.gd` circa 1022 LOC

Descrizione: diversi sistemi hanno superato la dimensione in cui modifiche
mirate restano semplici da validare.

Impatto sul gioco: aumentano regressioni e tempi di onboarding per nuove
feature.

Rischio tecnico: medio. Refactor grandi possono essere pericolosi, ma ignorare
questi hotspot rendera piu fragile ogni milestone futura.

Proposta: estrarre solo responsabilita evidenti e coperte da test, una alla
volta. Evitare riscritture generali.

### 8. Accesso a sistemi tramite gruppi ancora diffuso

File coinvolti:

- codice sotto `game/`
- `game/core/player_query.gd`
- sistemi manager/modalita

Descrizione: nel codice di gioco sono presenti circa 204 occorrenze di
`get_first_node_in_group`. Alcuni casi sono accettabili, ma molti indicano
dipendenze runtime implicite.

Impatto sul gioco: bug da scena incompleta o ordine di bootstrap piu difficili
da diagnosticare.

Rischio tecnico: medio. Una pulizia indiscriminata puo rompere scene e test.

Proposta: ridurre prima gli accessi in sistemi critici usando registry tipizzati
o injection coerenti con `PlayerQuery`.

### 9. Fallback/legacy ancora presenti

File coinvolti:

- codice sotto `game/`
- test milestone 10 legacy cleanup
- asset loader/rendering

Descrizione: sono presenti circa 220 occorrenze di `fallback` o `legacy` nel
codice di gioco. Non sono tutte bug: alcune sono guardrail intenzionali e i test
legacy cleanup passano. Il numero pero indica una fase di transizione ancora
aperta.

Impatto sul gioco: rischio di visual generici, codice morto e comportamenti
diversi tra test e run reale.

Rischio tecnico: medio.

Proposta: classificare fallback necessari, temporanei e rimovibili. Bloccare il
ritorno dei fallback generici nei percorsi standard con test mirati.

### 10. Validazione visuale/manuale non ancora sufficiente

File coinvolti:

- `tests/*_visual_qa.gd`
- `docs/`
- pipeline asset
- export preset

Descrizione: i visual QA non sono stati eseguiti in questa analisi headless.
L'import Godot e l'asset check passano, ma non e stata verificata una build
grafica giocata con mouse/tastiera e joypad.

Impatto sul gioco: possibili problemi di leggibilita, scaling HUD, asset non
coerenti o navigazione menu non rilevati dagli smoke headless.

Rischio tecnico: medio.

Proposta: rendere obbligatoria una checklist manuale breve dopo ogni milestone
e una visual QA completa prima di release.

## 4. Debito tecnico

- `MainMenu` dovrebbe essere diviso in controller menu, character select,
  settings bridge, slot navigation e survival launch context.
- `ObstacleLayoutGenerator` va spezzato per shape/layout/validation/debug output.
- `WeaponVisualRenderer` puo essere separato in rendering pickup, held/HUD,
  projectile, melee slash e fallback policy.
- `BiomeObstacle`, `IsometricTileResolver` e `IsometricSvgTextureLoader`
  meritano moduli dedicati per data, risoluzione terrain, collision/occupancy e
  cache asset.
- `HUDManager`, `PlayerHudCard` e `PlayerWorldHudVisual` necessitano un
  contratto scritto di ownership dati.
- Le dipendenze via gruppi vanno ridotte nei percorsi player, HUD, mode
  bootstrap e spawner.
- I fallback legacy vanno censiti e collegati a task di rimozione o motivazione
  esplicita.
- La suite test va divisa in fast, slow, soak, visual e manuale; oggi alcuni
  smoke durano oltre 100-200 secondi.

## 5. Stato gameplay

Il gioco sembra giocabile in molte parti: survival parte, wave e boss sono
coperti, armi/drop/progressione sono funzionanti nei test, asset isometrici e
streaming regioni superano smoke importanti. La modalita zombie ha gia una base
tecnica solida.

Punti forti:

- weapon catalog esteso con 30 armi e identita visuali;
- sistemi XP, passives, ammo/reload e drop coperti da test;
- region streaming, tile layer e no-portal transition passano;
- fall hazard e void fall component coperti;
- soak e ten-wave test zombie presenti.

Punti deboli:

- survival multi-bioma riallineata in Milestone 2, da monitorare su performance
  e playtest;
- HUD duplica dati e riduce chiarezza;
- Character Select non ha test affidabile;
- Tower Defense non segnala correttamente lo stato HUD;
- spawn preview fuori camera non e garantita;
- feedback visuale reale non e stato validato con sessione grafica.

## 6. Stato asset grafici

Asset verificati:

- `tools/generate_isometric_environment_assets.gd -- --check` passa con 124
  asset controllati.
- I test weapon visual identity e catalog smoke passano.
- La pipeline SVG/isometrica e presente e collegata ai test milestone.

Rischi residui:

- molti asset sono procedurali/SVG e richiedono QA visiva, non solo test logici;
- occorre controllare occupazione reale su griglia per ostacoli, cliff, void e
  wall;
- le varianti fuori `infected_plains` sono ora presenti nel graph standard, ma
  richiedono ancora QA visuale/playtest in run reale;
- non e stata eseguita visual QA con screenshot durante questa analisi.

## 7. Test e validazione

### Comandi eseguiti

| Comando | Esito | Note |
| --- | --- | --- |
| `git status --short --branch` | OK | Branch `master...origin/master`, modifica preesistente su `prompt.md`. |
| `godot --headless --path . --import --quit` | PASS | Import Godot completato. |
| `godot --headless --path . --script res://tools/generate_isometric_environment_assets.gd -- --check` | PASS | 124 asset isometrici controllati. |
| Runner custom PowerShell su test smoke/stress/soak/lifecycle/player_query/wave_cycle | PARZIALE | Molti test passano; suite interrotta da test Character Select con errore script/hang. |
| `tools/run_tests.ps1 -Filter milestone_rpg_10_balance -SkipImport` | FAIL falso | Il log Godot stampa PASS, ma il runner riporta fallimento per exit code non catturato. |
| Test diretti mirati su fallimenti | FAIL reali | Confermati HUD, biomi, spawner edge, Tower Defense HUD, Character Select. |

### Test passati osservati

Esempi significativi:

- asset manifest e generazione isometrica;
- milestone 10 cross-biome chase, full-region streaming, performance, tile
  layer, no-portal transition e legacy cleanup;
- milestone 11-21 principali;
- RPG stats, weapons, hitbox, XP, passives, adrenaline, balance e data-driven;
- weapon inventory/catalog e visual identity smoke;
- zombie wave director, boss, soak, ten-wave, fall hazard;
- player query, pause settings, exploration/dungeon, combat, survival wave.

### Fallimenti confermati

| Test | Esito | Problema |
| --- | --- | --- |
| `tests/milestone_10_visual_smoke_test.gd` | FAIL | Corner card duplica HP/reload/magazine ammo. |
| `tests/milestone_rpg_5_ammo_reload_smoke_test.gd` | FAIL | Corner card duplica reload bar. |
| `tests/milestone_rpg_9_hud_smoke_test.gd` | FAIL | Corner card duplica XP. |
| `tests/milestone_rpg_1_character_select_smoke_test.gd` | ERRORE/HANG | Accesso a `main_menu.character_detail_panel` inesistente. |
| `tests/tower_defense_smoke_test.gd` | FAIL | HUD non passa allo stato Tower Defense atteso. |
| `tests/zombie_biome_transition_smoke_test.gd` | FAIL | Graph solo `infected_plains`, biomi avanzati assenti nel contesto default. |
| `tests/zombie_revamp_foundation_smoke_test.gd` | FAIL | Spawner preview non garantisce posizioni fuori camera. |
| `tests/zombie_spawner_edge_smoke_test.gd` | FAIL | Edge north/south/east/west non risultano fuori camera. |
| `tests/test_scene_lifecycle.gd` eseguito direttamente | NON RUNNER | Helper non estende `SceneTree`; va escluso dai runner diretti. |

### Test mancanti o da rafforzare

- Smoke fast ufficiale che completi in pochi minuti e fallisca solo su regressioni
  reali.
- Test specifico per contratto survival standard: arena `1x1` vs megamappa `3x3`.
- Test HUD ownership con matrice esplicita dei dati mostrati.
- Test Character Select aggiornato al contratto UI corrente.
- Test input joypad/menu con focus navigation e conferma/back.
- Visual QA automatizzata con screenshot per survival multi-bioma, HUD, menu,
  weapon pickup e ostacoli.
- Checklist build Windows esportata e sessione manuale 10-20 minuti.

### Checklist manuale consigliata dopo ogni milestone

1. Avviare `game/main/main.tscn` in editor o build locale.
2. Navigare menu principale con tastiera/mouse e joypad.
3. Aprire Character Select, cambiare slot/personaggio e avviare survival.
4. Verificare movimento, dodge, camera, collisioni e caduta nel void.
5. Verificare pickup arma, cambio slot, ammo, reload e cooldown.
6. Verificare XP, level up, passives, drop e feedback visivo.
7. Sopravvivere almeno 3 wave zombie, includendo spawn fuori camera e boss se
   disponibile.
8. Attraversare almeno due regioni/biomi nella survival standard.
9. Controllare HUD: nessuna duplicazione critica, testi leggibili, niente
   overlap.
10. Salvare screenshot o log QA in `build/qa/` o `build/test_logs/`.

## 8. Raccomandazioni prioritarie

1. Completato in Milestone 1: correggere `tools/run_tests.ps1` e dividere
   suite fast/slow/visual.
2. Completato in Milestone 2: survival standard `3x3` multi-bioma, arena `1x1`
   solo esplicita.
3. Risolvere i duplicati HUD tra corner card e world HUD.
4. Riparare o aggiornare il test Character Select e rendere il menu validabile.
5. Correggere `ZombieSpawner` per garantire candidate edge fuori camera senza
   sacrificare walkability.
6. Sistemare lo stato HUD Tower Defense.
7. Documentare la matrice ownership UI/HUD in `ARCHITECTURE.md`.
8. Avviare refactor piccoli dei file oltre 1000 LOC, partendo da `MainMenu` e
   generatori/renderer con test gia presenti.
9. Ridurre progressivamente lookup globali tramite gruppi nei sistemi critici.
10. Rendere obbligatoria una checklist manuale e visual QA prima di ogni
    milestone di gameplay o asset.
