# Repo Health Report — 2026-07-17

Analisi statica dell'intero repository su `master` (commit `ede59c7`, working
tree pulito). Copre: criticità con rischio crash, duplicazioni di codice,
manutenibilità, known issue consolidati, test/CI e configurazione di build.
Nessuna modifica al codice è stata applicata; ogni finding cita file e riga.

> **Aggiornamento 2026-07-17 (stessa giornata):** le tre criticità P0 e C4
> sono state risolte — C1 in `f16178b`, C3 in `3a1a0da`, C2 in `ae7cbd8`,
> C4 in `db3a7a0` (suite combat 26/26, modes 17/17, save_edge 2/2 e soak
> lifecycle verdi). Le sezioni sotto restano come fotografia pre-fix.
>
> **Aggiornamento dedup:** i gruppi P1 4.4, 4.1 e 4.3 sono stati unificati —
> `ContextUtils` in `39bf724`, `GeometryUtils` + metodi layout/passage in
> `7422efa`, `BiomeZoneArea` in `84701c9` (suite completa 307/307, 30.337
> assert). Anche i tre residui inizialmente lasciati separati sono stati
> unificati in `68c352f` dopo verifica di equivalenza (esito identico:
> route del prop pass, road-cells del map validation, palette
> `edge_color_for_style` — quest'ultima era in realtà un duplicato esatto,
> il "quasi identica" del report era un falso negativo dello scan).
> Il gruppo 4.2 è stato chiuso in `953973f` (`QuadMeshBuffers` condiviso
> dai tre mesh builder; suite obstacles/environment/assets/world_gen
> verdi). Il gruppo 4.5 è stato chiuso in `4a17e93` (statics AudioManager
> UI, `BossSystem.connect_boss_feedback`, `sync_consumer` al posto delle
> copie `_sync_visual_settings`, basi `SettingsAwareVisual`/
> `PatternBossVisual`, più `_apply_visual_profile` del main menu rimosso
> in quanto codice morto; suite completa 307/307). Resta aperto il solo
> gruppo 4.6 (gameplay).

## 1. Sintesi

Il repo è in salute sopra la media: GDScript tipizzato ovunque, zero
TODO/FIXME residui nel codice di gioco, 247 test GUT verdi in CI, salvataggio
atomico con backup e migrazione legacy, documentazione operativa curata
(`ARCHITECTURE.md`, `TODO.md`, report in `docs/`). I problemi trovati sono
pochi ma concreti:

| # | Area | Severità | Sintesi |
|---|------|----------|---------|
| C1 | `weapon_effect_resolver.gd` | **Alta** | uso di `target` potenzialmente liberato dopo `await` (esplosione ritardata) |
| C2 | `zombie_mode_controller.gd` | **Alta** | avvio async senza token di cancellazione: `stop_run` durante il loading lascia la coroutine viva |
| C3 | `game_mode_manager.gd` | **Alta** (facile) | hotkey debug F1/F5/F6/F7 attive anche nella build esportata; amplificano C2 |
| C4 | `save_manager.gd` | Media | scrittura save non verificata con `get_error()`: disco pieno può sostituire un save valido con uno troncato |
| D1 | 29 gruppi di funzioni duplicate | Media | violazione misurabile della regola anti-duplicazione di `AGENTS.md` |
| M1 | 5 mega-file oltre 1.200 righe | Media | `obstacle_layout_generator.gd` a 2.829 righe |
| B1 | Export include `addons/gut` | Bassa | bloat nel `.pck` di release |
| T1 | CI: `--import \|\| true` e nessun lint | Bassa | errori d'import mascherati |

## 2. Numeri del repo

- 190 script `.gd` in `game/`, 107 in `tests/`, 25 scene `.tscn` di gioco.
- 1.503 file tracciati; asset ~129,5 MB.
- Stack: Godot 4.6 (`gl_compatibility`), GUT per i test, MCP server Node in
  `tools/mcp-server`, CI GitHub Actions (suite headless + soak notturno).
- Nessun autoload: tutti i sistemi vivono in `main.tscn` e si trovano tra loro
  via gruppi (`get_first_node_in_group`: 181 occorrenze in 57 file).
