# Report Tecnico & Roadmap — 2026-06-19

> Analisi dello stato della repo `Iso Local Sandbox` (Godot 4.6, GDScript).
> Obiettivo: evidenziare criticità, duplicazioni di codice/responsabilità e debito
> tecnico, con una roadmap prioritizzata di rientro.

## 1. Sintesi esecutiva

Il progetto è ampio e sorprendentemente disciplinato per essere un prototipo:
~251 script `.gd`, ~57k LOC, `class_name` su 147/251 file, contratti di sistema
documentati in dettaglio in [ARCHITECTURE.md](../ARCHITECTURE.md), e una buona
separazione "logica vs. visual" già esplicitata nei contratti. **Non** è un
codebase in stato di abbandono.

Le criticità non sono quindi "bug evidenti" ma **debito strutturale che cresce
con la scala**:

1. **Service locator pervasivo** (`get_first_node_in_group` usato 581 volte) — le
   dipendenze tra sistemi sono implicite, runtime e non verificabili a compile-time.
2. **God classes** — alcuni file superano 1000–1600 LOC con 50–88 funzioni.
3. **Macchine a stati "stringly-typed" e duplicate** tra le modalità.
4. **Nessun modulo di utility condivisa** — query ricorrenti (player vivi/downed,
   nearest player) reimplementate in 24+ punti.
5. **Nessuna CI**: 102 file di test esistono ma non c'è automazione che li esegua.
6. **Debito "fallback/legacy" accumulato** (241 occorrenze `fallback`, 60 `legacy`):
   percorsi tecnici mantenuti in parallelo a quelli attivi, soprattutto nel
   sottosistema zombie/biome.

## 2. Metriche di base

| Metrica | Valore |
|---|---|
| Script `.gd` | 251 |
| Scene `.tscn` | 20 |
| LOC totali `.gd` | ~57.700 |
| File test | 102 (in `tests/`, ~18.800 LOC) |
| `class_name` dichiarati | 147 |
| `get_first_node_in_group(...)` | 581 chiamate, 108 file |
| Guard `if x == null:` | 683 |
| Occorrenze `fallback` / `legacy` | 241 / 60 |
| `print/push_warning/push_error` | 422 |
| File `.import` versionati | 167 |
| Autoload / singleton | **0** (tutto in `main.tscn`) |
| CI workflow | **assente** |

### Concentrazione del codice (hotspot)

| LOC | File | Funzioni |
|---|---|---|
| 1591 | `game/procedural/world_generation/obstacle_layout_generator.gd` | 73 |
| 1400 | `game/ui/main_menu.gd` | 88 |
| 1190 | `game/modes/zombie/biome_obstacle.gd` | 56 |
| 1152 | `game/modes/zombie/isometric_tile_resolver.gd` | 54 |
| 1057 | `game/modes/zombie/isometric_svg_texture_loader.gd` | — |
| 780 | `game/ui/hud_manager.gd` | 39 |
| 765 | `game/modes/zombie/random_encounter_system.gd` | — |
| 699 | `game/modes/zombie/hazard_system.gd` | 46 |

Il sottosistema `game/modes/zombie/` da solo è ~11.400 LOC: è il centro di gravità
(e di rischio) del progetto.

## 3. Criticità architetturali

### 3.1 Service locator come unico meccanismo di dependency resolution — ALTA
581 chiamate a `get_first_node_in_group("...")` con string-key (`"wave_manager"`,
`"health_system"`, `"enemy_system"` …). Conseguenze:

- **Dipendenze invisibili**: per sapere cosa serve a un sistema bisogna leggerne
  il corpo; non c'è firma o costruttore che lo dichiari.
- **Fragilità runtime**: ogni lookup può restituire `null` → 683 guard `if x == null`
  sparse, in gran parte difensive contro questo stesso pattern.
- **Refactor rischioso**: rinominare un gruppo è un find/replace su stringhe non
  tipizzate; un typo non è rilevato dal compilatore.
- **Testabilità**: impossibile iniettare un doppio/mock senza montare l'intera
  `main.tscn` (infatti i test caricano la scena completa).

Non esistono autoload: tutti i ~45 sistemi vivono come nodi in `main.tscn` e si
trovano per gruppo. La scena principale è di fatto un grosso "container di
servizi" implicito.

### 3.2 God classes / Single Responsibility violata — ALTA
- `main_menu.gd` (1400 LOC, 88 funzioni): menu + character select + navigazione
  grid + gestione slot + binding context survival. Sono almeno 3–4 responsabilità.
- `obstacle_layout_generator.gd` (1591 LOC): strade, sentieri, case, vegetazione,
  fiumi/bridge, muri/bordi in un unico generatore.
