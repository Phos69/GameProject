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

`DungeonMode` usa `DungeonGenerator` per creare un percorso deterministico da seed.

Flusso:

1. start room con uscita aperta;
2. combat room con uscita bloccata;
3. sblocco dopo la morte dei nemici registrati;
4. loot room con pickup fisici;
5. boss room richiesta tramite `BossSystem`;
6. completamento dopo boss e portale finale.

Una sola `DungeonRoom` e attiva alla volta. Nemici, drop, health, progressione, boss e HUD restano sistemi condivisi. `F5` avvia dungeon e `F1` torna a survival durante il prototipo.

## Tower Defense

`TowerDefenseMode` istanzia una `TowerDefenseArena` separata e delega il ciclo ondate a `TowerDefenseWaveController`.

Flusso:

1. reset di core e crediti;
2. intermissione;
3. spawn progressivo tramite `EnemySystem`;
4. movimento nemici lungo i waypoint;
5. danno al core per i nemici che raggiungono la fine;
6. ricompensa crediti dopo l'eliminazione o fuga di tutta la wave;
7. boss ogni cinque ondate tramite `BossSystem`.

I player costruiscono entrando in un `TowerBuildSlot` e usando l'azione `interact`. `TowerDefenseManager` valida il costo e crea una `DefenseTower`, che spara tramite `ProjectileSystem`. `F6` avvia la modalita e `F1` torna a survival.
