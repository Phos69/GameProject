# Roadmap — Motore di Generazione Mappe e Biomi

## Obiettivo

Creare un motore procedurale seed-based per generare:

- mappa globale dei biomi;
- singoli biomi grandi almeno `200x200`;
- terreno interno del bioma;
- ostacoli grandi e significativi;
- corridoi naturali creati dagli ostacoli;
- confini tra biomi;
- muri, passaggi e zone di caduta;
- gameplay leggibile per zombie survival, esplorazione e combattimento.

Il bioma non deve essere un piccolo sfondo decorativo, ma una vera area di gioco completa.

---

# Milestone 1 — Seed globale e generazione deterministica

## Goal

Ogni partita deve poter essere generata da un seed.

Con lo stesso seed, il gioco deve ricreare:

- stessa mappa globale dei biomi;
- stessi biomi confinanti;
- stessi terreni;
- stessi ostacoli;
- stesse strade;
- stesse case;
- stessi passaggi;
- stessi confini;
- stessi punti di caduta.

## Task

- Creare un sistema `WorldGenerationSeed`.
- Il seed deve essere salvato all’inizio partita.
- Tutti i generatori devono usare random deterministico derivato dal seed.

## Struttura suggerita

```txt
global_seed
world_rng
biome_map_rng
biome_terrain_rng
obstacle_rng
border_rng
loot_rng
enemy_spawn_rng
```

## Acceptance Criteria

- Avviando due partite con lo stesso seed, la mappa generata è identica.
- Cambiando seed, cambia la disposizione dei biomi e del terreno.
- Nessuna generazione importante usa random non controllato.

---

# Milestone 2 — Mappa globale dei biomi

## Goal

Creare una mappa globale composta da celle-bioma.

Ogni cella rappresenta un bioma grande `200x200`.

## Regola principale

Un bioma non è una stanza piccola.

Ogni bioma deve essere una zona completa:

```txt
BiomeZone = 200 x 200 tile
```

Oppure, se il gioco usa pixel/unità:

```txt
BiomeZone = 200 x 200 celle logiche
```

## Task

- Creare `BiomeMapGenerator`.
- Generare una griglia di biomi.
- Ogni cella della griglia contiene:
  - tipo bioma;
  - coordinate globali;
  - seed locale;
  - lista vicini;
  - lati confinanti;
  - lati chiusi;
  - passaggi disponibili.

## Esempio

```txt
[ Neve       ][ Montagna Bloccata ][ Tossico    ]
[ Base/Town  ][ Base/Town         ][ Infuocato  ]
[ Vuoto/Fall ][ Acqua             ][ Palude     ]
```

## Dati suggeriti

```ts
BiomeCell {
  id: string
  type: BiomeType
  gridX: number
  gridY: number
  worldX: number
  worldY: number
  width: 200
  height: 200
  seed: number

  neighbors: {
    north?: BiomeCell
    south?: BiomeCell
    east?: BiomeCell
    west?: BiomeCell
  }

  borders: {
    north: BorderType
    south: BorderType
    east: BorderType
    west: BorderType
  }
}
```

## Tipi di bordo

```txt
CONNECTED      = confina con altro bioma
BLOCKED        = muro o ostacolo invalicabile
FALL           = vuoto, burrone, caduta
LOCKED_PASSAGE = passaggio chiuso o futuro unlock
```

## Acceptance Criteria

- Esiste una mappa logica dei biomi.
- Ogni bioma è grande `200x200`.
- Ogni lato del bioma sa se confina o no con un altro bioma.
- Se confina, può avere un passaggio.
- Se non confina, può diventare bordo di caduta.

---

# Milestone 3 — Regole dei confini tra biomi

## Goal

Gestire correttamente i bordi del bioma.

## Regole richieste

### Se il bioma confina con un altro bioma

Sul lato confinante devono esserci:

- muri;
- barriere;
- ostacoli naturali;
- almeno un passaggio aperto verso il bioma vicino.

Esempio:

```txt
#########################
###########     #########
###########     #########
#########################
```

Il passaggio deve essere abbastanza largo per:

- player;
- zombie;
- proiettili, se previsto;
- pathfinding.

### Se il bioma NON confina con un altro bioma

Sul lato esterno non deve esserci un altro bioma.

Il bordo deve diventare:

- burrone;
- vuoto;
- mare profondo;
- lava;
- nebbia mortale;
- bordo isometrico senza terreno.

Se il player supera il bordo o entra nella zona pericolosa:

- cade;
- perde `20 HP`;
- viene riportato all’ultima posizione sicura.

## Task

- Creare `BorderGenerator`.
- Per ogni lato del bioma:
  - controllare se esiste un vicino;
  - se sì, generare bordo con muro + passaggio;
  - se no, generare bordo di caduta.

