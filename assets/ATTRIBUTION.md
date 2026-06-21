# Asset Attribution

Aggiornare questa tabella prima di aggiungere qualsiasi asset esterno al
repository o alla build.

| Asset | Autore | Origine | Licenza | Modifiche |
| --- | --- | --- | --- | --- |
| Visual procedurali correnti | Progetto Iso Local Sandbox | Repository locale | Codice del progetto | Generati a runtime |
| Cue audio procedurali correnti | Progetto Iso Local Sandbox | Repository locale | Codice del progetto | Sintesi a runtime |
| Contratto asset ambiente isometrico v7 | Progetto Iso Local Sandbox | `assets/environment/isometric/manifest.json` | Originali del progetto | Inventario asset-driven pianificato con `needs_asset` e fallback espliciti; nessun asset esterno obbligatorio |
| Asset ambiente SVG generati | Progetto Iso Local Sandbox | `assets/environment/isometric/**/*.svg` | Originali del progetto | Generati da `tools/generate_isometric_environment_assets.gd`; 108 asset base trasparenti/sostituibili con silhouette isometriche dedicate |
| `forest_tree_3x3.png`, `large_rock_3x3.png` | Progetto Iso Local Sandbox con OpenAI image generation | Generazione interna 2026-06-20 | Originali del progetto | Rimossi chroma key e sfondo; downscale runtime deterministico dal manifest, nessun asset esterno incorporato |
| `cliff_face_generated.png`, `cliff_face_generated_v2.png`, `cliff_lip_generated.png` | Progetto Iso Local Sandbox con OpenAI image generation | Generazione interna 2026-06-21 | Originali del progetto | Texture seamless full-bleed; la v2 del fronte usa masse rocciose piu larghe e midtone piu chiari per la scala runtime; import limitato a 512 px con mipmap, UV world-space e dissolvenza nel void |
| Raster terreno forestale `*_generated*.png` e `grass_cliff_edge_generated.png` | Progetto Iso Local Sandbox con OpenAI image generation | Generazione interna 2026-06-21 | Originali del progetto | Materiali seamless full-bleed per prato, terra, asfalto e raccordi prato/terra/asfalto/roccia; import limitato a 512 px con mipmap e UV world-space runtime |
| Oggetti ambientali isometrici procedurali | Progetto Iso Local Sandbox | `assets/environment/isometric/manifest.json` + `game/modes/zombie/biome_obstacle.gd` | Codice del progetto | Render procedurale usato come fallback tecnico controllato |
| Asset personaggi RPG (7) | Progetto Iso Local Sandbox | `assets/characters/*` (SVG testuali + portrait PNG) | Originali del progetto | Autorati in-repo; nessun asset esterno; gameplay procedurale di fallback |

## Regole

- Conservare una copia della licenza quando richiesto.
- Indicare l'URL originale e la data di acquisizione.
- Documentare crop, recolor, remix, conversione e derivazioni.
- Non usare asset con licenza sconosciuta o incompatibile.
- Per pacchetti, elencare almeno pacchetto, autore, URL e file effettivamente
  inclusi nella build.
