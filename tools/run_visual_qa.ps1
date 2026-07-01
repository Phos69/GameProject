# Esegue i tool Visual QA (tests/visual_qa/*.gd) uno per file.
#
# I Visual QA producono screenshot/griglie sotto build/qa e richiedono un
# contesto di rendering reale. Non fanno parte della suite GUT headless.
#
# Uso:
#   ./tools/run_visual_qa.ps1
#   ./tools/run_visual_qa.ps1 -Filter biome
#
# Variabili d'ambiente:
#   GODOT      path/comando del binario Godot (default: "godot")
#   QA_RENDER  rendering method (default: gl_compatibility)

param(
	[string]$Godot = $(if ($env:GODOT) { $env:GODOT } else { "godot" }),
	[switch]$SkipImport,
	[string]$Filter = "",
	[string]$OutputLogDir = "build\qa_logs"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

$resolved = Get-Command $Godot -ErrorAction SilentlyContinue
if ($resolved) {
	$godotExe = $resolved.Source
} elseif (Test-Path $Godot) {
	$godotExe = $Godot
} else {
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

$qaRender = if ($env:QA_RENDER) { $env:QA_RENDER } else { "gl_compatibility" }

if (-not $SkipImport) {
	Write-Host "==> Import risorse (una tantum)..."
	$previousErrorActionPreference = $ErrorActionPreference
	$ErrorActionPreference = "Continue"
	try {
		& $godotExe --headless --import --path . | Out-Null
	} finally {
		$ErrorActionPreference = $previousErrorActionPreference
	}
}

$logDir = Join-Path $projectRoot $OutputLogDir
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$runStamp = Get-Date -Format "yyyyMMdd_HHmmss"

$qaFiles = Get-ChildItem -Path (Join-Path $projectRoot "tests\visual_qa") -Filter "*.gd" |
	Sort-Object Name

if ($qaFiles.Count -eq 0) {
	Write-Host "Nessun Visual QA trovato in tests/visual_qa/*.gd" -ForegroundColor Red
	exit 1
}

$passed = 0
$failed = 0
$selected = 0
$failedNames = @()

Write-Host "==> Visual QA ($($qaFiles.Count) file, rendering: $qaRender)"
foreach ($qaFile in $qaFiles) {
	$name = $qaFile.Name
	if ($Filter -and $name -notlike "*$Filter*") {
		continue
	}
	$selected++
	$logFile = Join-Path $logDir "$($runStamp)_$([System.IO.Path]::GetFileNameWithoutExtension($name)).log"
	$godotArgs = @(
		"--path", ".",
		"--rendering-method", $qaRender,
		"--script", $qaFile.FullName
	)
	$previousErrorActionPreference = $ErrorActionPreference
	$ErrorActionPreference = "Continue"
	try {
		& $godotExe @godotArgs > $logFile 2>&1
		$exitCode = $LASTEXITCODE
	} finally {
		$ErrorActionPreference = $previousErrorActionPreference
	}
	if ($exitCode -eq 0) {
		$passed++
		Write-Host ("  OK    {0} (log: {1})" -f $name, $logFile)
	} else {
		$failed++
		$failedNames += $name
		Write-Host ("  FAIL  {0} (exit {1}, log: {2})" -f $name, $exitCode, $logFile) -ForegroundColor Red
	}
}

Write-Host ""
Write-Host "==> Risultato Visual QA: $passed ok, $failed falliti"
if ($selected -eq 0) {
	Write-Host "    Nessun Visual QA selezionato (controlla il filtro)." -ForegroundColor Red
	exit 1
}
if ($failed -ne 0) {
	foreach ($name in $failedNames) {
		Write-Host "      - $name"
	}
	exit 1
}
exit 0