## Acceptance Criteria

- Ogni lato del bioma ha una regola chiara.
- I bordi collegati hanno almeno un passaggio.
- I bordi non collegati causano caduta.
- Il player non può uscire dalla mappa senza conseguenze.
- Gli zombie non spawnano nelle zone di caduta.

---

# Milestone 4 — Generatore terreno interno del bioma

## Goal

Generare il terreno interno del bioma in modo coerente con il tipo di bioma.

## Biomi iniziali

### Base / Cittadina iniziale

Tema:

- case grandi;
- strade;
- vicoli;
- cortili;
- barriere;
- recinti;
- rottami;
- casse risorse.

Questo bioma deve essere il punto di partenza della partita.

### Tossico

Tema:

- pozze tossiche;
- laboratori;
- barili;
- recinzioni industriali;
- fumi velenosi;
- terreno corrotto.

### Infuocato

Tema:

- terreno bruciato;
- lava;
- crepe incandescenti;
- case distrutte;
- muri anneriti;
- fiamme intermittenti.

### Neve

Tema:

- neve alta;
- ghiaccio;
- baite;
- rocce;
- tronchi;
- muri di neve.

### Acqua / Palude

Tema:

- acqua bassa;
- acqua profonda;
- ponti;
- fango;
- canneti;
- relitti;
- passerelle.

## Task

- Creare `BiomeTerrainGenerator`.
- Ogni bioma deve avere:
  - tile base;
  - tile decorativi;
  - tile pericolosi;
  - tile bloccanti;
  - tile attraversabili;
  - tile rallentanti;
  - tile di caduta.

## Acceptance Criteria

- Ogni bioma ha un aspetto e un comportamento diverso.
- Il terreno non è solo uno sfondo.
- Il terreno influenza movimento, pathfinding e combattimento.
- La dimensione effettiva del bioma è `200x200`.

---

# Milestone 5 — Ostacoli grandi e corridoi naturali

## Goal

Il bioma deve essere pieno di corridoi generati dagli ostacoli.

La mappa non deve essere una grande arena vuota.

## Regola centrale

Gli ostacoli devono creare percorsi, vicoli, choke point e zone tattiche.

Nel bioma base, per esempio:

- le case devono essere grandi;
- le strade devono attraversare il bioma;
- le case devono bloccare il movimento;
- tra case, barriere e recinti devono formarsi corridoi.

## Sistema suggerito

Usare una combinazione di:

- layout stradale principale;
- blocchi di edifici;
- ostacoli secondari;
- decorazioni;
- validazione pathfinding.

## Bioma base — esempio struttura

```txt
################################################
#        CASA GRANDE        #       CASA       #
#                           #                  #
#                           #                  #
#========== STRADA PRINCIPALE =================#
#   CASA       #        CORTILE       # CASA   #
#              #                      #        #
#------ VICOLO ----------- BARRIERA -----------#
#        CASA GRANDE              CASA GRANDE  #
################################################
```

## Dimensioni suggerite

### Case grandi

```txt
min_house_size = 12x12
max_house_size = 30x30
```

### Strade

```txt
main_road_width = 6/10 tile
secondary_road_width = 3/5 tile
alley_width = 2/4 tile
```

### Corridoi minimi

```txt
minimum_walkable_corridor = player_width * 2
minimum_zombie_corridor = zombie_width * 2
minimum_combat_corridor = player_width * 3
```

## Task

- Creare `ObstacleLayoutGenerator`.
- Per il bioma base:
  - generare strade principali;
  - generare strade secondarie;
  - piazzare case grandi lungo le strade;
  - aggiungere cortili e barriere;
  - lasciare corridoi percorribili.
- Per gli altri biomi:
  - usare ostacoli coerenti con il tema.

## Acceptance Criteria

- Il bioma base contiene case grandi.
- Le case non sono solo decorazioni, ma veri ostacoli.
- Le strade creano percorsi principali.
- Gli ostacoli creano corridoi naturali.
- Il player e gli zombie possono muoversi senza restare bloccati.
- La mappa non è vuota.

---

# Milestone 6 — Generazione passaggi tra biomi

## Goal

Quando due biomi confinano, deve esserci almeno un passaggio fisico tra loro.

## Regole

- Ogni lato collegato deve avere almeno un passaggio.
- Il passaggio deve essere allineato con il bioma vicino.
- Il passaggio deve essere coerente con il tema.

## Esempi

### Base → Tossico

- cancello rotto;
- strada che entra nella zona contaminata;
- muro industriale con apertura.

### Base → Neve

- strada che diventa sentiero innevato;
- tunnel;
- passo tra rocce.

### Base → Acqua

- ponte;
- passerella;
- strada allagata.

