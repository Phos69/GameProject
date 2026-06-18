#!/bin/sh
# Installa i git hooks del progetto in .git/hooks/
# Esegui una volta dopo ogni clone: sh tools/install_hooks.sh

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOKS_SOURCE="$PROJECT_ROOT/tools/hooks"
HOOKS_TARGET="$PROJECT_ROOT/.git/hooks"

if [ ! -d "$HOOKS_TARGET" ]; then
    echo "Errore: .git/hooks non trovato. Sei nella root del progetto?"
    exit 1
fi

installed=0
for hook in "$HOOKS_SOURCE"/*; do
    name="$(basename "$hook")"
    cp "$hook" "$HOOKS_TARGET/$name"
    chmod +x "$HOOKS_TARGET/$name"
    installed=$((installed + 1))
    echo "Hook installato: $name"
done

echo ""
echo "$installed hook(s) installati in .git/hooks/"
echo "I file .import verranno ora auto-staged ad ogni commit."
