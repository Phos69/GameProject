# ARCHITECTURE

## Visione tecnica

Il progetto e un sandbox Godot 4.x 2D con resa pseudo-isometrica. La scena principale avvia un playground minimo e registra i sistemi base. Le modalita future devono usare sistemi comuni invece di duplicare gameplay.

## Flusso runtime attuale

1. `main.tscn` carica manager, world e `MainMenu`.
2. `GameModeManager` entra nello stato `menu` senza avviare gameplay.
3. `SaveManager` carica progressione party, unlock e ultima modalita da JSON.
4. `MainMenu` seleziona una modalita registrata e nasconde la propria UI.
5. `InputManager` registra azioni tastiera/joypad.
6. `LocalMultiplayerManager` mantiene gli slot locali attivi.
7. `PlayerManager` ascolta gli slot attivi e spawna/despawna i player.
8. `PlayerController` legge input solo quando una modalita gameplay e attiva.
9. `WeaponSystem` gestisce fallback permanente, speciale, cooldown, caricatori, riserve e ricarica per il singolo player.
10. `WeaponData` inoltra l'eventuale `WeaponVisualData` a player, HUD e proiettile.
11. `ProjectileSystem` spawna proiettili che applicano danno tramite `HealthSystem`.
12. `EnemySystem` spawna scene basic, runner e tank; tutte usano `BasicEnemy` per selezionare il player vivo piu vicino.
13. Alla morte, il nemico chiede a `DropSystem` di generare pickup dalla propria `LootTable`.
14. `DropPickup` delega l'applicazione della ricompensa a `DropSystem`.
15. `GameModeManager` avvia `SurvivalMode`, che delega il ciclo delle ondate a `WaveManager`.
16. `WaveManager` spawna zombie tramite `EnemySystem` e richiede il boss a `SurvivalMode`.
17. `SurvivalMode` usa `GameModeManager` e `BossSystem` per creare il boss della quinta ondata.
18. `WaveManager` conta scorte e boss prima di assegnare la ricompensa.
19. `DungeonMode` genera un layout da seed, istanzia una `DungeonRoom` alla volta e usa nemici, drop e boss condivisi.
20. `DungeonRoom` controlla pareti, portale e stato locked/unlocked della stanza corrente.
21. `TowerDefenseMode` gestisce lifecycle, arena, player e richieste costruzione.
22. `TowerDefenseWaveController` governa ondate e usa `EnemySystem` per i nemici da percorso.
23. `TowerDefenseManager` mantiene vita core e crediti, mentre gli slot delegano lo spawn delle torri.
24. `DefenseTower` seleziona target e inoltra direzione e fuoco a `DefenseTowerVisual`.
25. `ProgressionManager` prepara i player a ogni nuova run applicando gli unlock persistenti.
26. `SurvivalAmmoDirector` osserva l'ammo speciale dei player vivi e genera supply crate configurabili.
27. `AudioManager` ascolta projectile, drop e segnali arma per generare feedback gameplay condiviso.
28. `IsometricCameraController` segue il gruppo `players`.
29. `HUDManager` mostra slot, progressione, vita, munizioni, feedback ammo, stato modalita e barra boss.
30. I componenti visuali di player, zombie, pickup e crate ricevono stato dai rispettivi controller senza possedere logica gameplay.
31. `BossTelegraphVisual` riceve pattern, direzione e durata da `BasicBoss` senza possedere danno o collisioni.
32. `WaveWardenVisual` riceve fase, mira, hit e carica senza possedere autorita gameplay.
33. `CombatAnnouncement` presenta segnali wave e boss tradotti da `HUDManager`.
34. `GameplayEffects` ascolta i segnali di proiettili, nemici e drop e genera effetti temporanei nel mondo.

## Sistemi principali