- Cultura difensiva buona: 130 usi di `is_instance_valid`, 106 guardie
  `is_connected` prima dei connect, campionamenti deterministici con guardie
  su array vuoti nei punti controllati a campione.

## 3. Criticità con rischio crash

### C1 — `target` liberato dopo l'await dell'esplosione ritardata (Alta)

`game/weapons/weapon_effect_resolver.gd:162-164`:

```gdscript
static func _resolve_delayed(...) -> void:
    await tree.create_timer(definition.delayed_explosion).timeout
    _resolve_now(tree, definition, target, position, owner_ref, definition.damage)
```

Se il bersaglio muore ed è liberato durante il ritardo (caso normale: granate
su zombie a bassa vita), `_resolve_now` lo riusa. Le righe 185-187 eseguono
`target is CharacterBody2D` e poi `(target as CharacterBody2D).velocity += ...`
su un'istanza liberata: in Godot 4 l'operando liberato di `is` produce un
errore runtime ("previously freed instance"). Le guardie esistenti non bastano:
`target != null` (riga 175/177) è vero-negativo per istanze liberate solo nel
confronto `==`, mentre `_apply_status` (riga 209) è l'unico punto con
`is_instance_valid`.

**Fix proposto:** dopo l'`await`, normalizzare
`if not is_instance_valid(target): target = null` (stesso pattern già usato
correttamente in `_grant_defensive_window`, righe 242-249). Vale anche per
`owner_ref`.

Nota collegata: la stessa classe di bug è già stata trovata e corretta due
volte nel progetto (HealthSystem `get_last_damage_source`, drops_test —
vedi `docs/latest_commit_validation_report.md`): conviene un pass unico su
tutti gli `await` che catturano nodi (`grep -n "await" game/`, 34 occorrenze
in 5 file).

### C2 — Avvio async del mondo senza cancellazione (Alta)

`game/modes/zombie/zombie_mode_controller.gd:180-208`: `_start_run_async`
attraversa quattro punti di sospensione (`while thread.is_alive(): await`,
`_await_active_tile_build`, `_await_streaming_readiness`) e poi chiama
`_finish_start_run` + `_emit_run_started`. `stop_run` (riga 326) non setta
alcun flag che la coroutine controlli: se la modalità viene fermata durante il
loading (ritorno al menu, retry, cambio modalità), la coroutine prosegue e:

- applica `world_data` a un `biome_manager` appena resettato (riga 197);
- riavvia la run su una modalità fermata (`_emit_run_started`);
- se il controller venisse liberato, `get_tree()` dentro il loop `await`
  restituirebbe `null` → crash.

**Fix proposto:** contatore di generazione (`_run_generation += 1` in
`start_run` e `stop_run`; la coroutine cattura il valore e ritorna se cambia
dopo ogni `await`). Il thread va comunque sempre raccolto con
`wait_to_finish` prima di abbandonare.

### C3 — Hotkey debug di cambio modalità attive in release (Alta, fix banale)

`game/modes/game_mode_manager.gd:10` — `@export var debug_mode_hotkeys := true`
non è mai sovrascritto (né in `main.tscn` né altrove) e il filtro export
esclude solo `build/*,tests/*`: nella build esportata F1/F5/F6/F7 cambiano
modalità in qualunque momento. Oltre a rompere il flusso (salta Character
Select, spawn immediato), è l'innesco più facile per C2: F1 premuto durante la
schermata di caricamento zombie chiama `stop_mode` a metà `_start_run_async`.

**Fix proposto:** default `false` fuori editor, es.
`debug_mode_hotkeys = OS.has_feature("editor")` in `_ready`, o gate
`OS.is_debug_build()` in `_unhandled_input`.

### C4 — Scrittura save non verificata (Media)

`game/saves/save_manager.gd:122-128`: `store_string` + `close()` senza
controllare `file.get_error()`; a disco pieno il `.tmp` troncato viene poi
promosso a save (righe 145-148) e il `.bak` buono viene cancellato (riga
155-156). Il resto della pipeline è esemplare (rename atomici, rollback,
marker di migrazione con check errore alle righe 375-383) — manca solo questo
check.

