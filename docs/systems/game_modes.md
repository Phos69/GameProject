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

`WaveManager` aumenta conteggio e statistiche nemiche. Ogni quinta ondata inoltra una richiesta a `BossSystem`; finche il boss reale non esiste, usa zombie extra potenziati.

La run termina quando non rimangono player attivi vivi.

## Dungeon

Usa generazione procedurale di stanze e boss finale per area/livello.

## Tower Defense

Usa base health, path nemici, torri e boss nelle ondate principali.
