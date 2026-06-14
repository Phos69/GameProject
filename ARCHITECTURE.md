# ARCHITECTURE

## Visione tecnica

Il progetto e un sandbox Godot 4.x 2D con resa pseudo-isometrica. La scena principale avvia un playground minimo e registra i sistemi base. Le modalita future devono usare sistemi comuni invece di duplicare gameplay.

## Flusso runtime attuale

1. `main.tscn` carica manager e world.
2. `InputManager` registra azioni tastiera/joypad.
3. `LocalMultiplayerManager` mantiene gli slot locali attivi.
4. `PlayerManager` ascolta gli slot attivi e spawna/despawna i player.
5. `PlayerController` legge input e muove il personaggio del proprio slot.
6. `WeaponSystem` gestisce arma, cooldown, caricatore, riserva e ricarica per il singolo player.
7. `ProjectileSystem` spawna proiettili che applicano danno tramite `HealthSystem`.
8. `EnemySystem` spawna nemici e `BasicEnemy` seleziona il player vivo piu vicino.
9. Alla morte, il nemico chiede a `DropSystem` di generare pickup dalla propria `LootTable`.
10. `DropPickup` delega l'applicazione della ricompensa a `DropSystem`.
11. `GameModeManager` avvia `SurvivalMode`, che delega il ciclo delle ondate a `WaveManager`.
12. `WaveManager` spawna zombie tramite `EnemySystem`, conta le morti e assegna ricompense.
13. `IsometricCameraController` segue il gruppo `players`.
14. `HUDManager` mostra slot, progressione, vita, munizioni e stato ondata.

## Sistemi principali

- `InputManager`: crea e legge azioni per slot player. Ogni slot usa azioni `p{slot}_{azione}`.
- `LocalMultiplayerManager`: mantiene gli slot locali attivi, gestisce join/leave e usa mapping deterministico `device joypad + 1 = player_slot`.
- `PlayerManager`: spawna/despawna player in base agli slot attivi e tiene il registro degli slot.
- `PlayerController`: movimento, mira, fire action e colore visuale per slot.
- `GameModeManager`: registra, arresta e avvia le modalita.
- `WeaponData`: risorsa immutabile con danno, fire rate, velocita proiettile, caricatore, riserva e durata ricarica.
- `WeaponSystem`: stato runtime per-player di arma, cooldown, munizioni e ricarica.
- `ProjectileSystem` e `Projectile`: spawn, movimento, collisione e consegna del danno.
- `HealthSystem` e `HealthComponent`: richieste globali di danno/cura e stato vita locale.
- `EnemySystem`: spawn, contenitore, registro runtime e notifica morte nemici.
- `BasicEnemy`: AI melee con stati idle, chase, attack e dead.
- `BossSystem`: contratto comune per boss richiesti dalle modalita.
- `SurvivalMode`: ciclo survival, condizione di sconfitta e inoltro richieste boss.
- `WaveManager`: macchina a stati per intermissione, spawn, combat, reward e boss wave.
- `DungeonGenerator`: generazione dati layout dungeon.
- `TowerDefenseManager`: base health e contratto tower defense.
- `DropEntry` e `LootTable`: dati tipizzati per chance, quantita e arma associata.
- `DropSystem`: roll, spawn pickup e applicazione centralizzata delle ricompense.
- `DropPickup`: rappresentazione fisica e raccolta da parte dei player.
- `ProgressionManager`: XP, livello e denaro party.
- `HUDManager`: UI prototipo.

## Contratto combat

- Ogni istanza player possiede il proprio `WeaponSystem`; caricatore, riserva e cooldown non sono condivisi.
- Le statistiche di bilanciamento vivono in risorse `WeaponData`, non nel controller player.
- `ProjectileSystem` riceve i dati dello sparo e configura il proiettile prima di aggiungerlo alla scena.
- Il proiettile non conosce classi nemico specifiche: colpisce un body damageable e inoltra il danno a `HealthSystem`.
- `HealthSystem` cerca un figlio `HealthComponent` sul target; player, nemici, boss e bersagli debug possono condividere lo stesso contratto.
- Collision layer `1`: player e corpi generici.
- Collision layer `2`: bersagli damageable.
- Collision layer `4`: proiettili; la mask attuale colpisce il layer `2`.
- Collision layer `8`: pickup; la mask attuale rileva i player sul layer `1`.
- `CombatTarget` e una fixture statica della scena principale per verificare il combat e non sostituisce l'AI nemica della Milestone 4.

