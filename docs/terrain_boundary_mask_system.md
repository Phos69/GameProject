# Terrain Boundary Mask System

Stato: contratto operativo corrente per il compositing visuale del terreno
survival. Il contratto cardinale generale resta
`docs/top_down_cardinal_contract.md`.

## Obiettivo

Il terreno non usa immagini di transizione complete per fondere coppie
specifiche di tile. Ogni regione genera invece una sola maschera RGBA che:

- classifica le superfici base come erba, sentiero, asfalto o void;
- traccia un divisore di terra sui confini tra classi diverse;
- permette ai chunk di riusare le texture di superficie gia presenti;
- mantiene identici tile ID, collisioni, danno, spawn e pathfinding.

La maschera e un dato di rendering, non una mappa gameplay. Non sostituisce la
classificazione `BiomeEnvironmentLayout.TERRAIN_*` e non puo essere usata per
dedurre attraversabilita o collisioni dall'immagine.

## Codifica RGBA

La maschera usa `Image.FORMAT_RGBA8`. I canali hanno questo significato:

| Canale | Valore | Significato |
| --- | --- | --- |
| `R` | `1` | superficie erba |
| `G` | `1` | superficie sentiero/lane |
| `B` | `1` | superficie asfalto/road-like |
| `RGB` | `(0, 0, 0)` | void uniforme |
| `A` | `0..1` | copertura feathered del divisore di terra |

Nell'interno di una superficie i canali RGB sono one-hot: un solo canale e
attivo. Il filtraggio lineare puo produrre valori intermedi esclusivamente
durante il campionamento tra texel. L'alpha e indipendente dai pesi RGB: copre
il risultato delle superfici senza modificarne la classe.

Il divisore viene emesso quando due celle cardinalmente adiacenti appartengono
a classi visuali diverse. Due tile ID diversi che condividono la stessa classe
non producono un bordo interno: per esempio `main_road`, un incrocio e un
passage asfaltato restano una sola superficie continua. Lo stesso vale per le
varianti dell'erba e per i tile semantici che appartengono al void.

## Classificazione visuale

`TerrainSurfaceClassifier` assegna una delle quattro classi senza cambiare il
layout:

1. celle fuori regione, `TERRAIN_VOID` e `TERRAIN_FALL_ZONE` diventano `void`;
2. le celle route che usano una lane diventano `path`;
3. le altre celle route e passage road-like diventano `asphalt`;
4. tutto il terreno restante diventa `grass`.

Tall grass, varianti cromatiche, hazard-underlay e detail non creano da soli
una nuova classe di confine. Possono mantenere i propri layer presentazionali
sopra la superficie base. La distinzione lane/asfalto continua a essere
risolta dalle API semantiche del `BiomeTileResolver`, non dal nome o dal colore
di un file raster.

## Generazione regionale

`TerrainBoundaryMaskBuilder` costruisce la maschera una volta per l'intera
regione. Con il valore corrente di otto texel per tile, una regione `75x75`
produce un'immagine `600x600`.

La generazione deve essere:

- deterministica per layout e `generation_seed`;
- indipendente dal preset e dalla suddivisione in chunk;
- continua su segmenti orizzontali, verticali e relative giunzioni;
- priva di linee tra celle della stessa classe visuale;
- limitata ai quattro vicini cardinali, senza collegare celle che si toccano
  soltanto in diagonale.

La larghezza del divisore puo ricevere una variazione leggera e deterministica,
ma deve usare la stessa chiave sui due lati del medesimo confine. Feather e
variazione restano presentazionali e non spostano il limite logico della cella.

Ogni chunk riceve soltanto il rettangolo UV relativo alla maschera regionale.
Non rigenera una maschera locale e non crea nodi per tile. In questo modo due
chunk adiacenti campionano gli stessi texel al seam e una eviction/rebuild non
puo cambiare la forma del divisore.

Qualsiasi modifica alla codifica dei canali, ai texel per tile, alla
classificazione o alla geometria del divisore richiede l'invalidazione della
cache visuale; non richiede una nuova firma del layout se i dati gameplay
restano invariati.

## Compositing delle texture

`TerrainSurfaceCanvas` disegna un quad per chunk e usa
`terrain_surface_blend.gdshader`. Il compositing segue questo ordine:

1. campiona la maschera con UV regionali;
2. campiona erba, sentiero e asfalto con UV world-space;
3. miscela le tre texture con i pesi RGB;
4. usa il colore void uniforme quando la somma RGB e zero;
5. applica il materiale logico `terrain_divider_dirt` usando il canale alpha.

Le UV world-space usano la posizione del chunk sommata all'offset della regione
streammata. La fase delle texture quindi continua tra regioni adiacenti e non
riparte dal loro centro; un rebuild o una nuova finestra di streaming conserva
lo stesso allineamento.

