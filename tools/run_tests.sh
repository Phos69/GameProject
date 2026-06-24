#!/usr/bin/env bash
# DEPRECATO — il runner legacy "un processo per file" e stato ritirato.
#
# La suite di test e ora interamente GUT (un solo processo Godot):
#   tools/run_gut.sh                        # tutte le suite logiche rapide
#   tools/run_gut.sh -gdir=res://tests/suites/<area>   # solo un'area
#   tools/run_visual_qa.sh                  # i Visual QA (rendering, non headless)
#   godot --headless -s res://addons/gut/gut_cmdln.gd \
#         -gconfig=res://.gutconfig.soak.json -gexit   # soak/stress
#
# Questo wrapper inoltra a tools/run_gut.sh per non rompere le invocazioni
# esistenti. La vecchia tassonomia di categorie (fast/slow/soak/visual) e gli
# argomenti pattern non sono piu supportati: usa i comandi qui sopra.

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "ATTENZIONE: tools/run_tests.sh e deprecato; inoltro a tools/run_gut.sh." >&2
echo "            Per i Visual QA usa tools/run_visual_qa.sh; per i soak usa .gutconfig.soak.json." >&2

exec bash "$PROJECT_ROOT/tools/run_gut.sh"
