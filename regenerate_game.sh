#!/bin/bash

# Rigenerazione completa del progetto Godot
# Questo script pulisce tutte le cache e i file generati, forzando una rigenerazione completa

echo ""
echo "======================================"
echo "Rigenerazione Completa Progetto Godot"
echo "======================================"
echo ""

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Funzione per rimuovere directory con controllo
remove_directory_if_exists() {
    local path=$1
    local description=$2

    if [ -d "$path" ]; then
        echo "🗑️  Eliminando $description..."
        rm -rf "$path"

        if [ $? -eq 0 ]; then
            echo "✅ $description eliminato"
        else
            echo "⚠️  Errore nell'eliminazione di $description"
        fi
    fi
}

# 1. Eliminare cache .godot
echo ""
echo "[1/5] Pulizia cache Godot..."
remove_directory_if_exists "$PROJECT_ROOT/.godot" ".godot cache"

# 2. Eliminare cartella build
echo ""
echo "[2/5] Pulizia build..."
remove_directory_if_exists "$PROJECT_ROOT/build" "cartella build"

# 3. Eliminare cartella exported
echo ""
echo "[3/5] Pulizia export..."
remove_directory_if_exists "$PROJECT_ROOT/.godot/exported" "exported cache"

# 4. Ripulire file temporanei
echo ""
echo "[4/5] Pulizia file temporanei..."
find "$PROJECT_ROOT" -maxdepth 1 -name "*.tmp" -type f -delete 2>/dev/null && echo "✅ File temporanei eliminati" || true

# 5. Ricreazione cartella .godot
echo ""
echo "[5/5] Ricreazione struttura Godot..."
if [ ! -d "$PROJECT_ROOT/.godot" ]; then
    mkdir -p "$PROJECT_ROOT/.godot"
    echo "✅ Cartella .godot ricreata"
fi

echo ""
echo "======================================"
echo "✨ Rigenerazione completata!"
echo "======================================"
echo ""
echo "Prossimi passi:"
echo "1. Apri Godot Editor (il progetto verrà rigenerato automaticamente)"
echo "2. Attendi il completamento dell'importazione delle risorse"
echo "3. Verifica che tutto funzioni correttamente"
echo ""