### Infuocato → Base

- ponte sopra crepa;
- strada bruciata;
- varco tra muri rotti.

## Task

- Creare `BiomePassageGenerator`.
- Ogni coppia di biomi collegati deve negoziare un passaggio comune.
- Salvare posizione e larghezza del passaggio.
- Generare il lato A e lato B in modo coerente.

## Dati suggeriti

```ts
BiomePassage {
  fromBiomeId: string
  toBiomeId: string
  side: "north" | "south" | "east" | "west"
  position: number
  width: number
  type: PassageType
}
```

## Acceptance Criteria

- Se due biomi confinano, il player trova un passaggio.
- Il passaggio non viene bloccato da case, muri o ostacoli.
- Il passaggio è coerente visivamente.
- Il pathfinding può attraversarlo.

---

# Milestone 7 — Zone di caduta ai lati senza confine

## Goal

Se un lato del bioma non confina con un altro bioma, quel lato deve diventare una zona di caduta.

## Regole

- I lati senza vicino non devono avere muro completo.
- Devono comunicare chiaramente che oltre il bordo si cade.
- Se il player entra nella zona di caduta:
  - perde `20 HP`;
  - viene riportato all’ultima posizione sicura;
  - riceve breve invulnerabilità;
  - viene mostrato feedback visivo.

## Feedback

- animazione caduta;
- dissolvenza;
- popup `-20 HP`;
- suono di caduta;
- shake camera leggero;
- respawn su tile sicuro.

## Task

- Creare `FallBoundaryGenerator`.
- Generare tile `fall_zone` sui bordi senza bioma confinante.
- Salvare ultima posizione sicura del player.
- Bloccare spawn zombie e casse nelle `fall_zone`.

## Acceptance Criteria

- I bordi senza bioma vicino fanno cadere il player.
- Il danno da caduta è sempre `20 HP`.
- Il player non resta incastrato.
- Le zone di caduta sono leggibili visivamente.
- Gli zombie non spawnano nel vuoto.

---

# Milestone 8 — Validazione pathfinding e giocabilità

## Goal

Ogni mappa generata deve essere giocabile.

Il seed non deve mai creare mappe impossibili.

## Controlli obbligatori

Dopo la generazione, eseguire una validazione:

- il player può muoversi dal punto di spawn iniziale;
- il player può raggiungere ogni passaggio verso biomi confinanti;
- i corridoi principali sono abbastanza larghi;
- le case non bloccano tutta la mappa;
- le strade principali non sono interrotte;
- gli zombie possono raggiungere il player;
- le casse non spawnano in zone irraggiungibili;
- gli ostacoli non chiudono completamente un’area critica;
- le fall zone sono solo sui lati senza confine.

## Task

- Creare `MapValidationSystem`.
- Usare flood fill, navmesh o grid pathfinding.
- Se una mappa non è valida:
  - rigenerare solo il layout problematico;
  - oppure correggere automaticamente aprendo corridoi;
  - oppure cambiare posizione agli ostacoli.

## Acceptance Criteria

- Non esistono seed che generano mappe completamente bloccate.
- Ogni passaggio tra biomi è raggiungibile.
- Ogni bioma è giocabile.
- Le mappe generate sono varie ma controllate.

---

# Milestone 9 — Integrazione con modalità zombie

## Goal

Collegare il motore di generazione alla modalità zombie.

## Regole

- La partita zombie deve iniziare sempre nel bioma base.
- Il bioma base viene generato come zona `200x200`.
- Gli zombie spawnano dai bordi della visuale attuale, ma rispettano:
  - bioma corrente;
  - collisioni;
  - ostacoli;
  - fall zone;
  - passaggi;
  - pathfinding.
- Le ondate cambiano in base al bioma corrente.
- Le casse e le risorse sono generate dal motore mappa.

## Task

- Collegare `BiomeManager` al `WaveDirector`.
- Collegare `ZombieSpawner` alla mappa generata.
- Collegare `ResourceCrateSystem` al generatore.
- Collegare `HazardSystem` a fall zone, veleno, fuoco, ghiaccio e acqua.

## Acceptance Criteria

- La modalità zombie usa la mappa generata.
- Il player parte nel bioma base.
- Gli zombie rispettano il terreno.
- Gli ostacoli creano corridoi reali durante il combattimento.
- Le ondate sono coerenti con il bioma corrente.

---

# Milestone 10 — Debug visuale del generatore

## Goal

Aggiungere strumenti per vedere e correggere la generazione.

## Debug overlay richiesti

- griglia bioma;
- confini bioma;
- passaggi;
- fall zone;
- ostacoli bloccanti;
- strade;
- aree camminabili;
- aree non camminabili;
- spawn point validi;
- pathfinding debug;
- seed corrente.

