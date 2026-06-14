# CHANGELOG

## Unreleased

### Added

- Inizializzato repository Git.
- Creato progetto Godot 4.x testuale.
- Creata struttura cartelle per core, input, multiplayer, player, camera, combat, modalita, drop, progressione, UI, audio e salvataggi.
- Aggiunta scena principale pseudo-isometrica.
- Aggiunto player controllabile con movimento fluido.
- Aggiunto input manager con supporto tastiera e joypad player 1.
- Aggiunta camera che segue il gruppo player.
- Aggiunti stub modulari per sistemi futuri: armi, projectile system, health system, nemici, boss, wave, dungeon, tower defense, drop, loot table e progressione.
- Creata documentazione iniziale di repository, architettura, design, roadmap e workflow IA.
- Completata Milestone 2 come prototipo minimo di multiplayer locale 1-4 player.
- Aggiunto join/leave locale con `Start`/`Back` joypad e fallback debug `F2`-`F4`.
- Collegato `PlayerManager` agli slot attivi per spawn/despawn dinamico.
- Aggiunti colori per slot player e HUD con slot locali attivi.
- Aggiornata documentazione di roadmap, architettura, design, README, TODO e checklist manuale.
- Completata Milestone 3 come prototipo minimo di combat.
- Aggiunta risorsa `WeaponData` e pistola base configurabile.
- Aggiunti caricatore, riserva munizioni e ricarica indipendenti per-player.
- Aggiunto input ricarica con `R` e pulsante joypad `X`.
- Collegati proiettili, collisioni, danni, `HealthSystem` e `HealthComponent`.
- Aggiunti bersagli statici damageable con barra vita nella scena principale.
- Esteso HUD con vita e munizioni per ogni player.
- Aggiunto smoke test headless per combat e regressione multiplayer a due player.
- Aggiornata documentazione per stato Milestone 3, contratti combat e backlog futuro.
- Completata Milestone 4 come prototipo minimo di nemici e drop.
- Aggiunto `BasicEnemy` melee con stati idle, chase, attack e dead.
- Aggiunti targeting del player vivo piu vicino e retarget su join/leave.
- Esteso `EnemySystem` con spawn, contenitore, registro e segnale morte.
- Integrati attacchi nemici e morte con `HealthSystem` e `HealthComponent`.
- Aggiunti `DropEntry` e loot table tipizzate configurabili.
- Aggiunti pickup fisici per esperienza, denaro, munizioni, vita e armi.
- Centralizzata in `DropSystem` l'applicazione delle ricompense party e per-player.
- Aggiunto `Prototype Blaster` come primo drop arma equipaggiabile.
- Aggiunti due nemici iniziali alla scena principale.
- Aggiunto smoke test headless enemy/drop con regressione multiplayer locale.
- Aggiornata documentazione per stato Milestone 4, contratti enemy/drop e prossima Milestone 5.
