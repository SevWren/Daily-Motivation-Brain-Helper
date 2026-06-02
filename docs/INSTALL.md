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

## Uninstallation
1. Delete the scheduled task: open Task Scheduler, find "Open Claude Folder Daily", right-click → Delete
2. Delete the application folder

## Troubleshooting
- Check `%TEMP%\DailyMotivation_debug.log` for diagnostic output
- Check `C:\daily_moti\launch_log.txt` for launcher output
