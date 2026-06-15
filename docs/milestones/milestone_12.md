# Milestone 12 - Varianti Zombie Runner e Tank

## Stato

Completata come primo pass gameplay e visuale.

## Obiettivo

Introdurre pressione e priorita di bersaglio diverse nella zombie survival
senza duplicare AI, health, drop o tracking delle ondate.

## Implementato

- `Runner Zombie` sottile, inclinato e animato con cadenza rapida;
- `Tank Zombie` largo, pesante e marcato da protezioni arancioni;
- scene dedicate configurate sul controller condiviso `BasicEnemy`;
- collisioni e health bar proporzionate alla silhouette;
- loot table dedicate con ricompense commisurate al ruolo;
- registrazione scene per ID in `EnemySystem`;
- composizione deterministica delle ondate survival;
- smoke test su spawn, statistiche, attacco, morte, loot e conteggio wave;
- QA visuale con quattro player a 1280x720.

## Ruoli

### Basic Zombie

- 30 HP;
- velocita 95;
- attacco 8;
- ruolo: pressione standard.

### Runner Zombie

- 18 HP;
- velocita 155;
- attacco 6 ogni 0,62 secondi;
- 4 XP garantiti;
- ruolo: raggiungere rapidamente player isolati e costringere al movimento.

### Tank Zombie

- 90 HP;
- velocita 58;
- attacco 18 ogni 1,25 secondi;
- 8 XP garantiti;
- ruolo: assorbire fuoco e comprimere lo spazio disponibile.

Tutte le statistiche continuano a ricevere gli stessi moltiplicatori per wave.

## Composizione survival

- wave 1: solo basic;
- dalla wave 2: ogni terzo slot regolare e un runner;
- dalla wave 3: se la wave ha almeno cinque zombie regolari, l'ultimo slot e
  un tank;
- le boss wave con due sole scorte mantengono per ora scorte basic.

La selezione e deterministica e non modifica il conteggio autoritativo della
wave.

## Contratto tecnico

- `BasicEnemy` resta l'unico controller AI melee.
- Runner e tank cambiano solo dati di scena, collisione, loot e profilo visuale.
- `ZombieVisual` disegna i tre archetipi ma non possiede logica gameplay.
- `EnemySystem.spawn_enemy()` resta il punto di ingresso unico.
- `WaveManager.get_enemy_id_for_spawn()` decide la composizione survival.
- Dungeon e tower defense mantengono gli ID e i roster precedenti.

## Verifica automatica

```text
godot --headless --path . --script res://tests/milestone_12_enemy_variants_smoke_test.gd
godot --headless --path . --script res://tests/survival_wave_smoke_test.gd
godot --headless --path . --script res://tests/enemy_drop_smoke_test.gd
godot --headless --path . --script res://tests/dungeon_smoke_test.gd
godot --headless --path . --script res://tests/tower_defense_smoke_test.gd
```

QA visuale:

```text
godot --path . --rendering-method gl_compatibility --script res://tests/enemy_variants_visual_qa.gd
```

Output:

```text
build/qa/milestone_12_enemy_variants.png
```

## Checklist manuale

- Avviare survival e verificare che la wave 1 contenga solo basic.
- Raggiungere la wave 2 e identificare il runner senza leggere testo.
- Verificare che il runner raggiunga il party prima dei basic.
- Raggiungere una wave 3 non boss con almeno cinque nemici e identificare il tank.
- Verificare che il tank richieda piu fuoco e infligga danno maggiore.
- Controllare hit reaction, health bar e morte di ogni archetipo.
- Raccogliere gli XP garantiti di runner e tank.
- Verificare il roster con 2-4 player e HUD completo.
- Passare a dungeon e confermare che usa ancora il roster basic.
- Passare a tower defense e confermare che i raider dedicati non cambiano.

## Fuori scope

- zombie ranged;
- abilita speciali o charge attack;
- armor break e punti deboli;
- varianti nel dungeon;
- nuovi effetti audio dedicati per archetipo.
