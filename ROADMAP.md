# ROADMAP

## Milestone 0 - Setup repository e documentazione

Stato: completata.

- Repository Git inizializzato.
- Progetto Godot 4.x creato.
- Struttura cartelle creata.
- Documentazione iniziale creata.
- Regole IA definite in `AGENTS.md`.

## Milestone 1 - Movimento, joypad e camera

Stato: completata come prototipo minimo.

- Scena principale pseudo-isometrica.
- Player controllabile.
- Movimento fluido.
- Input joypad player 1.
- Fallback tastiera.
- Camera che segue il gruppo player.
- Struttura predisposta per multiplayer locale.

## Milestone 2 - Multiplayer locale

Stato: completata come prototipo minimo.

- Assegnazione deterministica device/slot per 1-4 player locali.
- Spawn e despawn dinamico dei player locali.
- Camera di gruppo con zoom dinamico gia condivisa tra i player attivi.
- HUD con conteggio player e slot attivi.
- Join/leave locale: `Start`/`Back` su joypad e `F2`-`F4` come fallback debug per slot 2-4.

## Milestone 3 - Sparo, armi, danni e vita

Stato: completata come prototipo minimo.

- Proiettili visibili con collisione su bersagli damageable.
- Danno applicato tramite `HealthSystem` e `HealthComponent`.
- Statistiche arma configurabili tramite `WeaponData`.
- Pistola base con caricatore, riserva munizioni e ricarica.
- Stato vita e munizioni per-player nell'HUD.
- Bersagli statici per verifica combat nella scena principale.
- Smoke test headless con due player locali.

## Milestone 4 - Nemici base e drop

Stato: prossima.

- Nemico base con AI.
- Spawn nemici.
- Drop XP, denaro, armi, munizioni e vita.
- Pickup in scena.

## Milestone 5 - Zombie survival

Stato: pianificata.

- Arena survival.
- Wave manager operativo.
- Boss ogni N ondate.
- Ricompense tra ondate.

## Milestone 6 - Boss system

Stato: pianificata.

- Boss base con fasi.
- Health bar boss.
- Drop speciale boss.
- Contratto comune per tutte le modalita.

## Milestone 7 - Dungeon procedurale

Stato: pianificata.

- Grafo stanze.
- Stanza iniziale, combattimento, loot e boss.
- Transizioni stanza.
- Boss finale livello/area.

## Milestone 8 - Tower defense

Stato: pianificata.

- Path nemici.
- Base da difendere.
- Torri piazzabili.
- Boss nelle ondate principali.

## Milestone 9 - Polish, salvataggi e packaging

Stato: pianificata.

- Save/load.
- Audio e feedback.
- Bilanciamento.
- Export desktop.
