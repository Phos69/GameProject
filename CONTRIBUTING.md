# CONTRIBUTING

Questo repository e pensato per essere gestito principalmente da agenti IA, ma le regole restano quelle di un progetto software normale.

## Workflow

1. Leggere `AGENTS.md`.
2. Verificare lo stato Git.
3. Identificare milestone e TODO collegati.
4. Fare modifiche piccole e coerenti.
5. Testare la scena principale o la checklist collegata.
6. Aggiornare documentazione e changelog.
7. Preparare commit atomico.

## Qualita minima

- Il progetto deve restare apribile in Godot.
- La scena principale deve continuare ad avviarsi.
- I sistemi condivisi devono restare modulari.
- Le modalita non devono duplicare codice comune.

## Test automatici

La suite vive in `tests/`. Ogni test e uno script `extends SceneTree` con
`_initialize()` che termina con `quit(0)` (pass) o `quit(1)` (fail); l'exit code
di Godot riflette quindi l'esito. Gli script `extends RefCounted` in `tests/`
sono helper condivisi e non vengono eseguiti dal runner.

Esecuzione dell'intera suite:

```bash
# Linux / macOS / Git Bash
tools/run_tests.sh

# Windows PowerShell
./tools/run_tests.ps1
```

Eseguire un sottoinsieme (match sul nome file):

```bash
tools/run_tests.sh biome
./tools/run_tests.ps1 -Filter biome
```

Singolo test:

```bash
godot --headless --path . --script tests/<nome_test>.gd
```

Variabili utili: `GODOT` (path del binario, default `godot`), `TEST_TIMEOUT`
(secondi per test, default 180), `SKIP_IMPORT=1` (salta l'import iniziale quando
la cache `.godot/` e gia popolata).

La CI ([.github/workflows/ci.yml](.github/workflows/ci.yml)) esegue la stessa
suite su ogni push e PR verso `master`.

## Test manuali

Ogni modifica gameplay deve indicare:

- scena da aprire;
- input da usare;
- comportamento atteso;
- regressioni da controllare.

## Policy file `.import`

I file `*.import` accanto alle risorse **vanno versionati**: contengono la
mappatura UID e i parametri di import che Godot richiede per aprire il progetto
in modo deterministico (anche in CI). Va invece ignorata la sola cache
`.godot/` (gia in `.gitignore`). Non rimuovere i `*.import` dal versionamento.

