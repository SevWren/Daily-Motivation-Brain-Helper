# Daily Motivation Brain Helper

> Schedule tomorrow's working folder in 2 clicks.  
> At 2 PM, a motivational popup opens it for you.  
> No code. No config files. No manual steps.

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
|   |   +-- ConfigManager.Tests.ps1     # 100+ tests for ConfigManager module
|   |   +-- TaskScheduler.Tests.ps1     # 80+ tests for TaskScheduler module
|   +-- Integration/
|   |   +-- Initialization.Tests.ps1    # Integration tests (Issues #2-#8)
|   +-- Fixtures/                # Test data files
|   +-- README.md                # Test suite documentation
|
+-- .build.ps1                    # Invoke-Build automation (12 tasks)
+-- Invoke-Tests.ps1              # Test runner with CI support
+-- .PSScriptAnalyzerSettings.psd1  # Code quality configuration
+-- PesterConfiguration.psd1      # Test suite configuration
+-- TESTING.md                    # Testing guide
+-- docs/reports/                     # Historical session reports and audit artifacts
|
+-- .github/workflows/
|   +-- test.yml                  # CI/CD pipeline (automated tests)
|
+-- docs/                         # All planning and specification documents
    +-- README.md                 # Document index
    +-- SPRINT_PLAN.md            # 16-task sprint plan (4 sprints)
    +-- FEATURE_BRAINSTORM.md     # 14 approved features + approval record
    +-- DOC_IMPACT_ANALYSIS.md    # Impact analysis (17 docs, 132 changes)
    +-- NEXT_STEPS.md             # Original 13-task backlog
    +-- PRD.md                    # Product Requirements (FR-001 -- FR-025)
    +-- USER_STORIES.md           # US-001 -- US-018
    +-- ARCHITECTURE.md           # System design and module map
    +-- UX_SPEC.md                # Wireframes and tooltip spec
    +-- ... (23 more planning docs)
```

---

## Installation

### Requirements

- Windows 10 (build 19041+) or Windows 11
- PowerShell 5.1 (included with Windows)
- .NET Framework 4.x (included with Windows)
- No internet connection required

### Steps

**1.** Extract to a folder, e.g. `C:\DailyMotivation\`

**2.** Right-click `UpdateScheduledTask.ps1` -- Run with PowerShell (as Administrator)  
 This copies modules to `%APPDATA%` and initializes config files.

**3.** Run the app:

```powershell
powershell.exe -STA -ExecutionPolicy Bypass -File "C:\DailyMotivation\src\MainApp.ps1"
```

**4.** (Optional) Install Explorer right-click integration:  
 Right-click `src\ShellExtension\Register-ShellExtension.ps1` -- Run as Administrator

---

## Features

| Feature                    | Description                                   |
| -------------------------- | --------------------------------------------- |
| Folder Picker + Drag-Drop  | Select via dialog or drag from Explorer       |
| Schedule Today or Tomorrow | Option shown when before 2 PM                 |
| Remember Last Folder       | One-click reschedule banner on next launch    |
| Recent Folders List        | Top 5 previously scheduled folders            |
| Undo Schedule              | 30-second grace period after scheduling       |
| Duplicate Warning          | Warns before creating a duplicate task        |
| Motivational Popup         | 10 default messages, random selection         |
| Folder Name in Popup       | "Opening: FolderName" subtitle                |
| Snooze Duration Choice     | 5 / 15 / 30 / 60 minute options               |
| Dismiss for Today          | Cancel all re-triggers without opening folder |
| Moved Folder Re-Pick       | Re-pick if folder was renamed/moved           |
| First-Run Welcome Screen   | One-time onboarding overlay                   |
| Tooltips on All Controls   | Plain-English hover text on every button      |
| Task History Viewer        | In-app log of past outcomes                   |
| Task Management            | View and delete scheduled tasks               |
| Explorer Shell Extension   | Right-click any folder to schedule it         |
| Named Mutex                | Prevents duplicate popups                     |
| %APPDATA% Config           | User never edits any file                     |

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

### Test Coverage

- **ConfigManager.psm1**: ~90% coverage (100+ tests)
- **TaskScheduler.psm1**: ~85% coverage (80+ tests)
- **Integration**: End-to-end scenarios for initialization bugs

See [TESTING.md](TESTING.md) and [Tests/README.md](Tests/README.md) for details.

---

## Diagnostics

| File                                                  | Purpose                          |
| ----------------------------------------------------- | -------------------------------- |
| `%TEMP%\DailyMotivation_debug.log`                    | Popup script debug trace         |
| `%APPDATA%\DailyMotivationBrainHelper\popup_log.txt`  | Outcome history (pipe-delimited) |
| `%APPDATA%\DailyMotivationBrainHelper\launch_log.txt` | Launcher log                     |

---

## Documentation

See [`docs/README.md`](docs/README.md) for the full planning document index.

---

## License

MIT -- see [LICENSE](LICENSE)
