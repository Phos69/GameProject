# Installa i git hooks del progetto in .git/hooks/
# Esegui una volta dopo ogni clone: .\tools\install_hooks.ps1

$projectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$hooksSource = Join-Path $projectRoot "tools\hooks"
$hooksTarget = Join-Path $projectRoot ".git\hooks"

if (-not (Test-Path $hooksTarget)) {
    Write-Host "Errore: .git/hooks non trovato. Sei nella root del progetto?" -ForegroundColor Red
    exit 1
}

$installed = 0
foreach ($hook in Get-ChildItem $hooksSource -File) {
    $dest = Join-Path $hooksTarget $hook.Name
    Copy-Item $hook.FullName $dest -Force
    # Rendi eseguibile via Git Bash (necessario su Windows con Git for Windows)
    & git update-index --chmod=+x "tools/hooks/$($hook.Name)" 2>$null
    $installed++
    Write-Host "Hook installato: $($hook.Name)" -ForegroundColor Green
}

Write-Host ""
Write-Host "$installed hook(s) installati in .git/hooks/" -ForegroundColor Cyan
Write-Host "I file .import verranno ora auto-staged ad ogni commit."
