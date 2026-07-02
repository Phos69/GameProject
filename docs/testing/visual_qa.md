# Visual QA — tool di ispezione manuale

I Visual QA **non sono test logici**: producono screenshot/griglie (sotto
`build/qa/`) per l'ispezione manuale dell'identità visiva. Richiedono un
contesto di rendering (non headless), quindi **vivono fuori dalla suite GUT**
eseguita in CI e si lanciano su richiesta — localmente o in un job notturno con
display virtuale (xvfb).

Gli entry point vivono in `tests/visual_qa/` e sono script standalone
`extends SceneTree`. Gli helper WVIS top-level e gli helper condivisi sotto
`tests/visual_qa/helpers/` non vengono eseguiti direttamente dal runner.

Ogni cattura gameplay usa il contratto condiviso
`helpers/visual_qa_runtime.gd`: attende la rimozione di
`WorldLoadingScreen`, il marker specifico dello scenario, il completamento del
terreno e, quando lo streaming e attivo, area prefetch pronta, code regioni e
contenuti drenate e `visible_missing_chunks == 0` stabile per tre frame, seguiti
da due frame renderizzati `post_draw`. Il review biomi richiede inoltre almeno
il 30% di copertura world non-nera. La QA isometrica finale profila un
attraversamento seam continuo con zoom dinamico. Il cleanup dello stesso helper
libera scena e cache statiche prima dell'uscita.

## Esecuzione

```bash
# Tutti i Visual QA (rendering gl_compatibility, output in build/qa/)
tools/run_visual_qa.sh

# Solo quelli che matchano un pattern
tools/run_visual_qa.sh weapon
```

Su Windows/PowerShell:

```powershell
# Tutti i Visual QA
./tools/run_visual_qa.ps1

# QA mirata ai biomi survival
./tools/run_visual_qa.ps1 -Filter biome
```

In ambienti senza display usare xvfb:

```bash
xvfb-run -a tools/run_visual_qa.sh
```

Variabili utili: `GODOT` (binario), `QA_RENDER` (default `gl_compatibility`),
`SKIP_IMPORT=1` (salta l'import nello script Bash), `QA_LOG_DIR` (cartella log
Bash). In PowerShell usare anche `-SkipImport` e `-OutputLogDir`.

## Elenco dei tool

| Area | File |
| --- | --- |
| Ambiente / bioma | `biome_art_infected_plains_visual_qa.gd`, `biome_art_toxic_wastes_visual_qa.gd`, `biome_rendering_review_visual_qa.gd`, `zombie_biome_visual_qa.gd`, `forest_surface_generated_visual_qa.gd`, `milestone_10_isometric_final_visual_qa.gd` |
| Ostacoli / asset | `obstacle_3x3_visual_qa.gd`, `obstacle_asset_visual_qa.gd`, `rock_area_visual_qa.gd`, `void_cliff_generated_visual_qa.gd`, `void_cliff_runtime_visual_qa.gd` |
| Armi | `weapon_visual_identity_qa.gd`, `weapon_visual_identity_qa_board.gd`, `weapon_visual_identity_survival_qa.gd`, `weapon_tower_visual_qa.gd` |
| Nemici / boss | `enemy_variants_visual_qa.gd`, `ranged_enemy_visual_qa.gd`, `boss_telegraph_visual_qa.gd`, `rift_architect_visual_qa.gd` |
| Modalità / arena | `survival_visual_qa.gd`, `final_survival_visual_qa.gd`, `infinite_arena_cliff_visual_qa.gd` |
| UI / HUD / audio | `menu_visual_qa.gd`, `player_world_hud_visual_qa.gd`, `run_results_visual_qa.gd`, `audio_mix_visual_qa.gd`, `downed_revive_visual_qa.gd`, `visual_accessibility_qa.gd` |

> Nota: `weapon_visual_identity_qa.gd` orchestra `weapon_visual_identity_qa_board.gd`
> e `weapon_visual_identity_survival_qa.gd` via `preload`; i due helper sono
> esclusi esplicitamente dai runner PowerShell e Bash. La suite completa esegue
> 27 entry point standalone.
