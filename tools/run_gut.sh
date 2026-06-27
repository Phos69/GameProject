#!/usr/bin/env bash
# Esegue la suite GUT (tests/suites/**) in UN SOLO processo Godot.
#
# A differenza di run_tests.sh (un processo per file, suite legacy), GUT fa boot
# dell'engine una sola volta e raccoglie tutti i `*_test.gd` sotto tests/suites/.
#
# Uso:
#   tools/run_gut.sh [-d res://tests/suites/<area>] [-s <select>]
# Esempi:
#   tools/run_gut.sh                          # solo le suite golden (default)
#   GUT_CONFIG=res://.gutconfig.json tools/run_gut.sh   # tutta la suite
#   tools/run_gut.sh -d res://tests/suites/world_gen
#
# DEFAULT solo-golden: per ora la suite gira unicamente sul mondo golden
# (.gutconfig.golden.json). Per tutta la suite usa GUT_CONFIG=res://.gutconfig.json.
#
# Variabili d'ambiente:
#   GODOT        path/comando del binario Godot (default: "godot")
#   GUT_CONFIG   config GUT da usare (default: res://.gutconfig.golden.json)
#   SKIP_IMPORT  se "1", salta l'import iniziale delle risorse

set -u

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

GODOT="${GODOT:-godot}"
GUT_CONFIG="${GUT_CONFIG:-res://.gutconfig.golden.json}"

if ! command -v "$GODOT" >/dev/null 2>&1 && [ ! -x "$GODOT" ]; then
	echo "ERRORE: binario Godot non trovato (comando: '$GODOT')." >&2
	echo "Imposta la variabile GODOT con il path corretto." >&2
	exit 127
fi

EXTRA_ARGS=("$@")

if [ "${SKIP_IMPORT:-0}" != "1" ]; then
	echo "==> Import risorse (una tantum)..."
	"$GODOT" --headless --import --path . >/dev/null 2>&1 || true
fi

echo "==> GUT run (un solo processo, config: $GUT_CONFIG)..."
"$GODOT" --headless -s res://addons/gut/gut_cmdln.gd \
	-gconfig="$GUT_CONFIG" -gexit "${EXTRA_ARGS[@]}"
