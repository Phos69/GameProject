# Contratto visivo top-down cardinale

Questo documento e la fonte normativa per proiezione, coordinate, asset e
fallback world-space. In caso di conflitto, i documenti e i report precedenti
alla migrazione top-down del 2026-07-15 sono storici e questo contratto prevale.

## Coordinate e griglia

- `coordinate_system`: `orthogonal_top_down`.
- `volume_style`: `controlled_perspective`.
- Le celle logiche sono quadrate e allineate agli assi dello schermo.
- `+X` indica est/destra; `+Y` indica sud/basso.
- I vicini strutturali sono nord, est, sud e ovest.
- Il centro world-space di una cella e il suo `floor_center`.
- Oggetti alti e attori usano `bottom_center` per posizione, Y-sort e
  occlusione.
- La conversione cella/world e una scala cartesiana diretta. L'input analogico
  non subisce trasformazioni di proiezione.

Il movimento degli attori e il pathfinding possono restare analogici e
diagonali negli spazi aperti. La cardinalita e un contratto della griglia, dei
confini e delle route costruite, non un vincolo a quattro direzioni sul
gameplay.

## Terreno e route

- Ground, strade, sentieri, passaggi e transizioni coprono quad rettangolari,
  senza pavimento incorporato nell'asset.
- Le route principali e i connector seguono segmenti orizzontali o verticali.
- Curve e incroci collegano lati cardinali; non seguono assi visivi inclinati.
- Cliff, void, muri e transizioni dichiarano i lati tramite N/E/S/W e relativi
  angoli interni o esterni.
- Il footprint visuale deve coincidere con la griglia anche quando il soggetto
  presenta altezza.

## Volume prospettico controllato

La mappa non e piatta: edifici, cliff, mesa, rocce, alberi e ostacoli possono
mostrare volume e una facciata leggibile. Il volume e pero separato dalla
proiezione del terreno.

Sono consentiti:

- superfici superiori viste dall'alto e allineate agli assi;
- facciata sud e sottili facce laterali per comunicare altezza;
- ombre morbide sotto l'ingombro, senza cambiare il footprint;
- silhouette che superano il bordo nord della cella;
- prospettiva locale coerente, usata solo sul volume dell'oggetto.

Non sono consentiti nei contratti operativi o negli asset nuovi:

- griglie o pavimenti a rombo;
- rapporto di proiezione `2:1`;
- assi della mappa inclinati;
- route diagonali usate per simulare una proiezione;
- basi prospettiche incorporate sotto prop e personaggi;
- facce laterali che spostano collisione o punto di ancoraggio.

## Contratto asset

Il manifest ambiente vive in
`assets/environment/top_down/manifest.json` e dichiara almeno:

```json
{
  "coordinate_system": "orthogonal_top_down",
  "volume_style": "controlled_perspective"
}
```

Gli ID semantici, i footprint, le collisioni e i pool procedurali restano
stabili durante la sostituzione grafica. Il renderer non deduce collisioni
dall'alpha dell'immagine.

Anchor ammessi per oggetti e attori:

- `floor_center`: centro della base rettangolare, per tile e oggetti bassi;
- `bottom_center`: centro del bordo sud dell'ingombro, per attori e oggetti
  alti.

I contratti terrain/edge possono inoltre usare `center` per texture centrate e
`edge_aligned` per lip, muri e transizioni ancorati a un lato cardinale. Questi
anchor non cambiano mai il punto logico della cella o la collisione.

Le texture terrain sono full-bleed e seamless. I cutout di prop, attori e
facciate hanno alpha reale. I fallback devono rispettare lo stesso contratto:
un asset mancante non puo reintrodurre una base a rombo o una proiezione
inclinata.

## Attori e camera

- Movimento e mira restano analogici e indipendenti.
- Facing, bob, hit flash, stato downed/dead e layer arma restano runtime.
- Gli sprite gameplay non incorporano un pavimento e sono ancorati a
  `bottom_center`.
- La camera segue coordinate cartesiane; zoom e shake non alterano la
  proiezione.

## UI e debug

Menu, preview personaggio e mappa esplorativa usano una griglia rettangolare o
nessuna griglia. Footprint, celle bloccate e regioni debug sono rettangoli
allineati agli assi. Il simbolo a losanga usato come marker accessibile per uno
slot giocatore resta ammesso: e un pittogramma UI, non una proiezione del
mondo.

## Tooling e guardrail

Il generatore canonico e
`tools/generate_top_down_environment_assets.gd`. Supporta `--dry-run`,
`--write`, `--check` e `--only=...`, e non deve emettere pavimenti inclinati.
Gli asset `final` possono essere riscritti soltanto durante un cutover di
proiezione esplicito, combinando `--overwrite-generated` e
`--migrate-projection`; nessuno dei due flag da solo e sufficiente.

Ogni modifica a rendering o asset richiede:

1. import Godot headless;
2. GUT delle aree `assets`, `environment`, `obstacles` e `world_gen`;
3. check del generatore top-down;
4. Visual QA di tutti i biomi, degli attori, del menu e della mappa;
5. verifica dell'allineamento tra sprite, `bottom_center`, footprint e
   collisione;
6. ricerca finale di vecchi termini di proiezione fuori da changelog e report
   esplicitamente storici.

## Compatibilita

Seed, coordinate logiche, stato esplorazione, ID asset, footprint e collisioni
non cambiano per effetto della migrazione visiva. Le cache di rendering devono
invece includere la versione del contratto e venire invalidate quando cambia
la geometria visuale.