**Fix proposto:** dopo `store_string`, leggere `file.get_error()` (ed
eventualmente riaprire in lettura per validare il JSON) prima del rename;
in errore, cancellare il `.tmp` e mantenere save e backup correnti.

### C5 — Rifiniture minori (Bassa)

- `game/modes/game_mode_manager.gd:117`: `retry_active_mode` chiama
  `current_mode.start_mode(...)` fuori dal null-check; se un mode registrato
  fosse liberato senza deregistrazione (non esiste un `unregister_mode`),
  `registered_modes` terrebbe un riferimento morto e `has_method` su di esso
  errorerebbe. Rischio basso finché i mode vivono per tutta la sessione in
  `main.tscn`, ma vale la guardia `is_instance_valid`.
- `game/modes/game_mode_manager.gd:45`: `mode.get("mode_id")` senza
  validazione: un nodo senza `mode_id` viene registrato sotto chiave nulla.
- `game/weapons/weapon_effect_resolver.gd:173`: `randf()` per i critici in un
  progetto che altrove usa solo campionamenti deterministici seed-based
  (`_deterministic_unit`, `_unit_sample`); non è un bug, ma è incoerente con
  la riproducibilità delle run e complica i test.

## 4. Duplicazioni di codice

Scan automatico su `game/` (funzioni ≥6 righe, corpi normalizzati identici):
**29 gruppi di duplicati esatti**. `AGENTS.md` vieta esplicitamente di
"integrare il codice presente invece di duplicare responsabilità": questi sono
i punti dove la regola è stata persa. Raggruppati per tema, con il refactor
suggerito:

### 4.1 Geometria condivisa → estrarre `GeometryUtils` (static class in `game/core/`)

- `_clip_rect` ×5: `biome_environment_layout.gd:763`,
  `map_validation_system.gd:441`, `obstacle_layout_generator.gd:2967`,
  `random_prop_placement_pass.gd:480`, `static_hazard_placement_pass.gd:199`
- `_ellipse_points` ×6 (due varianti): `rift_architect_visual.gd:202`,
  `zombie_boss_visual.gd:262`, `biome_obstacle.gd:377`,
  `character_gameplay_preview.gd:362`, `drop_pickup_visual.gd:199`,
  `player_visual.gd:635`
- `_rect_overlaps_passage_corridor` ×3: `obstacle_layout_generator.gd:1454`,
  `mesa_placement_pass.gd:181`, `static_hazard_placement_pass.gd:138`
- `_intersects_route` ×2, `_passage_probe_cell`/`_passage_inner_anchor` ×2

### 4.2 Mesh builder cliff/rocks → helper comune buffer/quad

- `_append_quad` (25 righe!) ×2: `rectilinear_cliff_face_mesh_builder.gd:359`,
  `rectilinear_rock_area_mesh_builder.gd:224`
- `_build_mesh` ×3 e `_mesh_buffers`/`_new_buffers` ×3 negli stessi file più
  `top_down_cliff_border_mesh_builder.gd`

### 4.3 Zone (fall zone vs hazard zone) → base class comune

`biome_fall_zone.gd` e `biome_hazard_zone.gd` condividono corpo identico di
`contains_global_position` (60/63), `distance_to_zone` (68/71) e
`_rebuild_collision` (165/80). Anche `_edge_color_for_style` è quasi identica
tra `biome_fall_zone.gd:278` e `top_down_cliff_renderer.gd:408`.

### 4.4 Parsing del context dictionary → `ContextUtils`

`_get_context_string` ×2 (`biome_map_generator.gd:340`,
`obstacle_layout_generator.gd:1352`), `_get_context_bool` ×2
(`zombie_mode_controller.gd:309`, `obstacle_layout_generator.gd:1340`).

### 4.5 UI/audio/visual settings

- `_play_focus` ×3: `main_menu.gd:1615`, `pause_menu.gd:223`,
  `run_results_screen.gd:232`
- `_sync_visual_settings` ×3 e `apply_visual_settings` ×3 tra i visual —
  candidato a un piccolo mixin/nodo `VisualSettingsConsumer`
- `_connect_boss_feedback` (18 righe) ×2: `audio_event_router.gd:214`,
  `hud_manager.gd:567`
- `_apply_visual_profile` ×2: `main_menu.gd:1596`, `settings_panel.gd:538`

