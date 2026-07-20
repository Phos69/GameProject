# Manual Test Checklist

Checklist operativa corrente per `Local Action Sandbox`. Il contratto visuale
normativo e `docs/top_down_cardinal_contract.md`; la checklist precedente al
cutover del 2026-07-15 e conservata soltanto in `docs/archive/` e non deve
essere usata per generare asset o scegliere geometrie runtime.

## Preflight automatico

Eseguire dalla root del repository:

```powershell
godot --headless --path . --import
./tools/run_gut.ps1 -SkipImport
godot --headless --path . --script res://tools/generate_top_down_environment_assets.gd -- --check
godot --headless --path . --script res://tools/migrate_top_down_cliff_textures.gd -- --check
```

Per iterazioni mirate sulla mappa:

```powershell
./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/assets
./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/environment
./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/obstacles
./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/world_gen
./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/modes
./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/ui_audio
```

## Proiezione top-down cardinale

- La griglia del mondo e rettangolare e allineata allo schermo.
- Ground, menu, Character Select e mappa esplorativa non mostrano pavimenti a
  rombo, rapporto `2:1` o assi inclinati.
- Strade, sentieri e passaggi percorrono segmenti orizzontali o verticali;
  curve e incroci collegano esclusivamente lati N/E/S/W.
- Cliff, mesa ed edifici possono mostrare una superficie superiore e una
  facciata sud, ma non spostano il footprint logico.
- Con `F9`, i collider reali coincidono con il blocco fisico: cerchi centrati
  sulle radici per gli alberi e rettangoli allineati H/V per gli altri blocker.
- Con `F9`, attraversare fall zone larghe due tile sia orizzontali sia verticali:
  il rettangolo rosa deve coincidere con i confini del void senza offset di
  mezzo tile; la caduta deve continuare a scattare sul baricentro del player.
- Avvicinare il player ai quattro lati di una mesa: l'ombra deve raggiungere il
  bordo fisico; in particolare non deve restare un gap a sud ne oltrepassare il
  limite a nord.
- Nessun quadrato opaco resta visibile sotto gli asset con `F9` disattivato.
- Player, zombie, boss e prop non incorporano un piano sotto lo sprite.
- Alberi e soggetti alti possono superare il bordo nord e restano ordinati via
  Y-sort sul loro `floor_center`/`bottom_center`.
- Nella Pianura Infetta, percorrere entrambi i lati di un tratto di strada
  alberato: due `forest_tree` adiacenti devono toccarsi col collider `F9`, il
  player non deve attraversare il filare e il visuale deve risultare doppio
  rispetto al precedente asset runtime senza cambiare il footprint `2x2`.

## Asset ambiente

- Visitare tutti e cinque i biomi e controllare ground, route, passaggi,
  transizioni, void, cliff, mesa, hazard e bordi.
- Nella Pianura Infetta, roccia piccola, recinzione, barriera, tronco, due case,
  auto e vegetazione densa usano PNG trasparenti senza alone magenta; casse
  comuni e mediche hanno silhouette immediatamente distinguibili.
- Negli altri quattro biomi gli SVG individuali restano validi fino al pass
  `BIOME-RASTER-002`; nessun prop usa un ritaglio da tavola concept.
- Auto, relitti, barriere e muri hanno asse principale H/V; gli edifici hanno
  tetto rettangolare e, al massimo, facciata sud controllata.
- Ogni ostacolo, hazard e fall zone resta a rotazione zero. Attraversando a
  nord/sud di alberi e mesa, l'attore passa rispettivamente dietro/davanti senza
  salti di layer.
- Verificare trasparenza, scala, contatto col terreno e assenza di aloni chiari
  a `1280x720` e `960x540`.
- Con `F9` nella Pianura Infetta, confrontare ogni nuovo raster col collider:
  il cutover non deve cambiare area bloccata, anchor, Y-sort o probabilita di
  generazione; la silhouette deve coprire larghezza e altezza del collider senza
  stretch, anche quando oltrepassa l'altro asse. Passare davanti e dietro
  entrambe le case, l'auto e la vegetazione.
- Un asset mancante attiva un fallback top-down con lo stesso footprint.

## Maschera confini terrain

Il contratto tecnico completo e in `docs/terrain_boundary_mask_system.md`.

- In tutti e cinque i biomi, erba, sentiero e asfalto devono conservare la
  propria texture; il divisore di terra copre soltanto il cambio tra classi
  visuali diverse.
- Tile ID diversi della stessa superficie non creano linee interne: controllare
  in particolare strada, incrocio, passage ed entry/exit asfaltati.
- Verificare split orizzontali e verticali, angoli, T-junction e incroci: il
  divisore deve essere continuo, senza rettangoli per-cell, fori, doppie linee o
  ponti tra celle che si toccano soltanto in diagonale.