## Comandi utili

```txt
F1 = mostra/nascondi debug map
F2 = mostra collisioni
F3 = mostra pathfinding
F4 = mostra confini bioma
F5 = rigenera con stesso seed
F6 = genera nuovo seed
```

## Acceptance Criteria

- Si può vedere chiaramente come è stata generata la mappa.
- Si può copiare il seed corrente.
- Si può rigenerare una mappa per test.
- I problemi di generazione sono facili da individuare.

---

# Milestone 11 — Salvataggio e caricamento seed

## Goal

Permettere di salvare e ricaricare mappe generate.

## Task

- Salvare il seed nella run.
- Salvare eventuali override o correzioni.
- Mostrare il seed nella schermata debug o pausa.
- Permettere di avviare una partita inserendo un seed manuale.

## Acceptance Criteria

- Posso copiare un seed e rigenerare la stessa mappa.
- Posso testare bug specifici su un seed problematico.
- Il seed viene salvato nei log della partita.

---

# Milestone 12 — Biome Definition Data-Driven

## Goal

Rendere i biomi configurabili senza dover modificare codice ovunque.

## Ogni bioma deve definire

```ts
BiomeDefinition {
  id: string
  name: string

  size: {
    width: 200
    height: 200
  }

  terrainTiles: string[]
  decorationTiles: string[]
  blockingTiles: string[]
  hazardTiles: string[]

  obstacleTypes: string[]
  largeObstacleTypes: string[]

  enemyTypes: string[]
  enemyWeights: Record<string, number>

  crateTypes: string[]
  crateWeights: Record<string, number>

  borderRules: BorderRuleSet
  passageTypes: PassageType[]

  roadRules?: RoadGenerationRules
  buildingRules?: BuildingGenerationRules
  hazardRules?: HazardGenerationRules
}
```

## Acceptance Criteria

- Aggiungere un nuovo bioma richiede soprattutto una nuova definizione dati.
- Il generatore non ha logica hardcoded per ogni singolo bioma.
- Base, tossico, infuocato, neve e acqua usano lo stesso motore con parametri diversi.

---

# Pipeline finale di generazione

La generazione deve seguire questo ordine:

```txt
1. Read global seed
2. Generate biome map
3. Assign biome types
4. Compute biome neighbors
5. Compute borders
6. Generate shared passages
7. Generate each biome zone 200x200
8. Generate terrain base
9. Generate roads / main paths
10. Generate large obstacles
11. Generate secondary obstacles
12. Generate crates
13. Generate hazards
14. Generate fall zones on non-neighbor borders
15. Generate walls on neighbor borders
16. Open passages between connected biomes
17. Validate pathfinding
18. Fix or regenerate invalid areas
19. Spawn player in base biome
20. Start zombie mode
```

---

# Priorità di sviluppo

## Fase 1 — Fondamenta

1. Seed globale.
2. Mappa globale biomi.
3. BiomeCell `200x200`.
4. Regole neighbor/border.
5. Bioma base iniziale.

## Fase 2 — Bioma base giocabile

6. Generazione strade.
7. Generazione case grandi.
8. Corridoi tra ostacoli.
9. Casse e barriere.
10. Validazione pathfinding.

## Fase 3 — Confini

11. Muri sui lati confinanti.
12. Passaggi tra biomi.
13. Fall zone sui lati senza bioma.
14. Danno caduta `20 HP`.

## Fase 4 — Biomi avanzati

15. Tossico.
16. Infuocato.
17. Neve.
18. Acqua / Palude.

## Fase 5 — Integrazione zombie

19. Spawn dai bordi visuale.
20. Ondate basate sul bioma.
21. Casse bioma-specifiche.
22. Hazard bioma-specifici.

## Fase 6 — Debug e polish

23. Overlay debug.
24. Seed copiabile.
25. Rigenerazione stesso seed.
26. Bilanciamento mappe.
27. Test automatici sui seed.

---

# Definition of Done

Il motore di generazione mappe e biomi è completo quando:

- ogni partita usa un seed;
- lo stesso seed genera sempre la stessa mappa;
- la mappa globale contiene biomi collegati tra loro;
- ogni bioma è una zona grande `200x200`;
- il player parte sempre dal bioma base;
- il bioma base contiene case grandi, strade e corridoi;
- gli ostacoli creano percorsi reali, non solo decorazione;
- i lati confinanti tra biomi hanno muri e almeno un passaggio;
- i lati senza bioma confinante diventano zone di caduta;
- cadere causa `20 HP` di danno;
- ogni bioma è validato con pathfinding;
- casse, ostacoli e nemici rispettano il bioma;
- la modalità zombie usa la mappa generata;
- è possibile visualizzare debug overlay e seed corrente.
