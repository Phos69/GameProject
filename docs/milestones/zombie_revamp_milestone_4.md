# Revamp Zombie - Milestone Z4

## Stato

Completata come primo layout ambientale fisico della `Pianura Infetta`.

## Obiettivo

Rendere il bioma iniziale meno vuoto con terreno, risorse e impedimenti fisici,
mantenendo leggibili le corsie e compatibile l'AI diretta esistente.

## Implementato

- Aggiunto `BiomeEnvironmentLayout` per tenere i placement fuori dai controller.
- Aggiunte patch non collidenti per erba secca, terra e detriti.
- Aggiunti due massi, recinto rotto, barriera, rudere e confine parziale.
- Gli ostacoli sono `StaticBody2D` sul layer fisico condiviso e appartengono ai
  gruppi `environment_obstacles` e `spawn_blockers`.
- Aggiunte una cassa comune e una medica con loot table dedicate.
- Le casse riusano `SupplyCrate`, `DropSystem` e i pickup esistenti.
- Le posizioni delle casse vengono validate contro ostacoli, hazard e altre
  casse.
- Stop e cambio modalita rimuovono tutto il runtime ambientale.

## Contratto

- `BiomeDefinition.environment_layout` e la sorgente dati del layout.
- `TerrainGenerator` non crea collisioni.
- `ObstacleSystem` possiede gli impedimenti fisici e la query di blocco.
- `ResourceCrateSystem` possiede solo le casse ambientali del bioma.
- `SurvivalAmmoDirector` resta proprietario delle crate anti-frustrazione e
  boss.
- Il corridoio centrale resta libero finche non viene introdotto un sistema di
  navigazione piu avanzato.

## Verifica

```text
godot --headless --path . --script res://tests/zombie_environment_milestone_smoke_test.gd
godot --headless --path . --script res://tests/zombie_spawner_edge_smoke_test.gd
godot --headless --path . --script res://tests/zombie_revamp_foundation_smoke_test.gd
godot --headless --path . --script res://tests/survival_wave_smoke_test.gd
godot --headless --path . --script res://tests/milestone_20_arena_environment_smoke_test.gd
tools/run_visual_qa.sh survival
```

QA visuale verificata a 1280x720 su `Industrial Crossroads` e `Rift Foundry`.

## Prossimo step

Milestone Z5: `fall_zone` con 20 HP di danno, ultima posizione sicura,
respawn e invulnerabilita breve.
