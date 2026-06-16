# Roadmap — Megamappa Persistente Isometrica

## Stato implementazione

Prima versione completata nel repository:

- `game/world/` contiene il modello dati e runtime per grafo, regioni, connessioni, esplorazione e stato persistente.
- `BiomeMapGenerator` genera una megamappa `5x5` di territori `200x200` tramite seed, spanning tree ed edge extra, con grafo sempre connesso.
- `BiomeTransitionSystem` usa passaggi fisici aperti tra regioni confinanti e non teletrasporta il party nel flusso standard.
- I lati senza regione vicina restano fall boundary; i lati con regione non connessa sono bloccati fisicamente.
- `BiomeEnvironmentLayout` classifica l'intera area `200x200` in walkable, obstacle, hazard, border, void e fall zone.
- `SaveManager` usa save v6 e conserva lo stato mondo/esplorazione tramite `PersistentWorldState`.
- `HUDManager` espone una mappa esplorazione consultabile con input `M` o joypad `Back/Select/View`.
- `PlayerDodgeComponent` aggiunge dodge/roll con cooldown, invulnerabilita breve e validazione per piccoli gap.
- `assets/environment/isometric/manifest.json` censisce il primo set di placeholder/asset ambientali da sostituire.
- Gli smoke test dedicati della Milestone 10 sono stati aggiunti e verificati headless.

## Obiettivo

Trasformare l’attuale generazione a biomi/stanze/portali in una **megamappa persistente isometrica** composta da territori `200x200`, collegati da una topologia a grafo completamente connesso. I giocatori devono attraversare fisicamente i passaggi tra biomi senza portali/teletrasporti, consultare la mappa dei territori esplorati, vedere chiaramente le zone di caduta e usare un nuovo comando di dodge/roll anche per saltare piccoli gap tra piattaforme.

## Stato attuale da cui partire

La repo ha già una base utile:

- generazione biomi seed-based;
- celle bioma `200x200`;
- `WorldGenerationSeed`;
- `BiomeWorldGenerator`;
- `BiomeMapGenerator`;
- `BorderGenerator`;
- `BiomePassageGenerator`;
- `BiomeTerrainGenerator`;
- `ObstacleLayoutGenerator`;
- `FallBoundaryGenerator`;
- `MapValidationSystem`;
- smoke test per generazione biomi, ostacoli, encounter e debug overlay.

Il problema attuale è che la logica va ancora trattata come insieme di mappe/stanze/biomi separati. La nuova direzione deve essere una mappa continua, persistente, isometrica e consultabile.

---

# Milestone 1 — Contratto dati della megamappa

## Obiettivo

Creare un modello dati unico per rappresentare territori, biomi, connessioni, stato esplorazione e stato persistente.

## File/sistemi da creare o estendere

```text
game/world/
  world_graph.gd
  world_region.gd
  world_region_connection.gd
  world_exploration_state.gd
  persistent_world_state.gd
```

## Ogni territorio deve contenere

```gdscript
region_id
biome_id
grid_position
world_origin
size_tiles = Vector2i(200, 200)
neighbors = { north, east, south, west }
connection_edges = []
generated_layout
exploration_state
discovered_cells
visited
cleared
```

## Regola fondamentale

La topologia deve essere un grafo completamente connesso in senso navigazionale: da ogni territorio raggiungibile deve esistere almeno un percorso verso ogni altro territorio della megamappa. Non serve che ogni nodo sia collegato direttamente a tutti gli altri; serve che non esistano regioni isolate.

## Criteri di accettazione

- Con lo stesso seed, la megamappa generata è identica.
- Ogni territorio ha coordinate globali stabili.
- Tutti i territori sono raggiungibili dallo start.
- Ogni edge logico del grafo corrisponde a un passaggio fisico nel mondo.
- Non esistono regioni isolate.

## Test

```text
tests/world_graph_connectivity_smoke_test.gd
tests/persistent_world_generation_smoke_test.gd
```

---

# Milestone 2 — Generatore topologico a grafo connesso

## Obiettivo

Sostituire la progressione lineare o a portali con una topologia di territori collegati.

