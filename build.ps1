#Requires -Version 5.1
# =============================================================================
# build.ps1 -- Compile DailyMotivation.ps1 -> DailyMotivation.exe via PS2EXE
# Usage: .\build.ps1
# =============================================================================

$InputFile  = Join-Path $PSScriptRoot "DailyMotivation.ps1"
$OutputFile = Join-Path $PSScriptRoot "DailyMotivation.exe"

if (-not (Test-Path $InputFile)) {
    Write-Error "Input file not found: $InputFile"
    exit 1
}

if (-not (Get-Command Invoke-ps2exe -ErrorAction SilentlyContinue)) {
    Write-Error "ps2exe module not installed. Run: Install-Module ps2exe -Scope CurrentUser"
    exit 1
}

Write-Host "Building $OutputFile ..."

Invoke-ps2exe `
    -inputFile  $InputFile `
    -outputFile $OutputFile `
    -STA `
    -noConsole `
    -title   "Daily Motivation Brain Helper" `
    -version "2.0.0.0" `
    -company "SevWren"

if (Test-Path $OutputFile) {
    $size = (Get-Item $OutputFile).Length
    Write-Host "Build succeeded. Output: $OutputFile ($([math]::Round($size/1KB, 1)) KB)"
} else {
    Write-Error "Build failed: output file not found."
    exit 1
}
