# Asset Attribution

Aggiornare questa tabella prima di aggiungere qualsiasi asset esterno al
repository o alla build.

| Asset | Autore | Origine | Licenza | Modifiche |
| --- | --- | --- | --- | --- |
| Visual procedurali correnti | Progetto Iso Local Sandbox | Repository locale | Codice del progetto | Generati a runtime |
| Cue audio procedurali correnti | Progetto Iso Local Sandbox | Repository locale | Codice del progetto | Sintesi a runtime |
| Contratto asset ambiente isometrico v7 | Progetto Iso Local Sandbox | `assets/environment/isometric/manifest.json` | Originali del progetto | Inventario asset-driven pianificato con `needs_asset` e fallback espliciti; nessun asset esterno obbligatorio |
| Oggetti ambientali isometrici procedurali | Progetto Iso Local Sandbox | `assets/environment/isometric/manifest.json` + `game/modes/zombie/biome_obstacle.gd` | Codice del progetto | Render procedurale usato come fallback tecnico controllato |
| Asset personaggi RPG (7) | Progetto Iso Local Sandbox | `assets/characters/*` (SVG testuali + portrait PNG) | Originali del progetto | Autorati in-repo; nessun asset esterno; gameplay procedurale di fallback |

## Regole

- Conservare una copia della licenza quando richiesto.
- Indicare l'URL originale e la data di acquisizione.
- Documentare crop, recolor, remix, conversione e derivazioni.
- Non usare asset con licenza sconosciuta o incompatibile.
- Per pacchetti, elencare almeno pacchetto, autore, URL e file effettivamente
  inclusi nella build.

