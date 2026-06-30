# Report — Generazione mappa: Zombie Survival vs Infinite Arena

Data analisi: 2026-06-30. Branch: `master`.
Scopo: mappare **tutti** i modi in cui viene generata la mappa, evidenziare le
differenze tra `Zombie Survival` e `Infinite Arena` (alias "infinite wave") e
indicare cosa serve per renderle coerenti.

---

## 0. Sintesi (TL;DR)

Le due modalità **condividono già lo stesso motore** di base
(`ZombieModeController` → `BiomeManager` → `BiomeWorldGenerator`). Le differenze
che percepisci **non nascono da motori diversi tra le modalità**, ma da tre
divergenze interne al motore condiviso:

1. **Due pipeline di layout coesistono, scelte per BIOMA e non per modalità.**
   `infected_plains` usa la pipeline nuova *void-first*; gli altri 4 biomi usano
   la pipeline *legacy*. → Strade/ostacoli/void costruiti in modo diverso.
2. **I cliff/void interni sono soppressi di proposito nell'arena murata.**
   `Infinite Arena` passa `arena_boundary_mode = "walled"`, che (a) trasforma i
   bordi esterni da *FALL* a *BLOCKED* (muri al posto del precipizio) e (b)
   disattiva la "void lottery" dei burroni interni.
3. **Lo streaming multi-regione è attivo solo in Zombie Survival.** L'arena è una
   singola cella 1×1 senza streaming.

Il **rendering** dei cliff è invece **già condiviso** (stesso `BiomeTileLayer` +
`BiomeFallZone`), guidato unicamente da `layout.fall_zone_rects`: se il layout
contiene fall zone, entrambe le modalità le disegnano in modo identico. La
divergenza è quindi tutta in **generazione**, non in rendering.

