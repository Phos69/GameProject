#!/usr/bin/env bash
# Esegue l'intera suite di test headless (tests/*.gd) e aggrega gli exit code.
#
# Ogni test e uno script `extends SceneTree` che termina con `quit(0)` (pass)
# o `quit(1)` (fail). Lo runner lancia Godot una volta per file e considera
# il test fallito se l'exit code non e 0 o se va in timeout.
#
# Uso:
#   tools/run_tests.sh [pattern]
# Esempi:
#   tools/run_tests.sh                 # tutti i test
#   tools/run_tests.sh biome           # solo i test che matchano "biome"
#
# Variabili d'ambiente:
#   GODOT          path/comando del binario Godot (default: "godot")
#   TEST_TIMEOUT   timeout per singolo test in secondi (default: 180)
#   SKIP_IMPORT    se "1", salta l'import iniziale delle risorse

set -u

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

GODOT="${GODOT:-godot}"
TEST_TIMEOUT="${TEST_TIMEOUT:-180}"
FILTER="${1:-}"

if ! command -v "$GODOT" >/dev/null 2>&1; then
	echo "ERRORE: binario Godot non trovato (comando: '$GODOT')." >&2
	echo "Imposta la variabile GODOT con il path corretto." >&2
	exit 127
fi

# Import iniziale delle risorse: necessario su checkout pulito (CI) perche i
# test caricano main.tscn e risorse importate.
if [ "${SKIP_IMPORT:-0}" != "1" ]; then
	echo "==> Import risorse (una tantum)..."
	timeout 300 "$GODOT" --headless --import --path . >/dev/null 2>&1 || true
fi

# Selezione, per timeout robusto: usa `timeout` se disponibile.
if command -v timeout >/dev/null 2>&1; then
	RUN_WITH_TIMEOUT="timeout ${TEST_TIMEOUT}"
else
	RUN_WITH_TIMEOUT=""
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
failed_names=()

echo "==> Esecuzione suite di test (${#tests[@]} file)"
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

	$RUN_WITH_TIMEOUT "$GODOT" --headless --path . --script "$test_file" >/tmp/test_out.$$ 2>&1
	code=$?

	if [ "$code" -eq 0 ]; then
		passed=$((passed + 1))
		printf "  PASS  %s\n" "$name"
	else
		failed=$((failed + 1))
		failed_names+=("$name")
		if [ "$code" -eq 124 ]; then
			printf "  TIMEOUT  %s (oltre %ss)\n" "$name" "$TEST_TIMEOUT"
		else
			printf "  FAIL  %s (exit %s)\n" "$name" "$code"
		fi
		# Mostra le ultime righe di output per il debug.
		sed 's/^/        | /' /tmp/test_out.$$ | tail -n 15
	fi
done
rm -f /tmp/test_out.$$

echo
echo "==> Risultato: ${passed} passati, ${failed} falliti"
if [ "$failed" -ne 0 ]; then
	printf '    Falliti:\n'
	for n in "${failed_names[@]}"; do printf '      - %s\n' "$n"; done
	exit 1
fi
exit 0
