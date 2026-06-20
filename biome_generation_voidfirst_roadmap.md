# Roadmap — Generazione biomi "void-first" (rocce → boschi → strade → void lottery)

Analisi e roadmap operativa per riscrivere la generazione del bioma secondo il
nuovo modello richiesto:

1. si parte da **void**;
2. prima si generano **≥10 rocce quadrate** di lato `15..30` celle (placeholder
   `large_rock`, nuova base `15x15`, asset adattato alla dimensione istanza);
3. poi i **boschi quadrati** di lato `9..60`, resi come riempimento di alberi a
   grandezza naturale; se un bosco copre una roccia, **vince la roccia** (l'albero
   non viene reso su quelle celle);
4. poi **strade e sentieri**: le strade attraversano i boschi ma **aggirano** le
   rocce; i sentieri attraversano i boschi ma **si fermano** alle rocce;
5. lungo le strade, dove non c'è già un confine, si aggiunge un **layer di alberi**;
6. il **void residuo** viene sorteggiato: resta void oppure diventa pavimento, con
   rapporto **1 burrone : 3 slot calpestabili**.

Data analisi: 2026-06-20. Bioma di riferimento: `infected_plains` (foresta base).

---

## 1. Stato attuale (audit)

Pipeline attuale in
[`ObstacleLayoutGenerator.populate_layout()`](game/procedural/world_generation/obstacle_layout_generator.gd#L70):

```
_add_roads                 # croce di 2 main road larghe 40 + passaggi
_add_biome_navigation_features  # 2 sentieri secondari larghi 20 (griglia fissa)
_add_internal_blocks       # taglia i rettangoli tra le strade in "blocchi"
_add_starter_water_crossing
_add_large_obstacles       # 1 ostacolo grande centrato per blocco
_add_secondary_obstacles
_add_starter_roadside_details
_add_connected_border_walls
_add_crates / _add_theme_hazards / _add_block_props
_ensure_starter_*          # garanzie su house/dense/3x3
```

Fatti rilevanti per la riscrittura:

- **Void è già la base.** [`BiomeEnvironmentLayout`](game/modes/zombie/biome_environment_layout.gd#L409-L439)
  riempie la classificazione con `TERRAIN_CODE_VOID` e marca walkable solo
  floor/road/passage/bridge. Il punto 1 è già soddisfatto a livello di modello.
- **Modello dati per scavare** (già presente): `floor_rects`/`floor_rect_tags`,
  `road_rects`/`road_cell_tags`, `obstacle_*`, `block_rects`/`block_kinds`,
  `fall_zone_rects` (= burroni/hazard di caduta), `wall_segment_*` (mura
  perimetrali), `passage_rects`. Le API `add_floor_rect`, `add_road_cell`,
  `add_fall_zone_rect`, `_add_obstacle` coprono tutte le primitive necessarie.
- **Contratto ostacoli rigido.** [`validate_obstacle_records()`](game/modes/zombie/biome_environment_layout.gd#L153-L165)
  impone `rect.size == manifest.footprint_tiles` (eccetto categoria `border`).
- **Sprite a dimensione fissa.** [`IsometricEnvironmentObject._position_asset_sprite()`](game/modes/zombie/isometric_environment_object.gd#L178-L227)
  scala lo sprite a `get_native_visual_size(obstacle_id)` (derivato dal footprint
  del manifest), **non** dalla dimensione dell'istanza: oggi un ostacolo non può
  variare di taglia per istanza.
- **Manifest** (`assets/environment/isometric/manifest.json`):
  - `large_rock`: `footprint_tiles 12x12`, `footprint_slots 3x3`,
    `collision rectangle`, `visual_height 8`.
  - `forest_tree`: `footprint_tiles 12x12`, `footprint_slots 3x3`,
    `collision rectangle` (footprint **intero bloccante**), `visual_height 18`.
  - `slot_size_cells = 4x4`, `logical_cell_world_pixels = 8`.
- **Streaming.** [`world_region_streamer._stream_obstacles()`](game/world/world_region_streamer.gd#L205-L248)
  istanzia un nodo per ostacolo da `obstacle_positions/sizes/ids`, **filtrando**
  per `biome.obstacle_ids.has(id)`: ogni id usato in generazione deve stare nella
  whitelist del bioma (oggi gestita da `BiomeManager._apply_generated_layouts`).
- **Validazione mappa.** `MapValidationSystem` tratta void, fall zone, ostacoli e
  acqua profonda come bloccati nel flood-fill: la connettività dei calpestabili va
  ri-verificata dopo la lottery del void.

---

## 2. Gap: requisito → stato → intervento

| # | Requisito | Stato attuale | Intervento |
|---|-----------|---------------|------------|
| 1 | Si parte da void | Già così a livello di modello | Rimuovere lo scavo "a blocchi" che riempie quasi tutto; tenere solo ciò che i passi 2–6 scavano |
| 2 | ≥10 rocce quadrate 15–30, asset adattato all'istanza | Rocce a footprint fisso 12x12, 1 sola garantita | Nuovo passo `_place_rocks`; rendere `large_rock` **scalabile** (base 15x15, sprite scalato a istanza) |
| 3 | Boschi quadrati 9–60 come fill di alberi; roccia vince | `dense_vegetation` = massa unica impassabile; albero a footprint fisso bloccante | Nuovo passo `_place_forests` con fill di `forest_tree`; interno **walkable**, tronchi piccoli; skip celle roccia |
| 4 | Strade aggirano rocce/attraversano boschi; sentieri si fermano alle rocce | Croce di strade fissa, nessun routing | Router su griglia (costi): rocce = bloccate, boschi = attraversabili; sentieri terminano a contatto roccia |
| 5 | Layer di alberi lungo le strade senza confine | Nessuno | Nuovo passo `_line_roads_with_trees` |
| 6 | Void residuo 1:3 burrone:calpestabile | Logica void/fall a blocchi diversa | Nuovo passo `_resolve_void_lottery` deterministico |

---

## 3. Decisioni architetturali (con raccomandazione)

1. **Rocce/alberi a footprint variabile.** Il blocco è il contratto
   `rect.size == footprint_tiles` + sprite a `get_native_visual_size`.
   *Raccomandato:* introdurre nel manifest un flag `scalable: true` (categoria
   `rock` e l'albero usato come fill). Per gli oggetti scalabili:
   - `validate_obstacle_records` salta il check `rect.size == footprint_tiles`
     (come già fa per `border`);
   - `_position_asset_sprite` scala lo sprite alla **dimensione istanza**
     (`obstacle_size`) invece che a `get_native_visual_size`;
   - `large_rock` ottiene un footprint base `15x15` (default per gli helper che
     leggono il manifest), pur potendo essere istanziato `15..30`.
   - *Nota:* `15` non è multiplo di `slot_size_cells (4)`. Gli oggetti scalabili
     vanno quindi **esentati dalla regola slot** (footprint libero), non incanalati
     nel modello a slot.

2. **Bosco = floor walkable + alberi a tronco piccolo.** Perché strade e sentieri
   possano attraversare i boschi e gli zombie navigarli, l'interno del bosco deve
   essere **calpestabile**; solo i tronchi bloccano.
   *Raccomandato:* l'albero-fill usa **collisione tronco piccola** (es. `2x2`/`3x3`
   celle) con **canopy visiva alta** (visual_height invariato). Il bosco aggiunge
   `add_floor_rect(forest_rect, &"forest_tall_grass")` e poi distribuisce alberi su
   griglia jitterata.

3. **Priorità roccia sul bosco.** Generare **rocce prima dei boschi**; il fill di
   alberi salta ogni cella coperta da una `rock_rect`. La roccia resta
   obstacle/void; nessun albero viene istanziato sopra.

4. **Budget istanze (performance).** Un bosco 60x60 riempito fitto può generare
   centinaia di alberi → un nodo ciascuno nello streaming. *Raccomandato:* spaziatura
   alberi ≈ footprint tronco (es. ogni `5..7` celle) con jitter, e **cap globale**
   alberi per chunk (es. `MAX_FOREST_TREES`), validato con il performance smoke test.
   Valutare in seguito un layer "canopy" bakeato a livello tile per le aree dense.

5. **Routing strade/sentieri.** Sostituire la croce fissa con un router su griglia
   (BFS/A* sulle celle logiche) con costi: rocce = muro, bosco = transitabile,
   void = transitabile (verrà poi scavato a road). I **sentieri** sono route a
   bassa larghezza che terminano appena la cella successiva è una roccia.

6. **Ambito biomi.** I requisiti sono a tema foresta. *Raccomandato:* implementare
   la nuova pipeline come **default** validandola su `infected_plains`; gli altri
   biomi riusano la stessa struttura con swap di asset (rocce/alberi a tema) in un
   follow-up. Mantenere intatti perimetro/passaggi/casse/spawn.

> Decisioni prese di default (modificabili): nuovo file roadmap dedicato anziché
> estendere `isometric_biome_generation_rewrite_roadmap.md`; pipeline nuova dietro
> ramo per `infected_plains`, vecchi passi a blocchi disattivati per quel bioma.

---

## 4. Roadmap a milestone

### M0 — Fondamenta: oggetti scalabili (abilitatore di rendering)
**Obiettivo:** rendere possibili rocce 15–30 adattate all'istanza e alberi-fill
con tronco piccolo, senza rompere gli altri ostacoli.

- Manifest: `large_rock` → `scalable: true`, footprint base `15x15`; nuovo id
  albero-fill (o `forest_tree` con `scalable: true` + `collision` tronco piccolo,
  `visual_height` alto).
- [`isometric_environment_manifest.gd`](game/modes/zombie/isometric_environment_manifest.gd):
  helper `is_scalable(id)`.
- [`biome_environment_layout.gd`](game/modes/zombie/biome_environment_layout.gd#L153-L165):
  `validate_obstacle_records` esenta gli scalabili dal check footprint.
- [`isometric_environment_object.gd`](game/modes/zombie/isometric_environment_object.gd#L178-L227):
  per gli scalabili scala lo sprite a `obstacle_size`.

**Accettazione:** un'istanza roccia 20x20 ha collisione 20x20 e sprite scalato e
seduto sul footprint; gli ostacoli non-scalabili invariati.
**Test:** nuovo `tests/scalable_obstacle_smoke_test.gd`; regressione
`isometric_environment_manifest_smoke_test.gd`, `obstacle_3x3_smoke_test.gd`.

### M1 — Rocce (void → ≥10 quadrati 15–30)
**Obiettivo:** primo passo della pipeline: piazzare ≥10 rocce quadrate, lato
`15..30`, non sovrapposte, deterministiche dal seed.

- Nuovo `_place_rocks(layout, rng)`: campiona lato `15..30`, posizione su area
  utile (dentro al perimetro, fuori dai corridoi dei passaggi), `MIN_RECT_GAP`
  fra rocce; registra ogni roccia come ostacolo scalabile `large_rock` e tiene una
  lista `rock_rects` sul layout.
- `populate_layout`: per `infected_plains` invoca `_place_rocks` al posto della
  catena `_add_internal_blocks`/`_add_large_obstacles`/`_add_secondary_obstacles`.

**Accettazione:** ≥10 rocce, tutte quadrate `15..30`, nessuna sovrapposizione,
classificazione completa, nessuna roccia sui passaggi.
**Test:** `tests/voidfirst_rocks_smoke_test.gd`.

### M2 — Boschi (quadrati 9–60, roccia vince)
**Obiettivo:** piazzare boschi quadrati `9..60` resi come fill di alberi; interno
walkable; nessun albero sopra le rocce.

- Nuovo `_place_forests(layout, rng)`: campiona quadrati `9..60`; per ciascuno
  `add_floor_rect(rect, &"forest_tall_grass")` e distribuisce `forest_tree` su
  griglia jitterata (passo ≈ footprint tronco) **saltando** le celle coperte da
  `rock_rects`; rispetta `MAX_FOREST_TREES`.
- Tiene `forest_rects` sul layout per i passi successivi (routing/bordo).

**Accettazione:** boschi quadrati `9..60`; zero alberi sovrapposti a `rock_rects`;
interno bosco walkable; conteggio alberi ≤ cap.
**Test:** `tests/voidfirst_forests_smoke_test.gd` (priorità roccia + walkability).

### M3 — Strade e sentieri (routing)
**Obiettivo:** strade che aggirano le rocce e attraversano i boschi; sentieri che
attraversano i boschi ma si fermano alle rocce.

- Router su griglia logica: costo `rock = bloccato`, `forest/void/floor =
  transitabile`. Strade principali edge-to-edge larghe `ROAD_WIDTH`; sentieri
  stretti (`SECONDARY_ROAD_WIDTH`/meno) che terminano alla cella roccia.
- Scava le celle route come walkable (`add_road_cell`/`add_road_rect`) e **rimuove
  gli alberi** sul corridoio stradale (strada attraverso bosco = corsia sgombra).
- Mantiene i passaggi inter-bioma esistenti come ancore del router.

**Accettazione:** nessuna cella strada interseca una `rock_rect`; le strade
connettono i bordi; un sentiero che incontra una roccia termina; gli alberi sul
tracciato strada sono rimossi.
**Test:** `tests/voidfirst_roads_smoke_test.gd` + regressione
`biome_world_generation_smoke_test.gd`.

### M4 — Bordo alberato lungo le strade
**Obiettivo:** lungo le strade, dove non c'è già un confine (roccia, bosco, muro
perimetrale, altra strada), aggiungere una fila di alberi.

- Nuovo `_line_roads_with_trees(layout, rng)`: per le celle adiacenti al bordo
  strada prive di confine, piazza alberi (tronco piccolo), senza invadere
  strada/roccia.

**Accettazione:** celle bordo-strada senza confine pre-esistente ricevono alberi;
nessun albero su strada o roccia; pathfinding strada intatto.
**Test:** `tests/voidfirst_road_border_smoke_test.gd`.

### M5 — Lotteria del void (1 burrone : 3 calpestabili)
**Obiettivo:** assegnare il void residuo a pavimento o burrone con rapporto 1:3.

- Nuovo `_resolve_void_lottery(layout, rng)`: itera le celle ancora `TERRAIN_VOID`
  (per regioni o a griglia di patch), assegna ~75% `add_floor_rect` e ~25%
  `add_fall_zone_rect`, in modo deterministico; mai burroni su strade/passaggi.

**Accettazione:** sul void residuo rapporto ≈ 1:3 (entro tolleranza); area
calpestabile principale connessa (flood-fill); nessun burrone su route/passaggi.
**Test:** `tests/voidfirst_void_lottery_smoke_test.gd` + `MapValidationSystem`.

### M6 — Integrazione, validazione, performance, cleanup
**Obiettivo:** cablare la pipeline, garantire connettività/spawn, performance e
ripulire i passi legacy non più usati per il bioma nuovo.

- `populate_layout` nuova sequenza (per `infected_plains`):
  `void → _place_rocks → _place_forests → roads/paths → _line_roads_with_trees →
  _resolve_void_lottery → perimetro/passaggi/casse/spawn`.
- Spawn player e casse su walkable; `MapValidationSystem` verde.
- Performance: `milestone_10_isometric_performance_smoke_test.gd` con il cap alberi.
- Rimuovere/segregare `_resolve_block_kind`, `_apply_block_surface`,
  `_add_internal_blocks` e simili dal percorso del bioma nuovo (tenuti per i biomi
  non ancora migrati).
- Aggiornare `docs/obstacle_rendering.md` e `docs/testing/manual_checklist.md`.

**Accettazione:** run streaming giocabile su `infected_plains` con i 6 criteri;
suite smoke verde; performance entro budget.

---

## 5. Rischi e note

- **Esplosione istanze alberi**: il rischio #1. Tenere cap + spaziatura; valutare
  canopy bakeata a tile per le aree dense (oggi `terrain_patch` NON è reso nello
  streaming survival — verificare prima di puntarci).
- **Connettività dopo la lottery**: i burroni 1:3 possono isolare aree. La lottery
  deve girare dopo le strade e preservare un cammino tra i passaggi; validare con
  flood-fill.
- **Footprint non-slot (15..30)**: rompe l'assunzione `footprint = slots *
  slot_size`. Confinare gli scalabili fuori dal modello a slot.
- **Whitelist bioma**: ogni id usato deve finire in `biome.obstacle_ids`
  (`BiomeManager._apply_generated_layouts`) o lo streamer lo scarta.
- **Asset placeholder**: `large_rock` e `forest_tree` sono PNG generati con base
  3x3; con la base roccia a 15x15 e lo scaling per-istanza vanno riverificati
  anchor/seating su footprint grandi.
- **Test pre-esistente rosso**: `zombie_biome_transition_smoke_test.gd` (FAIL 15)
  già rotto prima di questo lavoro (conteggi single-region vs streaming).
