# Visual QA — tool di ispezione manuale

I Visual QA **non sono test logici**: producono screenshot/griglie (sotto
`build/qa/`) per l'ispezione manuale dell'identità visiva. Richiedono un
contesto di rendering (non headless), quindi **vivono fuori dalla suite GUT**
eseguita in CI e si lanciano su richiesta — localmente o in un job notturno con
display virtuale (xvfb).

I file vivono in `tests/visual_qa/` (sono script standalone `extends SceneTree`).

## Esecuzione

```bash
# Tutti i Visual QA (rendering gl_compatibility, output in build/qa/)
tools/run_visual_qa.sh

# Solo quelli che matchano un pattern
tools/run_visual_qa.sh weapon
```

In ambienti senza display usare xvfb:

```bash
xvfb-run -a tools/run_visual_qa.sh
```

Variabili utili: `GODOT` (binario), `QA_RENDER` (default `gl_compatibility`),
`SKIP_IMPORT=1` (salta l'import), `QA_LOG_DIR` (cartella log).

## Elenco dei tool

| Area | File |
| --- | --- |
| Ambiente / bioma | `zombie_biome_visual_qa.gd`, `forest_surface_generated_visual_qa.gd`, `milestone_10_isometric_final_visual_qa.gd` |
| Ostacoli / asset | `obstacle_3x3_visual_qa.gd`, `obstacle_asset_visual_qa.gd`, `void_cliff_generated_visual_qa.gd`, `void_cliff_runtime_visual_qa.gd` |
| Armi | `weapon_visual_identity_qa.gd`, `weapon_visual_identity_qa_board.gd`, `weapon_visual_identity_survival_qa.gd`, `weapon_tower_visual_qa.gd` |
| Nemici / boss | `enemy_variants_visual_qa.gd`, `ranged_enemy_visual_qa.gd`, `boss_telegraph_visual_qa.gd`, `rift_architect_visual_qa.gd` |
| Modalità / arena | `arena_variants_visual_qa.gd`, `survival_visual_qa.gd`, `final_survival_visual_qa.gd` |
| UI / HUD / audio | `menu_visual_qa.gd`, `player_world_hud_visual_qa.gd`, `run_results_visual_qa.gd`, `audio_mix_visual_qa.gd`, `downed_revive_visual_qa.gd`, `visual_accessibility_qa.gd` |

> Nota: `weapon_visual_identity_qa.gd` orchestra `weapon_visual_identity_qa_board.gd`
> e `weapon_visual_identity_survival_qa.gd` via `preload`.