## Algoritmo consigliato

1. Generare una griglia logica di regioni, per esempio `5x5` o `7x7`.
2. Scegliere una regione iniziale.
3. Generare uno spanning tree per garantire connessione minima.
4. Aggiungere edge extra per creare loop, scorciatoie e percorsi alternativi.
5. Assegnare biomi per cluster: pianura infetta vicino allo start, poi tossico, fuoco, neve, palude, ecc.
6. Per ogni edge creare un `WorldRegionConnection` con lato, centro, larghezza, tipo passaggio e coordinate globali.

## Esempio concettuale

```text
[Plains]---[Plains]---[Toxic]
   |          |           |
[Ruins]---[Marsh]---[Fire]
   |                      |
[Frozen]---[Frozen]---[Boss Land]
```

## Criteri di accettazione

- Nessun territorio isolato.
- Ogni connessione ha un passaggio fisico su entrambi i lati.
- I passaggi tra due regioni combaciano perfettamente.
- I lati senza vicino diventano fall boundary, non muri invisibili.

---

# Milestone 3 — Passaggi aperti al posto dei portali

## Obiettivo

Eliminare il feeling da stanza chiusa con portale e trasformare il passaggio tra biomi in una transizione fisica e continua.

## Da rimuovere o ridurre

```text
- Portali verdi di cambio stanza.
- Teletrasporto tra mappe.
- Gate come unico modo di avanzare.
- Cambio bioma percepito come cambio livello.
```

## Da introdurre

```text
- Aperture fisiche ai bordi del bioma.
- Corridoi naturali tra regioni.
- Strade, ponti, rampe, passerelle e varchi.
- Aggiornamento della regione corrente quando il party attraversa la soglia.
```

## Regola gameplay

Il cambio territorio deve essere invisibile. Quando i player attraversano il bordo tra bioma A e bioma B, la camera continua a seguirli e il mondo sembra una singola mappa continua.

## Criteri di accettazione

- Se due territori confinano, il bordo contiene una o più aperture attraversabili.
- Se non confinano, il bordo mostra chiaramente vuoto/caduta.
- I player non vengono teletrasportati.
- Il sistema aggiorna `current_region_id` in base alla posizione globale.

---

# Milestone 4 — Streaming o istanziazione controllata della megamappa

## Obiettivo

Evitare di istanziare tutta la megamappa contemporaneamente e mantenere buone performance.

## Soluzione consigliata

```text
- Regione corrente sempre attiva.
- Regioni vicine N/E/S/W precaricate.
- Regioni lontane conservate come dati, non come nodi renderizzati.
- Stato runtime salvato per region_id.
```

## Sistema suggerito

```text
WorldRuntime
  active_regions: Dictionary
  loaded_region_radius = 1
  current_party_region
  spawn_region(region_id)
  unload_region(region_id)
  save_region_runtime_state(region_id)
```

## Stato persistente minimo

```text
- casse aperte
- boss uccisi
- encounter completati
- ostacoli distrutti
- territori scoperti
- celle viste nella mappa
- posizione party
- risorse permanenti della run
```

## Criteri di accettazione

- Entrando e uscendo da una regione, gli oggetti già raccolti non ricompaiono.
- Il seed rigenera il layout, ma lo stato runtime viene sovrapposto dal save.
- Le regioni lontane non restano istanziate inutilmente.
- La performance non degrada con mappe grandi.

---

# Milestone 5 — Terreno isometrico esteso a tutto il bioma 200x200

## Obiettivo

Il terreno calpestabile non deve essere un semplice patch centrale. Tutta la regione `200x200` deve avere una classificazione visuale e di gameplay: camminabile, ostacolo, hazard, bordo, vuoto o caduta.

## Sistemi da creare o estendere

```text
BiomeTerrainRenderer
IsoTilePainter
TerrainLayer
WalkableMask
FallMask
```

## Ogni bioma deve generare

```text
- base terrain su tutta l’area 200x200
- varianti tile isometriche
- strade/corridoi isometrici
- bordi visivi
- maschera calpestabile
- maschera caduta
- decorazioni coerenti con il tema
```

## Regola chiave

