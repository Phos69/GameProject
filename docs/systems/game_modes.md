# Sistema Modalita

Le modalita devono usare sistemi condivisi:

- `GameModeManager` per selezione e richieste globali;
- `BaseGameMode` come contratto concettuale;
- `WaveManager` per ondate;
- `BossSystem` per boss;
- `DropSystem` e `ProgressionManager` per ricompense.

## Survival

`SurvivalMode` viene registrata presso `GameModeManager` e avvia `WaveManager`.

Flusso:

1. intermissione;
2. spawn progressivo;
3. combattimento finche i nemici registrati sono morti;
4. ricompensa party;
5. ondata successiva.

`WaveManager` aumenta conteggio e statistiche nemiche. Ogni quinta ondata usa due scorte e inoltra a `BossSystem` la richiesta per il `Wave Warden`. La wave resta attiva finche scorte e boss non sono morti.

La run termina quando non rimangono player attivi vivi.

## Boss condivisi

Le modalita richiedono boss tramite `GameModeManager`, che delega a `BossSystem`.

`BossSystem`:

- mantiene un solo boss attivo;
- riceve posizione e scaling dalla modalita;
- emette spawn e sconfitta;
- usa lo stesso contratto per survival, dungeon e tower defense.

## Dungeon

Usa generazione procedurale di stanze e boss finale per area/livello.

## Tower Defense

Usa base health, path nemici, torri e boss nelle ondate principali.