- `InputManager`: crea e legge azioni per slot player. Ogni slot usa azioni `p{slot}_{azione}`.
- `LocalMultiplayerManager`: mantiene gli slot locali attivi, gestisce join/leave e usa mapping deterministico `device joypad + 1 = player_slot`.
- `PlayerManager`: spawna/despawna player in base agli slot attivi e tiene il registro degli slot.
- `PlayerController`: movimento, mira, fire action e colore visuale per slot.
- `GameModeManager`: registra, arresta e avvia le modalita.
- `MainMenu`: UI iniziale, selezione modalita, continue e ritorno con `Esc`.
- `SaveManager`: persistenza JSON versionata e autosave della progressione.
- `AudioManager`: feedback audio procedurale per UI, sparo, impatto, pickup e stato ammo.
- `WeaponData`: risorsa immutabile con statistiche gameplay e riferimento visuale opzionale.
- `WeaponVisualData`: palette, dimensioni e profilo condivisi da arma, HUD, proiettile e flash.
- `WeaponSystem`: stato runtime per-player di fallback, speciale, cooldown, munizioni e ricarica.
- `ProjectileSystem` e `Projectile`: spawn, movimento, collisione e consegna del danno.
- `HealthSystem` e `HealthComponent`: richieste globali di danno/cura e stato vita locale.
- `EnemySystem`: registro di scene nemico per ID, spawn, contenitore, registro runtime e notifica morte.
- `BasicEnemy`: AI melee condivisa con stati idle, chase, attack e dead.
- `ZombieVisual`: profili procedurali basic, runner e tank senza autorita gameplay.
- `BossSystem`: spawn centralizzato, registro del boss attivo e notifica sconfitta.
- `BasicBoss`: boss modulare con targeting, movimento, fasi e pattern proiettile.
- `SurvivalMode`: ciclo survival, condizione di sconfitta e inoltro richieste boss.
- `WaveManager`: macchina a stati per intermissione, spawn, combat, reward e boss wave.
- `SurvivalAmmoDirector`: supporto anti-frustrazione esclusivo della survival.
- `DungeonGenerator`: generazione deterministica dei dati layout dungeon.
- `DungeonMode`: avanzamento stanza, encounter, loot, boss e completamento run.
- `DungeonRoom`: rappresentazione riusabile della stanza attiva e portale di transizione.
- `TowerDefenseMode`: lifecycle della modalita, arena, player, costruzione e pulizia runtime.
- `TowerDefenseWaveController`: macchina a stati per intermissione, spawn, combat, boss e reward.
- `TowerDefenseManager`: vita core, crediti di run e acquisto centralizzato delle torri.
- `TowerDefenseArena`: percorso, rappresentazione core, spawn party e slot costruzione.
- `TowerDefenseEnemy`: movimento a waypoint, danno al core e contratto health/drop condiviso.
- `TowerBuildSlot`: rileva il player e inoltra la richiesta di costruzione.
- `DefenseTower`: targeting automatico e sparo tramite `ProjectileSystem`.
- `DefenseTowerVisual`: base, canne, tracking, idle scan e feedback di fuoco senza logica gameplay.
- `DropEntry` e `LootTable`: dati tipizzati per chance, quantita e arma associata.
- `DropSystem`: roll, spawn pickup e applicazione centralizzata delle ricompense.
- `DropPickup`: rappresentazione fisica e raccolta da parte dei player.
- `SupplyCrate`: contenitore fisico configurato da `LootTable` per ammo e cura.
- `ProgressionManager`: XP, livello, denaro, unlock party e bonus di inizio run.
- `HUDManager`: UI prototipo.
- `PlayerVisual` e `ZombieVisual`: presentazione animata procedurale degli attori.
- `DropPickupVisual` e `SupplyCrateVisual`: icone world-space sostituibili.
- `BossTelegraphVisual`: warning world-space per pattern aimed, radial e cambio fase.
- `WaveWardenVisual`: silhouette, animazione e stato visuale delle due fasi del boss.
- `PlayerHudCard`: scheda HUD riusabile per ogni slot locale.
- `WeaponIcon`: icona HUD generata dal profilo dell'arma attiva.
- `CombatAnnouncement`: banner temporaneo e riusabile per transizioni gameplay.
- `GameplayEffects`: feedback visuale event-driven senza dipendenze dai controller.