### 4.6 Gameplay condiviso

- `_grant_kill_experience` ×2: `basic_boss.gd:433`, `basic_enemy.gd:377` —
  esperienza kill in due copie che possono divergere sul bilanciamento
- `_reach_base` ×2: `basic_boss.gd:145`, `tower_defense_enemy.gd:68`
- `_process` del ciclo wave ×2: `wave_manager.gd:69`,
  `tower_defense_wave_controller.gd:46`
- Duplicato *nello stesso file*: `biome_tile_resolver.gd:847` vs `:1175`
  (`_route_cell_touches_non_route[_surface]`)
- `asset_path_exists` ×2: `biome_tile_resolver_utils.gd:18` (che esiste
  proprio per essere l'utility condivisa) vs copia privata in
  `environment_asset_manifest.gd:863`

Lo scan rileva solo duplicati *esatti*: i near-duplicate (stessa logica,
nomi diversi) sono verosimilmente di più. Consiglio di rifare lo scan dopo il
primo pass di estrazione.

## 5. Manutenibilità

### 5.1 Mega-file (violazione della regola "evitare mega-file" di `AGENTS.md`)

| Righe | File |
|-------|------|
| 2.829 | `game/procedural/world_generation/obstacle_layout_generator.gd` |
| 1.951 | `game/modes/zombie/biome_tile_layer.gd` |
| 1.486 | `game/ui/main_menu.gd` |
| 1.331 | `game/modes/zombie/cliffs/top_down_cliff_border_mesh_builder.gd` |
| 1.285 | `game/modes/zombie/biome_tile_resolver.gd` |

`obstacle_layout_generator.gd` ha già una direzione di split avviata
(`world_generation/passes/` con mesa/prop/hazard pass): continuare
l'estrazione è il refactor a rischio più basso, coperto dalle suite
`world_gen`/`obstacles`. `main_menu.gd` mischia navigazione, layout, profili
visivi e audio focus: buon candidato a scorporo dei pannelli.

### 5.2 Service locator a gruppi

Il pattern `get_tree().get_first_node_in_group(...)` + boilerplate
`_resolve_*` (7 resolver solo in `save_manager.gd`) è replicato in 57 file.
Funziona ed è testato, ma: (a) ogni consumer riimplementa caching e
null-check; (b) i typo sui nomi gruppo falliscono in silenzio; (c) l'ordine
di inizializzazione dipende da `call_deferred` sparsi. Opzioni non invasive:
costanti `StringName` centralizzate in `GameConstants` per i nomi gruppo, o un
`ServiceRegistry` leggero (anche senza autoload, come nodo di `main.tscn`).

### 5.3 Naming e igiene

- `GameplayEffect` (nodo effetto singolo, `game/visuals/gameplay_effect.gd`)
  vs `GameplayEffects` (manager, `gameplay_effects.gd`): una lettera di
  differenza per due ruoli diversi — rinomina suggerita
  (`GameplayEffectSpawner` o simile).
- Directory vuote residue: `tests/suites/_tmp/`, `tmp/imagegen/`.
- `.gitignore` non copre la dir radice `tmp/` (solo `*.tmp`).
- `map_generation_report.md` in radice mentre tutti gli altri report stanno in
  `docs/` (è citato da `TODO.md`, spostarlo richiede aggiornare i riferimenti).

## 6. Known issue consolidati (già noti, per riferimento)

- **Smoke build esportata:** lanciare senza `--log-file` — con quel flag
  l'exe termina con access violation prima di scrivere il log
  (`docs/latest_commit_validation_report.md`). Non risolto a monte: è un
  workaround documentato, upstream da verificare su Godot 4.6.x.
- **Firma digitale:** blocco esterno (nessun signtool/certificato);
  `codesign/enable=false` nel preset.
- **Perf raster mob:** ~60 µs CPU + ~57 µs GPU per zombie a schermo; tetto
  accettato fino a ~96 mob visibili (worst frame 28,9 ms), sfora verso ~192.
  Opzione futura documentata: baking degli archetipi in sprite texture.
- **Test flaky storici:** `drops_test::test_weapon_tower_visual_identity`
  risolto il 2026-07-07; `character_select_test::test_character_select_ui`
  stabilizzato il 2026-07-03, da riconfermare alla prossima full run.
- **Backlog aperto:** `BIOME-RASTER-002` (raster per Tossico/Infuocato/Neve/
  Palude) e i soli playtest manuali di `BAL-001` (`TODO.md`).

## 7. Test e CI

Punti di forza: 247 test / ~24.700 assert in un solo processo headless, suite
soak notturna separata, pre/post-run script per isolare il disco, guardrail
anti-asset-esterni, config GUT multiple (quick/golden/soak/envcheck).

Gap:

1. **`godot --headless --import ... || true`** (`.github/workflows/ci.yml:50`):
   un import rotto (asset corrotto, `.import` incoerente) non fallisce il job;
   la suite a valle può fallire con errori fuorvianti o, peggio, passare senza
   aver importato le risorse nuove. Meglio rimuovere `|| true` e, se serve
   tollerare warning, filtrare sull'exit code specifico.
2. **Nessun lint/format check:** con 190 file GDScript conviene aggiungere
   `gdtoolkit` (gdlint/gdformat) come job veloce in CI; intercetterebbe anche
   le funzioni duplicate sopra una soglia di lunghezza.
3. **Nessun check di parse dedicato:** un job `--check-only` (dopo import)
   fallirebbe in secondi su errori di script, prima dei 51+ secondi di GUT.
4. I Visual QA (`tools/run_visual_qa.*`) restano manuali per scelta; ok, ma
   vale la pena registrare in `docs/` la cadenza attesa.

## 8. Configurazione e build

- **Export include l'addon GUT:** `export_filter="all_resources"` con
  `exclude_filter="build/*,tests/*"` porta `addons/gut/**` (e gli script in
  `tools/*.gd`) dentro il `.pck` di release. Aggiungere
  `addons/gut/*,tools/*` all'exclude riduce superficie e dimensione (pck
  attuale 44,4 MB).
