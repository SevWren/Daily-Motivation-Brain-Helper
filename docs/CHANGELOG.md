# Changelog

All notable changes documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)

---

## [v1.0.0-dev] -- 2026-06-03 (In Development)

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