- `biome_obstacle.gd` (1190): ormai descritto come "fallback tecnico", ma ancora
  enorme (collisione + draw mode + footprint + 56 funzioni).
- `isometric_tile_resolver.gd` (1152) e `isometric_svg_texture_loader.gd` (1057):
  resolver tile e loader SVG con responsabilità di rasterizzazione, fallback
  silhouette e import editor mescolate.

### 3.3 FSM "stringly-typed" e duplicate — MEDIA
`wave_manager.gd` e `tower_defense_wave_controller.gd` implementano **la stessa**
macchina a stati (`"intermission"` → `"spawning"` → `"combat"` → `"reward"`/boss)
con `state` come `StringName` non tipizzata e `match` su stringhe. Problemi:
- Stati validi non enumerati → typo silenziosi, nessun controllo esaustività.
- Logica di intermission/spawn/combat/reward duplicata tra i due controller
  (~715 LOC combinate) invece di una base FSM condivisa.

Per contrasto, `basic_enemy`, `player_controller`, `melee_attack`, `briciola_companion`
usano correttamente `enum State` — la convenzione esiste ma non è applicata in modo
uniforme.

### 3.4 Assenza di CI / automazione test — ALTA
102 test (`tests/*.gd`, sia `SceneTree` headless sia smoke che montano `main.tscn`)
ma nessun `.github/workflows`, nessuno script unico di esecuzione della suite.
L'unico hook git installato auto-staga i file `.import`. Una suite così ricca senza
gate automatico significa che le regressioni vengono scoperte tardi.

### 3.5 Costanti non centralizzate / magic number — MEDIA
`game/core/game_constants.gd` esiste ma contiene solo 11 costanti (cap player, drop
keys, mode ids). Valori di bilanciamento, durate, raggi, scale tile (40/20 celle),
collision-layer bit, ecc. sono hardcoded nei singoli sistemi e nei contratti
testuali di ARCHITECTURE.md, non in un punto unico tipizzato. I collision layer
(1/2/4/8/16/32) sono documentati a parole ma non esistono come costanti nominate.

### 3.6 Logging non strutturato — BASSA
422 `print/push_warning/push_error` senza un wrapper/logger con livelli o
toggle. In un progetto con percorsi fallback estesi questo rende rumoroso il debug
e impossibile silenziare per categoria.

## 4. Duplicazione di codice e responsabilità

### 4.1 Query "player" reimplementate ovunque — ALTA
Non esiste alcun modulo `utils/helper/common/service` (verificato: zero file).
Di conseguenza il pattern "itera i player, prendi `HealthComponent`, filtra per
vivo/downed" è copiato in **24+ punti** (`revive_system`, `survival_ammo_director`,
`zombie_spawner`, `hud_manager`, `wave_manager`, …):

```gdscript
for player in get_tree().get_nodes_in_group("players"):
    var hc := player.get_node_or_null("HealthComponent") as HealthComponent
    if hc == null or not hc.is_downed: # oppure is_alive / is_dead
        continue
    ...
```

Manca un `PlayerQuery` / `PartyService` con `get_alive_players()`,
`get_downed_players()`, `get_nearest_player(pos)`.

### 4.2 "Nearest/closest player" duplicato — MEDIA
Implementazioni indipendenti di "trova il player più vicino":
`zombie_spawner._distance_squared_to_nearest_player`,
`random_encounter_system._find_player_anchor`,
`rpg_super_resolver._find_nearest_target`,
più la logica di targeting in `basic_enemy`. Stessa responsabilità, 4 copie.

### 4.3 Doppia macchina a stati wave (vedi 3.3) — MEDIA
`WaveManager` e `TowerDefenseWaveController` sono due implementazioni della stessa
responsabilità "orchestratore di ondate". `wave_director.gd` è invece il
roster/scaling: la divisione corretta sarebbe una FSM wave condivisa + provider
di roster per modalità.

### 4.4 Percorsi "fallback/legacy" paralleli nel sottosistema zombie — MEDIA
ARCHITECTURE.md documenta esplicitamente molte classi come "fallback tecnico"
mantenute accanto al percorso attivo asset-driven: `MultiRegionRenderer`,
`BiomeRegionGround`, `BiomeTerrainPatch`, `BiomeObstacle`, `BiomeTransitionGate`,
`BiomeTransitionSystem`. È debito intenzionale e tracciato — ma è **doppia
manutenzione**: ogni modifica al percorso asset-driven rischia di divergere dal
fallback, e i test devono coprire entrambi.

## 5. Altri miglioramenti

- **`.import` versionati (167 file)**: generati dall'editor, causano churn e
  conflitti di merge. Valutare `.gitignore` + rigenerazione in CI/hook (esiste già
  un hook che li auto-staga — segnale che il problema è sentito).
