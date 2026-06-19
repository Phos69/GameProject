# Esegue l'intera suite di test headless (tests/*.gd) e aggrega gli exit code.
#
# Ogni test e uno script `extends SceneTree` che termina con `quit(0)` (pass)
# o `quit(1)` (fail). Lo runner lancia Godot una volta per file.
#
# Uso:
#   tools/run_tests.ps1 [-Filter <substring>] [-Godot <path>] [-TimeoutSec <n>] [-SkipImport]
# Esempi:
#   ./tools/run_tests.ps1
#   ./tools/run_tests.ps1 -Filter biome
#
param(
	[string]$Filter = "",
	[string]$Godot = $(if ($env:GODOT) { $env:GODOT } else { "godot" }),
	[int]$TimeoutSec = $(if ($env:TEST_TIMEOUT) { [int]$env:TEST_TIMEOUT } else { 180 }),
	[switch]$SkipImport
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

$godotCmd = Get-Command $Godot -ErrorAction SilentlyContinue
if (-not $godotCmd) {
	Write-Host "ERRORE: binario Godot non trovato (comando: '$Godot')." -ForegroundColor Red
	Write-Host "Imposta -Godot o la variabile d'ambiente GODOT con il path corretto."
	exit 127
}

if (-not $SkipImport) {
	Write-Host "==> Import risorse (una tantum)..."
	& $Godot --headless --import --path . 2>$null | Out-Null
}

$tests = Get-ChildItem -Path "tests" -Filter "*.gd" -File | Sort-Object Name
if ($tests.Count -eq 0) {
	Write-Host "Nessun test trovato in tests/*.gd"
	exit 1
}

Write-Host "==> Esecuzione suite di test ($($tests.Count) file)`n"

$passed = 0
$failed = 0
$failedNames = @()

foreach ($test in $tests) {
	if ($Filter -and ($test.Name -notlike "*$Filter*")) { continue }
	# Esegui solo gli script-test (SceneTree); salta gli helper condivisi.
	if (-not (Select-String -Path $test.FullName -Pattern "^extends SceneTree" -Quiet)) { continue }

	$outFile = [System.IO.Path]::GetTempFileName()
	$proc = Start-Process -FilePath $Godot `
		-ArgumentList @("--headless", "--path", ".", "--script", "tests/$($test.Name)") `
		-NoNewWindow -PassThru -RedirectStandardOutput $outFile -RedirectStandardError "$outFile.err"

	if (-not $proc.WaitForExit($TimeoutSec * 1000)) {
		try { $proc.Kill() } catch {}
		$failed++
		$failedNames += $test.Name
		Write-Host "  TIMEOUT  $($test.Name) (oltre ${TimeoutSec}s)" -ForegroundColor Red
	}
	elseif ($proc.ExitCode -eq 0) {
		$passed++
		Write-Host "  PASS  $($test.Name)" -ForegroundColor Green
	}
	else {
		$failed++
		$failedNames += $test.Name
		Write-Host "  FAIL  $($test.Name) (exit $($proc.ExitCode))" -ForegroundColor Red
		Get-Content $outFile -Tail 15 -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "        | $_" }
	}
	Remove-Item $outFile, "$outFile.err" -ErrorAction SilentlyContinue
}

Write-Host "`n==> Risultato: $passed passati, $failed falliti"
if ($failed -ne 0) {
	Write-Host "    Falliti:"
	$failedNames | ForEach-Object { Write-Host "      - $_" }
	exit 1
}
exit 0
