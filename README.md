# Daily Motivation Brain Helper

> Schedule tomorrow's working folder in 2 clicks.  
> At 2 PM, a motivational popup opens it for you.  
> No code. No config files. No manual steps.

---

## Project status

**Current development is taking place on the `project-restart-pwsh7` branch.**

The project is being migrated from **Windows PowerShell 5.1** to **PowerShell 7**. The migration's primary goal is to enable a cross-platform development workflow so contributors can work from Linux and macOS environments while the codebase remains consistent.

Important notes:

- Development tooling and active contributions are moving to PowerShell 7 to support non-Windows development environments.
- Windows 10/11 remains the primary runtime target for end users; runtime support on non-Windows platforms is minimal and limited to development scenarios unless a clear need arises.
- For the latest features and ongoing development, use the `project-restart-pwsh7` branch. The `main` branch continues to contain the stable Windows PowerShell 5.1 implementation and is the recommended release for users running the application on Windows.

## Branches

- `main` — Stable, user-targeted codebase (Windows PowerShell 5.1).
- `project-restart-pwsh7` — Active development branch targeting PowerShell 7 (recommended for contributors who want the latest features and the cross-platform development setup).

---

## How It Works

1. **Open the app** -- `MainApp.ps1`
2. **Select your folder** (picker dialog or drag-and-drop)
3. **Click Schedule** -- done

At 2 PM the next day (or today, if before 2 PM), a popup appears with a motivational message.
Click **Open Folder** and Windows Explorer opens your folder automatically.

---

## Repository Structure

```
Daily-Motivation-Brain-Helper/
|
+-- src/                          # All runnable source files
|   +-- MainApp.ps1               # Main application entry point (WPF)
|   +-- MainWindow.xaml           # Main window UI layout
|   +-- DailyMotivation.ps1       # Motivational popup (run by Task Scheduler)
|   +-- LaunchMotivation.bat      # Task Scheduler launcher wrapper
|   +-- UpdateScheduledTask.ps1   # One-time setup script (run as Admin)
|   |
|   +-- Modules/
|   |   +-- ConfigManager.psm1    # All JSON read/write, settings, history log
|   |   +-- TaskScheduler.psm1    # Windows Task Scheduler wrapper module
|   |
|   +-- data/
|   |   +-- messages.json         # 10 default motivational messages
|   |
|   +-- ShellExtension/           # Optional: Explorer right-click integration
|       +-- MotivationShellExt.cs          # COM shell extension (C#)
|       +-- Register-ShellExtension.ps1    # Compile + register (run as Admin)
|       +-- ShellBridge.ps1                # PowerShell bridge called by DLL
|
+-- Tests/                        # Pester 5.x test suite (180+ tests)
|   +-- Unit/
|   +-- Integration/
|   +-- Fixtures/
|   +-- README.md                # Test suite documentation
|
+-- .build.ps1                    # Invoke-Build automation (12 tasks)
+-- Invoke-Tests.ps1              # Test runner with CI support
+-- .PSScriptAnalyzerSettings.psd1  # Code quality configuration
+-- PesterConfiguration.psd1      # Test suite configuration
+-- TESTING.md                    # Testing guide
+-- docs/reports/                 # Historical session reports and audit artifacts
|
+-- .github/workflows/
|   +-- test.yml                  # CI/CD pipeline (automated tests)
|
+-- docs/                         # All planning and specification documents
    +-- README.md                 # Document index
```

---

## Installation

### Requirements

- Windows 10 (build 19041+) or Windows 11
- PowerShell 5.1 (included with Windows)
- .NET Framework 4.x (included with Windows)
- No internet connection required

### Steps

1. Extract to a folder, e.g. `C:\DailyMotivation\`
2. Right-click `UpdateScheduledTask.ps1` -- Run with PowerShell (as Administrator)  
   This copies modules to `%APPDATA%` and initializes config files.
3. Run the app:

```powershell
powershell.exe -STA -ExecutionPolicy Bypass -File "C:\DailyMotivation\src\MainApp.ps1"
```

4. (Optional) Install Explorer right-click integration:  
   Right-click `src\ShellExtension\Register-ShellExtension.ps1` -- Run as Administrator

---

## Features

- Folder Picker + Drag-Drop
- Schedule Today or Tomorrow (option shown when before 2 PM)
- Remember Last Folder
- Recent Folders List
- Undo Schedule (30-second grace)
- Duplicate Warning
- Motivational Popup with random selection
- Snooze and Dismiss options
- Explorer Shell Extension (optional)

---

## Testing & Development

### Running Tests

```powershell
# All tests (180+ tests across unit and integration suites)
.\Invoke-Tests.ps1

# Unit tests only
.\Invoke-Tests.ps1 -Tag Unit

# Integration tests only
.\Invoke-Tests.ps1 -Tag Integration

# CI mode with coverage reports
.\Invoke-Tests.ps1 -CI
```

### Building

```powershell
# Install development dependencies
Invoke-Build InstallDependencies

# Full build (clean, analyze, test, build)
Invoke-Build

# Quick build (skip tests)
Invoke-Build QuickBuild

# Create release package
Invoke-Build Release
```

See [TESTING.md](TESTING.md) and [Tests/README.md](Tests/README.md) for details.

---

## Contributing

Contributions are welcome. To get started:

1. Fork the repository and create a branch for your change.
2. If your change is a runtime improvement or a Windows-specific fix, target `main`.
3. If your change is part of the PowerShell 7 migration or cross-platform tooling, target `project-restart-pwsh7` and include migration notes.

When submitting pull requests, state which branch your change targets (`main` or `project-restart-pwsh7`) and whether it requires PowerShell 5.1 or PowerShell 7 at runtime.

---

## Support and feedback

Open an issue for bugs, feature requests, or questions. For development-related discussions, referencing the branch (`main` or `project-restart-pwsh7`) in your issue helps route feedback.

---

## License

MIT -- see [LICENSE](LICENSE)

_Last updated: 2026-08-03_
