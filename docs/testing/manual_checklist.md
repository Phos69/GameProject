# Manual Test Checklist

## Smoke test base

- Il progetto si apre in Godot 4.x.
- La scena principale parte senza errori.
- Il player viene spawnato.
- La griglia pseudo-isometrica e visibile.
- Il movimento tastiera funziona.
- Il joypad player 1 funziona se collegato.
- La camera segue il player.
- L'HUD mostra stato prototipo.

## Regressione input

- `WASD` produce movimento.
- Le frecce aggiornano la mira.
- Lo stick sinistro produce movimento.
- Lo stick destro aggiorna la mira.
- Il fire action non genera errori.
- Il fire action genera proiettili placeholder senza collisioni gameplay.

## Regressione multiplayer locale

- La scena parte con player 1 attivo.
- `F2`, `F3` e `F4` attivano rispettivamente player 2, 3 e 4.
- Premere di nuovo `F2`, `F3` o `F4` rimuove lo slot corrispondente senza rimuovere player 1.
- Con piu player attivi, l'HUD mostra conteggio e slot corretti.
- Con piu player attivi, la camera segue il centro del gruppo e modifica lo zoom.
- Con joypad multipli, `Start` attiva lo slot associato al controller e `Back/Select` lo disattiva se non e player 1.
- Ogni player mantiene input, mira e fire action del proprio slot.

## Regressione architettura

- I sistemi non sono duplicati in cartelle diverse.
- Ogni nuova modalita usa `GameModeManager`.
- Drop, XP, boss e wave restano sistemi separati.
