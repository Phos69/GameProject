# Esegue la suite di test headless (tests/*.gd) e aggrega gli exit code.
#
# Ogni test e uno script `extends SceneTree` che termina con `quit(0)` (pass)
# o `quit(1)` (fail). Lo runner lancia Godot una volta per file e considera
# il test fallito se l'exit code non e 0 o se va in timeout.
#
# Uso:
#   tools/run_tests.ps1 [-Filter <substring>] [-Category all|fast|slow|soak|visual] [-Godot <path>] [-TimeoutSec <n>] [-SkipImport]
# Esempi:
#   ./tools/run_tests.ps1
#   ./tools/run_tests.ps1 -Filter biome
#   ./tools/run_tests.ps1 -Category fast
#
# Variabili d'ambiente:
#   GODOT          path/comando del binario Godot (default: "godot")
#   TEST_TIMEOUT   timeout per singolo test in secondi (default: 180)
#   TEST_CATEGORY  categoria default: all, fast, slow, soak, visual
#   TEST_LOG_DIR   cartella log (default: build/test_logs)

param(
	[string]$Filter = "",
	[ValidateSet("all", "fast", "slow", "soak", "visual")]
	[string]$Category = $(if ($env:TEST_CATEGORY) { $env:TEST_CATEGORY } else { "all" }),
	[string]$Godot = $(if ($env:GODOT) { $env:GODOT } else { "godot" }),
	[int]$TimeoutSec = $(if ($env:TEST_TIMEOUT) { [int]$env:TEST_TIMEOUT } else { 180 }),
	[switch]$SkipImport,
	[switch]$IncludeVisualQa
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

function Get-GodotExecutable {
	param([string]$Command)

	$resolved = Get-Command $Command -ErrorAction SilentlyContinue
	if (-not $resolved) {
		Write-Host "ERRORE: binario Godot non trovato (comando: '$Command')." -ForegroundColor Red
		Write-Host "Imposta -Godot o la variabile d'ambiente GODOT con il path corretto."
		exit 127
	}
	return $resolved.Source
}

function Get-TestCategory {
	param([string]$Name)

	$lowerName = $Name.ToLowerInvariant()
	if (($lowerName -like "*_visual_qa.gd") -or ($lowerName -like "*_qa.gd")) {
		return "visual"
	}
	if (($lowerName -like "*soak*") -or ($lowerName -like "*stress*") -or ($lowerName -like "*ten_wave*")) {
		return "soak"
	}

	$slowPatterns = @(
		"biome_world_generation",
		"forest_isometric_texture_transition",
		"milestone_10_asset_fallback_policy",
		"milestone_11_weapon_drop_progression",
		"milestone_12_balance_metrics",
		"milestone_12_zombie_balance_metrics",
		"milestone_10_cross_biome_chase",
		"milestone_10_full_region_streaming",
		"milestone_10_isometric_performance",
		"milestone_10_no_portal_transition",
		"milestone_10_tile_layer",
		"open_passage_transition"
	)
	foreach ($pattern in $slowPatterns) {
		if ($lowerName -like "*$pattern*") {
			return "slow"
		}
	}
	return "fast"
}

function Stop-ProcessTree {
	param([int]$ProcessId)

	if (Get-Command taskkill.exe -ErrorAction SilentlyContinue) {
		& taskkill.exe /PID $ProcessId /T /F > $null 2>&1
		return
	}

	try {
		Stop-Process -Id $ProcessId -Force -ErrorAction Stop
	} catch {
		# Il processo potrebbe essere gia terminato.
	}
}

function Invoke-LoggedProcess {
	param(
		[string]$FilePath,
		[string]$Arguments,
		[string]$WorkingDirectory,
		[string]$LogPath,
		[int]$TimeoutSeconds
	)

	$launchFile = $FilePath
	$launchArguments = $Arguments
	$fileExtension = [System.IO.Path]::GetExtension($FilePath).ToLowerInvariant()
	if (($fileExtension -eq ".cmd") -or ($fileExtension -eq ".bat")) {
		$launchFile = if ($env:ComSpec) { $env:ComSpec } else { "cmd.exe" }
		$launchArguments = "/d /s /c `"`"$FilePath`" $Arguments`""
	}

	$psi = New-Object System.Diagnostics.ProcessStartInfo
	$psi.FileName = $launchFile
	$psi.Arguments = $launchArguments
	$psi.WorkingDirectory = $WorkingDirectory
	$psi.UseShellExecute = $false
	$psi.RedirectStandardOutput = $true
	$psi.RedirectStandardError = $true
	$psi.CreateNoWindow = $true

	$process = New-Object System.Diagnostics.Process
	$process.StartInfo = $psi

	$timedOut = $false
	$exitCode = 1
	$stdout = ""
	$stderr = ""

	try {
		[void]$process.Start()
		$stdoutTask = $process.StandardOutput.ReadToEndAsync()
		$stderrTask = $process.StandardError.ReadToEndAsync()

		if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
			$timedOut = $true
			Stop-ProcessTree -ProcessId $process.Id
			[void]$process.WaitForExit(5000)
			$exitCode = 124
		} else {
			$exitCode = $process.ExitCode
			# Second wait flushes async redirected streams on older runtimes.
			$process.WaitForExit()
		}

		try { [void]$stdoutTask.Wait(5000) } catch {}
		try { [void]$stderrTask.Wait(5000) } catch {}
		if ($stdoutTask.IsCompleted) { $stdout = $stdoutTask.Result }
		if ($stderrTask.IsCompleted) { $stderr = $stderrTask.Result }
	} finally {
		$process.Dispose()
	}

	$log = @(
		"COMMAND: $FilePath $Arguments",
		"LAUNCH: $launchFile $launchArguments",
		"WORKDIR: $WorkingDirectory",
		"EXIT_CODE: $exitCode",
		"TIMED_OUT: $timedOut",
		"",
		"--- stdout ---",
		$stdout,
		"",
		"--- stderr ---",
		$stderr
	) -join [Environment]::NewLine
	[System.IO.File]::WriteAllText($LogPath, $log)

	return [pscustomobject]@{
		ExitCode = $exitCode
		TimedOut = $timedOut
		LogPath = $LogPath
	}
}