## Contratto presentazione visuale

- Controller, collisioni, health, armi, wave e drop restano autoritativi.
- I nodi visuali ricevono solo stato, direzione, velocita e richieste di feedback.
- Sostituire un placeholder con sprite o animazioni non deve cambiare scene manager o sistemi gameplay.
- Lo sfondo survival usa colori meno saturi e meno luminosi degli attori.
- Il colore slot resta il primo identificatore del player nel multiplayer locale.
- Pickup e supply crate devono essere riconoscibili dalla forma e dal colore senza dipendere da label world-space.
- I telegraph boss mostrano direzione, area e durata prima del danno e non possiedono collisioni.
- `WaveWardenVisual` riceve solo stato presentazionale da `BasicBoss`.
- Gli annunci HUD reagiscono ai segnali pubblici e non pilotano wave o boss.
- Arma world-space, icona HUD, proiettile e muzzle flash leggono lo stesso `WeaponVisualData`.
- `DefenseTowerVisual` riceve mira e feedback ma non sceglie target, range, danno o fire rate.
- `GameplayEffects` reagisce a segnali pubblici e non applica danno, cura o ricompense.
- I bersagli combat debug restano istanziati ma invisibili e senza collisione nel gameplay normale; lo smoke test combat abilita la fixture usata.

## Contratto combat

- Ogni istanza player possiede il proprio `WeaponSystem`; caricatore, riserva e cooldown non sono condivisi.
- Ogni `WeaponSystem` conserva sempre una fallback infinita e al massimo una speciale finita.
- Esaurire caricatore e riserva della speciale attiva la fallback e tenta lo sparo nello stesso input.
- La fallback infinita conserva caricatore e reload; solo la riserva e virtualmente infinita.
- Un nuovo rifornimento della speciale la riattiva e avvia il reload.
- Le statistiche di bilanciamento vivono in risorse `WeaponData`, non nel controller player.
- Palette, silhouette e trail vivono in `WeaponVisualData` e non modificano il bilanciamento.
- `ProjectileSystem` riceve i dati dello sparo e configura il proiettile prima di aggiungerlo alla scena.
- Il parametro visuale di `ProjectileSystem` e opzionale per mantenere compatibili boss e chiamanti esistenti.
- Il proiettile non conosce classi nemico specifiche: colpisce un body damageable e inoltra il danno a `HealthSystem`.
- `Projectile` emette l'impatto risolto e `ProjectileSystem` lo espone ai sistemi di feedback.
- `HealthSystem` cerca un figlio `HealthComponent` sul target; player, nemici, boss e bersagli debug possono condividere lo stesso contratto.
- Collision layer `1`: player e corpi generici.
- Collision layer `2`: bersagli damageable.
- Collision layer `4`: proiettili; la mask attuale colpisce il layer `2`.
- Collision layer `8`: pickup; la mask attuale rileva i player sul layer `1`.
- Collision layer `16`: proiettili ostili; la mask colpisce i player sul layer `1`.
- `CombatTarget` e una fixture statica della scena principale per verificare il combat e non sostituisce l'AI nemica della Milestone 4.

## Contratto nemici

- `EnemySystem.spawn_enemy()` e il punto di ingresso per modalita e wave future.
- `EnemySystem` mantiene solo nemici validi in `active_enemies` ed emette `enemy_died`.
- `BasicEnemy` cerca periodicamente il player vivo piu vicino entro il detection range.
- Il target viene rivalutato anche quando un player lascia la sessione o muore.
- L'attacco inoltra il danno a `HealthSystem`; non modifica direttamente la vita del player.
- La morte nasce dal segnale `HealthComponent.died`, disabilita collisioni, genera drop e rimuove il nodo.
- I dati di movimento, detection, attacco, cooldown, vita e loot sono configurabili dalla scena o da risorse.
- `EnemySystem` registra `survival_runner` e `survival_tank` su scene dedicate.
- Basic, runner e tank riusano lo stesso script `BasicEnemy`; non esistono controller AI duplicati.
- `ZombieVisual.archetype_id` cambia silhouette e animazione senza cambiare collisioni o statistiche.
- Runner: 18 HP, velocita 155, danno 6 e cooldown 0,62 secondi.
- Tank: 90 HP, velocita 58, danno 18 e cooldown 1,25 secondi.

