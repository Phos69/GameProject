#!/usr/bin/env bash
# Esegue la suite di test headless (tests/*.gd) e aggrega gli exit code.
#
# Ogni test e uno script `extends SceneTree` che termina con `quit(0)` (pass)
# o `quit(1)` (fail). Lo runner lancia Godot una volta per file e considera
# il test fallito se l'exit code non e 0 o se va in timeout.
#
# Uso:
#   tools/run_tests.sh [pattern] [all|fast|slow|soak|visual]
# Esempi:
#   tools/run_tests.sh                 # tutti i test non visual QA
#   tools/run_tests.sh biome           # solo i test che matchano "biome"
#   tools/run_tests.sh "" fast         # suite fast
#
# Variabili d'ambiente:
#   GODOT              path/comando del binario Godot (default: "godot")
#   TEST_TIMEOUT       timeout per singolo test in secondi (default: 180)
#   TEST_CATEGORY      categoria default: all, fast, slow, soak, visual
#   TEST_LOG_DIR       cartella log (default: build/test_logs)
#   SKIP_IMPORT        se "1", salta l'import iniziale delle risorse
#   INCLUDE_VISUAL_QA  se "1", include visual QA anche in categoria all

set -u

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

GODOT="${GODOT:-godot}"
TEST_TIMEOUT="${TEST_TIMEOUT:-180}"
FILTER="${1:-}"
CATEGORY="${TEST_CATEGORY:-${2:-all}}"
LOG_DIR="${TEST_LOG_DIR:-build/test_logs}"

case "$CATEGORY" in
	all|fast|slow|soak|visual) ;;
	*)
		echo "ERRORE: categoria test non valida: '$CATEGORY' (usa all, fast, slow, soak, visual)." >&2
		exit 2
		;;
esac

if ! command -v "$GODOT" >/dev/null 2>&1; then
	echo "ERRORE: binario Godot non trovato (comando: '$GODOT')." >&2
	echo "Imposta la variabile GODOT con il path corretto." >&2
	exit 127
fi

mkdir -p "$LOG_DIR"
RUN_STAMP="$(date +%Y%m%d_%H%M%S)"

classify_test() {
	local name
	name="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
	case "$name" in
		*_visual_qa.gd|*_qa.gd)
			printf 'visual'
			return
			;;
	esac
	case "$name" in
		*soak*|*stress*|*ten_wave*)
			printf 'soak'
			return
			;;
	esac
	case "$name" in
		*biome_world_generation*|\
		*forest_isometric_texture_transition*|\
		*milestone_10_asset_fallback_policy*|\
		*milestone_11_weapon_drop_progression*|\
		*milestone_10_cross_biome_chase*|\
		*milestone_10_full_region_streaming*|\
		*milestone_10_isometric_performance*|\
		*milestone_10_no_portal_transition*|\
		*milestone_10_tile_layer*|\
		*open_passage_transition*)
			printf 'slow'
			return
			;;
	esac
	printf 'fast'
}

# Import iniziale delle risorse: necessario su checkout pulito (CI) perche i
# test caricano main.tscn e risorse importate.
if [ "${SKIP_IMPORT:-0}" != "1" ]; then
	echo "==> Import risorse (una tantum)..."
	import_log="$LOG_DIR/${RUN_STAMP}_import.log"
	if command -v timeout >/dev/null 2>&1; then
		timeout 300 "$GODOT" --headless --import --path . >"$import_log" 2>&1
		import_code=$?
		if [ "$import_code" -eq 124 ]; then
			echo "ERRORE: import risorse in timeout (log: $import_log)." >&2
			exit 1
		fi
	else
		"$GODOT" --headless --import --path . >"$import_log" 2>&1
		import_code=$?
	fi
	if [ "$import_code" -ne 0 ]; then
		echo "ATTENZIONE: import risorse terminato con exit $import_code, continuo (log: $import_log)." >&2
	fi
fi

# Selezione, per timeout robusto: usa `timeout` se disponibile.
if command -v timeout >/dev/null 2>&1; then
	RUN_WITH_TIMEOUT=(timeout "$TEST_TIMEOUT")
else
	RUN_WITH_TIMEOUT=()
fi

shopt -s nullglob
tests=(tests/*.gd)
shopt -u nullglob

if [ "${#tests[@]}" -eq 0 ]; then
	echo "Nessun test trovato in tests/*.gd" >&2
	exit 1
fi

passed=0
failed=0
selected=0
skipped_category=0
skipped_visual=0
failed_names=()

echo "==> Esecuzione suite di test (${#tests[@]} file, categoria: ${CATEGORY}, timeout: ${TEST_TIMEOUT}s)"
echo

for test_file in "${tests[@]}"; do
	name="$(basename "$test_file")"
	if [ -n "$FILTER" ] && [[ "$name" != *"$FILTER"* ]]; then
		continue
	fi
	# Esegui solo gli script-test (SceneTree); salta gli helper condivisi.
	if ! grep -q "^extends SceneTree" "$test_file"; then
		continue
	fi

	test_category="$(classify_test "$name")"
	if [ "$CATEGORY" != "all" ] && [ "$test_category" != "$CATEGORY" ]; then
		skipped_category=$((skipped_category + 1))
		continue
	fi
	if [ "$test_category" = "visual" ] && [ "$CATEGORY" != "visual" ] && [ "${INCLUDE_VISUAL_QA:-0}" != "1" ]; then
		skipped_visual=$((skipped_visual + 1))
		continue
	fi

	selected=$((selected + 1))
	log_file="$LOG_DIR/${RUN_STAMP}_${name%.gd}.log"
	"${RUN_WITH_TIMEOUT[@]}" "$GODOT" --headless --path . --script "$test_file" >"$log_file" 2>&1
	code=$?

	if [ "$code" -eq 0 ]; then
		passed=$((passed + 1))
		printf "  PASS  %s (log: %s)\n" "$name" "$log_file"
	else
		failed=$((failed + 1))
		failed_names+=("$name")
		if [ "$code" -eq 124 ]; then
			printf "  TIMEOUT  %s (oltre %ss, log: %s)\n" "$name" "$TEST_TIMEOUT" "$log_file"
		else
			printf "  FAIL  %s (exit %s, log: %s)\n" "$name" "$code" "$log_file"
		fi
		# Mostra le ultime righe di output per il debug.
		sed 's/^/        | /' "$log_file" | tail -n 15
	fi
done

echo
echo "==> Risultato: ${passed} passati, ${failed} falliti, ${skipped_category} saltati (categoria), ${skipped_visual} saltati (visual_qa)"
if [ "$selected" -eq 0 ]; then
	echo "    Nessun test eseguibile selezionato. Controlla pattern, categoria o INCLUDE_VISUAL_QA." >&2
	exit 1
fi
if [ "$failed" -ne 0 ]; then
	printf '    Falliti:\n'
	for n in "${failed_names[@]}"; do printf '      - %s\n' "$n"; done
	exit 1
fi
exit 0
