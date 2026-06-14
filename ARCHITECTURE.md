# ARCHITECTURE

## Visione tecnica

Il progetto e un sandbox Godot 4.x 2D con resa pseudo-isometrica. La scena principale avvia un playground minimo e registra i sistemi base. Le modalita future devono usare sistemi comuni invece di duplicare gameplay.

## Flusso runtime attuale

1. `main.tscn` carica manager e world.
2. `InputManager` registra azioni tastiera/joypad.
3. `PlayerManager` spawna il player 1.
4. `PlayerController` legge input e muove il personaggio.
5. `IsometricCameraController` segue il gruppo `players`.
6. `HUDManager` mostra stato prototipo e controlli.

## Sistemi principali

- `InputManager`: crea e legge azioni per slot player.
- `LocalMultiplayerManager`: mantiene gli slot locali attivi e prepara il mapping device.
- `PlayerManager`: spawna player e tiene il registro degli slot.
- `PlayerController`: movimento, mira e fire action.
- `GameModeManager`: selezione modalita e contratto comune futuro.
- `WeaponSystem`: punto di ingresso per armi e fire rate.
- `ProjectileSystem` e `Projectile`: spawn e base proiettile.
- `HealthSystem` e `HealthComponent`: richieste globali di danno/cura e stato vita locale.
- `EnemySystem`: contratto di spawn nemici.
- `BossSystem`: contratto comune per boss richiesti dalle modalita.
- `WaveManager`: logica ondate e boss ogni N ondate.
- `DungeonGenerator`: generazione dati layout dungeon.
- `TowerDefenseManager`: base health e contratto tower defense.
- `DropSystem` e `LootTable`: drop XP, denaro, armi, munizioni e vita.
- `ProgressionManager`: XP, livello e denaro party.
- `HUDManager`: UI prototipo.

## Contratti per modalita

Ogni modalita deve derivare concettualmente da `BaseGameMode` e fornire:

- `mode_id`;
- start/stop;
- condizione di vittoria/sconfitta;
- richiesta boss;
- collegamento a spawn nemici, drop e progressione.

Modalita previste:

- `survival`: ondate zombie, boss ogni N ondate.
- `dungeon`: stanze generate, boss finale per livello/area.
- `tower_defense`: path nemici, base da difendere, boss nelle ondate principali.

## Estendibilita IA

Per mantenere il progetto gestibile:

- aggiungere sistemi piccoli con responsabilita chiara;
- documentare ogni nuovo contratto pubblico;
- lasciare esempi minimi giocabili;
- mantenere milestone e TODO aggiornati;
- preferire scene/test manuali ripetibili.
