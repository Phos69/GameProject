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

## Regressione architettura

- I sistemi non sono duplicati in cartelle diverse.
- Ogni nuova modalita usa `GameModeManager`.
- Drop, XP, boss e wave restano sistemi separati.