- **Documentazione vs. codice**: ARCHITECTURE.md è eccellente ma è di fatto una
  *spec narrativa di 839 righe*. Rischio di drift rispetto al codice; conviene
  spostare i contratti verificabili (collision layer, stati, costanti) in codice e
  lasciare al doc la sola visione.
- **Mancano README di esecuzione test**: il meccanismo (`--build-smoke`, test
  `SceneTree` headless) va documentato in CONTRIBUTING.
- **Naming bilingue**: identificatori inglesi + commenti/doc italiani. Coerente
  internamente, ma da fissare come convenzione esplicita.

## 6. Roadmap di rientro

Prioritizzata per **rapporto valore/rischio**. Le fasi 0–1 abilitano in sicurezza
tutte le successive.

### Fase 0 — Rete di sicurezza (1–2 giorni) · prerequisito
- [ ] Aggiungere CI (GitHub Actions o equivalente) che esegue la suite `tests/`
      headless con Godot in modalità `--headless`/`SceneTree`. **Gate su PR.**
- [ ] Script unico `run_tests.ps1`/`.sh` che scopre ed esegue tutti i test e
      ritorna exit-code aggregato. Documentarlo in CONTRIBUTING.
- [ ] Decidere policy sui `.import` (ignore + rigenerazione) per ridurre churn.

### Fase 1 — Fondamenta condivise (2–4 giorni) · alto valore, basso rischio
- [ ] Creare `game/core/party_service.gd` (`PlayerQuery`): `get_alive_players()`,
      `get_downed_players()`, `get_nearest_player(pos)`. Migrare i 24+ call site
      uno alla volta, ognuno coperto da test.
- [ ] Estendere `GameConstants` con collision-layer bit nominati, scale tile,
      durate/raggi di bilanciamento ricorrenti. Sostituire i magic number.
- [ ] Introdurre un `Log` wrapper minimale con livelli + categoria; sostituire i
      `print` di debug nei sistemi core.

### Fase 2 — Tipizzazione e de-duplica FSM (3–5 giorni)
- [ ] Convertire le FSM wave a `enum` tipizzato.
- [ ] Estrarre una `WaveStateMachine` base condivisa; far derivare
      `WaveManager` e `TowerDefenseWaveController` (roster via provider).
- [ ] Unificare la logica "nearest player" nel `PartyService` (rimuove 4 copie).

### Fase 3 — Riduzione dei service locator (incrementale, in corso)
- [ ] Introdurre un `SystemRegistry` (autoload unico) con accessor **tipizzati**
      (`SystemRegistry.health_system`) che incapsula i lookup di gruppo.
- [ ] Migrare i sistemi più "richiesti" per primi (`wave_manager`,
      `health_system`, `enemy_system`, `game_mode_manager`).
- [ ] Obiettivo: azzerare i `get_first_node_in_group` con string-literal nel
      codice gameplay, mantenendoli solo dietro il registry. Misurare con il
      conteggio (581 → target progressivo).

### Fase 4 — Scomposizione god classes (per file, opportunistica)
- [ ] `main_menu.gd` → separare `CharacterSelectController` e
      `MenuContextBuilder` dal menu vero e proprio.
- [ ] `obstacle_layout_generator.gd` → suddividere per feature (roads/sentieri,
      strutture, idrografia, bordi) in generatori componibili.
- [ ] `isometric_svg_texture_loader.gd` → separare rasterizzazione, import editor
      e fallback silhouette.
- Regola operativa: niente nuovi file >600 LOC; scomporre quando si tocca.

### Fase 5 — Ritiro del debito fallback/legacy zombie (quando il path asset-driven è stabile)
- [ ] Definire criteri di "asset-driven stabile" (coperto da test, nessun fallback
      attivato in run normale).
- [ ] Marcare i fallback con `@deprecated`/commento datato e piano di rimozione.
- [ ] Rimuovere `MultiRegionRenderer`, `BiomeRegionGround`, `BiomeTerrainPatch`,
      `BiomeTransitionGate` quando i rispettivi test sul path attivo sono verdi.

### Trasversale — Governance
- [ ] Spostare i contratti *verificabili* da ARCHITECTURE.md a codice/test;
      lasciare al doc la visione e i contratti non codificabili.
- [ ] Aggiungere un linter/format check (gdformat/gdlint) al gate CI.

## 7. Quick wins (≤ mezza giornata ciascuno)
1. Script unico esecuzione test + job CI minimale.
2. `PartyService.get_alive_players()` e migrazione dei 3–4 call site più caldi.
3. Costanti collision-layer nominate in `GameConstants`.
4. `enum` per gli stati wave (anche senza unificare le due FSM).
