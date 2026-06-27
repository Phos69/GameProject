# Esegue la suite GUT (tests/suites/**) in UN SOLO processo Godot.
#
# A differenza di run_tests.ps1 (un processo per file, suite legacy), GUT fa boot
# dell'engine una sola volta e raccoglie tutti i `*_test.gd` sotto tests/suites/.
#
# Uso:
#   tools/run_gut.ps1 [-Godot <path>] [-SkipImport] [-Config <res://...>] [-Full] [<extra gut args>...]
# Esempi:
#   ./tools/run_gut.ps1                        # solo le suite golden (default)
#   ./tools/run_gut.ps1 -Full                  # tutte le suite (.gutconfig.json)
#   ./tools/run_gut.ps1 -Godot "C:\path\Godot.exe" -- -gdir=res://tests/suites/world_gen
#
# DEFAULT solo-golden: per ora la suite gira unicamente sul mondo golden
# (.gutconfig.golden.json). Le altre suite restano nel repo ma non girano finche'
# non riattivate con -Full o -Config.
#
# Variabili d'ambiente:
#   GODOT  path/comando del binario Godot (default: "godot")

param(
	[string]$Godot = $(if ($env:GODOT) { $env:GODOT } else { "godot" }),
	[switch]$SkipImport,
	[string]$Config = "res://.gutconfig.golden.json",
	[switch]$Full,
	[Parameter(ValueFromRemainingArguments = $true)]
	[string[]]$ExtraArgs
)

if ($Full) { $Config = "res://.gutconfig.json" }

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

Write-Host "==> GUT run (un solo processo, config: $Config)..."
$gutArgs = @(
	"--headless",
	"-s", "res://addons/gut/gut_cmdln.gd",
	"-gconfig=$Config",
	"-gexit"
)
if ($ExtraArgs) { $gutArgs += $ExtraArgs }
& $godotExe @gutArgs
exit $LASTEXITCODE
