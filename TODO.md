# TODO

## Completati recenti

- Milestone 2: multiplayer locale 1-4 player.
  - Obiettivo: attivare/disattivare slot locali e spawnare player multipli.
  - Milestone collegata: Milestone 2.
  - File/sistemi coinvolti: `LocalMultiplayerManager`, `PlayerManager`, `PlayerController`, `HUDManager`.
  - Criterio di accettazione: player 1 sempre attivo, player 2-4 attivabili con joypad o tastiera debug, camera condivisa sul gruppo.
  - Test richiesto: checklist manuale multiplayer locale in `docs/testing/manual_checklist.md`.

## Priorita alta

- Milestone 3: completare combat system base.
  - Obiettivo: collegare sparo, proiettili, danni, vita e munizioni base.
  - Milestone collegata: Milestone 3.
  - File/sistemi coinvolti: `WeaponSystem`, `ProjectileSystem`, `Projectile`, `HealthSystem`, `HealthComponent`, scena player.
  - Criterio di accettazione: un proiettile puo colpire un bersaglio con vita e applicare danno senza rompere il multiplayer locale.
  - Test richiesto: scena principale con 1 player e con almeno 2 player locali attivi.
- Milestone 4: creare un nemico base con AI chase/attack.
  - Obiettivo: introdurre il primo nemico che insegue e attacca i player.
  - Milestone collegata: Milestone 4.
  - File/sistemi coinvolti: `EnemySystem`, nuova scena nemico, `HealthComponent`.
  - Criterio di accettazione: il nemico sceglie un target player vivo, si muove verso di lui e puo morire.
  - Test richiesto: spawn manuale in scena principale e verifica con 1-2 player.
- Milestone 4: rendere operativo il drop system con pickup in scena.
  - Obiettivo: trasformare i drop in pickup raccoglibili.
  - Milestone collegata: Milestone 4.
  - File/sistemi coinvolti: `DropSystem`, `LootTable`, `ProgressionManager`, pickup scene future.
  - Criterio di accettazione: alla morte di un nemico puo apparire un pickup e il party riceve la ricompensa.
  - Test richiesto: uccidere un nemico in scena e verificare XP/denaro/HUD.

## Priorita media

- Milestone 5: implementare arena zombie survival con ondate e scaling.
- Milestone 6: implementare primo boss con pattern semplice.
- Milestone 7: trasformare `DungeonGenerator` in generatore di stanze giocabili.
- Milestone 8: implementare base tower defense, path nemici e torri piazzabili.
- Aggiungere menu debug per selezionare modalita.

## Priorita bassa

- Aggiungere audio placeholder.
- Aggiungere salvataggi progressione.
- Aggiungere asset definitivi.
- Preparare export desktop.
- Aggiungere test automatici dove Godot headless sara disponibile.