- `debug/export_console_wrapper=1`: la release apre con wrapper console —
  utile ora per lo smoke, da valutare 0 per la release finale.
- `project.godot` è minimale per scelta (niente autoload, niente `[input]`
  perché `InputManager` registra le azioni a runtime con guardie
  `has_action`). Due rifiniture: dare nomi ai physics layer 2D
  (`layer_names/2d_physics/*`) per leggibilità di editor/debug, e valutare un
  set minimo di azioni `[input]` di fallback per la navigazione UI qualora
  `InputManager` fallisca l'inizializzazione.

## 9. Raccomandazioni prioritizzate

| Priorità | Azione | Effort |
|----------|--------|--------|
| P0 | C1: guardia `is_instance_valid` post-await in `weapon_effect_resolver.gd` (+ pass sugli altri 34 `await`) | ~1h |
| P0 | C3: gate editor/debug sulle hotkey F1/F5/F6/F7 | ~10 min |
| P0 | C2: token di generazione in `_start_run_async`/`stop_run` | ~2h + test lifecycle |
| P1 | C4: check `get_error()` nella scrittura save | ~30 min + smoke persistenza |
| P1 | Dedup 4.1/4.3/4.4 (geometria, zone, context utils) — i gruppi a più alto rischio di divergenza | 1-2 giorni, suite esistenti coprono |
| P1 | CI: rimuovere `\|\| true` dall'import, aggiungere job `--check-only` | ~30 min |
| P2 | Escludere `addons/gut` e `tools/*.gd` dall'export | ~15 min + re-export smoke |
| P2 | Dedup 4.2/4.5/4.6 + rinomina `GameplayEffects` | 1-2 giorni |
| P2 | Split incrementale di `obstacle_layout_generator.gd` verso `passes/` | continuo |
| P3 | gdlint in CI, nomi physics layer, cleanup dir vuote e `.gitignore` per `tmp/` | sparso |

---

*Metodo: analisi statica (grep pattern crash/duplicazioni, scan automatico dei
corpi funzione con hash normalizzato, lettura mirata dei sistemi core) +
consolidamento dei report esistenti in `docs/` e della cronologia test. Nessun
test eseguito in questa sessione; i numeri di suite citati provengono da
`docs/latest_commit_validation_report.md` (2026-07-08).*
