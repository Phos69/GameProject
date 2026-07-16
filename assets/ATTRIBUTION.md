# Asset Attribution

Aggiornare questa tabella prima di aggiungere qualsiasi asset esterno al
repository o alla build.

| Asset | Autore | Origine | Licenza | Modifiche |
| --- | --- | --- | --- | --- |
| Visual procedurali correnti | Progetto Local Action Sandbox | Repository locale | Codice del progetto | Generati a runtime |
| Cue audio procedurali correnti | Progetto Local Action Sandbox | Repository locale | Codice del progetto | Sintesi a runtime |
| Contratto asset ambiente top-down | Progetto Local Action Sandbox | `assets/environment/top_down/manifest.json` | Originali del progetto | Inventario asset-driven `orthogonal_top_down` con volume prospettico controllato, SVG e raster; fallback espliciti e nessun asset esterno obbligatorio |
| Asset ambiente SVG generati | Progetto Local Action Sandbox | `assets/environment/top_down/**/*.svg` | Originali del progetto | Generati da `tools/generate_top_down_environment_assets.gd`; restano attivi per i biomi non ancora migrati al raster |
| 195 raster terreno/cliff per bioma | Progetto Local Action Sandbox con OpenAI image generation | Generazione interna, `assets/environment/top_down/generated_images/` | Originali del progetto | Cornici e gutter rimossi; matte dei cutout convertito in alpha da `prepare_top_down_biome_assets.gd`; 133 asset attivi inclusi i road border definiti e set `desert`/`forest` non assegnati |
| `forest_tree_3x3.png` | Progetto Local Action Sandbox con OpenAI image generation | Generazione interna 2026-06-20 | Originale del progetto | Rimossi chroma key e sfondo; downscale runtime deterministico dal manifest, nessun asset esterno incorporato |
| 23 sorgenti prop cardinali individuali | Progetto Local Action Sandbox | `assets/environment/top_down/objects/generated_props/*.svg` | Originali del progetto | Generati internamente con source `project_svg_generator` e attribution `environment_top_down_internal`; restano runtime per i biomi non migrati e sostituiscono le vecchie risorse AtlasTexture `.tres` |
| 10 prop raster della Pianura Infetta | Progetto Local Action Sandbox con OpenAI image generation | Generazione interna 2026-07-16, `assets/environment/top_down/objects/generated_raster/infected_plains/` | Originali del progetto | Otto prop ambientali piu casse comune/medica; background `#ff00ff` convertito in alpha con soft matte/despill, prompt e processing registrati in `generation_manifest.json`; nessun asset esterno incorporato |
| `cliff_face_generated.png`, `cliff_face_generated_v2.png`, `cliff_lip_generated.png` | Progetto Local Action Sandbox con OpenAI image generation | Generazione interna 2026-06-21 | Originali del progetto | Texture seamless full-bleed; la v2 del fronte usa masse rocciose piu larghe e midtone piu chiari per la scala runtime; import limitato a 512 px con mipmap, UV world-space e dissolvenza nel void |
| `rock_plateau_top_generated.png` | Progetto Local Action Sandbox con OpenAI image generation | Generazione interna 2026-06-22 | Originale del progetto | Materiale top-down full-bleed per il top delle aree rocciose; lastre irregolari, crepe e muschio coerenti con i cliff v2; import limitato a 512 px con mipmap e UV world-space |
| `rock_cliff_face_upward_generated.png` | Progetto Local Action Sandbox con OpenAI image generation | Generazione interna 2026-06-22 | Originale del progetto | Materiale full-bleed per facce cliff rialzate; fratture e colonne rocciose orientate dal basso verso l'alto, import limitato a 512 px con mipmap e UV world-space |
| Raster terreno forestale `*_generated*.png`, `*_defined.png` e `grass_cliff_edge*_generated*.png` | Progetto Local Action Sandbox con OpenAI image generation | Generazione interna 2026-06-21/22/07-08 | Originali del progetto | Materiali full-bleed per prato, terra, asfalto, bordo strada definito e raccordi prato/terra/asfalto/roccia; i cliff usano bordi lineari orizzontali/verticali con angoli risolti dalla geometria; import limitato a 512 px con mipmap e UV world-space runtime |
| Oggetti ambientali top-down procedurali | Progetto Local Action Sandbox | `assets/environment/top_down/manifest.json` + `game/modes/zombie/biome_obstacle.gd` | Codice del progetto | Render procedurale ortogonale con volume controllato usato come fallback tecnico |
| Asset personaggi RPG (7) | Progetto Local Action Sandbox | `assets/characters/*` (SVG testuali + portrait PNG) | Originali del progetto | Autorati in-repo; nessun asset esterno; gameplay procedurale di fallback |
| Pittogrammi personaggi RPG (7) e zombie regolari/elite (8) | Progetto Local Action Sandbox con OpenAI image generation | Generazione interna 2026-07-14, `assets/characters/*/sprites/*_gameplay_pictogram.png` e `assets/sprites/enemies/zombie/` | Originali del progetto | Atlanti su chroma key convertiti in alpha con soft matte/despill, crop deterministico `4x2`, canvas `512x512`; manifest locali con prompt sintetico; fallback procedurale runtime |
| Sprite `grave_colossus`, `gore_charger`, `plague_spitter`, `bone_mortar`, `carrion_shepherd` | Progetto Local Action Sandbox con OpenAI image generation | Generazione interna 2026-07-13, `assets/sprites/bosses/zombie/` | Originali del progetto | Background chroma key rimosso in alpha, bordo morbido/despill; import non pixel-art limitato a 512 px; fallback procedurale runtime |

## Regole

- Conservare una copia della licenza quando richiesto.
- Indicare l'URL originale e la data di acquisizione.
- Documentare crop, recolor, remix, conversione e derivazioni.
- Non usare asset con licenza sconosciuta o incompatibile.
- Per pacchetti, elencare almeno pacchetto, autore, URL e file effettivamente
  inclusi nella build.
