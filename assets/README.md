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

