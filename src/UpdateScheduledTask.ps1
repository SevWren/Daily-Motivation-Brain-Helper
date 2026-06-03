# =============================================================================
# UpdateScheduledTask.ps1 -- Daily Motivation Brain Helper
# One-time setup: registers the LaunchMotivation.bat scheduled task.
# Run as Administrator after extracting the app.
# This is a thin wrapper -- scheduling logic lives in TaskScheduler.psm1.
# =============================================================================

#Requires -Version 5.1

$scriptDir  = $PSScriptRoot
$batchPath  = Join-Path $scriptDir "LaunchMotivation.bat"
$ps1Path    = Join-Path $scriptDir "DailyMotivation.ps1"

# --- Guard: verify files exist ---
foreach ($f in @($batchPath, $ps1Path)) {
    if (-not (Test-Path $f)) {
        Write-Error "File not found: $f`nPlace all files in the same directory and retry."
        exit 1
    }
}

Write-Host "Daily Motivation Brain Helper -- Initial Setup" -ForegroundColor Cyan
Write-Host ""

# --- Copy modules to %APPDATA% so ShellBridge and popup can find them ---
$appDataDir  = Join-Path $env:APPDATA "DailyMotivationBrainHelper"
$moduleSrc   = Join-Path $scriptDir "Modules"
$moduleDst   = Join-Path $appDataDir "Modules"
$dataSrc     = Join-Path $scriptDir "data"
$dataDst     = $appDataDir

if (-not (Test-Path $appDataDir)) { New-Item -ItemType Directory $appDataDir -Force | Out-Null }

if (Test-Path $moduleSrc) {
    if (-not (Test-Path $moduleDst)) { New-Item -ItemType Directory $moduleDst -Force | Out-Null }
    Copy-Item "$moduleSrc\*.psm1" $moduleDst -Force
    Write-Host "  Modules copied to $moduleDst" -ForegroundColor Green
}
if (Test-Path $dataSrc) {
    # Only copy messages.json if it doesn't already exist (preserve user customisations)
    $msgDst = Join-Path $dataDst "messages.json"
    if (-not (Test-Path $msgDst)) {
        Copy-Item "$dataSrc\messages.json" $msgDst -Force
        Write-Host "  Default messages installed." -ForegroundColor Green
    }
}

# --- Initialize config files ---
Import-Module (Join-Path $moduleDst "ConfigManager.psm1") -Force -ErrorAction SilentlyContinue
if (Get-Command Initialize-AppData -ErrorAction SilentlyContinue) {
    Initialize-AppData
    Write-Host "  App data initialised at $appDataDir" -ForegroundColor Green
}

# --- Register the Task Scheduler entry ---
$taskName = "DailyMotivationBrainHelper_Launcher"

# Remove old task if present
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue

$action = New-ScheduledTaskAction `
    -Execute  "cmd.exe" `
    -Argument "/c `"$batchPath`""

# Placeholder trigger (2 PM tomorrow) -- real tasks are created by the app
$trigger = New-ScheduledTaskTrigger -Once -At ((Get-Date).Date.AddDays(1).AddHours(14))

$settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 10) `
    -MultipleInstances IgnoreNew

$principal = New-ScheduledTaskPrincipal `
    -UserId    $env:USERNAME `
    -LogonType Interactive   `
    -RunLevel  Limited

$result = Register-ScheduledTask `
    -TaskName   $taskName `
    -Action     $action   `
    -Trigger    $trigger  `
    -Settings   $settings `
    -Principal  $principal `
    -Description "Daily Motivation Brain Helper placeholder task -- real tasks managed by the app"

if ($result) {
    Write-Host ""
    Write-Host "Setup complete!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Run MainApp.ps1 to schedule your first folder"
    Write-Host "  2. (Optional) Run ShellExtension\Register-ShellExtension.ps1 for Explorer right-click"
    Write-Host ""
    Write-Host "Log files will appear in: $appDataDir" -ForegroundColor Gray
} else {
    Write-Error "Setup failed. Make sure you ran this script as Administrator."
}