> Conferma dai documenti interni del repo:
> - [`biome_generation_voidfirst_roadmap.md`](biome_generation_voidfirst_roadmap.md) —
>   "infected_plains usa la pipeline void-first […]; gli altri biomi restano sul
>   layout legacy".
> - [`repo_fix_roadmap.md`](repo_fix_roadmap.md#L463-L484) — l'arena murata fu resa
>   *deliberatamente* "senza fall zone interne" disattivando la void lottery.

---

## 1. Flusso condiviso (entrambe le modalità)

```
InfiniteArenaMode ──delega──► SurvivalMode ──► ZombieModeController.start_run(context)
                                                      │
                                                      ▼
                                          BiomeManager.generate_world_data(context)
                                                      │
                                                      ▼
                                          BiomeWorldGenerator.generate_world()
                                            ├─ BiomeMapGenerator.generate_map()      (celle, bordi, passaggi)
                                            └─ BiomeTerrainGenerator.generate_layouts_for_cells()
                                                  └─ ObstacleLayoutGenerator         (rocce, strade, void, ostacoli)
                                                  └─ FallBoundaryGenerator           (cliff perimetrali sui bordi FALL)
```

- `Infinite Arena` **non è un motore separato**: è un wrapper sottile attorno a
  `SurvivalMode`. Vedi
  [`infinite_arena_mode.gd`](game/modes/survival/infinite_arena_mode.gd#L25-L75):
  costruisce un `context` e chiama `survival_mode.start_mode(context)`.
- Tutto il mondo è costruito da
  [`zombie_mode_controller.gd`](game/modes/zombie/zombie_mode_controller.gd#L79-L109)
  in entrambi i casi.

### Cosa cambia nel `context` tra le due modalità

| Chiave context | Infinite Arena | Zombie Survival |
|---|---|---|
| `single_biome_arena` | `true` | (assente) |
| `biome_map_width` / `height` | `1` × `1` | default `3` × `3` |
| `biome_cell_width` / `height` | `500` × `500` | default `BiomeEnvironmentLayout.DEFAULT_ZONE_SIZE` |
| `arena_boundary_mode` | `"walled"` | (assente) |
| `disable_world_runtime` | `true` | (assente → runtime attivo) |
| `disable_region_streaming` | `true` | (assente → streaming attivo) |

Sorgente: [`infinite_arena_mode.gd:55-75`](game/modes/survival/infinite_arena_mode.gd#L55-L75).

> Nota: con mappa 1×1 il `BiomeMapGenerator` assegna alla cella (0,0) il bioma di
> partenza `infected_plains`
> ([`biome_map_generator.gd:181`](game/procedural/world_generation/biome_map_generator.gd#L181)).
> Quindi **Infinite Arena vede SEMPRE e SOLO il motore void-first**, mentre Zombie
> Survival vede void-first sulla cella starter e legacy sulle altre 8 celle.

---

## 2. Le DUE pipeline di layout (la causa principale dell'incoerenza)

Il punto di biforcazione è
[`biome_terrain_generator.gd:38-46`](game/procedural/world_generation/biome_terrain_generator.gd#L38-L46):

```gdscript
if biome.biome_id == &"infected_plains":
    obstacle_layout_generator.populate_layout_voidfirst(layout, cell, biome, context)
else:
    obstacle_layout_generator.populate_layout(layout, cell, biome, context)
```

### 2A. Pipeline VOID-FIRST (`populate_layout_voidfirst`) — solo `infected_plains`

[`obstacle_layout_generator.gd:140-160`](game/procedural/world_generation/obstacle_layout_generator.gd#L140-L160):

```
_carve_passages          # corridoi inter-bioma come strade calpestabili
_place_rocks             # ~10-16 rocce quadrate sul void
_place_forests           # boschi quadrati riempiti di alberi
_add_voidfirst_roads     # MODELLO "hub + spokes" (vedi §3)
_choose_voidfirst_spawn
_add_voidfirst_paths     # sentieri nei boschi
_clear_trees_on_routes
_add_connected_border_walls
_line_roads_with_trees
_resolve_void_lottery    # void residuo → pavimento o BURRONE (chasm)
_add_voidfirst_crates
```

### 2B. Pipeline LEGACY (`populate_layout`) — tutti gli altri biomi

[`obstacle_layout_generator.gd:109-132`](game/procedural/world_generation/obstacle_layout_generator.gd#L109-L132):

```
_add_roads               # CROCE fissa di 2 main road bordo-a-bordo (40 px) + passaggi
_add_biome_navigation_features  # griglia fissa di 2 sentieri secondari (20 px)
_add_internal_blocks     # taglia i rettangoli tra le strade in "blocchi"
                         #   → blocchi full_void/partial_void = burroni interni
_add_starter_water_crossing
_add_large_obstacles / _add_secondary_obstacles / _add_starter_roadside_details
_add_connected_border_walls
_add_crates / _add_theme_hazards / _add_block_props
_ensure_starter_*
```

### Conseguenza diretta

Dentro una singola partita di **Zombie Survival**, la cella di partenza
(`infected_plains`, void-first) ha un *aspetto e una logica di strade/void diversi*
dalle celle vicine (legacy). E **Infinite Arena** non vede mai la pipeline legacy.
Questa è la radice di *"costruzione/rendering di strade non coerente"*.

---

## 3. STRADE — come vengono generate

### Void-first (`_add_voidfirst_roads` / `_collect_road_spokes`)

[`obstacle_layout_generator.gd:360-442`](game/procedural/world_generation/obstacle_layout_generator.gd#L360-L442).

Modello unico **"hub + spokes"**: il centro del chunk è collegato con una strada
("spoke") a ogni "uscita". Un'uscita è:

- un **passaggio inter-bioma** → spoke `broken_street` instradato in A* (aggira le
  rocce) dal passaggio al centro → *"strade verso i biomi confinanti"*;
- oppure, **se l'arena è murata**, ogni bordo senza passaggio → spoke `main_road`
  fino al punto medio del lato → i 4 spoke insieme formano la **croce bordo-a-bordo**
  → *"4 strade che vanno ai lati"*.

> **Questo è già esattamente il comportamento che descrivi come desiderato.** Il
> "muro = vicino" è ciò che permette a entrambe le modalità di usare un solo
> percorso di codice: la croce a 4 è il caso degenere in cui ogni lato è un muro.

### Legacy (`_add_roads`)

[`obstacle_layout_generator.gd:783-810`](game/procedural/world_generation/obstacle_layout_generator.gd#L783-L810).

- Disegna **sempre** una croce fissa di 2 `main_road` da bordo a bordo, *a
  prescindere* da dove siano i passaggi.
- Aggiunge i passaggi inter-bioma come rect separati.
- `_add_biome_navigation_features` aggiunge una **griglia fissa** di 2 sentieri
  secondari con ratio per-bioma
  ([:812-838](game/procedural/world_generation/obstacle_layout_generator.gd#L812-L838)).

→ Le strade legacy **non dipendono dai vicini** e spesso corrono in parallelo ai
corridoi dei passaggi (il commento al void-first §3 spiega perché il vecchio
modello fu abbandonato per le celle connesse). Questa è la seconda fonte di
incoerenza nelle strade.

---

## 4. CLIFF e VOID — come vengono generati e dove vengono soppressi

Esistono **due tipi** di void/cliff:

### 4A. Cliff PERIMETRALI (bordo del mondo)

Decisi dal **tipo di bordo della cella** (`BiomeCell.BorderType`):

- Default di ogni lato = **`FALL`**
  ([`biome_cell.gd:42`](game/procedural/world_generation/biome_cell.gd#L42)).
- Un lato con vicino diventa `CONNECTED`; un edge selezionato come bloccato diventa
  `BLOCKED`.
- [`FallBoundaryGenerator`](game/procedural/world_generation/fall_boundary_generator.gd)
  aggiunge una striscia di fall zone (cliff verso il void) **solo** sui lati `FALL`.

**Divergenza:** in Infinite Arena,
[`_apply_outer_boundary_mode`](game/procedural/world_generation/biome_map_generator.gd#L308-L321)
converte **tutti** i bordi esterni senza vicino in `BLOCKED` perché
`arena_boundary_mode == "walled"`. Quindi:
- Zombie Survival → bordi esterni `FALL` → **cliff perimetrali verso il void**.
- Infinite Arena → bordi esterni `BLOCKED` → **muri**, nessun cliff perimetrale.

### 4B. Void/burroni INTERNI

- **Void-first:** `_resolve_void_lottery` sorteggia il void residuo in rapporto
  1 burrone : 3 calpestabili
  ([:641-684](game/procedural/world_generation/obstacle_layout_generator.gd#L641-L684)),
  ma **solo se `allow_chasms`**.
- **Legacy:** `_add_internal_blocks` crea blocchi `full_void`/`partial_void` →
  `_apply_block_surface` li trasforma in `add_fall_zone_rect`
  ([:1179-1204](game/procedural/world_generation/obstacle_layout_generator.gd#L1179-L1204)),
  ma **solo se `allow_internal_void`**.

**Divergenza:** entrambi i flag derivano da
`not _is_walled_arena_context(context)`
([:117](game/procedural/world_generation/obstacle_layout_generator.gd#L117) e
[:148](game/procedural/world_generation/obstacle_layout_generator.gd#L148);
helper a [:1062](game/procedural/world_generation/obstacle_layout_generator.gd#L1062)).
Quindi nell'arena murata **non viene mai generato void interno**.

### Riepilogo cliff/void

| | Zombie Survival | Infinite Arena |
|---|---|---|
| Cliff perimetrali | Sì (bordi `FALL`) | No (bordi `BLOCKED`/muri) |
| Void/burroni interni | Sì (lottery + blocchi void) | No (soppressi da `walled`) |

Questo spiega le tue osservazioni 2 e 3: *"cliff con void generati solo in zombie
survival"* e *"ci sono i cliff in zombie survival"*.

---

## 5. RENDERING dei cliff — già condiviso

Il rendering **non** è una fonte di divergenza tra le modalità. È guidato solo dal
contenuto del layout:

- Il terreno/ground dei cliff è disegnato dal
  [`BiomeTileLayer`](game/modes/zombie/biome_tile_layer.gd) tramite
  `IsometricCliffMeshBuilder` e `IsometricCliffBorderMeshBuilder`, a partire da
  `layout.fall_zone_rects`
  ([biome_tile_layer.gd:637-668](game/modes/zombie/biome_tile_layer.gd#L637-L668)).
- La fisica di caduta + bordo "ledge" è
  [`BiomeFallZone`](game/modes/zombie/biome_fall_zone.gd) (Area2D) +
  [`IsometricCliffRenderer`](game/modes/zombie/isometric_cliff_renderer.gd).
- Lo sfondo oltre il chunk è il "void backdrop" colorato col bioma
  ([zombie_mode_controller.gd:462-489](game/modes/zombie/zombie_mode_controller.gd#L462-L489)).

→ Conseguenza pratica: **se la generazione producesse fall zone anche nell'arena,
verrebbero renderizzate identiche senza toccare il codice di rendering.**

---

## 6. STREAMING / runtime — differenza strutturale (solo Survival)

- Zombie Survival usa lo streaming multi-regione:
  [`_stream_active_regions`](game/modes/zombie/zombie_mode_controller.gd#L521-L547)
  con `WorldRegionStreamer` + `RegionSeamSystem` + `WorldRuntime`.
- Infinite Arena disabilita tutto (`disable_region_streaming`,
  `disable_world_runtime`) e prende il percorso diretto single-region:
  `terrain_generator/obstacle_system/hazard_system/resource_crate_system.start_run(biome)`
  ([zombie_mode_controller.gd:508-519](game/modes/zombie/zombie_mode_controller.gd#L508-L519)).

Entrambi i percorsi consumano lo **stesso** `BiomeEnvironmentLayout`, quindi questa
differenza è legittima (1 cella vs 9 celle) e **non** è causa delle incoerenze
estetiche; va però tenuta presente perché qualsiasi modifica al layout deve
funzionare su entrambi i percorsi.

---

## 7. Tabella riassuntiva delle differenze

| Aspetto | Zombie Survival | Infinite Arena | Condiviso? |
|---|---|---|---|
| Entry mode | `SurvivalMode` | `InfiniteArenaMode`→`SurvivalMode` | Sì (stesso controller) |
| Mappa biomi | 3×3 multi-bioma | 1×1 (`infected_plains`) | Stesso generatore |
| Pipeline layout | void-first (starter) **+ legacy** (altri) | **solo** void-first | ❌ split per-bioma |
| Strade | hub+spokes (starter) **+ croce fissa legacy** | hub+spokes (croce a 4) | ❌ misto |
| Bordi esterni | `FALL` → cliff sul void | `BLOCKED` → muri | ❌ per `walled` |
| Void interno | Sì (lottery + blocchi) | No (soppresso) | ❌ per `walled` |
| Rendering cliff | `BiomeTileLayer`/`BiomeFallZone` | idem | ✅ |
| Streaming | multi-regione | single-region | ❌ (per design) |

---

## 8. Mappatura osservazioni → cause radice

1. **"Strade non coerenti / motore diverso"** → §2 (split pipeline per-bioma) + §3
   (legacy croce fissa vs void-first hub+spokes). Causa primaria:
   `biome_terrain_generator.gd:38`.
2. **"Cliff con void solo in Zombie Survival e non in Infinite Wave"** → §4B:
   `allow_internal_void = not _is_walled_arena_context` sopprime i burroni interni
   nell'arena murata.
3. **"Ci sono i cliff in Zombie Survival"** → §4A: i bordi esterni della survival
   sono `FALL` (default), mentre l'arena li forza a `BLOCKED`.

---

## 9. Raccomandazioni per unificare (obiettivo richiesto)

Obiettivo dichiarato: **stesso motore per tutto**; condividere strade, cliff e void;
le **uniche** differenze ammesse sono *generazione dei confini* e *numero di strade*
(Survival: solo verso biomi confinanti; Arena: 4 strade ai lati — comportamento già
implementato dal modello hub+spokes).

Interventi proposti, in ordine di impatto:

1. **Un solo motore di layout.** Instradare **tutti** i biomi su
   `populate_layout_voidfirst` rimuovendo il branch in
   [`biome_terrain_generator.gd:38-46`](game/procedural/world_generation/biome_terrain_generator.gd#L38-L46).
   Richiede di rendere void-first "biome-aware" per tag terreno/ostacoli per-bioma
   (oggi hardcoda asset tipo `large_rock`/`forest_tree`); la pipeline legacy resta
   come riferimento finché la void-first non copre i 4 biomi tematici.
2. **Disaccoppiare il void interno dalla modalità.** Far sì che la void lottery
   (`_resolve_void_lottery`) e i blocchi void **non** dipendano da
   `_is_walled_arena_context`, così i burroni interni compaiono anche nell'arena.
   → cliff/void diventano *condivisi*, come richiesto.
3. **Tenere il confine come unica leva esplicita.** Mantenere
   `arena_boundary_mode = "walled"` come scelta *del solo bordo* (muro vs
   precipizio), senza più usarlo per spegnere il void interno. Le strade restano
   guidate dagli spoke (passaggi vs muri), già differenziate correttamente.
4. **Decisione di design da confermare** (vedi sotto): nell'arena il *perimetro*
   deve restare murato o diventare anch'esso cliff-verso-il-void come in Survival?
   Da questa scelta dipende se il punto 3 va lasciato `walled` o cambiato.

> Nota: oggi i contratti/test e i documenti (`ARCHITECTURE.md`, `GAME_DESIGN.md`,
> `repo_fix_roadmap.md`) sanciscono esplicitamente "Infinite Arena = cella 500×500
> murata e senza fall zone interne". Qualsiasi unificazione va accompagnata
> dall'aggiornamento di quei contratti e dei test relativi
> (`tests/suites/environment/fall_test.gd`, `tests/suites/modes/zombie_modes_test.gd`,
> `tests/suites/assets/void_cliff_asset_test.gd`).

---

## 10. File chiave (indice)

| Ruolo | File |
|---|---|
| Entry Infinite Arena | [game/modes/survival/infinite_arena_mode.gd](game/modes/survival/infinite_arena_mode.gd) |
| Entry Survival | [game/modes/survival/survival_mode.gd](game/modes/survival/survival_mode.gd) |
| Orchestratore mondo | [game/modes/zombie/zombie_mode_controller.gd](game/modes/zombie/zombie_mode_controller.gd) |
| Manager biomi | [game/modes/zombie/biome_manager.gd](game/modes/zombie/biome_manager.gd) |
| Generatore mondo | [game/procedural/world_generation/biome_world_generator.gd](game/procedural/world_generation/biome_world_generator.gd) |
| Mappa/bordi/passaggi | [game/procedural/world_generation/biome_map_generator.gd](game/procedural/world_generation/biome_map_generator.gd) |
| Cella + tipi bordo | [game/procedural/world_generation/biome_cell.gd](game/procedural/world_generation/biome_cell.gd) |
| Selettore pipeline | [game/procedural/world_generation/biome_terrain_generator.gd](game/procedural/world_generation/biome_terrain_generator.gd) |
| **Layout (2 pipeline)** | [game/procedural/world_generation/obstacle_layout_generator.gd](game/procedural/world_generation/obstacle_layout_generator.gd) |
| Cliff perimetrali | [game/procedural/world_generation/fall_boundary_generator.gd](game/procedural/world_generation/fall_boundary_generator.gd) |
| Strade (passaggi) | [game/procedural/world_generation/biome_passage_generator.gd](game/procedural/world_generation/biome_passage_generator.gd) |
| Rendering cliff (ground) | [game/modes/zombie/biome_tile_layer.gd](game/modes/zombie/biome_tile_layer.gd) |
| Fall zone (fisica+bordo) | [game/modes/zombie/biome_fall_zone.gd](game/modes/zombie/biome_fall_zone.gd) |
| Renderer cliff (sprite) | [game/modes/zombie/isometric_cliff_renderer.gd](game/modes/zombie/isometric_cliff_renderer.gd) |
| Streaming regioni | [game/world/world_region_streamer.gd](game/world/world_region_streamer.gd) |
