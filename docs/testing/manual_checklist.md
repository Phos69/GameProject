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
- Il fire action genera proiettili visibili.
- `R` ricarica l'arma del player 1.
- Il pulsante joypad `X` ricarica l'arma dello slot associato.

## Regressione multiplayer locale

- La scena parte con player 1 attivo.
- `F2`, `F3` e `F4` attivano rispettivamente player 2, 3 e 4.
- Premere di nuovo `F2`, `F3` o `F4` rimuove lo slot corrispondente senza rimuovere player 1.
- Con piu player attivi, l'HUD mostra conteggio e slot corretti.
- Con piu player attivi, la camera segue il centro del gruppo e modifica lo zoom.
- Con joypad multipli, `Start` attiva lo slot associato al controller e `Back/Select` lo disattiva se non e player 1.
- Ogni player mantiene input, mira e fire action del proprio slot.

## Regressione combat

- L'HUD mostra `HP 100/100` e `Ammo 12/36` per ogni player appena spawnato.
- Sparare riduce il caricatore di una unita per colpo valido.
- Le munizioni di un player non modificano quelle degli altri player.
- Tenere premuto fire rispetta il fire rate della pistola.
- `R` o pulsante `X` avvia la ricarica e l'HUD mostra il suffisso `R`.
- Dopo un secondo il caricatore viene riempito consumando la riserva.
- Un proiettile che colpisce un bersaglio rosso riduce la sua barra vita.
- Quattro colpi della pistola distruggono un bersaglio da 40 HP.
- I proiettili non collidono con il player che li ha sparati.

## Smoke test automatico

Eseguire con Godot 4.x disponibile nel PATH:

```text
godot --headless --path . --script res://tests/combat_smoke_test.gd
```

Il test verifica scena principale, due player locali, sparo, collisione, danno, munizioni indipendenti e ricarica.

## Regressione architettura

- I sistemi non sono duplicati in cartelle diverse.
- Ogni nuova modalita usa `GameModeManager`.
- Drop, XP, boss e wave restano sistemi separati.
