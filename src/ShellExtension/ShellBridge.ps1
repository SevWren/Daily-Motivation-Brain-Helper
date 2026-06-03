# =============================================================================
# ShellBridge.ps1 -- TASK-NEW-02 / B-13
# Called by MotivationShellExt.dll when user clicks "Schedule for Tomorrow at 2 PM"
# in Explorer right-click menu.
#
# Usage (by shell extension):
#   powershell.exe -STA -ExecutionPolicy Bypass -File ShellBridge.ps1 "C:\MyFolder"
# =============================================================================

#Requires -Version 5.1
param([Parameter(Mandatory)][string]$FolderPath)

$appDataDir = Join-Path $env:APPDATA "DailyMotivationBrainHelper"
$modulesDir = Join-Path $appDataDir "Modules"

# Try to find modules relative to the main app install location
$possibleModulePaths = @(
    $modulesDir,
    (Join-Path $PSScriptRoot "..\Modules"),
    (Join-Path $PSScriptRoot "..\..\src\Modules")
)

$modulePath = $possibleModulePaths | Where-Object { Test-Path (Join-Path $_ "TaskScheduler.psm1") } | Select-Object -First 1
$configModulePath = $possibleModulePaths | Where-Object { Test-Path (Join-Path $_ "ConfigManager.psm1") } | Select-Object -First 1

if (-not $modulePath) {
    [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
    [System.Windows.Forms.MessageBox]::Show(
        "Daily Motivation Brain Helper is not installed correctly.`n`nCould not find TaskScheduler module.",
        "Not Found", "OK", "Error") | Out-Null
    exit 1
}

Import-Module (Join-Path $modulePath "TaskScheduler.psm1") -Force
Import-Module (Join-Path $configModulePath "ConfigManager.psm1") -Force
Initialize-AppData

# Validate the path
if (-not (Test-Path $FolderPath -PathType Container)) {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show(
        "Folder not found:`n$FolderPath",
        "Daily Motivation", "OK", "Warning") | Out-Null
    exit 1
}

# Pick a random motivational message
$messagesPath = Join-Path $appDataDir "messages.json"
$msg = $null
if (Test-Path $messagesPath) {
    try {
        $msgs = Get-Content $messagesPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($msgs.Count -gt 0) { $msg = $msgs | Get-Random }
    } catch {}
}
if (-not $msg) {
    $msg = [PSCustomObject]@{ glyph = "[+]"; title = "Time to Show Up"; body = "Let's make this session count." }
}

# Schedule for tomorrow at 14:00
$tomorrow = (Get-Date).Date.AddDays(1).AddHours(14)
$result   = New-MotivationTask -FolderPath $FolderPath -TriggerTime $tomorrow

if ($result.Success) {
    # Write popup config
    Set-PopupConfig -Glyph $msg.glyph -Title $msg.title -Body $msg.body `
                    -ExplorerPath $FolderPath -TaskId $result.TaskId
    Set-LastFolder -FolderPath $FolderPath
    Add-RecentFolder -FolderPath $FolderPath

    $folderName  = Split-Path -Leaf $FolderPath
    $dateDisplay = $tomorrow.ToString("dddd 'at' h:mm tt")

    # Show Windows toast notification
    Add-Type -AssemblyName System.Windows.Forms
    $notify             = [System.Windows.Forms.NotifyIcon]::new()
    $notify.Icon        = [System.Drawing.SystemIcons]::Information
    $notify.Visible     = $true
    $notify.BalloonTipTitle = "Scheduled!"
    $notify.BalloonTipText  = "$folderName will open $dateDisplay"
    $notify.BalloonTipIcon  = "Info"
    $notify.ShowBalloonTip(4000)
    Start-Sleep -Seconds 5
    $notify.Dispose()
} elseif ($result.IsDuplicate) {
    Add-Type -AssemblyName System.Windows.Forms
    $folderName = Split-Path -Leaf $FolderPath
    [System.Windows.Forms.MessageBox]::Show(
        "'$folderName' is already scheduled for tomorrow at 2 PM.",
        "Already Scheduled", "OK", "Information") | Out-Null
} else {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show(
        "Could not schedule the folder. Please open the Daily Motivation Brain Helper app.",
        "Scheduling Failed", "OK", "Error") | Out-Null
}