## Contratto nemici

- `EnemySystem.spawn_enemy()` e il punto di ingresso per modalita e wave future.
- `EnemySystem` mantiene solo nemici validi in `active_enemies` ed emette `enemy_died`.
- `BasicEnemy` cerca periodicamente il player vivo piu vicino entro il detection range.
- Il target viene rivalutato anche quando un player lascia la sessione o muore.
- L'attacco inoltra il danno a `HealthSystem`; non modifica direttamente la vita del player.
- La morte nasce dal segnale `HealthComponent.died`, disabilita collisioni, genera drop e rimuove il nodo.
- I dati di movimento, detection, attacco, cooldown, vita e loot sono configurabili dalla scena o da risorse.

## Contratto drop

- Ogni nemico possiede una `LootTable` composta da risorse `DropEntry`.
- `DropSystem` e l'unico sistema che esegue roll, crea pickup e applica ricompense.
- XP e denaro aggiornano `ProgressionManager` e sono condivisi dal party.
- Munizioni, cura e arma vengono applicate al player che raccoglie.
- Un pickup non viene consumato se la ricompensa non puo essere applicata, per esempio cura su vita piena.
- Il drop arma equipaggia immediatamente il relativo `WeaponData`; inventario e scelta arma restano futuri.

## Contratto multiplayer locale

- Player 1 e sempre attivo e non puo lasciare la sessione dal prototipo.
- Gli slot 2-4 possono entrare/uscire durante la scena.
- Un joypad con `device = 0` controlla lo slot 1, `device = 1` controlla lo slot 2, e cosi via.
- `Start` attiva lo slot del controller, `Back/Select` disattiva lo slot se non e player 1.
- `F2`, `F3` e `F4` sono fallback debug per attivare/disattivare gli slot 2, 3 e 4 senza controller fisici.
- `active_slots_changed` e il segnale autoritativo: i sistemi interessati devono ascoltare questo segnale invece di duplicare lo stato multiplayer.

## Contratti per modalita

Ogni modalita deriva da `BaseGameMode` e fornisce:

- `mode_id`;
- start/stop;
- condizione di vittoria/sconfitta;
- richiesta boss;
- collegamento a spawn nemici, drop e progressione.

## Contratto survival e wave

- `GameModeManager.register_mode()` avvia la modalita registrata se coincide con `default_mode`.
- `SurvivalMode` avvia e arresta `WaveManager` e controlla la sconfitta del party.
- `WaveManager` e autoritativo per indice ondata, stato, spawn pendenti e nemici della wave.
- Gli stati runtime sono `idle`, `intermission`, `spawning`, `combat` e `reward`.
- Gli zombie vengono creati esclusivamente tramite `EnemySystem.spawn_enemy()`.
- Ogni ondata aumenta il conteggio base e passa moltiplicatori a `BasicEnemy`.
- Solo le morti dei nemici registrati nella wave contribuiscono al completamento.
- Le ricompense tra ondate aggiungono denaro party e munizioni/cura ai player attivi vivi.
- Join e leave non modificano il conteggio nemici; i nuovi player partecipano alle ricompense successive.
- Ogni quinta ondata emette `boss_wave_requested` e `SurvivalMode` la inoltra a `BossSystem`.
- Finche Milestone 6 non fornisce un boss, la boss wave usa zombie extra con bonus vita e danno.
- Se tutti i player attivi sono morti, `SurvivalMode` arresta la run.

Modalita previste:

- `survival`: ondate zombie, boss ogni N ondate.
- `dungeon`: stanze generate, boss finale per livello/area.
- `tower_defense`: path nemici, base da difendere, boss nelle ondate principali.

## Estendibilita IA

Per mantenere il progetto gestibile:

- aggiungere sistemi piccoli con responsabilita chiara;
- documentare ogni nuovo contratto pubblico;
- lasciare esempi minimi giocabili;
- mantenere milestone e TODO aggiornati;
- preferire scene/test manuali ripetibili.
