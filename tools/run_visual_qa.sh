#!/usr/bin/env bash
# Esegue i tool Visual QA (tests/visual_qa/*.gd) uno per file.
#
# I Visual QA NON sono test logici: producono screenshot/griglie sotto build/qa
# per l'ispezione manuale e richiedono un contesto di rendering (non headless).
# Per questo vivono fuori dalla suite GUT della CI e si lanciano su richiesta,
# localmente o in un job notturno con display virtuale (xvfb).
#
# Uso:
#   tools/run_visual_qa.sh [pattern]
# Esempi:
#   tools/run_visual_qa.sh              # tutti i Visual QA
#   tools/run_visual_qa.sh weapon       # solo quelli che matchano "weapon"
#
# Variabili d'ambiente:
#   GODOT             path/comando del binario Godot (default: "godot")
#   QA_RENDER         rendering method (default: gl_compatibility)
#   SKIP_IMPORT       se "1", salta l'import iniziale delle risorse
#   QA_LOG_DIR        cartella log (default: build/qa_logs)

set -u

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

GODOT="${GODOT:-godot}"
QA_RENDER="${QA_RENDER:-gl_compatibility}"
FILTER="${1:-}"
LOG_DIR="${QA_LOG_DIR:-build/qa_logs}"

if ! command -v "$GODOT" >/dev/null 2>&1 && [ ! -x "$GODOT" ]; then
	echo "ERRORE: binario Godot non trovato (comando: '$GODOT')." >&2
	exit 127
fi

mkdir -p "$LOG_DIR"
RUN_STAMP="$(date +%Y%m%d_%H%M%S)"

if [ "${SKIP_IMPORT:-0}" != "1" ]; then
	echo "==> Import risorse (una tantum)..."
	"$GODOT" --headless --import --path . >/dev/null 2>&1 || true
fi

shopt -s nullglob
qa_files=(tests/visual_qa/*.gd)
shopt -u nullglob
helper_files=(
	"weapon_visual_identity_qa_board.gd"
	"weapon_visual_identity_survival_qa.gd"
)
standalone_qa_files=()
for qa_file in "${qa_files[@]}"; do
	name="$(basename "$qa_file")"
	if [[ " ${helper_files[*]} " != *" ${name} "* ]]; then
		standalone_qa_files+=("$qa_file")
	fi
done
qa_files=("${standalone_qa_files[@]}")

if [ "${#qa_files[@]}" -eq 0 ]; then
	echo "Nessun Visual QA trovato in tests/visual_qa/*.gd" >&2
	exit 1
fi

passed=0
failed=0
selected=0
failed_names=()

echo "==> Visual QA (${#qa_files[@]} file, rendering: ${QA_RENDER})"
for qa_file in "${qa_files[@]}"; do
	name="$(basename "$qa_file")"
	if [ -n "$FILTER" ] && [[ "$name" != *"$FILTER"* ]]; then
		continue
	fi
	selected=$((selected + 1))
	log_file="$LOG_DIR/${RUN_STAMP}_${name%.gd}.log"
	"$GODOT" --path . --rendering-method "$QA_RENDER" --script "$qa_file" >"$log_file" 2>&1
	code=$?
	if [ "$code" -eq 0 ]; then
		passed=$((passed + 1))
		printf "  OK    %s (log: %s)\n" "$name" "$log_file"
	else
		failed=$((failed + 1))
		failed_names+=("$name")
		printf "  FAIL  %s (exit %s, log: %s)\n" "$name" "$code" "$log_file"
	fi
done

echo
echo "==> Risultato Visual QA: ${passed} ok, ${failed} falliti"
if [ "$selected" -eq 0 ]; then
	echo "    Nessun Visual QA selezionato (controlla il pattern)." >&2
	exit 1
fi
if [ "$failed" -ne 0 ]; then
	for n in "${failed_names[@]}"; do printf '      - %s\n' "$n"; done
	exit 1
fi
exit 0
