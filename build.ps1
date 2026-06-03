# =============================================================================
# build.ps1 — Daily Motivation Brain Helper
# Compiles MainApp.ps1 into a single EXE using PS2EXE-NG.
#
# IMPORTANT: Output goes to src\DailyMotivation.exe — NOT the project root.
# All referenced files (Modules\, MainWindow.xaml, data\, LaunchMotivation.bat)
# live in src\, so the EXE must sit in the same directory for path resolution
# to work correctly at runtime.
#
# Prerequisites:
#   Install-Module -Name ps2exe -Scope CurrentUser
#
# Usage (from project root):
#   .\build.ps1
#
# To distribute:
#   Copy the entire src\ folder to the target machine.
#   The end user double-clicks src\DailyMotivation.exe.
# =============================================================================

#Requires -Version 5.1

$ErrorActionPreference = "Stop"

$projectRoot = $PSScriptRoot
$srcDir      = Join-Path $projectRoot "src"
$inputFile   = Join-Path $srcDir "MainApp.ps1"
$outputFile  = Join-Path $srcDir "DailyMotivation.exe"

Write-Host "Building DailyMotivation.exe into src\" -ForegroundColor Cyan

if (-not (Get-Command Invoke-ps2exe -ErrorAction SilentlyContinue)) {
    Write-Error "PS2EXE not found. Run: Install-Module -Name ps2exe -Scope CurrentUser"
    exit 1
}

Invoke-ps2exe `
    -inputFile   $inputFile  `
    -outputFile  $outputFile `
    -requireAdmin            `
    -noConsole               `
    -title       "Daily Motivation Brain Helper" `
    -version     "1.0.0.0"  `
    -company     "SevWren"   `
    -product     "Daily Motivation Brain Helper" `
    -copyright   "2026 SevWren"

if (Test-Path $outputFile) {
    $size = [math]::Round((Get-Item $outputFile).Length / 1MB, 1)
    Write-Host "Build succeeded: $outputFile ($size MB)" -ForegroundColor Green
    Write-Host ""
    Write-Host "To run: double-click src\DailyMotivation.exe" -ForegroundColor Yellow
    Write-Host "To distribute: copy the entire src\ folder." -ForegroundColor Yellow
} else {
    Write-Error "Build failed — output file not created."
    exit 1
}
