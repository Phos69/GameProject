# Sistema Modalita

Le modalita devono usare sistemi condivisi:

- `GameModeManager` per selezione e richieste globali;
- `BaseGameMode` come contratto concettuale;
- `WaveManager` per ondate;
- `BossSystem` per boss;
- `DropSystem` e `ProgressionManager` per ricompense.

## Survival

Usa ondate e boss ogni N ondate.

## Dungeon

Usa generazione procedurale di stanze e boss finale per area/livello.

## Tower Defense

Usa base health, path nemici, torri e boss nelle ondate principali.

