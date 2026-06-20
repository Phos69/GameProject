# Rendering ostacoli isometrici

## Contratto unico

La mappa logica resta la sorgente di verita. `BiomeEnvironmentLayout.obstacle_rects`
contiene le celle occupate; `ObstacleLayoutGenerator` centra su ogni richiesta il
footprint canonico letto da `assets/environment/isometric/manifest.json`. Da quel
rettangolo derivano posizione world-space, collisione, spawn blocker e base visiva.

Il manifest v9 usa slot da `4x4` celle logiche (`8 px` world-space per cella):

```text
obstacle_id -> footprint_slots -> footprint_tiles -> occupied_cells
            -> collision/blocks -> asset_path + visual_height_tiles
```

`BiomeEnvironmentLayout.get_obstacle_record()` espone il record completo usato dal
runtime: tipo, categoria, slot, celle, asset/variante, altezza e proprieta di
collisione. `validate_obstacle_records()` fallisce se rettangolo logico, posizione,
dimensione collisione o asset non coincidono. I segmenti `border` sono l'unica
eccezione: possono avere lunghezza variabile per chiudere il perimetro.

Le dimensioni piccole supportate e coperte da smoke sono `1x1`, `2x1`, `1x2`,
`2x2`, `3x1`, `1x3`, `3x2`, `2x3` e `3x3`. Case e blocchi grandi usano gli stessi
slot (`4x4`, `5x3`, `6x6`); l'altezza grafica puo salire sopra la base senza
allargare la collisione.

## Asset e anchor

Gli SVG sono organizzati per categoria e riportano il footprint nel filename e
nel metadata `data-footprint-slots`, per esempio:

- `objects/rocks/rock_1x1.svg`;
- `objects/fences/fence_2x1.svg`;
- `objects/trees/log_3x1.svg`;
- `objects/trees/dense_forest_3x3.svg`;
- `objects/houses/ruined_house_4x4.svg`;
- `objects/houses/lab_block_6x6.svg`.

`IsometricEnvironmentObject` disegna sempre una base isometrica pari al footprint
bloccante e ancora lo sprite a `iso_floor_center`/`bottom_center`. La dimensione
dello sprite e deterministica: footprint e `visual_height_tiles` del manifest
producono la dimensione nativa, senza scale casuali del generatore. I container
world-space restano in Y-sort con `z_index = 0` e posizione derivata dal centro
del rettangolo logico; `sort_offset` ancora lo sprite al pavimento. Tetti e chiome
possono cosi coprire gli attori dietro senza cambiare ordine durante il movimento.

Void/fall zone usano contratti `void_tiles`/cliff separati e non sono ostacoli
solidi. Pareti, case, vegetazione e rocce usano invece `object_scenes` e dichiarano
esplicitamente `blocks_movement` e `blocks_projectiles`.

## Aggiungere un ostacolo

1. Aggiungere l'ID a `objects`, con categoria, `footprint_tiles`,
   `footprint_slots`, `visual_height_tiles`, collisione e blocchi.
2. Aggiungere lo stesso ID a `object_scenes`, con SVG, anchor e biomi ammessi.
3. Usare un filename `snake_case` con suffisso `<larghezza>x<altezza>`.
4. Generare l'asset mancante:

   ```text
   godot --headless --path . --script res://tools/generate_isometric_environment_assets.gd -- --write
   ```

5. Aggiungere l'ID al catalogo del generatore/bioma solo se deve essere piazzato.
   Il generatore verifica lo spazio usando gia il footprint canonico.
6. Eseguire lo smoke del contratto e quello della pipeline asset.

## Debug e verifica

Durante una run survival, `F9` mostra/nasconde la base e il contorno dei footprint
degli ostacoli attivi. `F8` continua a mostrare il riepilogo della generazione dei
biomi. Check manuale dopo modifiche a rendering o collisioni:

- attraversare davanti e dietro una casa e un gruppo di alberi, verificando Y-sort
  stabile e nessun flicker;
- provare tutti i lati del footprint: il blocco fisico deve iniziare e finire sulla
  base disegnata;
- verificare almeno un esempio per ciascuna delle nove dimensioni piccole;
- verificare che vegetazione densa, case, rocce, recinzioni e cliff siano
  distinguibili senza overlay;
- confrontare `F9` con la collisione: non devono esistere collisioni invisibili;
- verificare che void/cliff attivi la caduta e non venga letto come muro solido.

Smoke automatici:

```text
godot --headless --path . --script res://tests/obstacle_rendering_contract_smoke_test.gd
godot --headless --path . --script res://tests/obstacle_asset_visual_qa.gd
godot --headless --path . --script res://tests/isometric_environment_manifest_smoke_test.gd
godot --headless --path . --script res://tests/milestone_10_object_asset_smoke_test.gd
godot --headless --path . --script res://tests/starter_biome_vertical_slice_smoke_test.gd
```