## Contratto drop

- Ogni nemico possiede una `LootTable` composta da risorse `DropEntry`.
- `DropSystem` e l'unico sistema che esegue roll, crea pickup e applica ricompense.
- XP e denaro aggiornano `ProgressionManager` e sono condivisi dal party.
- Le munizioni vengono applicate alle speciali di tutti i player vivi.
- Cura e arma vengono applicate al player che raccoglie.
- Un pickup non viene consumato se la ricompensa non puo essere applicata, per esempio cura su vita piena.
- Un pickup ammo non viene consumato se nessun player vivo possiede una speciale.
- Il drop arma equipaggia immediatamente il relativo `WeaponData`; inventario e scelta arma restano futuri.
- Le supply crate usano una `LootTable` e generano pickup standard tramite `DropSystem`.

## Contratto multiplayer locale

- Player 1 e sempre attivo e non puo lasciare la sessione dal prototipo.
- Gli slot 2-4 possono entrare/uscire durante la scena.
- Un joypad con `device = 0` controlla lo slot 1, `device = 1` controlla lo slot 2, e cosi via.
- `Start` attiva lo slot del controller, `Back/Select` disattiva lo slot se non e player 1.
- `F2`, `F3` e `F4` sono fallback debug per attivare/disattivare gli slot 2, 3 e 4 senza controller fisici.
- Ogni slot possiede anche l'azione `interact`: joypad `A`, con fallback tastiera `E` per player 1.
- `InputManager` garantisce che `ui_accept` includa joypad `A` con device globale, cosi ogni controller puo navigare e confermare il menu.
- `active_slots_changed` e il segnale autoritativo: i sistemi interessati devono ascoltare questo segnale invece di duplicare lo stato multiplayer.

## Contratti per modalita

Ogni modalita deriva da `BaseGameMode` e fornisce:

- `mode_id`;
- start/stop;
- condizione di vittoria/sconfitta;
- richiesta boss;
- collegamento a spawn nemici, drop e progressione.

Lo stato `menu` non e una modalita gameplay registrata. Entrare in `menu` arresta la modalita corrente; i player restano istanziati ma il loro input gameplay viene sospeso.

## Contratto salvataggi

- Il file predefinito e `user://savegame.json`.
- Il formato v2 contiene `version`, dati `party`, `party.unlocks` e `settings.last_mode`.
- I save v1 restano caricabili; gli unlock deterministici vengono ricostruiti dal livello e riscritti in v2 al salvataggio successivo.
- `ProgressionManager` espone dati serializzabili e applica valori validati.
- XP, denaro e unlock attivano autosave; il cambio modalita aggiorna `last_mode`.
- File assente, root non valida o versione non supportata non modificano lo stato runtime.
- L'auto-persistenza e disabilitata nei test headless, ma save/load espliciti restano disponibili.

## Contratto progressione e run

- `Field Kit` e l'unlock base: viene concesso al livello party 2 e resta persistente.
- All'ingresso in una modalita gameplay, `ProgressionManager` prepara tutti i player attivi.
- `GameModeManager.game_mode_started` viene emesso anche quando riparte la stessa modalita dopo un arresto.
- I player che entrano durante una run ricevono la stessa preparazione.
- `PlayerController.prepare_for_run()` calcola la vita dal valore base, quindi i bonus non si accumulano tra cambi modalita.
- Ogni nuova run ripristina la vita; `Field Kit` porta il massimo da 100 a 120 HP.

## Contratto audio

- `AudioManager` mantiene player separati per UI e gameplay.
- `ProjectileSystem.projectile_spawned` genera il feedback di sparo.
- Solo un impatto con danno applicato genera il feedback di colpo.
- `DropSystem.drop_collected` genera il feedback pickup in base al tipo raccolto.
- `WeaponSystem` genera feedback per low ammo, reload e fallback.
- I toni procedurali restano placeholder e non richiedono asset esterni.
- Spawn boss, telegraph e cambio fase usano cue distinti esposti da `gameplay_feedback_generated`.

