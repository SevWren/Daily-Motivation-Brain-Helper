# Installation Guide

**Last Reviewed**: 2026-06-09

## Requirements
- Windows 10 (build 19041) or Windows 11
- PowerShell 5.1 (included with Windows)
- .NET Framework 4.x (included with Windows)
- No internet connection required

## Step 1 — Download
Download the latest release ZIP from the [Releases](https://github.com/SevWren/Daily-Motivation-Brain-Helper/releases) page.

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
Or double-click `src\DailyMotivation.exe` if you built the EXE with `Invoke-Build` (see Developer Setup below).

## Uninstallation
1. Delete scheduled tasks: open Task Scheduler, find tasks named "DailyMotivationBrainHelper_Launcher" and any "DailyMotivation_*" tasks, right-click each → Delete
2. Delete the application folder

## Troubleshooting
- Check `%TEMP%\DailyMotivation_debug.log` for popup script trace
- Check `%APPDATA%\DailyMotivationBrainHelper\launch_log.txt` for launcher output

---

## Developer Setup

This section is for developers building from source or running tests.

### Prerequisites

Install development dependencies (one-time setup):

```powershell
# Requires Invoke-Build module. Install it first if needed:
Install-Module -Name InvokeBuild -Scope CurrentUser -Force

# Then install all project dev dependencies:
Invoke-Build InstallDependencies
```

This installs: **Pester 5.x**, **PSScriptAnalyzer**, **ps2exe**

### Running Tests

```powershell
# All tests (180+ total)
.\Invoke-Tests.ps1

# Unit tests only (fast, no integration overhead)
.\Invoke-Tests.ps1 -Tag Unit

# Integration tests only
.\Invoke-Tests.ps1 -Tag Integration

# CI mode -- generates NUnit XML and JaCoCo coverage XML
.\Invoke-Tests.ps1 -CI
```

### Building the EXE

```powershell
# Full build: clean, analyze, test, compile
Invoke-Build

# Quick build (skip tests, useful during active development)
Invoke-Build QuickBuild

# Release package (ZIP + EXE)
Invoke-Build Release
```

See `TESTING.md` for complete developer testing guide.
