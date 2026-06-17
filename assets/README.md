# Asset Pipeline

Questa cartella contiene solo asset distribuibili con origine e licenza
documentate in `ATTRIBUTION.md`. Il prototipo deve continuare a funzionare
quando una risorsa esterna manca: visual, audio e font mantengono sempre un
fallback procedurale o di engine.

## Struttura

```text
assets/
  audio/       musica e SFX
  fonts/       font runtime
  sprites/     attori, armi, props ed effetti
  tilesets/    tile, atlas e materiali ambiente
  ui/          pannelli, icone e cursori
```

## Naming

- file e cartelle in `snake_case`;
- suffissi consigliati: `_diffuse`, `_normal`, `_emission`, `_icon`;
- atlas: `{sistema}_{variante}_atlas.png`;
- animazioni: `{attore}_{stato}_{direzione}_{frame}.png`;
- nessuno spazio, versione o nome autore nel filename;
- la provenienza vive in `ATTRIBUTION.md`, non nel nome.

## Sprite e Atlas

- mantenere il pivot logico coerente tra frame;
- usare dimensioni potenza di due per atlas quando non aumenta lo spreco;
- evitare padding trasparente non necessario;
- lasciare almeno 2 pixel di separazione tra regioni interpolate;
- importare pixel art senza filtro e senza mipmap;
- per artwork scalabile non pixel-art, documentare l'eccezione nel `.import`
  e verificare il risultato a 1280x720.

## Compressione

- sprite e UI: lossless;
- normal map: tipo Normal Map;
- audio breve: WAV o OGG senza normalizzazione automatica distruttiva;
- musica lunga: OGG in streaming;
- evitare compressione lossy su icone, testo rasterizzato e pixel art.

## Ambiente isometrico (manifest)

`environment/isometric/manifest.json` e la fonte di verita per gli oggetti
ambientali del bioma (ostacoli, bordi, casse, cliff, passaggi). Per ogni id
definisce categoria, `collision_shape`, `footprint_tiles`, flag `blocks_*`,
`is_jumpable_gap_anchor` e `sort_offset` usato dall'ombra a terra e dal Y-sort.

- Il loader `game/modes/zombie/isometric_environment_manifest.gd` legge e valida
  il manifest; `ObstacleSystem` lo usa per `sort_offset` e flag di blocco.
- `visual_scene` che punta a uno script `.gd` (o vuoto) significa rendering
  procedurale: nessun file esterno e obbligatorio per il bootstrap.
- Lo smoke `tests/isometric_environment_manifest_smoke_test.gd` verifica che ogni
  `obstacle_id` dei biomi sia descritto, che nessun oggetto richieda asset
  esterni e che collisione/footprint/Y-sort restino coerenti.
- Per convertire un oggetto in arte esterna: aggiungere la risorsa al nodo
  presentazionale mantenendo il draw procedurale come fallback, aggiornare lo
  `status` nel manifest e registrare la licenza in `ATTRIBUTION.md`.

## Sostituzione Placeholder

1. Conservare controller, collisioni e timing esistenti.
2. Aggiungere la risorsa visuale opzionale al nodo presentazionale.
3. Mantenere il draw procedurale come fallback.
4. Verificare silhouette, telegraph e contrasto con tutti i profili M21.
5. Registrare autore, URL, licenza e modifiche in `ATTRIBUTION.md`.

## Checklist Import

- filtering coerente con il tipo di asset;
- mipmap disattivate per pixel art e UI;
- compressione lossless per sprite gameplay;
- dimensioni e pivot verificati;
- nessun asset esterno obbligatorio per il bootstrap;
- licenza compatibile con distribuzione e modifica;
- QA default, reduced motion e high contrast completata.

