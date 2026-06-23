# Esegue la suite GUT (tests/suites/**) in UN SOLO processo Godot.
#
# A differenza di run_tests.ps1 (un processo per file, suite legacy), GUT fa boot
# dell'engine una sola volta e raccoglie tutti i `*_test.gd` sotto tests/suites/.
#
# Uso:
#   tools/run_gut.ps1 [-Godot <path>] [-SkipImport] [<extra gut args>...]
# Esempi:
#   ./tools/run_gut.ps1
#   ./tools/run_gut.ps1 -Godot "C:\path\Godot.exe" -- -gdir=res://tests/suites/world_gen
#
# Variabili d'ambiente:
#   GODOT  path/comando del binario Godot (default: "godot")

param(
	[string]$Godot = $(if ($env:GODOT) { $env:GODOT } else { "godot" }),
	[switch]$SkipImport,
	[Parameter(ValueFromRemainingArguments = $true)]
	[string[]]$ExtraArgs
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

$resolved = Get-Command $Godot -ErrorAction SilentlyContinue
if ($resolved) { $godotExe = $resolved.Source }
elseif (Test-Path $Godot) { $godotExe = $Godot }
else {
	Write-Host "ERRORE: binario Godot non trovato (comando: '$Godot')." -ForegroundColor Red
	Write-Host "Imposta -Godot o la variabile d'ambiente GODOT con il path corretto."
	exit 127
}

if (-not $SkipImport) {
	Write-Host "==> Import risorse (una tantum)..."
	& $godotExe --headless --import --path . | Out-Null
}

Write-Host "==> GUT run (un solo processo)..."
$gutArgs = @(
	"--headless",
	"-s", "res://addons/gut/gut_cmdln.gd",
	"-gconfig=res://.gutconfig.json",
	"-gexit"
)
if ($ExtraArgs) { $gutArgs += $ExtraArgs }
& $godotExe @gutArgs
exit $LASTEXITCODE
