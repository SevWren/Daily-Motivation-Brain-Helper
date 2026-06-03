# Installation Guide

## Requirements
- Windows 10 (build 19041) or Windows 11
- PowerShell 5.1 (included with Windows)
- .NET Framework 4.x (included with Windows)
- No internet connection required

## Step 1 — Download
Download the latest release ZIP from the [Releases](../releases) page.

## Step 2 — Extract
Extract the ZIP to a folder, for example: `C:\daily_moti\`

## Step 3 — Register the Scheduled Task
Right-click `UpdateScheduledTask.ps1` and select **Run with PowerShell** (as Administrator).

That's it. The application is now installed.

## Step 4 — Use It
Run the main application to pick a folder and schedule it for tomorrow at 2 PM.

Run the main application:
```powershell
powershell.exe -STA -ExecutionPolicy Bypass -File "src\MainApp.ps1"
```
Or double-click `src\DailyMotivation.exe` if you built the EXE with `build.ps1`.

## Uninstallation
1. Delete scheduled tasks: open Task Scheduler, find tasks named "DailyMotivationBrainHelper_Launcher" and any "DailyMotivation_*" tasks, right-click each → Delete
2. Delete the application folder

## Troubleshooting
- Check `%TEMP%\DailyMotivation_debug.log` for popup script trace
- Check `%APPDATA%\DailyMotivationBrainHelper\launch_log.txt` for launcher output