Tutto il `200x200` deve avere identità visiva. Non deve più esistere uno sfondo generico piatto con solo una zona centrale disegnata.

## Esempi per bioma

### Pianura infetta

- asfalto rotto;
- erba contaminata;
- case diroccate isometriche;
- marciapiedi e strade diagonali.

### Tossico

- terreno verde/grigio;
- tubi isometrici;
- cisterne;
- pozze tossiche con bordo leggibile.

### Fuoco

- terra bruciata;
- crepe incandescenti;
- lava/fiamme leggibili;
- auto carbonizzate.

### Neve

- neve battuta;
- ghiaccio;
- rocce ghiacciate;
- scarpate innevate.

### Palude

- passerelle;
- fango;
- radici;
- acqua stagnante non calpestabile.

---

# Milestone 6 — Caduta leggibile in visuale isometrica

## Obiettivo

Le zone dove si cade devono essere immediatamente leggibili. Il player deve capire visivamente che oltre quel bordo non c’è terreno.

## Da evitare

```text
- Bordo nero piatto.
- Area invisibile di morte.
- Fuori mappa non comunicato.
- Collisione non allineata al visual.
```

## Da creare

```text
IsoFallBoundaryRenderer
IsoCliffEdge
VoidDepthLayer
FallWarningMask
```

## Visual consigliato

```text
- bordo del terreno con spessore verticale isometrico
- lato/scarpata più scuro
- ombra sotto la piattaforma
- vuoto/parallax sotto
- piccoli detriti sul bordo
- edge highlight solo in debug o accessibilità
```

## Gameplay

```text
- Camminare oltre il bordo attiva fall.
- Dodge/roll può attraversare piccoli gap validi.
- Nemici base evitano fall zone.
- Alcuni nemici speciali possono saltare o emergere in futuro.
```

## Criteri di accettazione

- Il giocatore capisce chiaramente che oltre il bordo si cade.
- Il bordo segue la prospettiva isometrica.
- Collisione e visual sono allineati.
- La validazione controlla che spawn/casse/passaggi non siano in fall zone.

---

# Milestone 7 — Sostituzione ostacoli e oggetti non isometrici

## Obiettivo

Eliminare placeholder frontali/piatti e sostituirli con oggetti coerenti con la visuale isometrica.

## Cartelle consigliate

```text
assets/environment/isometric/
  obstacles/
  props/
  crates/
  hazards/
  cliffs/
  bridges/
  terrain/
```

## Categorie da convertire

```text
- case
- muretti
- auto
- casse
- barili
- rocce
- alberi
- tubi
- cisterne
- pozze
- ponti
- passerelle
- slot/interazioni
- hazard
- supply crate
```

## Ogni oggetto deve avere

```text
visual_scene
collision_shape
shadow
sort_offset
footprint_tiles
blocks_movement
blocks_projectiles
is_jumpable_gap_anchor
```

## Criteri di accettazione

- Nessun ostacolo importante resta non-isometrico.
- Ogni oggetto ha footprint coerente con collisione.
- Lo sorting Y/isometrico è corretto.
- Gli oggetti grandi creano corridoi leggibili, non muri casuali.

---

# Milestone 8 — Mappa dei territori esplorati

## Obiettivo

Il player può aprire una mappa e vedere solo i territori scoperti o visitati.

## Input consigliato

```text
Tastiera: M
Joypad: Back/Select/View
```

## UI suggerita

```text
ExplorationMapPanel
  world graph view
  current region marker
  discovered regions
  visited regions
  cleared regions
  unknown fog
  biome colors/icons
  passaggi scoperti
```

## Stati territorio

```text
unknown
discovered
visited
cleared
danger
boss
shop/future
```

## Logica

```text
- Entrare in una regione la marca visited.
- Avvicinarsi a un passaggio marca il vicino discovered.
- Completare encounter/boss marca cleared.
- La mappa mostra il grafo e non necessariamente la geometria precisa 200x200.
```

## Criteri di accettazione

- La mappa non rivela tutto subito.
- Mostra chiaramente la posizione del party.
- Mostra i collegamenti già scoperti.
- Lo stato mappa è persistente su save/load.