Il void non campiona una texture ripetuta: `RGB == 0` restituisce sempre il
`void_color` condiviso col backdrop fuori mappa. Non devono comparire griglia,
quilt, dettaglio ripetuto o pannelli di tile nel vuoto profondo.

Le texture di superficie restano scelte dal manifest e dal catalogo del bioma:

- la Pianura Infetta usa `forest_grass`, `forest_path` e `forest_road`;
- i quattro biomi generated usano i rispettivi ruoli `ground`, `path` e
  `road`;
- nella Pianura Infetta il divisore logico `terrain_divider_dirt` aliasa la
  stessa istanza normalizzata e lo stesso periodo world-space di `forest_path`;
- i quattro biomi generated usano il raster comune
  `terrain_divider_dirt_generated.png`.

Il contratto non dipende da core ritagliati, strip mono-lato o raster dedicati
agli angoli. Gli asset semantici di transizione possono restare censiti per
compatibilita o debug, ma non sono necessari per costruire il confine.

## Void, cliff e ordine dei layer

La maschera puo emettere alpha anche sul contatto tra una superficie e il void,
ma il divisore di terra non diventa l'autorita visiva o fisica della caduta.
Faccia cliff e lip restano geometria dedicata e vengono disegnati sopra il
`TerrainSurfaceCanvas`.

Devono restare valide queste regole:

- il prato raggiunge la cresta senza estendersi nel void;
- lip e faccia rendono la caduta leggibile sui quattro lati e agli angoli;
- il void sotto il cliff resta uniforme e coincide col backdrop fuori mappa;
- la maschera non cambia `fall_zone`, danno, respawn o attraversabilita;
- un asset o shader mancante non puo rendere il void calpestabile.

Raised cliff, mesa, pareti perimetrali, hazard, prop e attori restano sistemi
separati. Il nome "terrain divider" indica soltanto il materiale di terra della
maschera e non il biome divider fisico tra regioni.

## Contratto di verifica

I guardrail automatici devono coprire almeno:

- encoding one-hot di erba, sentiero e asfalto;
- `RGB == 0` per void e fall zone;
- alpha nullo su una regione uniforme;
- alpha presente su split orizzontali e verticali;
- angoli, T-junction e incroci senza fori o segmenti duplicati;
- assenza di un ponte su un semplice contatto diagonale;
- nessun bordo tra tile ID diversi della stessa classe;
- output identico a seed e layout uguali;
- campionamento equivalente prima e dopo rebuild dei chunk;
- texture base e divisore caricati senza fallback inatteso;
- void uniforme e cliff/lip ancora presenti;
- `visible_missing_chunks == 0` durante movimento e zoom.

## Checklist manuale

1. Avviare Zombie Survival con seed `641004` e `772031` e visitare tutti e
   cinque i biomi.
2. Controllare a `1280x720` e `960x540` che erba, sentiero e asfalto conservino
   la propria texture su entrambi i lati del divisore.
3. Ispezionare una strada e un sentiero sia orizzontali sia verticali: la fascia
   di terra deve essere continua, con larghezza simile sui due assi e senza
   rettangoli per-cell.
4. Cercare angoli convessi/concavi, una T-junction e un incrocio: non devono
   comparire fori, quadrati sovrapposti, croci spurie o linee interrotte.
5. Attraversare un passage e un incrocio road-like: non deve esserci una linea
   interna tra tile semantici che condividono l'asfalto.
6. Muovere la camera lungo un confine e attraversare piu chunk con zoom variabile:
   il divisore non deve cambiare spessore, sparire o raddoppiare ai seam.
7. Ispezionare chasm interni e bordi esterni: il void deve restare uniforme;
   cliff e lip devono coprire il contatto ed essere piu leggibili del divisore.
8. Attivare e disattivare `F9`: collisioni e classificazione gameplay devono
   restare identiche alla geometria precedente alla sostituzione visuale.
9. Verificare high contrast e reduced motion: road, path, cliff, player e
   pickup devono restare distinguibili.

Comandi consigliati:

```powershell
godot --headless --path . --import
./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/assets
./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/environment
./tools/run_gut.ps1 -SkipImport -GutDir res://tests/suites/world_gen
./tools/run_visual_qa.ps1 -SkipImport -Filter biome_art
./tools/run_visual_qa.ps1 -SkipImport -Filter biome_rendering_review
./tools/run_visual_qa.ps1 -SkipImport -Filter cliff
```

Il pass manuale e accettato quando tutte le superfici restano leggibili, il
divisore copre ogni cambio di classe senza introdurre seam e il void continua a
essere definito dal cliff sopra un fondale uniforme.
