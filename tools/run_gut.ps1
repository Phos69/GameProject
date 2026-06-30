# Esegue la suite GUT (tests/suites/**) in UN SOLO processo Godot.
#
# A differenza di run_tests.ps1 (un processo per file, suite legacy), GUT fa boot
# dell'engine una sola volta e raccoglie tutti i `*_test.gd` sotto tests/suites/.
#
# Uso:
#   tools/run_gut.ps1 [-Godot <path>] [-SkipImport] [-Config <res://...>] [-Golden] [-GutDir <res://...>] [-Select <name>] [<extra gut args>...]
# Esempi:
#   ./tools/run_gut.ps1                        # tutte le suite logiche rapide
#   ./tools/run_gut.ps1 -Golden                # solo le suite golden
#   ./tools/run_gut.ps1 -Godot "C:\path\Godot.exe" -GutDir res://tests/suites/world_gen
#
# Default: suite logiche rapide (.gutconfig.json), come README e CI. La config
# golden resta disponibile con -Golden o -Config res://.gutconfig.golden.json.
#
# Variabili d'ambiente:
#   GODOT  path/comando del binario Godot (default: "godot")

param(
	[string]$Godot = $(if ($env:GODOT) { $env:GODOT } else { "godot" }),
	[switch]$SkipImport,
	[string]$Config = "res://.gutconfig.json",
	[switch]$Golden,
	[switch]$Full,
	[string]$GutDir = "",
	[string]$Select = "",
	[Parameter(ValueFromRemainingArguments = $true)]
	[string[]]$ExtraArgs
)

if ($Full) { $Config = "res://.gutconfig.json" }
if ($Golden) { $Config = "res://.gutconfig.golden.json" }

function Normalize-GutArgs {
	param([string[]]$Args)
	$normalized = @()
	for ($index = 0; $index -lt $Args.Count; $index++) {
		$current = $Args[$index]
		if (
			$current.EndsWith("res:") -and
			$index + 1 -lt $Args.Count -and
			$Args[$index + 1].StartsWith("//")
		) {
			$normalized += "$current$($Args[$index + 1])"
			$index++
			continue
		}
		$normalized += $current
	}
	return $normalized
}

function Test-GutArgPresent {
	param(
		[string[]]$Args,
		[string]$Name
	)
	foreach ($arg in $Args) {
		if ($arg -eq $Name -or $arg.StartsWith("$Name=")) {
			return $true
		}
	}
	return $false
}

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

if ([System.IO.Path]::GetFileName($godotExe).ToLowerInvariant() -eq "godot.exe") {
	$consoleCandidate = Join-Path (Split-Path -Parent $godotExe) "godot_console.exe"
	if (Test-Path $consoleCandidate) {
		$godotExe = $consoleCandidate
	}
}

if (-not $SkipImport) {
	Write-Host "==> Import risorse (una tantum)..."
	& $godotExe --headless --import --path . | Out-Null
}

$normalizedExtraArgs = @()
if ($ExtraArgs) { $normalizedExtraArgs = Normalize-GutArgs $ExtraArgs }

$junitReport = ""
if (-not (Test-GutArgPresent $normalizedExtraArgs "-gjunit_xml_file")) {
	$testLogDir = Join-Path $projectRoot "build\test_logs"
	New-Item -ItemType Directory -Force -Path $testLogDir | Out-Null
	$configName = [System.IO.Path]::GetFileNameWithoutExtension(($Config -replace "^res://", ""))
	$configSlug = ($configName -replace "^\.", "" -replace "[^A-Za-z0-9_-]", "_")
	$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
	$junitReport = "res://build/test_logs/gut_${configSlug}_${timestamp}.xml"
}

Write-Host "==> GUT run (un solo processo, config: $Config)..."
$gutArgs = @(
	"--headless",
	"-s", "res://addons/gut/gut_cmdln.gd",
	"-gconfig=$Config",
	"-gexit"
)
if ($GutDir) { $gutArgs += "-gdir=$GutDir" }
if ($Select) { $gutArgs += "-gselect=$Select" }
if ($junitReport) { $gutArgs += "-gjunit_xml_file=$junitReport" }
if ($normalizedExtraArgs.Count -gt 0) { $gutArgs += $normalizedExtraArgs }
& $godotExe @gutArgs
$exitCode = $LASTEXITCODE
if ($junitReport) {
	Write-Host "==> GUT JUnit report: $junitReport"
}
if ($exitCode -eq 0) {
	Write-Host "==> GUT result: PASS (exit code 0, config: $Config)" -ForegroundColor Green
} else {
	Write-Host "==> GUT result: FAIL (exit code $exitCode, config: $Config)" -ForegroundColor Red
}
exit $exitCode