---

# Milestone 9 — Dodge/Roll con salto tra piattaforme

## Obiettivo

Aggiungere un pulsante di dodge/roll utile sia in combat sia per attraversare piccoli gap tra piattaforme.

## Input consigliato

```text
Tastiera: Shift oppure Ctrl
Joypad: B / Circle
```

## Sistema suggerito

```text
PlayerDodgeComponent
  dodge_distance
  dodge_duration
  invulnerability_window
  cooldown
  can_cross_gap
  max_gap_cross_distance
  landing_validation
```

## Regole gameplay

```text
- Roll su terreno: schivata rapida.
- Roll su gap valido: salto breve tra due piattaforme.
- Roll verso vuoto non valido: roll ridotto, blocco input o caduta, da decidere in fase di tuning.
- Durante roll, il player non spara e non usa melee salvo eccezioni future.
- Invulnerabilità breve solo nella parte centrale del roll.
```

## Validazione prima del roll

```text
- Calcolare landing point.
- Verificare che landing point sia walkable.
- Verificare che la traiettoria attraversi gap consentito.
- Verificare che non attraversi muri/ostacoli solidi.
- Se landing non valida, negare input o fare roll ridotto.
```

## Criteri di accettazione

- Il player può saltare gap piccoli tra due piattaforme.
- Non può attraversare muri.
- Non può uscire dalla mappa con roll infinito.
- Il roll è leggibile con animazione, scia e cooldown HUD.
- Funziona in multiplayer locale per ogni player.

---

# Milestone 10 — Validazione automatica della megamappa

## Obiettivo

Estendere `MapValidationSystem` per prevenire mappe impossibili, regioni isolate, passaggi ostruiti e fall zone ambigue.

## Controlli richiesti

```text
- grafo completamente connesso
- passaggi fisici combacianti tra regioni confinanti
- nessun passaggio ostruito da ostacoli
- ogni regione ha almeno un’area spawn valida
- ogni regione ha corridoi navigabili
- fall boundary solo sui lati senza vicino
- terreno 200x200 completamente classificato
- dodge gap con distanza entro limite e landing valida
- mappa esplorazione aggiornata correttamente
```

## Test consigliati

```text
godot --headless --path . --script res://tests/world_graph_connectivity_smoke_test.gd
godot --headless --path . --script res://tests/persistent_world_generation_smoke_test.gd
godot --headless --path . --script res://tests/open_passage_transition_smoke_test.gd
godot --headless --path . --script res://tests/isometric_biome_terrain_coverage_smoke_test.gd
godot --headless --path . --script res://tests/fall_boundary_visual_logic_smoke_test.gd
godot --headless --path . --script res://tests/player_dodge_gap_smoke_test.gd
godot --headless --path . --script res://tests/exploration_map_smoke_test.gd
```

---

# Priorità consigliata

```text
1. World graph persistente
2. Passaggi aperti al posto dei portali
3. Streaming regioni 200x200
4. Terreno isometrico completo
5. Fall boundary isometrico
6. Conversione oggetti/ostacoli
7. Mappa esplorazione
8. Dodge/roll + gap traversal
9. Validazione completa e smoke test
```

---

# Prompt Codex — Modalità Goal

