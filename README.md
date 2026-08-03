# Daily Motivation Brain Helper

> Schedule your working folder for tomorrow in 2 clicks.
> At 2 PM, a motivational popup opens it for you.  
> No code. No config files. No manual steps.

---

> [!WARNING]
> **This branch (`main`) will be replaced by a force push once the migration is complete.**
> The [`project-restart-pwsh7`](../../tree/project-restart-pwsh7) branch is under active development and will be **force-pushed to replace `main`** once the PowerShell 7 migration is complete. After that point, this PowerShell 5.1 version will no longer be maintained. If you need to preserve the PS5.1 build, download a release archive before the switchover.

## Project status

**Current development is taking place on the `project-restart-pwsh7` branch.**

The project is being migrated from **Windows PowerShell 5.1** to **PowerShell 7**. The migration's primary goal is to enable a cross-platform development workflow with a single shared codebase. This allows contributors to develop, run tests, and iterate from cloud-based Linux environments (for example, Claude Code) as well as locally on Windows 10/11.

Important notes:

- PowerShell 7 allows development and test runs on non-Windows systems and cloud IDEs running Linux.
- Windows 10/11 remains the primary runtime target for end users; runtime support outside Windows is currently minimal and intended for development and testing scenarios only.
- For the latest features and active development, use `project-restart-pwsh7`. The `main` branch is the current stable release for Windows PowerShell 5.1 users, but note that it will be superseded once the PowerShell 7 migration is complete (see warning above).

## Branches

- `main` — Stable end-user release (Windows PowerShell 5.1).
- `project-restart-pwsh7` — Active development branch targeting PowerShell 7 (recommended for contributors who want cloud-based Linux development and the latest changes).

---

## How It Works

1. **Open the app** — `MainApp.ps1`
2. **Select your folder** (picker dialog or drag-and-drop)
3. **Click Schedule** — done

If you schedule before 2 PM, the popup appears that same day at 2 PM; otherwise, it appears the following day at 2 PM.
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
+-- docs/                         # All planning and specification documents
|   +-- README.md                 # Document index
|   +-- reports/                  # Historical session reports and audit artifacts
|
+-- .github/workflows/
|   +-- test.yml                  # CI/CD pipeline (automated tests)
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
2. Right-click `UpdateScheduledTask.ps1` — Run with PowerShell (as Administrator)
   Running this script copies modules to `%APPDATA%` and initializes the config files.
3. Run the app:

```powershell
powershell.exe -STA -ExecutionPolicy Bypass -File "C:\DailyMotivation\src\MainApp.ps1"
```

4. (Optional) Install Explorer right-click integration:  
   Right-click `src\ShellExtension\Register-ShellExtension.ps1` — Run as Administrator

---

## Features

- Folder Picker + Drag-Drop
- Schedule Today or Tomorrow (today option available before 2 PM only)
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

## Development

- PowerShell 7 is the recommended environment for contributors. It enables development on cloud-based Linux environments (for example, Claude Code) and local development on Windows 10/11.
- Example: in a Linux or cloud-based container with PowerShell 7 installed, you can run tests with `pwsh -File ./Invoke-Tests.ps1`.

---

## Contributing

Contributions are welcome. To get started:

1. Fork the repository and create a branch for your change.
2. If your change is a runtime improvement or a Windows-specific fix, target `main`.
3. If your change is part of the PowerShell 7 migration or cross-platform tooling, target `project-restart-pwsh7` and include migration notes.

When submitting pull requests, state which branch your change targets (`main` or `project-restart-pwsh7`) and whether it requires PowerShell 5.1 or PowerShell 7 at runtime.

---

## Support and feedback

Open an issue for bugs, feature requests, or questions. For development-related discussions, mentioning the relevant branch (`main` or `project-restart-pwsh7`) in your issue helps maintainers triage it correctly.

---

## License

MIT — see [LICENSE](LICENSE)

_Last updated: 2026-08-03_