$godotExecutable = Get-GodotExecutable -Command $Godot
$logDir = if ($env:TEST_LOG_DIR) { $env:TEST_LOG_DIR } else { Join-Path "build" "test_logs" }
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$runStamp = Get-Date -Format "yyyyMMdd_HHmmss"

if (-not $SkipImport) {
	Write-Host "==> Import risorse (una tantum)..."
	$importLog = Join-Path $logDir "${runStamp}_import.log"
	$importResult = Invoke-LoggedProcess -FilePath $godotExecutable -Arguments "--headless --import --path ." -WorkingDirectory $projectRoot -LogPath $importLog -TimeoutSeconds 300
	if ($importResult.TimedOut) {
		Write-Host "ERRORE: import risorse in timeout (log: $importLog)." -ForegroundColor Red
		exit 1
	}
	if ($importResult.ExitCode -ne 0) {
		Write-Host "ATTENZIONE: import risorse terminato con exit $($importResult.ExitCode), continuo come runner bash (log: $importLog)." -ForegroundColor Yellow
	}
}

$tests = Get-ChildItem -Path "tests" -Filter "*.gd" -File | Sort-Object Name
if ($tests.Count -eq 0) {
	Write-Host "Nessun test trovato in tests/*.gd" -ForegroundColor Red
	exit 1
}

Write-Host "==> Esecuzione suite di test ($($tests.Count) file, categoria: $Category, timeout: ${TimeoutSec}s)`n"

$passed = 0
$failed = 0
$selected = 0
$skippedCategory = 0
$skippedVisual = 0
$failedNames = @()

foreach ($test in $tests) {
	if ($Filter -and ($test.Name -notlike "*$Filter*")) { continue }
	# Esegui solo gli script-test (SceneTree); salta gli helper condivisi.
	if (-not (Select-String -Path $test.FullName -Pattern "^extends SceneTree" -Quiet)) { continue }

	$testCategory = Get-TestCategory -Name $test.Name
	if (($Category -ne "all") -and ($testCategory -ne $Category)) {
		$skippedCategory++
		continue
	}
	if (($testCategory -eq "visual") -and ($Category -ne "visual") -and (-not $IncludeVisualQa)) {
		$skippedVisual++
		continue
	}

	$selected++
	$baseName = [System.IO.Path]::GetFileNameWithoutExtension($test.Name)
	$logFile = Join-Path $logDir "${runStamp}_${baseName}.log"
	$scriptPath = "tests/$($test.Name)"
	$result = Invoke-LoggedProcess -FilePath $godotExecutable -Arguments "--headless --path . --script $scriptPath" -WorkingDirectory $projectRoot -LogPath $logFile -TimeoutSeconds $TimeoutSec

	if ($result.TimedOut) {
		$failed++
		$failedNames += $test.Name
		Write-Host "  TIMEOUT  $($test.Name) (oltre ${TimeoutSec}s, log: $logFile)" -ForegroundColor Red
	}
	elseif ($result.ExitCode -eq 0) {
		$passed++
		Write-Host "  PASS  $($test.Name) (log: $logFile)" -ForegroundColor Green
	}
	else {
		$failed++
		$failedNames += $test.Name
		Write-Host "  FAIL  $($test.Name) (exit $($result.ExitCode), log: $logFile)" -ForegroundColor Red
		Get-Content $logFile -Tail 15 -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "        | $_" }
	}
}

Write-Host "`n==> Risultato: $passed passati, $failed falliti, $skippedCategory saltati (categoria), $skippedVisual saltati (visual_qa)"
if ($selected -eq 0) {
	Write-Host "    Nessun test eseguibile selezionato. Controlla -Filter, -Category o -IncludeVisualQa." -ForegroundColor Red
	exit 1
}
if ($failed -ne 0) {
	Write-Host "    Falliti:"
	$failedNames | ForEach-Object { Write-Host "      - $_" }
	exit 1
}
exit 0
