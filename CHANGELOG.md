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
