# Milestone 20 - Arena, Biomi e Props Interattivi

## Stato

Completata come primo sistema arena survival data-driven.

## Obiettivo

Aumentare la varieta ambientale senza duplicare `SurvivalMode`, compromettere
la leggibilita degli attori o introdurre ostacoli incompatibili con l'AI
diretta degli zombie.

## Implementato

- `BiomePalette` per palette ambientali sostituibili;
- `SurvivalArenaProfile` per layout, spawn, player start, crate e props;
- profilo `Industrial Crossroads` a corsie incrociate;
- profilo `Rift Foundry` con anelli e sei ingressi radiali;
- `SurvivalArenaManager` per applicare il profilo ai sistemi condivisi;
- spawn gate non collidenti con impulso collegato allo spawn reale;
- barili esplosivi colpibili dai proiettili ma non bloccanti;
- warning temporizzato e area world-space prima del danno;
- danno ad area inoltrato a `HealthSystem`;
- effetto esplosione in `GameplayEffects`;
- nome arena attiva nell'HUD survival.

## Contratto

- `SurvivalMode` legge `context.arena_id` e non contiene layout specifici.
- `WaveManager` riceve i punti spawn dal profilo attivo.
- `PlayerManager` e `SurvivalAmmoDirector` ricevono spawn coerenti dal profilo.
- Lo sfondo legge solo dati visuali da `BiomePalette`.
- I gate sono presentazione pura e non hanno collisioni.
- I barili sono `Area2D` sul layer damageable: ricevono proiettili senza
  bloccare basic, runner, tank o shooter.
- Il danno esplosivo avviene solo dopo `warning_started`.

## Verifica

```text
godot --headless --path . --script res://tests/milestone_20_arena_environment_smoke_test.gd
godot --headless --path . --script res://tests/milestone_20_arena_stress_test.gd
godot --headless --path . --script res://tests/combat_smoke_test.gd
godot --headless --path . --script res://tests/boss_smoke_test.gd
godot --headless --path . --script res://tests/dungeon_smoke_test.gd
godot --headless --path . --script res://tests/tower_defense_smoke_test.gd
tools/run_visual_qa.sh survival
```

Output QA:

```text
build/qa/milestone_20_industrial_crossroads.png
build/qa/milestone_20_rift_foundry.png
```

## Checklist manuale

- Avviare survival con entrambi gli `arena_id`.
- Verificare che ogni spawn coincida con un gate visibile.
- Controllare che gate e barili non fermino il movimento degli zombie.
- Colpire un barile e uscire dal cerchio prima della detonazione.
- Verificare danno su player, nemici e boss dentro l'area.
- Controllare quattro player e roster misto a 1280x720.
- Passare a dungeon e tower defense e verificare la pulizia dei props.