## Contratto survival e wave

- `GameModeManager.register_mode()` avvia la modalita registrata se coincide con `default_mode`.
- `SurvivalMode` avvia e arresta `WaveManager` e controlla la sconfitta del party.
- L'arresto di survival rimuove i nemici e il boss della wave prima di attivare un'altra modalita.
- `WaveManager` e autoritativo per indice ondata, stato, spawn pendenti e nemici della wave.
- Gli stati runtime sono `idle`, `intermission`, `spawning`, `combat` e `reward`.
- Gli zombie vengono creati esclusivamente tramite `EnemySystem.spawn_enemy()`.
- `WaveManager.get_enemy_id_for_spawn()` compone deterministicamente il roster survival.
- La wave 1 usa solo basic; dalla wave 2 ogni terzo slot e runner.
- Dalla wave 3, se sono presenti almeno cinque zombie regolari, l'ultimo slot e tank.
- Ogni ondata aumenta il conteggio base e passa moltiplicatori a `BasicEnemy`.
- Solo le morti dei nemici registrati nella wave contribuiscono al completamento.
- Le ricompense tra ondate aggiungono denaro party e munizioni/cura ai player attivi vivi.
- Le ricompense ammo alimentano solo lo slot speciale; la fallback non necessita drop.
- `SurvivalAmmoDirector` valuta ogni secondo i player vivi con speciale.
- Sotto la soglia configurata di 8 colpi totali puo generare una supply crate, con cooldown di 12 secondi.
- Ogni boss wave riceve una supply crate garantita prima dell'avvio o all'inizio della wave.
- Le crate attive non aperte vengono rimosse quando survival si arresta.
- Join e leave non modificano il conteggio nemici; i nuovi player partecipano alle ricompense successive.
- Ogni quinta ondata emette `boss_wave_requested` e `SurvivalMode` la inoltra a `BossSystem`.
- La boss wave usa due zombie di scorta e un boss registrato separatamente.
- `WaveManager` include il boss nel conteggio e aspetta il suo segnale `died`.
- Se tutti i player attivi sono morti, `SurvivalMode` arresta la run.

## Contratto boss

- Le modalita richiedono boss tramite `GameModeManager.request_boss()`.
- `BossSystem` e l'unico proprietario dello spawn e impedisce boss attivi duplicati.
- Il boss riceve un dizionario di configurazione prima di entrare nell'albero.
- `BasicBoss` usa `HealthComponent` e appartiene al gruppo `damageable_targets`.
- Il targeting seleziona il player vivo piu vicino e supporta join/leave.
- I pattern usano `ProjectileSystem` con una scena proiettile ostile separata.
- Aimed e radial passano profili `WeaponVisualData` distinti allo stesso proiettile ostile.
- La fase 1 usa una raffica mirata da tre proiettili.
- Sotto il 50% di vita, la fase 2 alterna raffica radiale e mirata.
- Gli attacchi schedulati entrano prima in uno stato di telegraph.
- La raffica mirata mostra cono e corsie per 0,70 secondi e blocca la direzione annunciata.
- La raffica radiale mostra raggi e countdown per 0,90 secondi.
- Nessun proiettile viene creato durante il warning.
- `attack_telegraph_started` e `attack_telegraph_finished` espongono il timing ai sistemi di presentazione.
- `BossTelegraphVisual` puo essere sostituito senza cambiare pattern, danno o targeting.
- `WaveWardenVisual` puo essere sostituito senza cambiare health, collisioni o timing.
- Il danno letale genera un effetto `boss_death` senza ritardare il segnale `died`.
- La morte genera la `LootTable` boss, emette `died` e notifica `BossSystem`.
- `HUDManager` legge il boss attivo da `BossSystem` e mostra nome, fase e vita.
- Il contratto non dipende da survival: dungeon e tower defense possono riusare la stessa API.

