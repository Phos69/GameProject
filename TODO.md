# TODO

## Completati recenti

- Milestone 7: dungeon procedurale giocabile.
  - Obiettivo: generare e attraversare start room, combat room, loot room e boss room.
  - Milestone collegata: Milestone 7.
  - File/sistemi coinvolti: `DungeonGenerator`, `DungeonMode`, `DungeonRoom`, `EnemySystem`, `BossSystem`, `DropSystem`, `HUDManager`.
  - Criterio di accettazione: una run da seed attraversa tutte le stanze, blocca le uscite durante il combat, genera loot e termina dopo il boss.
  - Test richiesto: `tests/dungeon_smoke_test.gd` e checklist manuale dungeon.
- Milestone 6: boss system modulare.
  - Obiettivo: integrare un boss reale nella quinta ondata survival.
  - Milestone collegata: Milestone 6.
  - File/sistemi coinvolti: `BasicBoss`, `BossSystem`, `WaveManager`, `SurvivalMode`, `ProjectileSystem`, `HUDManager`, `DropSystem`.
  - Criterio di accettazione: il boss usa due pattern, cambia fase, blocca il completamento della wave, muore, genera drop speciale e permette la prosecuzione.
  - Test richiesto: `tests/boss_smoke_test.gd` e checklist manuale boss.
- Milestone 5: zombie survival a ondate.
  - Obiettivo: creare un loop survival con spawn progressivo, scaling e ricompense.
  - Milestone collegata: Milestone 5.
  - File/sistemi coinvolti: `SurvivalMode`, `WaveManager`, `GameModeManager`, `EnemySystem`, `BasicEnemy`, `HUDManager`, `ProgressionManager`.
  - Criterio di accettazione: almeno tre ondate consecutive aumentano conteggio e statistiche, terminano alla morte dei nemici e premiano tutti i player attivi.
  - Test richiesto: `tests/survival_wave_smoke_test.gd` e checklist manuale survival.
- Milestone 4: nemico base e drop system.
  - Obiettivo: introdurre AI chase/attack, morte, spawn e pickup raccoglibili.
  - Milestone collegata: Milestone 4.
  - File/sistemi coinvolti: `BasicEnemy`, `EnemySystem`, `DropEntry`, `LootTable`, `DropSystem`, `DropPickup`, `HealthSystem`, `ProgressionManager`, `WeaponSystem`.
  - Criterio di accettazione: il nemico seleziona un player vivo, attacca, muore per danno e genera ricompense applicate correttamente in multiplayer locale.
  - Test richiesto: `tests/enemy_drop_smoke_test.gd` e checklist manuale enemy/drop.
- Milestone 3: combat system base.
  - Obiettivo: collegare sparo, proiettili, danni, vita e munizioni base.
  - Milestone collegata: Milestone 3.
  - File/sistemi coinvolti: `WeaponData`, `WeaponSystem`, `ProjectileSystem`, `Projectile`, `HealthSystem`, `HealthComponent`, HUD e scena principale.
  - Criterio di accettazione: un proiettile colpisce un bersaglio con vita, applica danno e consuma munizioni senza condividere lo stato tra player.
  - Test richiesto: `tests/combat_smoke_test.gd` e checklist manuale combat.
- Milestone 2: multiplayer locale 1-4 player.
  - Obiettivo: attivare/disattivare slot locali e spawnare player multipli.
  - Milestone collegata: Milestone 2.
  - File/sistemi coinvolti: `LocalMultiplayerManager`, `PlayerManager`, `PlayerController`, `HUDManager`.
  - Criterio di accettazione: player 1 sempre attivo, player 2-4 attivabili con joypad o tastiera debug, camera condivisa sul gruppo.
  - Test richiesto: checklist manuale multiplayer locale in `docs/testing/manual_checklist.md`.

## Priorita alta

- Milestone 8: implementare base tower defense, path nemici e torri piazzabili.
  - Obiettivo: creare il loop minimo di difesa della base con economia.
  - Milestone collegata: Milestone 8.
  - File/sistemi coinvolti: `TowerDefenseMode`, `TowerDefenseManager`, path, torri e base.
  - Criterio di accettazione: i nemici seguono il path, danneggiano la base e una torre puo eliminarli.
  - Test richiesto: smoke test tower defense e checklist manuale di una ondata completa.

## Priorita media

