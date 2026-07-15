# Rendering ostacoli top-down

## Contratto unico

La mappa logica resta la sorgente di verita. `BiomeEnvironmentLayout.obstacle_rects`
contiene le celle occupate; `ObstacleLayoutGenerator` centra su ogni richiesta il
footprint canonico letto da `assets/environment/top_down/manifest.json`. Da quel
rettangolo derivano posizione world-space, collisione, spawn blocker e base visiva.

La base segue `coordinate_system: orthogonal_top_down`. Altezza, facciata sud e
fianchi sono `controlled_perspective`: possono superare la base solo sul piano
visivo e non spostano celle, anchor o collisioni. Il contratto generale e in
`docs/top_down_cardinal_contract.md`.

Il manifest v11 usa slot da `4x4` celle logiche (`8 px` world-space per cella):

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

Gli asset sono organizzati per categoria e riportano il footprint nel filename.
Gli SVG dichiarano anche il metadata `data-footprint-slots`; i PNG finali
mantengono sorgente, licenza e attribuzione nel manifest.
Esempi:

- `objects/rocks/rock_1x1.svg`;
- `objects/generated_props/broken_fence_2x1_generated.svg`;
- `objects/trees/log_3x1.svg`;
- `objects/trees/dense_forest_3x3.svg`;
- `objects/trees/forest_tree_3x3.png`;
- `edges/cliffs/textures/rock_plateau_top_generated.png` (top massa rocciosa scalabile);
- `edges/cliffs/textures/rock_cliff_face_upward_generated.png` (faccia cliff rialzata);
- `objects/generated_props/ruined_house_4x4_generated.svg`;
- `objects/generated_props/lab_block_6x6_generated.svg`.

I 23 prop che in precedenza condividevano cinque tavole raster sono ora SVG
individuali. Il generatore assegna a ciascuno una pianta ortogonale, un
footprint esplicito e, dove serve, una sola facciata sud prospettica. Le vecchie
risorse `AtlasTexture` non sono piu caricate. `reed_wall` resta uno SVG
verticale `1x3` dedicato.

`EnvironmentObject` usa sempre una base rettangolare pari al footprint
bloccante e ancora lo sprite a `floor_center`/`bottom_center`. La dimensione
dello sprite e deterministica: footprint e `visual_height_tiles` del manifest
producono la dimensione nativa, senza scale casuali del generatore. I container
world-space restano in Y-sort con `z_index = 0` e posizione derivata dal centro
del rettangolo logico; `sort_offset` ancora lo sprite al pavimento. Tetti e chiome
possono cosi coprire gli attori dietro senza cambiare ordine durante il movimento.

`forest_tree` resta il riferimento per l'ostacolo singolo `3x3`: occupa nove
slot di design e un footprint runtime `2x2` tile logici. `large_rock` e invece
scalabile: il void-first genera rettangoli quadrati da `3x3` a `5x5` tile logici e
`RectilinearRockAreaMeshBuilder` trasforma ogni `rock_rect` in un plateau
rialzato, cioe il void cliff specchiato verso l'alto. La corona cobble
(`rock_plateau_top_generated.png`) e sollevata di `RAISE_HEIGHT_CELLS` e rientra
in un mesa; tre pareti continue a colonne (`rock_cliff_face_upward_generated.png`)
salgono dal prato fino al bordo: il fronte sud a tutta larghezza piu i due
fianchi obliqui inclinati di `LATERAL_LEAN_RATIO`. La parete nord guarda lontano
dalla camera e non viene emessa. Le pareti sono disegnate per prime e la corona
le copre, mascherando i triangoli alti come fa il void con il suo lip. Lo shading
e per lato (fronte chiaro, est illuminato, ovest in ombra) con gradiente verso la
base; non ci sono fenditure o lip disegnati a mano, quindi la superficie resta
priva di linee procedurali. Il nodo `large_rock` non disegna uno sprite e non
ridisegna la corona: mantiene solo collisione, blocker e overlay `F9`, mentre il
tile layer produce l'unico top visibile. Entrambi bloccano movimento e
proiettili sull'intera area dichiarata.

Void/fall zone usano contratti `void_tiles`/cliff separati e non sono ostacoli
solidi. Pareti, case, vegetazione e rocce usano invece `object_scenes` e dichiarano
esplicitamente `blocks_movement` e `blocks_projectiles`.

## Aggiungere un ostacolo

1. Aggiungere l'ID a `objects`, con categoria, `footprint_tiles`,
   `footprint_slots`, `visual_height_tiles`, collisione e blocchi.
2. Aggiungere lo stesso ID a `object_scenes`, con SVG/PNG/Texture2D, anchor e biomi ammessi.
3. Usare un filename `snake_case` con suffisso `<larghezza>x<altezza>`.
4. Generare l'asset mancante:

   ```text
   godot --headless --path . --script res://tools/generate_top_down_environment_assets.gd -- --write
   ```

5. Aggiungere l'ID al catalogo del generatore/bioma solo se deve essere piazzato.
   Il generatore verifica lo spazio usando gia il footprint canonico.
6. Eseguire lo smoke del contratto e quello della pipeline asset.

Per un PNG o un'`AtlasTexture`, il canvas sorgente puo essere piu grande della dimensione nativa:
`EnvironmentObject` applica il downscale deterministico derivato da
footprint e `visual_height_tiles`; corner trasparenti e copertura minima restano
obbligatori.

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
tools/run_gut.sh -gdir=res://tests/suites/obstacles
tools/run_gut.sh -gdir=res://tests/suites/assets
tools/run_visual_qa.sh obstacle
tools/run_visual_qa.sh rock_area
```
