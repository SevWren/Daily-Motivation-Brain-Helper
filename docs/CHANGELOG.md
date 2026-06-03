# Changelog

All notable changes documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)

---

## [v1.0.0-dev] -- 2026-06-03 (In Development)

### Added -- Test Infrastructure (commit 4ba633a)

- Modern PowerShell test infrastructure with **180+ Pester 5.x tests**
- `Tests/Unit/ConfigManager.Tests.ps1` -- 100+ unit tests for ConfigManager module
  - Initialize-AppData directory creation and default file deployment
  - Settings management (firstRun, lastFolder, recentFolders)
  - Recent folders FIFO queue (max 5, deduplication, newest-first)
  - Popup configuration (all 6 fields including folder_name derivation)
  - Outcome logging (write/read/clear/parse pipe-delimited log)
  - UTF-8 encoding preservation for international paths and emoji glyphs
  - Error recovery for corrupted JSON files (graceful degradation)
- `Tests/Unit/TaskScheduler.Tests.ps1` -- 80+ unit tests for TaskScheduler module
  - Task creation with unique 16-char IDs and ISO 8601 timestamps
  - Duplicate detection (case-insensitive, same folder+date, Force flag override)
  - Task CRUD operations (create, read, update status, delete)
  - Status enum validation (all 5 values: PENDING/COMPLETED/SNOOZED/DISMISSED/DELETED)
  - Network path detection (UNC paths)
- `Tests/Integration/Initialization.Tests.ps1` -- Integration tests
  - Fresh installation flow (Issue #2 - PASSING)
  - Module import order independence (Issue #4 - PASSING)
  - Issues #3, #5, #6, #7 documented with skipped tests pending fixes
  - End-to-end workflow validation (init → task creation → logging)
  - UTF-8 preservation across entire system
- `Tests/Fixtures/` -- Test data files (sample JSON configurations)
- `Tests/README.md` -- Comprehensive test suite documentation
- **Invoke-Build automation system** (`.build.ps1`)
  - 12 build tasks: Clean, Analyze, Test, Build, Package, Release, QuickBuild, etc.
  - PSScriptAnalyzer static analysis integration
  - Pester test execution with code coverage
  - PS2EXE compilation
  - Release package creation
- **Test runner** (`Invoke-Tests.ps1`)
  - Tag-based test filtering (Unit, Integration, Initialization)
  - CI mode with NUnit XML and JaCoCo coverage reports
  - Colored console output with test summary
  - Error exit codes for CI/CD pipelines
- **PSScriptAnalyzer configuration** (`.PSScriptAnalyzerSettings.psd1`)
  - Custom rules: no cmdlet aliases (except cd/ls), consistent formatting
  - 4-space indentation, UTF-8 encoding enforcement
  - Comment-based help validation
- **GitHub Actions CI/CD pipeline** (`.github/workflows/test.yml`)
  - Automated testing on push/PR
  - Code coverage reporting with PR comments
  - PSScriptAnalyzer with SARIF output for GitHub Security
  - Build artifact generation
- **Comprehensive documentation**
  - `TESTING.md` -- Complete testing guide (usage, best practices, debugging)
  - `MODERN-POWERSHELL-SCAFFOLDING.md` -- Infrastructure overview and modern PowerShell practices
- Code coverage: ~85% for ConfigManager and TaskScheduler modules (target: 80%+)

### Added -- Core Application

- `src/MainApp.ps1` -- WPF main application window
- `src/MainWindow.xaml` -- Full UI layout (dark theme)
- `src/Modules/ConfigManager.psm1` -- All JSON config management
- `src/Modules/TaskScheduler.psm1` -- Windows Task Scheduler wrapper module
- `src/data/messages.json` -- 10 default motivational messages

### Added -- Features

- **B-01** Remember Last Folder -- one-click reschedule banner on launch
- **B-02** Recent Folders List -- top 5 with Schedule Again buttons
- **B-03** Schedule For Today -- option shown when before 2:00 PM
- **B-04** Undo Schedule -- 30-second grace period after scheduling
- **B-05** Moved Folder Re-Pick -- popup re-pick prompt when path missing
- **B-07** First-Run Welcome Screen -- one-time onboarding overlay
- **B-09** Drag-and-Drop -- drop folder from Explorer onto app window
- **B-10** Snooze Duration Choice -- 5 / 15 / 30 / 60 minute split-button
- **B-11** Dismiss for Today -- cancel all re-triggers without opening folder
- **B-12** Show Folder Name in Popup -- "Opening: FolderName" subtitle
- **B-13** Shell Extension -- Explorer right-click "Schedule for Tomorrow at 2 PM"
- **B-16** Duplicate Schedule Warning -- confirmation dialog before duplicate
- **B-18** Task History Viewer -- in-app outcome log panel
- **B-19** Tooltips on All Controls -- plain-English hover text everywhere

### Added -- Reliability

- Named mutex (SSOT-006): only one popup can run at a time
- Path validation (Security MEDIUM): explorer_path verified before launch
- RunAtLogon missed-trigger recovery (NPR-004)
- Task Scheduler health check at startup (TASK-012)
- All config in `%APPDATA%\DailyMotivationBrainHelper\` (SSOT-007, TASK-013)
- Structured pipe-delimited outcome log (parseable by History Viewer)

### Added -- Shell Extension (B-13)

- `src/ShellExtension/MotivationShellExt.cs` -- COM IContextMenu implementation
- `src/ShellExtension/Register-ShellExtension.ps1` -- compile + register
- `src/ShellExtension/ShellBridge.ps1` -- PowerShell bridge for DLL

### Updated -- Prototype Files

- `src/DailyMotivation.ps1` -- full rewrite incorporating all popup features
- `src/LaunchMotivation.bat` -- updated to use `%APPDATA%` config path
- `src/UpdateScheduledTask.ps1` -- now handles full setup (module copy, init)

### Added -- Documentation (29 files in docs/)

- SPRINT_PLAN.md, FEATURE_BRAINSTORM.md, DOC_IMPACT_ANALYSIS.md
- All 17 planning docs refreshed for 14 approved features (132 changes)
- Full traceability from user story through FR through AC through TC

---

## [Prototype] -- 2026-05-21 (Initial Prototype)

### Added
- DailyMotivation.ps1 -- WPF motivational popup (original prototype)
- LaunchMotivation.bat -- Task Scheduler launcher wrapper
- UpdateScheduledTask.ps1 -- one-time task registration
- popup_config.json -- hardcoded config (replaced by app in v1.0)