- Menu debug per selezionare modalita.
  - Obiettivo: sostituire le hotkey `F1`/`F5` con una UI per survival, dungeon e tower defense.
  - Milestone collegata: supporto alle Milestone 5-8.
  - File/sistemi coinvolti: `GameModeManager`, nuova UI debug.
  - Criterio di accettazione: ogni modalita registrata puo essere selezionata e avviata.
  - Test richiesto: smoke test manuale di selezione modalita.
- Espandere il dungeon oltre il percorso lineare.
  - Obiettivo: aggiungere diramazioni, scelta stanza, shop e predisposizione biomi.
  - Milestone collegata: evoluzione Milestone 7.
  - File/sistemi coinvolti: `DungeonGenerator`, `DungeonMode`, scene stanza e UI mappa.
  - Criterio di accettazione: almeno un seed produce una scelta reale tra due stanze senza rompere il percorso al boss.
  - Test richiesto: smoke test su piu seed e checklist manuale delle diramazioni.
- Respawn o revive player.
  - Obiettivo: definire il recupero di un player morto nelle modalita a ondate.
  - Milestone collegata: Milestone 5.
  - File/sistemi coinvolti: `PlayerManager`, `HealthComponent`, `SurvivalMode`, HUD.
  - Criterio di accettazione: la regola di respawn non interrompe gli altri player locali e viene documentata nel design.
  - Test richiesto: checklist manuale morte/respawn con due player.
- Varianti nemico base.
  - Obiettivo: aggiungere almeno runner e tank riusando il contratto `BasicEnemy`.
  - Milestone collegata: Milestone 5.
  - File/sistemi coinvolti: `game/enemies/`, `EnemySystem`, loot table dedicate.
  - Criterio di accettazione: le varianti cambiano dati o comportamento senza duplicare il sistema condiviso.
  - Test richiesto: smoke test spawn e morte per ogni variante.
- Telegraph e feedback boss.
  - Obiettivo: rendere anticipabili raffiche e cambio fase con animazioni, indicatori e audio.
  - Milestone collegata: Milestone 9.
  - File/sistemi coinvolti: `BasicBoss`, HUD, `AudioManager`, asset visuali.
  - Criterio di accettazione: ogni pattern mostra un preavviso leggibile prima del danno.
  - Test richiesto: checklist manuale visuale e audio.
- Varianti boss.
  - Obiettivo: aggiungere boss configurabili per dungeon e tower defense riusando `BossSystem`.
  - Milestone collegata: Milestone 7-8.
  - File/sistemi coinvolti: `game/bosses/`, `BossSystem`, modalita.
  - Criterio di accettazione: almeno due boss possono essere richiesti per ID senza cambiare il chiamante.
  - Test richiesto: smoke test spawn, morte e drop per ogni boss.

## Priorita bassa

- Audio placeholder.
  - Obiettivo: aggiungere feedback audio minimi per sparo, colpo, pickup e UI.
  - Milestone collegata: Milestone 9.
  - File/sistemi coinvolti: `AudioManager`, scene gameplay e asset audio.
  - Criterio di accettazione: gli eventi principali emettono audio con volume configurabile.
  - Test richiesto: checklist manuale audio.
- Salvataggi progressione.
  - Obiettivo: persistere impostazioni e progressione prevista dal design.
  - Milestone collegata: Milestone 9.
  - File/sistemi coinvolti: `SaveManager`, `ProgressionManager`.
  - Criterio di accettazione: save/load ripristina dati validi e gestisce file assente.
  - Test richiesto: test automatico round-trip e checklist manuale.
- Asset definitivi.
  - Obiettivo: sostituire progressivamente i placeholder senza introdurre dipendenze obbligatorie.
  - Milestone collegata: Milestone 9.
  - File/sistemi coinvolti: `assets/` e scene visuali.
  - Criterio di accettazione: leggibilita gameplay invariata e licenze documentate.
  - Test richiesto: revisione visuale delle scene principali.
- Export desktop.
  - Obiettivo: produrre una build desktop avviabile.
  - Milestone collegata: Milestone 9.
  - File/sistemi coinvolti: preset export, configurazione progetto e README.
  - Criterio di accettazione: build pulita avviabile senza editor.
  - Test richiesto: smoke test della build esportata.
- Ampliare i test automatici.
  - Obiettivo: coprire health, multiplayer, wave e generazione oltre al combat smoke test.
  - Milestone collegata: trasversale.
  - File/sistemi coinvolti: `tests/` e sistemi gameplay.
  - Criterio di accettazione: ogni sistema condiviso critico ha almeno uno smoke test headless.
  - Test richiesto: esecuzione completa della suite headless.
