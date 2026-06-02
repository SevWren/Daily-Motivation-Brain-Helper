# ============================================================
#  UpdateScheduledTask.ps1 — Run as Administrator
#
#  This registers the scheduled task to launch LaunchMotivation.bat
#  via cmd.exe. The batch file handles all PowerShell launch flags
#  and captures all output to log files in C:\login\daily_moti\.
#
#  STEP 1: Confirm both files are at the paths below.
#  STEP 2: Right-click this script → "Run with PowerShell" AS ADMIN.
# ============================================================

$batchPath  = "C:\login\daily_moti\LaunchMotivation.bat"
$scriptPath = "C:\login\daily_moti\DailyMotivation.ps1"

# --- Guard: verify files exist before touching the task ---
foreach ($f in @($batchPath, $scriptPath)) {
    if (-not (Test-Path $f)) {
        Write-Error "File not found: $f`nPlace both files in C:\login\daily_moti\ and retry."
        exit 1
    }
}

# --- Build the action: cmd.exe runs the batch file ---
# Using cmd.exe /c eliminates ALL PowerShell argument-quoting issues
# that cause Task Scheduler to mangle the -WindowStyle Hidden flag.
$action = New-ScheduledTaskAction `
    -Execute  "cmd.exe" `
    -Argument "/c `"$batchPath`""

$trigger = New-ScheduledTaskTrigger -Daily -At 2:00PM

$principal = New-ScheduledTaskPrincipal `
    -UserId    $env:USERNAME `
    -LogonType Interactive `
    -RunLevel  Limited

# --- Remove old task (ignore if it doesn't exist) ---
Unregister-ScheduledTask -TaskName "Open Claude Folder Daily" -Confirm:$false -ErrorAction SilentlyContinue

# --- Register new task ---
$result = Register-ScheduledTask `
    -TaskName   "Open Claude Folder Daily" `
    -Action     $action `
    -Trigger    $trigger `
    -Principal  $principal `
    -Description "Daily motivation popup via batch launcher"

if ($result) {
    Write-Host "Task registered successfully." -ForegroundColor Green
    Write-Host ""
    Write-Host "After the task runs, check these files for diagnostics:"
    Write-Host "  launch_log.txt  -> C:\login\daily_moti\launch_log.txt"
    Write-Host "  ps_output.log   -> C:\login\daily_moti\ps_output.log"
    Write-Host ""
    Write-Host "To run the test script first, temporarily edit LaunchMotivation.bat"
    Write-Host "and change PS_SCRIPT to point to test_task.ps1."
} else {
    Write-Error "Task registration failed. Make sure you ran this script as Administrator."
}