- Muovere la camera lungo il confine e attraversare piu chunk con zoom
  variabile: la maschera regionale non deve produrre seam, cambi di spessore o
  segmenti che compaiono durante il rebuild.
- Il void resta un colore uniforme, senza texture o griglia ripetuta. Faccia
  cliff e lip sono disegnati sopra il canvas delle superfici e restano
  l'indicazione principale della caduta.
- Con `F9` attivo e disattivo, la sostituzione visuale non modifica collisioni,
  fall zone, danno, spawn o pathfinding.
- Ripetere i controlli a `1280x720` e `960x540`, includendo high contrast e
  reduced motion.

Visual QA consigliate:

```powershell
./tools/run_visual_qa.ps1 -SkipImport -Filter obstacle_asset
./tools/run_visual_qa.ps1 -SkipImport -Filter biome_art
./tools/run_visual_qa.ps1 -SkipImport -Filter biome_rendering_review
./tools/run_visual_qa.ps1 -SkipImport -Filter cliff
./tools/run_visual_qa.ps1 -SkipImport -Filter top_down_final
```

## Movimento, input e camera

- `WASD` e stick sinistro producono movimento analogico senza trasformazioni
  di proiezione; la velocita diagonale e normalizzata.
- Frecce e stick destro aggiornano la mira indipendentemente dal movimento.
- Camera, zoom, shake e follow di gruppo non inclinano la griglia.
- `Shift`/`Ctrl` o joypad `B` eseguono dodge/roll.
- Con ciascuno dei sette personaggi, fermarsi e mirare verso
  Sud/Est/Nord/Ovest: il corpo deve usare quattro viste distinte e a Nord deve
  mostrare la schiena. Ripetere il roll nelle quattro direzioni verificando
  anticipazione, tuck e recovery, senza arma sovrapposta e senza cambiare
  traiettoria o hitbox.
- `R` o joypad `X` ricaricano; `Spazio`/`RB`, `F`/`LB` e `Q`/`Y` attivano le
  azioni previste.

## Multiplayer locale e UI

- Player 1 e sempre attivo; `F2`, `F3`, `F4` e i joypad aggiuntivi gestiscono
  gli altri slot senza sottrarre il controllo al primo.
- Character Select naviga solo card valide in quattro direzioni e conserva il
  controller proprietario dello slot.
- HUD, menu, pausa, Settings e risultati restano nella safe area a
  `1280x720`, `1024x768` e `960x540`.
- La mappa esplorativa (`M` o `Back/Select/View`) usa una griglia H/V e segue
  correttamente regioni visitate, correnti e non scoperte.
- Simboli accessibili dei player possono includere una losanga: e un marker UI,
  non una cella o una proiezione del mondo.

## Modalita e persistenza

- Dal menu avviare Infinite Arena, Zombie Survival, Dungeon e Tower Defense;
  mettere in pausa, aprire Settings e tornare al menu senza nodi o audio
  residui.
- Zombie Survival attraversa seam e passaggi, genera ondate e boss, applica
  hazard/fall e mantiene spawn su celle valide.
- In Zombie Survival attraversare avanti/indietro lo stesso seam per almeno
  20 volte, attendendo oltre 2 secondi sui lati per esercitare l'unload: nessun
  freeze/crash, chunk vuoto o collider residuo. Nel profilo balanced a
  `1280x720` verificare p95 <= 33,3 ms e frame massimo al seam <= 50 ms;
  `get_streaming_stats()` deve mostrare code che tornano a zero,
  `pending_retirement_roots == 0` dopo il drain e nessuna crescita monotona di
  regioni/chunk. `max_retirement_msec` non deve produrre il vecchio picco circa
  2 secondi dopo il seam; `last_frame_chunk_evictions` non deve superare `1` e
  `max_chunk_eviction_msec` va registrato insieme al frame massimo.
- Durante lo stesso percorso verificare che l'autosave compaia soltanto dopo la
  finestra di quiete e che il frame della transizione non contenga I/O file;
  progressione, regione corrente ed esplorazione devono risultare persistite
  riavviando il gioco.
- Un salvataggio corrente viene letto e scritto senza perdita di progressione.
- Se esiste soltanto il vecchio save di `Iso Local Sandbox`, il primo avvio lo
  copia una sola volta nella directory `Local Action Sandbox`, senza migrare
  cache del mondo e senza cancellare la sorgente.

## Criterio di accettazione

Il pass e accettato quando import, GUT completo, check dei due generatori e
Visual QA pertinenti sono verdi, la scena principale e giocabile con tastiera e
joypad e nessuna documentazione operativa o asset attivo richiede una
proiezione diversa da `orthogonal_top_down` con `controlled_perspective`. La
maschera terrain deve inoltre mantenere il void uniforme, il divisore continuo
tra classi diverse e cliff/lip sopra il canvas delle superfici.
