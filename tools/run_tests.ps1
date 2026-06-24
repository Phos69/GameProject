# DEPRECATO — il runner legacy "un processo per file" e stato ritirato.
#
# La suite di test e ora interamente GUT (un solo processo Godot):
#   ./tools/run_gut.ps1                       # tutte le suite logiche rapide
#   ./tools/run_visual_qa.sh                  # i Visual QA (rendering, non headless)
#   godot --headless -s res://addons/gut/gut_cmdln.gd `
#         -gconfig=res://.gutconfig.soak.json -gexit   # soak/stress
#
# Questo wrapper inoltra a tools/run_gut.ps1 per non rompere le invocazioni
# esistenti. La vecchia tassonomia di categorie (fast/slow/soak/visual) e gli
# argomenti pattern non sono piu supportati: usa i comandi qui sopra.

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot

Write-Host "ATTENZIONE: tools/run_tests.ps1 e deprecato; inoltro a tools/run_gut.ps1." -ForegroundColor Yellow
Write-Host "            Per i Visual QA usa tools/run_visual_qa.sh; per i soak usa .gutconfig.soak.json."

& (Join-Path $projectRoot "tools/run_gut.ps1")
exit $LASTEXITCODE
