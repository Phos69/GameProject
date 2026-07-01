# GameProject MCP Server

Server MCP locale read-only per `Iso Local Sandbox`. Espone a Codex e ad altri client MCP un set di tool strutturati per leggere il contesto del progetto, interrogare architettura/roadmap/asset, cercare codice e avviare solo controlli allowlisted.

## Posizione e stack

- Cartella: `tools/mcp-server/`
- Runtime: Node.js 20+
- Linguaggio: TypeScript
- SDK: `@modelcontextprotocol/sdk`
- Transport: `stdio`
- Root progetto: rilevata automaticamente risalendo dalla posizione del server fino alla cartella che contiene `project.godot` (la root del repo), indipendentemente da dove è clonato; override opzionale con `PROJECT_MCP_ROOT`.

Il server non viene caricato da Godot e non modifica il runtime del gioco.

## Installazione

Da root repo:

```powershell
npm install --prefix tools/mcp-server
```

Se la versione locale di npm fallisce con `Cannot read properties of undefined (reading 'spec')` usando `--prefix`, entra nella cartella del package e rilancia:

```powershell
cd tools/mcp-server
npm install
```

## Script

Da root repo:

```powershell
npm run mcp:build
npm run mcp:test
npm run mcp:smoke
npm run mcp:start
npm run mcp:dev
```

Script equivalenti dalla cartella `tools/mcp-server/`:

```powershell
npm run build
npm run test
npm run smoke
npm run start
npm run dev
```

`mcp:smoke` compila il server, lo avvia via `stdio` con un client MCP e verifica che tool e prompt siano listabili.

## Configurazione Codex

Codex legge i server MCP da `config.toml`. Puoi usare la configurazione globale `~/.codex/config.toml` oppure una configurazione di progetto `.codex/config.toml` se il progetto e trusted. Non modificare automaticamente la configurazione globale: copia uno degli esempi sotto nel file che preferisci.