## Contratto dungeon

- `DungeonGenerator.generate_layout(seed, room_count)` produce almeno quattro stanze con celle uniche.
- Lo stesso seed e conteggio producono lo stesso layout.
- Il prototipo genera un percorso sequenziale con start room, combat room, una loot room e boss room finale.
- `DungeonMode` istanzia una sola `DungeonRoom` attiva per volta e riposiziona il party al suo ingresso.
- Start e loot room hanno il portale aperto; combat e boss room lo bloccano fino al completamento.
- I nemici vengono creati solo tramite `EnemySystem` e tracciati localmente dalla modalita.
- La loot room usa una `LootTable` e `DropSystem`; i pickup non raccolti vengono rimossi al cambio stanza.
- Il boss finale viene richiesto tramite `GameModeManager` e `BossSystem`.
- La sostituzione di una stanza richiesta da un trigger fisico avviene in modo differito.
- Il menu principale seleziona dungeon; `F5` e `F1` restano scorciatoie debug.
- Diramazioni, shop, biomi e persistenza della run non fanno parte del prototipo minimo.

## Contratto tower defense

- `F6` seleziona `TowerDefenseMode`; il cambio modalita arresta e ripulisce survival o dungeon.
- La modalita istanzia una `TowerDefenseArena` e nasconde il playground prototipo.
- `TowerDefenseWaveController` e autoritativo per stato, indice wave, spawn e bersagli tracciati.
- Il percorso e un `PackedVector2Array` convertito in coordinate globali dall'arena.
- `EnemySystem.register_enemy_scene()` associa l'ID `tower_defense_raider` alla scena dedicata.
- `TowerDefenseEnemy` segue i waypoint senza selezionare player; alla fine chiama `TowerDefenseManager.damage_base()`.
- Vita, morte, drop e collisione proiettile continuano a usare `HealthComponent`, `DropSystem` e `ProjectileSystem`.
- I crediti sono valuta di run separata dal denaro party e vengono azzerati all'avvio della modalita.
- `TowerBuildSlot` rileva player sovrapposti e richiede la costruzione con l'azione `interact`.
- `TowerDefenseManager` valida disponibilita e costo prima di creare la torre.
- `DefenseTower` considera solo nodi nel gruppo `tower_defense_targets`.
- `DefenseTower` calcola target e origine di fuoco; `DefenseTowerVisual` presenta orientamento, rinculo e flash.
- Il proiettile torre usa il profilo visuale `defense_tower` senza cambiare danno o collisioni.
- Le boss wave richiedono il `Wave Warden` tramite `GameModeManager` e `BossSystem`.
- `BasicBoss` mantiene il comportamento action normale, ma se riceve `path_points` usa il percorso e danneggia il core al termine.
- La distruzione del core porta la modalita in stato `defeated` e ripulisce la wave.
- Percorsi multipli, upgrade, vendita, riparazione e tipi torre aggiuntivi restano futuri.

Modalita previste:

- `survival`: ondate zombie, boss ogni N ondate.
- `dungeon`: stanze generate, boss finale per livello/area.
- `tower_defense`: path nemici, base da difendere, boss nelle ondate principali.

## Contratto packaging e QA

- `export_presets.cfg` definisce il preset `Windows Desktop` x86_64.
- `build/*` e `tests/*` sono esclusi dal pacchetto release.
- `Main` crea `BuildRuntimeSmoke` solo con l'argomento utente `--build-smoke`.
- Il runner verifica bootstrap menu, focus, D-pad, joypad `A`, audio UI, avvio survival, HUD e ritorno con `Esc`.
- Il QA visuale usa `tests/menu_visual_qa.gd` e salva catture temporanee in `build/qa/`.

## Estendibilita IA

Per mantenere il progetto gestibile:

- aggiungere sistemi piccoli con responsabilita chiara;
- documentare ogni nuovo contratto pubblico;
- lasciare esempi minimi giocabili;
- mantenere milestone e TODO aggiornati;
- preferire scene/test manuali ripetibili.
