#!/usr/bin/env bash
# Esegue la suite GUT (tests/suites/**) in UN SOLO processo Godot.
#
# A differenza di run_tests.sh (un processo per file, suite legacy), GUT fa boot
# dell'engine una sola volta e raccoglie tutti i `*_test.gd` sotto tests/suites/.
#
# Uso:
#   tools/run_gut.sh [--golden] [<extra gut args>...]
# Esempi:
#   tools/run_gut.sh                          # tutte le suite logiche rapide
#   tools/run_gut.sh --golden                 # solo le suite golden
#   tools/run_gut.sh -gdir=res://tests/suites/world_gen
#
# Default: suite logiche rapide (.gutconfig.json), come README e CI. La config
# golden resta disponibile con --golden o GUT_CONFIG=res://.gutconfig.golden.json.
#
# Variabili d'ambiente:
#   GODOT        path/comando del binario Godot (default: "godot")
#   GUT_CONFIG   config GUT da usare (default: res://.gutconfig.json)
#   SKIP_IMPORT  se "1", salta l'import iniziale delle risorse

set -u

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

GODOT="${GODOT:-godot}"
GUT_CONFIG="${GUT_CONFIG:-res://.gutconfig.json}"

if command -v "$GODOT" >/dev/null 2>&1; then
	GODOT_BIN="$(command -v "$GODOT")"
elif [ -x "$GODOT" ]; then
	GODOT_BIN="$GODOT"
else
	echo "ERRORE: binario Godot non trovato (comando: '$GODOT')." >&2
	echo "Imposta la variabile GODOT con il path corretto." >&2
	exit 127
fi

case "$(basename "$GODOT_BIN" | tr '[:upper:]' '[:lower:]')" in
	godot.exe)
		console_candidate="$(dirname "$GODOT_BIN")/godot_console.exe"
		if [ -x "$console_candidate" ]; then
			GODOT_BIN="$console_candidate"
		fi
		;;
esac

EXTRA_ARGS=()
HAS_JUNIT_REPORT=0
for arg in "$@"; do
	case "$arg" in
		--golden)
			GUT_CONFIG="res://.gutconfig.golden.json"
			;;
		-gjunit_xml_file|-gjunit_xml_file=*)
			HAS_JUNIT_REPORT=1
			EXTRA_ARGS+=("$arg")
			;;
		*)
			EXTRA_ARGS+=("$arg")
			;;
	esac
done

JUNIT_REPORT=""
if [ "$HAS_JUNIT_REPORT" -eq 0 ]; then
	mkdir -p build/test_logs
	config_name="${GUT_CONFIG##*/}"
	config_slug="${config_name%.json}"
	config_slug="${config_slug#.}"
	config_slug="$(printf '%s' "$config_slug" | tr -c 'A-Za-z0-9_-' '_')"
	run_stamp="$(date +%Y%m%d_%H%M%S)"
	JUNIT_REPORT="res://build/test_logs/gut_${config_slug}_${run_stamp}.xml"
	EXTRA_ARGS+=("-gjunit_xml_file=$JUNIT_REPORT")
fi

if [ "${SKIP_IMPORT:-0}" != "1" ]; then
	echo "==> Import risorse (una tantum)..."
	"$GODOT_BIN" --headless --import --path . >/dev/null 2>&1 || true
fi

echo "==> GUT run (un solo processo, config: $GUT_CONFIG)..."
"$GODOT_BIN" --headless -s res://addons/gut/gut_cmdln.gd \
	-gconfig="$GUT_CONFIG" -gexit "${EXTRA_ARGS[@]}"
code=$?
if [ -n "$JUNIT_REPORT" ]; then
	echo "==> GUT JUnit report: $JUNIT_REPORT"
fi
if [ "$code" -eq 0 ]; then
	echo "==> GUT result: PASS (exit code 0, config: $GUT_CONFIG)"
else
	echo "==> GUT result: FAIL (exit code $code, config: $GUT_CONFIG)" >&2
fi
exit "$code"
