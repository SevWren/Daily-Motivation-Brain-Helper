# Architecture

**Last Updated:** 2026-06-03

## System Overview

```
┌──────────────────────────────────────────────────────────────┐
│                     Main Application                          │
│                                                               │
│  ┌──────────────┐  ┌───────────────┐  ┌──────────────────┐  │
│  │ Welcome      │  │ Folder Picker │  │  Task Manager UI  │  │
│  │ Overlay (B-07│  │ + Drag-Drop   │  │  (List/Delete)   │  │
│  │ first run)   │  │ (B-09)        │  │                  │  │
│  └──────┬───────┘  └──────┬────────┘  └────────┬─────────┘  │
│         │                 │                     │            │
│  ┌──────▼─────────────────▼─────────────────────▼─────────┐  │
│  │                  Config Manager                          │  │
│  │   lastFolder (B-01) | recentFolders[] (B-02)           │  │
│  │   firstRun flag (B-07) | app_settings.json             │  │
│  └──────────────────────────┬────────────────────────────┘  │
│                              │                               │
│  ┌───────────────────────────▼────────────────────────────┐  │
│  │              Task Scheduler Module                      │  │
│  │  New-MotivationTask(path, triggerTime)  (B-03)         │  │
│  │  Get-MotivationTasks()                                  │  │
│  │  Remove-MotivationTask(id)                              │  │
│  │  Duplicate check (B-16)                                │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐    │
│  │  Undo Banner (B-04) — 30s DispatcherTimer            │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐    │
│  │  History Viewer (B-18) — reads popup_log.txt         │    │
│  └──────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────┘

At Scheduled Time (2 PM):

┌──────────────────────────────────────────┐
│         Notification Engine              │
│  ┌─────────────────────────────────────┐ │
│  │  Motivational Popup (WPF)           │ │
│  │  Subtitle: "Opening: FolderName"    │ │
│  │  (B-12)                             │ │
│  │  [Open Folder] [Snooze ▾] [Dismiss] │ │
│  │  (B-10 split)   (B-11)             │ │
│  └───┬──────────┬──────────┬───────────┘ │
│      │          │          │             │
│ Explorer  Snooze Engine  Dismiss         │
│ Launcher  (B-10 duration  for Today      │
│           + B-11 dismiss) (B-11)         │
│                                          │
│  ┌───────────────────────────────────┐  │
│  │  Path Validation (B-05)           │  │
│  │  If missing → Re-Pick UI          │  │
│  └───────────────────────────────────┘  │
│                                          │
│  Named Mutex: Global\DailyMotivationBrainHelperPopup    │
│  (SSOT-006 enforcement)                  │
└──────────────────────────────────────────┘

Optional (Sprint 4):

┌──────────────────────────────────────────┐
│  Shell Extension (B-13)                  │
│  COM DLL → ShellBridge.ps1               │
│  → Task Scheduler Module                 │
│  → Windows Toast Notification            │
└──────────────────────────────────────────┘
```

## Module Inventory

| Module | Responsibility | New in v1.1 |
|--------|---------------|-------------|
| Main Window | Entry point, welcome overlay, undo banner, layout | B-07, B-04 |
| Folder Picker Module | Picker dialog + drag-drop acceptance | B-09 |
| Task Scheduler Module | Create/list/delete tasks, duplicate check | B-03, B-16 |
| Config Manager | Read/write all JSON; lastFolder, recentFolders, firstRun | B-01, B-02, B-07 |
| Notification Engine | WPF popup, countdown, button handlers, path validation | B-05, B-10, B-11, B-12 |
| Snooze Engine | Duration-parameterised re-trigger scheduling | B-10, B-11 |
| Explorer Launcher | Start-Process explorer.exe after path validation | — |
| Motivation Repository | Random message selection from messages.json | — |
| History Viewer | Parse popup_log.txt and render in UI | B-18 |
| Shell Extension | COM DLL + registry + PowerShell bridge | B-13 |

## Technology Stack
- Language: PowerShell 5.1 + C# (shell extension only)
- UI: WPF (Windows Presentation Foundation)
- Scheduling: Windows Task Scheduler (schtasks COM API)
- Config: JSON files in `%APPDATA%\DailyMotivationBrainHelper\`
- Shell Extension: .NET Framework 4.x COM-visible DLL

## Status
> v1.1

---

## Quality Assurance & Test Infrastructure

### Test Coverage by Module

| Module | Test File | Test Count | Coverage |
|--------|-----------|------------|----------|
| `ConfigManager.psm1` | `Tests/Unit/ConfigManager.Tests.ps1` | 100+ | ~90% |
| `TaskScheduler.psm1` | `Tests/Unit/TaskScheduler.Tests.ps1` | 80+ | ~85% |
| Integration | `Tests/Integration/Initialization.Tests.ps1` | 16 scenarios | N/A |

### Coverage Gap: Notification Engine

`DailyMotivation.ps1` has **zero automated test coverage**. WPF components cannot be
exercised by Pester without a live Windows desktop session. Manual testing (TC-003 through
TC-020 in `docs/TEST_PLAN.md`) remains the validation mechanism for this component.

This is the highest quality risk in the codebase. See `docs/NOTIFICATION_ENGINE_SPEC.md`
for the testing approach roadmap.

### Build Automation (`.build.ps1`)

| Task | Command | Description |
|------|---------|-------------|
| Default | `Invoke-Build` | Clean -> Analyze -> Test -> Build |
| Test only | `Invoke-Build Test` | Run Pester suite |
| Quick build | `Invoke-Build QuickBuild` | Build without tests |
| Release | `Invoke-Build Release` | Full pipeline + package |
| Install deps | `Invoke-Build InstallDependencies` | Install Pester, PSScriptAnalyzer, ps2exe |

### CI/CD Pipeline (`.github/workflows/test.yml`)

Three jobs run on every push and PR:

1. **test** -- PSScriptAnalyzer + Pester suite + coverage upload + PR comment
2. **build** -- PS2EXE compilation; only runs after `test` job passes
3. **analyze** -- PSScriptAnalyzer SARIF for GitHub Security code scanning

**Quality gates (PR merge is blocked if any fail):**
- All Pester tests must pass
- Code coverage must be >= 80%
- PSScriptAnalyzer zero warnings

See `TESTING.md` for developer usage.