```text
Analizza lo stato attuale della repository Godot `GameProject`, in particolare i sistemi di generazione bioma/zombie survival, dungeon, world generation, obstacle layout, fall boundary, transition/passages, player controller, input manager, HUD, minimap/map UI e save system.

Obiettivo generale: implementare una prima versione funzionante della roadmap “Megamappa Persistente Isometrica”, trasformando l’attuale generazione a biomi/stanze/portali in una megamappa persistente composta da territori isometrici 200x200 collegati da passaggi fisici aperti.

Requisiti principali:

1. La megamappa deve essere seed-based e persistente.
2. Ogni territorio/bioma deve essere una regione 200x200.
3. La topologia deve essere un grafo completamente connesso: da ogni regione deve esistere almeno un percorso verso ogni altra regione.
4. I passaggi tra territori confinanti non devono essere portali o teletrasporti: devono essere aperture fisiche, visibili e attraversabili dai player.
5. I lati senza territorio confinante devono essere fall boundary: zone di caduta chiaramente leggibili in visuale isometrica.
6. Il terreno calpestabile deve estendersi a tutto il bioma 200x200, non solo al centro.
7. Tutto il 200x200 deve essere classificato come terreno calpestabile, ostacolo, hazard, bordo, vuoto o fall zone.
8. Gli ostacoli e gli oggetti non isometrici devono essere censiti e progressivamente sostituiti con versioni isometriche, con collisioni, footprint e sorting coerenti.
9. Va aggiunta una mappa consultabile dei territori esplorati, con unknown/fog, regioni scoperte, regioni visitate, regioni ripulite e posizione attuale del party.
10. Va aggiunto un pulsante di dodge/roll per ogni player, con input tastiera e joypad, cooldown, breve invulnerabilità e possibilità di attraversare piccoli gap tra piattaforme quando landing e traiettoria sono valide.
11. Non rompere survival, dungeon, tower defense, RPG, multiplayer locale e smoke test esistenti.

Procedura richiesta:

1. Fai audit dei file esistenti e scrivi un breve piano tecnico prima di modificare.
2. Crea o estendi i sistemi dati per `WorldGraph`, `WorldRegion`, `WorldRegionConnection`, `PersistentWorldState` ed `ExplorationState`.
3. Integra il generatore esistente di biomi 200x200 nel nuovo grafo persistente, riusando il più possibile `WorldGenerationSeed`, `BiomeWorldGenerator`, `BiomeMapGenerator`, `BiomePassageGenerator`, `FallBoundaryGenerator`, `ObstacleLayoutGenerator` e `MapValidationSystem`.
4. Implementa una generazione topologica con spanning tree più edge extra, così il grafo è sempre connesso ma ha anche loop e percorsi alternativi.
5. Sostituisci la logica di portale/teletrasporto con passaggi fisici aperti tra regioni confinanti.
6. Implementa fall boundary isometrici sui lati senza vicino, con visual leggibile e collisione allineata.
7. Estendi la generazione del terreno in modo che tutto il bioma 200x200 abbia tile/visual/maschera coerenti, non solo la zona centrale.
8. Aggiungi un primo sistema di mappa esplorazione consultabile da input tastiera/joypad.
9. Aggiungi un primo `PlayerDodgeComponent` o equivalente, integrato con `PlayerController` e `InputManager`, con supporto a roll normale e attraversamento di gap piccoli validati.
10. Aggiorna o crea smoke test headless per:
    - connettività del grafo;
    - coerenza dei passaggi tra regioni;
    - assenza di passaggi ostruiti;
    - classificazione completa del terreno 200x200;
    - fall boundary sui lati senza vicino;
    - persistenza dello stato esplorazione;
    - dodge/roll e gap traversal;
    - regressioni survival/dungeon/RPG.
11. Aggiorna README, CHANGELOG, TODO e/o documentazione tecnica con stato della milestone e comandi test.
12. Esegui i test Godot headless disponibili. Se Godot non è disponibile nell’ambiente, documenta chiaramente quali test non sono stati eseguiti e lascia i comandi pronti.

Criteri di accettazione:

- Con seed fisso, la megamappa viene rigenerata identica.
- Tutte le regioni sono raggiungibili.
- I passaggi tra regioni sono fisici, aperti e attraversabili.
- I bordi senza vicino sono fall boundary leggibili e validati.
- Il bioma 200x200 ha terreno/visual/maschere su tutta l’area.
- Lo stato esplorazione può essere salvato e ricaricato.
- Il player può fare dodge/roll e attraversare piccoli gap validi senza attraversare muri o uscire dalla mappa.
- Gli oggetti non isometrici vengono censiti e la prima sostituzione isometrica viene implementata o preparata con manifest/placeholder coerenti.
- I nuovi test non rompono quelli esistenti.

Lavora in modo incrementale: implementa una prima versione completa e stabile, evita refactor enormi non necessari, mantieni compatibilità con i sistemi esistenti e privilegia test automatici e debug overlay per verificare la generazione.
```
