# src/ — Daily Motivation Brain Helper

This directory contains all runnable source files for the Daily Motivation Brain Helper application.

## File Map

| File | Purpose |
|------|---------|
| `MainApp.ps1` | WPF main application entry point — run with `-STA` flag |
| `MainWindow.xaml` | Main window UI layout (dark theme) |
| `DailyMotivation.ps1` | Motivational popup — fired by Windows Task Scheduler at scheduled time |
| `LaunchMotivation.bat` | Task Scheduler wrapper — launches PowerShell with all required flags |
| `UpdateScheduledTask.ps1` | One-time setup script — copies modules, initialises config, registers placeholder task (run as Admin) |
| `popup_config.json` | Active task config — written by the app on schedule, read by the popup at fire time |
| `Modules/ConfigManager.psm1` | All JSON config I/O — settings, tasks, history log, error dialogs |
| `Modules/TaskScheduler.psm1` | Windows Task Scheduler CRUD wrapper |
| `data/messages.json` | 10 default motivational messages (glyph + title + body) |
| `ShellExtension/` | Optional: Explorer right-click integration (B-13, Sprint 4) |

## Implemented Features

- [x] WPF main window (dark theme)
- [x] Folder picker dialog + drag-and-drop (B-09)
- [x] Schedule for Today or Tomorrow (B-03)
- [x] Remember last folder — one-click reschedule banner (B-01)
- [x] Recent folders list with Schedule Again buttons (B-02)
- [x] Undo schedule — 30-second grace period with countdown (B-04)
- [x] Duplicate schedule warning (B-16)
- [x] Network path detection and warning (GAP-010)
- [x] Motivational popup with 20-second countdown (WPF, dark theme)
- [x] 10 default messages, random selection (TASK-010)
- [x] Folder name subtitle in popup — "Opening: FolderName" (B-12)
- [x] Snooze split-button — 5 / 15 / 30 / 60 min (B-10)
- [x] Dismiss for Today — cancels all re-triggers (B-11)
- [x] Moved folder re-pick prompt (B-05)
- [x] Named mutex — one popup at a time (SSOT-006)
- [x] Task history viewer in main window (B-18)
- [x] Task list display and deletion (TASK-008, TASK-009)
- [x] First-run welcome overlay (B-07)
- [x] Tooltips on all UI controls (B-19)
- [x] Task Scheduler health check at startup (TASK-012)
- [x] All config in `%APPDATA%\DailyMotivationBrainHelper\` (SSOT-007)
- [x] RunAtLogon missed-trigger recovery (NPR-004)
- [x] Explorer right-click shell extension (B-13, optional)

## Running the App

```powershell
# Main application
powershell.exe -STA -ExecutionPolicy Bypass -File "src\MainApp.ps1"

# Popup only (for testing, as Task Scheduler would call it)
.\src\LaunchMotivation.bat

# One-time setup (run as Admin on first install)
.\src\UpdateScheduledTask.ps1
```

## Config Files (all under `%APPDATA%\DailyMotivationBrainHelper\`)

| File | Purpose |
|------|---------|
| `popup_config.json` | Active task: glyph, title, body, explorer_path, folder_name, task_id |
| `tasks.json` | All scheduled task records |
| `app_settings.json` | firstRun flag, lastFolder, recentFolders[], theme |
| `messages.json` | Message library (copied from `src/data/messages.json` on first run) |
| `popup_log.txt` | Pipe-delimited outcome log |

## Log Files

| File | Purpose |
|------|---------|
| `%TEMP%\DailyMotivation_debug.log` | Popup script trace |
| `%APPDATA%\DailyMotivationBrainHelper\launch_log.txt` | Launcher trace |

## Testing & Build Infrastructure

| File/Directory | Purpose |
|----------------|---------|
| `../Tests/` | Pester 5.x test suite (180+ tests) |
| `../Tests/Unit/ConfigManager.Tests.ps1` | Unit tests for ConfigManager module (100+ tests) |
| `../Tests/Unit/TaskScheduler.Tests.ps1` | Unit tests for TaskScheduler module (80+ tests) |
| `../Tests/Integration/Initialization.Tests.ps1` | Integration tests for initialization (Issues #2-#8) |
| `../Tests/Fixtures/` | Test data files (sample JSON configs) |
| `../Tests/README.md` | Test suite documentation |
| `../.build.ps1` | Invoke-Build automation script (12 build tasks) |
| `../Invoke-Tests.ps1` | Test runner with tag filtering and CI support |
| `../.PSScriptAnalyzerSettings.psd1` | Code quality rules (enforced in CI) |
| `../PesterConfiguration.psd1` | Test suite configuration |
| `../.github/workflows/test.yml` | CI/CD pipeline (GitHub Actions) |
| `../TESTING.md` | Complete testing guide |
| `../MODERN-POWERSHELL-SCAFFOLDING.md` | Infrastructure overview |

### Development Workflow
```powershell
# Install dependencies
Invoke-Build InstallDependencies

# Run tests
..\Invoke-Tests.ps1              # All tests
..\Invoke-Tests.ps1 -Tag Unit    # Unit tests only
..\Invoke-Tests.ps1 -CI          # With coverage reports

# Build
Invoke-Build                     # Full build (clean, analyze, test, build)
Invoke-Build QuickBuild          # Skip tests
Invoke-Build Release             # Create release package
```

### Test Coverage
- **ConfigManager.psm1**: ~90% coverage
  - Initialize-AppData (directory creation, defaults)
  - Settings management (firstRun, lastFolder, recentFolders)
  - Popup configuration (all 6 fields)
  - Outcome logging (write/read/parse)
  - UTF-8 encoding for international paths
  - Error recovery for corrupted files

- **TaskScheduler.psm1**: ~85% coverage
  - Task CRUD operations
  - Duplicate detection (case-insensitive, Force flag)
  - Status enum validation (5 states)
  - Network path detection (UNC paths)

- **Integration Tests**: End-to-end initialization scenarios
  - Fresh installation (Issue #2 - PASSING)
  - Module import order independence (Issue #4 - PASSING)
  - Issues #3, #5, #6, #7 (tests skipped, pending fixes)

See `../TESTING.md` for complete testing documentation.
