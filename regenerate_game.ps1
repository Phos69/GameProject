# Rigenerazione completa del progetto Godot
# Pulisce la cache e usa Godot headless per reimportare tutto in anticipo

param(
    [string]$GodotPath = ""
)

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "======================================"
Write-Host "Rigenerazione Completa Progetto Godot"
Write-Host "======================================"
Write-Host ""

# --- Trova Godot ---
function Find-Godot {
    param([string]$UserPath)

    if ($UserPath -and (Test-Path $UserPath)) {
        return $UserPath
    }

    $candidates = @(
        # WinGet
        (Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Filter "godot.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName),
        # Steam / installazioni comuni
        "C:\Program Files\Godot\Godot.exe",
        "C:\Program Files (x86)\Godot\Godot.exe",
        "$env:USERPROFILE\Godot\Godot.exe",
        # PATH
        (Get-Command "godot" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source)
    )

    foreach ($path in $candidates) {
        if ($path -and (Test-Path $path)) {
            return $path
        }
    }

    return $null
}

$godotExe = Find-Godot -UserPath $GodotPath
if ($godotExe) {
    Write-Host "[OK] Godot trovato: $godotExe" -ForegroundColor Green
} else {
    Write-Host "[WARN] Godot non trovato automaticamente." -ForegroundColor Yellow
    Write-Host "       Specifica il percorso con: .\regenerate_game.ps1 -GodotPath 'C:\Path\To\godot.exe'"
    Write-Host "       La pulizia della cache avverra' comunque, ma il pre-import verra' saltato."
    Write-Host ""
}

# --- Pulizia cache ---
Write-Host "[1/3] Pulizia cache .godot ..." -ForegroundColor Cyan

if (Test-Path "$projectRoot\.godot") {
    Remove-Item -Recurse -Force "$projectRoot\.godot" -ErrorAction SilentlyContinue
    Write-Host "      Cache eliminata." -ForegroundColor Green
} else {
    Write-Host "      Cache gia' assente, nessuna azione necessaria." -ForegroundColor Gray
}

if (Test-Path "$projectRoot\build") {
    Remove-Item -Recurse -Force "$projectRoot\build" -ErrorAction SilentlyContinue
    Write-Host "      Build eliminata." -ForegroundColor Green
}

# Ricrea .godot con .gdignore per evitare che Godot importi i propri file
New-Item -ItemType Directory -Path "$projectRoot\.godot" -Force | Out-Null
Set-Content -Path "$projectRoot\.godot\.gdignore" -Value "" -Encoding utf8
Write-Host "      Struttura .godot ricreata." -ForegroundColor Green

# --- Pre-import headless ---
Write-Host ""
Write-Host "[2/3] Pre-import headless ..." -ForegroundColor Cyan

if ($godotExe) {
    Write-Host "      Questo puo' richiedere 1-5 minuti per un progetto di questo size."
    Write-Host "      Non chiudere questa finestra."
    Write-Host ""

    $importArgs = @("--headless", "--editor", "--import", "--path", "`"$projectRoot`"")
    $process = Start-Process -FilePath $godotExe -ArgumentList $importArgs -Wait -PassThru -NoNewWindow 2>$null

    if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 128) {
        Write-Host "      Pre-import completato." -ForegroundColor Green
    } else {
        Write-Host "      Pre-import terminato (exit code: $($process.ExitCode))." -ForegroundColor Yellow
        Write-Host "      Alcuni asset verranno importati all'apertura dell'editor." -ForegroundColor Yellow
    }
} else {
    Write-Host "      [SALTATO] Godot non trovato. Godot reimportera' all'apertura." -ForegroundColor Yellow
}

# --- Risultato ---
Write-Host ""
Write-Host "[3/3] Rigenerazione completata." -ForegroundColor Cyan
Write-Host ""
Write-Host "======================================"
Write-Host "Apri ora il progetto in Godot Editor."
Write-Host "L'importazione dovrebbe essere gia' pronta"
Write-Host "oppure richiedera' solo pochi secondi."
Write-Host "======================================"
Write-Host ""
