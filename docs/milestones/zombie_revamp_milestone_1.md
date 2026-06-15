# Revamp Zombie - Milestone Z1

## Stato

Completata come fondazione modulare.

## Obiettivo

Separare la modalita zombie in componenti dedicati senza rompere la survival
esistente, preparando spawn dinamico, biomi, terreno, casse, ostacoli e hazard.

## Implementato

- `ZombieModeController` come coordinatore interno della survival.
- `BiomeManager` e `BiomeDefinition` come registro e dati dei biomi.
- Cinque biomi iniziali: Pianura Infetta, Tossico, Infuocato, Neve e Palude.
- `WaveDirector` per roster e moltiplicatori basati sul bioma corrente.
- `ZombieSpawner` per posizioni dai bordi camera con fallback arena.
- Stub ambientali: `TerrainGenerator`, `ResourceCrateSystem`, `ObstacleSystem`, `HazardSystem`.
- Collegamento di `SurvivalMode`, `WaveManager` e `SurvivalArenaManager` ai nuovi componenti.

## Contratto

- Ogni run survival seleziona sempre `infected_plains` come bioma iniziale.
- `BiomeManager` e il punto unico per leggere il bioma corrente.
- `WaveManager` resta autoritativo sul ciclo wave, ma delega roster e spawn ai
  nuovi componenti quando sono presenti.
- `EnemySystem.spawn_enemy()` resta l'unico punto di creazione nemici.
- `spawn_points` resta disponibile per gate, test e fallback.

## Verifica

```text
godot --headless --path . --script res://tests/zombie_revamp_foundation_smoke_test.gd
godot --headless --path . --script res://tests/survival_wave_smoke_test.gd
godot --headless --path . --script res://tests/milestone_20_arena_environment_smoke_test.gd
```

## Prossimo step

Milestone Z2: rendere lo spawn camera-edge piu completo con pesi configurabili,
validazione pathability/collisioni piu ricca e test specifici su edge nord,
sud, est e ovest.
