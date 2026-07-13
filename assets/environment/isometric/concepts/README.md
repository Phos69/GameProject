# Biome prop concept sheets

Queste cinque tavole sono sia la direzione artistica sia la sorgente raster
runtime dei prop promossi dal manifest v10. Le regioni opache vengono esposte
senza ricampionamento da risorse Godot `AtlasTexture` in
`objects/generated_props/`: 20 grafiche alimentano 23 ID, conservando per ogni
oggetto footprint, anchor, collisione e Y-sort esistenti.

## Ordine dei quadranti

| Tavola | Alto sinistra | Alto destra | Basso sinistra | Basso destra |
| --- | --- | --- | --- | --- |
| `infected_plains_props_concept.png` | `ruined_house` | `abandoned_car` | `broken_fence` | `wood_barrier` |
| `toxic_wastes_props_concept.png` | `lab_block`/`lab_ruin` | `pipe_stack` | `toxic_barrel`/`chemical_barrel` | `industrial_fence`/`corroded_barrier` |
| `burning_fields_props_concept.png` | `burned_house` | `burned_car` | `charred_wall` | `scorched_barricade` |
| `frozen_outskirts_props_concept.png` | `snow_cabin` | `ice_rock` | `ice_block` | `snow_wall` |
| `drowned_marsh_props_concept.png` | `sunken_house` | `sunken_wreck` | `dead_tree` | `marsh_log` (`reed_wall` resta SVG) |

## Contratto visuale

- vista ortografica isometrica `2:1` coerente con il gioco;
- stylized realism pittorico, silhouette leggibile e materiali tematici;
- soggetti isolati, senza testo, logo, watermark, ombra proiettata o piano;
- `forest_tree_3x3.png` e `large_rock_3x3.png` usati come riferimenti di stile;
- sorgenti generate con background chroma uniforme `#ff00ff`, poi convertite
  localmente in PNG con alpha e despill;
- OpenAI image generation built-in; asset originali del progetto.

## Prompt di generazione

Prompt base comune: creare una tavola concept raster `2x2` per il bioma,
vista ortografica isometrica `2:1`, stylized realism pittorico coerente con i
riferimenti `forest_tree_3x3.png` e `large_rock_3x3.png`; quattro oggetti
isolati nei quadranti nell'ordine della tabella, ampio margine, nessuna
sovrapposizione, testo, logo, watermark, ombra o piano; sfondo piatto opaco
`#ff00ff` e silhouette nette. I soggetti specifici di ogni prompt sono gli ID
riportati nella tabella precedente.

Post-processing comune con `remove_chroma_key.py`: auto-key sul bordo, matte
morbido, soglia trasparente `12`, soglia opaca `220` e despill.

## Integrazione runtime

- Ogni risorsa `.tres` usa una regione stretta con margine alpha e
  `filter_clip = true`; i filename restano `snake_case` e includono il
  footprint a slot.
- `lab_block`/`lab_ruin`, i due barili e le due barriere tossiche condividono
  consapevolmente tre grafiche; i loro target size restano distinti nel
  manifest.
- Il quadrante palude in basso a destra rappresenta un tronco legato con
  canne ed e quindi assegnato solo a `marsh_log`. `reed_wall` conserva il suo
  SVG verticale `1x3`: ruotare o stirare il tronco avrebbe disallineato arte e
  collisione.
- I 23 contratti promossi sono `final`, con source
  `openai_image_generation`, licenza `Project original` e attribution
  `environment_isometric_openai`.
- Suite `assets`/`obstacles`, asset check e Visual QA verificano caricamento,
  alpha, regioni, scala runtime e footprint.

Restano 18 `object_scenes` SVG non rappresentati da queste tavole. La loro
eventuale sostituzione richiede nuova arte dedicata; non vanno aliasati a
soggetti semanticamente diversi.