Esempio `config.toml` (sostituisci `<REPO_ROOT>` con il path assoluto del tuo clone locale, es. `C:\\Git\\GameProject`; è l'unico valore specifico della macchina, perché `--prefix` è relativo a `cwd` e la root del progetto viene rilevata da sola):

```toml
[mcp_servers.gameproject]
command = "npm"
args = ["--prefix", "tools/mcp-server", "run", "start"]
cwd = "<REPO_ROOT>"
startup_timeout_sec = 20
tool_timeout_sec = 120
enabled = true
```

Esempio CLI (esegui dalla root del repo):

```powershell
codex mcp add gameproject -- npm --prefix tools/mcp-server run start
```

Nel TUI Codex puoi usare `/mcp` per controllare che il server sia attivo.

## Sicurezza

Il server e read-only per default.

Cosa puo fare:

- leggere file testuali dentro la root del progetto;
- cercare testo con limiti su dimensione file e numero risultati;
- sintetizzare architettura, roadmap, TODO e asset partendo dai file reali;
- eseguire solo safe check allowlisted.

Cosa non puo fare:

- eseguire shell arbitraria;
- scrivere, cancellare o spostare file;
- uscire dalla root repo tramite path traversal;
- leggere `.env`, chiavi, token, credenziali o file sensibili;
- includere cartelle pesanti/cache/vendor per default, come `.git`, `.godot`, `build`, `dist`, `coverage`, `node_modules`, `addons/gut`.

Limiti principali:

- lettura file: default `200000` byte per file, cap `1000000`;
- ricerca: default `50` risultati, cap `200`;
- lista file: default `300` file, cap `2000`;
- output processi: troncato a `16000` caratteri;
- processi safe check: timeout per comando, con cap lato server.

## Tool

### `repo_overview`

Input: `{}`.

Output: JSON con stack, entrypoint, script package, stato documentazione, conteggi per area e estensioni.

Esempio:

```json
{}
```

### `list_project_files`

Elenca file filtrando per area.

Input:

```json
{
  "area": "zombie mode",
  "maxResults": 100,
  "includeIgnored": false,
  "includeLockfiles": false
}
```

Aree supportate: `all`, `gameplay`, `rendering`, `biomi`, `zombie mode`, `gui`, `assets`, `tests`, `docs`, `config`.

### `read_project_context`

Legge file testuali specifici, validando i path.

Input:

```json
{
  "paths": ["README.md", "res://game/main/main.gd"],
  "maxBytesPerFile": 20000
}
```

Path accettati: repo-relative, `res://...`, oppure assoluti purche dentro la root repo. File binari e sensibili vengono saltati.

### `search_project`

Cerca testo letterale nella repo.

Input:

```json
{
  "query": "class_name ZombieSpawner",
  "extensions": [".gd"],
  "directories": ["game/modes/zombie"],
  "caseSensitive": false,
  "maxResults": 20,
  "maxFileBytes": 250000
}
```

Output: path, riga, colonna e preview.

### `game_system_summary`

Input: `{}`.

Output: sintesi dei sistemi principali con evidenze file per zombie mode, player/input, armi/combat, nemici/boss, biomi/generazione, rendering isometrico, GUI/HUD e asset.

### `roadmap_context`

Input: `{}`.

Output: documenti trovati, backlog aperto da `TODO.md`, stati milestone da `ROADMAP.md` e segnali di debito/follow-up.

### `run_safe_check`

Esegue solo comandi allowlisted. Non accetta shell libera.

Lista check:

```json
{
  "check": "list"
}
```

Check disponibili:

- `gut:quick`
- `gut:golden`
- `gut:area`
- `godot:import`
- `asset:check`
- `mcp:build`
- `mcp:test`
- `mcp:smoke`

Esempio area GUT:

```json
{
  "check": "gut:area",
  "area": "combat",
  "timeoutMs": 120000
}
```

### `asset_inventory`

Input: `{}`.

Output: conteggi asset grafici/audio per categoria, esempi, placeholder/fallback evidenti, basename duplicati, asset manifest mancanti e candidati non referenziati.

Categorie: `player`, `zombie`, `weapons`, `projectiles`, `biomes`, `obstacles`, `ui`, `audio`, `other`.

### `codex_task_brief`

Produce un brief operativo partendo da un obiettivo testuale.

Input:

```json
{
  "goal": "Improve zombie spawn balance near hazards"
}
```

Output: file probabilmente coinvolti, sistemi impattati, rischi, test consigliati, criteri di accettazione e primi passi.

### `git_context`

Ispezione git read-only. Esegue solo sottocomandi allowlisted (`status`, `log`, `diff`), mai shell libera.

Input:

```json
{
  "command": "log",
  "maxCount": 20,
  "path": "game/modes/zombie",
  "staged": false
}
```

- `status`: stato del working tree in formato porcelain (stabile e indipendente dalla lingua).
- `log`: ultimi commit (`maxCount` con cap lato server), opzionalmente ristretti a `path`.
- `diff`: diff del working tree, oppure staged con `staged: true`; opzionalmente ristretto a `path`.

Il path è repo-relative, validato contro il traversal e passato dopo `--`. Output troncato al limite del server.

### `find_symbol`

Cerca dichiarazioni GDScript per nome in tutti i file `.gd`.

Input:

```json
{
  "query": "ZombieSpawner",
  "kind": ["class_name", "func"],
  "exact": false,
  "maxResults": 50
}
```

Tipi (`kind`) supportati: `class_name`, `inner_class`, `extends`, `func`, `signal`, `const`, `enum`. Senza `query` elenca tutte le dichiarazioni del tipo richiesto (utile per navigare, es. tutte le `class_name` della repo). Output: nome, tipo, path, riga e riga sorgente (`signature`).

## Prompt MCP

Il server espone questi template:

- `audit_isometric_generation`
- `improve_zombie_mode`
- `implement_roadmap_milestone`
- `refactor_gameplay_system`
- `asset_quality_pass`

Ogni prompt produce un messaggio orientato a usare prima tool di contesto e ricerca, poi eventuale implementazione.

## Test

Test automatici:

```powershell
npm run mcp:test
```

Coprono:

- validazione path e blocco traversal;
- esclusione file sensibili;
- ricerca con limiti;
- allowlist safe check;
- handler principali dei tool.

Manual/smoke MCP:

```powershell
npm run mcp:smoke
```

Output atteso: lista degli 11 tool e dei 5 prompt.
