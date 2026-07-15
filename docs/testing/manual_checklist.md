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
- Nessun quadrato opaco resta visibile sotto gli asset con `F9` disattivato.
- Player, zombie, boss e prop non incorporano un piano sotto lo sprite.
- Alberi e soggetti alti possono superare il bordo nord e restano ordinati via
  Y-sort sul loro `floor_center`/`bottom_center`.

## Asset ambiente

- Visitare tutti e cinque i biomi e controllare ground, route, passaggi,
  transizioni, void, cliff, mesa, hazard e bordi.
- I 23 prop in `objects/generated_props/` sono SVG individuali; nessuno usa un
  ritaglio da tavola concept o una base inclinata.
- Auto, relitti, barriere e muri hanno asse principale H/V; gli edifici hanno
  tetto rettangolare e, al massimo, facciata sud controllata.
- Ogni ostacolo, hazard e fall zone resta a rotazione zero. Attraversando a
  nord/sud di alberi e mesa, l'attore passa rispettivamente dietro/davanti senza
  salti di layer.
- Verificare trasparenza, scala, contatto col terreno e assenza di aloni chiari
  a `1280x720` e `960x540`.
- Un asset mancante attiva un fallback top-down con lo stesso footprint.

Visual QA consigliate:

```powershell
./tools/run_visual_qa.ps1 -SkipImport -Filter obstacle_asset
./tools/run_visual_qa.ps1 -SkipImport -Filter biome_art
./tools/run_visual_qa.ps1 -SkipImport -Filter cliff
./tools/run_visual_qa.ps1 -SkipImport -Filter top_down_final
```

## Movimento, input e camera

- `WASD` e stick sinistro producono movimento analogico senza trasformazioni
  di proiezione; la velocita diagonale e normalizzata.
- Frecce e stick destro aggiornano la mira indipendentemente dal movimento.
- Camera, zoom, shake e follow di gruppo non inclinano la griglia.
- `Shift`/`Ctrl` o joypad `B` eseguono dodge/roll.
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
- Un salvataggio corrente viene letto e scritto senza perdita di progressione.
- Se esiste soltanto il vecchio save di `Iso Local Sandbox`, il primo avvio lo
  copia una sola volta nella directory `Local Action Sandbox`, senza migrare
  cache del mondo e senza cancellare la sorgente.

## Criterio di accettazione

Il pass e accettato quando import, GUT completo, check dei due generatori e
Visual QA pertinenti sono verdi, la scena principale e giocabile con tastiera e
joypad e nessuna documentazione operativa o asset attivo richiede una
proiezione diversa da `orthogonal_top_down` con `controlled_perspective`.
