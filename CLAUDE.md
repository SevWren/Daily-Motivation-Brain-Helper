# CLAUDE.md — Daily Motivation Brain Helper

## Architecture

**One file, one exe.**

```
DailyMotivation.ps1  →  Invoke-ps2exe -STA -noConsole  →  DailyMotivation.exe
```

The compiled exe is fully self-contained. No `src/`, no companion files, no setup script.

## Execution Modes

| Invocation | Mode | When |
|------------|------|------|
| `DailyMotivation.exe` | `main` | User double-clicks the exe |
| `DailyMotivation.exe /popup` | `popup` | Windows Task Scheduler fires |
| `DailyMotivation.exe /setfolder "C:\path"` | `setfolder` | Explorer right-click context menu |

## Script Sections

| Section | Contents |
|---------|----------|
| 1 | `param($Mode, $FolderPath, [switch]$NoRun)` |
| 2 | Assembly loading (WPF + WinForms); exits only if `-not $NoRun` on failure |
| 3 | Config functions: `Initialize-AppData`, `Get-Config`, `Save-Config`, `Get/Set-PopupConfig`, `Write-OutcomeLog`, `Show-ErrorDialog` |
| 4 | Task Scheduler: `Get/Save-TasksJson`, `New-MotivationTask`, `Get-MotivationTasks`, `Remove-MotivationTask` |
| 5 | Context menu: `Register-ContextMenu`, `Unregister-ContextMenu` (HKCU, no admin) |
| 6 | Main window XAML (`[xml]$MainXaml`) |
| 7 | `function Show-MainWindow { }` |
| 8 | Popup window XAML (`[xml]$PopupXaml`) |
| 9 | `function Show-PopupWindow { }` |
| 10 | `$Messages = @(...)` + `function Get-RandomMessage { }` |
| 11 | Entry point: `if (-not $NoRun) { Initialize-AppData; switch($Mode) { ... } }` |

## Config Files (all in `%APPDATA%\DailyMotivationBrainHelper\`)

| File | Contents |
|------|----------|
| `config.json` | `{"default_trigger_hour": 14, "task_warning_threshold": 5}` |
| `popup_config.json` | Written by `main`/`setfolder` mode, read by `popup` mode |
| `tasks.json` | Scheduled task list |
| `popup_log.txt` | Pipe-delimited outcome history |

## Build

```powershell
.\build.ps1
```

Requires `ps2exe` module: `Install-Module ps2exe -Scope CurrentUser`

## Test

```powershell
.\Invoke-Tests.ps1               # all tests
.\Invoke-Tests.ps1 -CI           # CI mode (exit code, XML reports)
```

Tests dot-source the script with `-NoRun` — no exe required to run tests.

## Key Design Constraints

- PowerShell 5.1 / .NET 4.x only (no PS 6+/7+ features, no `pwsh`)
- STA thread model required for WPF (`-STA` baked in by ps2exe)
- Named mutex `Global\DailyMotivationBrainHelperPopup` enforces single popup
- Task Scheduler action calls `$script:ExePath /popup` (captured at runtime via `$MyInvocation.MyCommand.Path`)
- Tests override `$script:ExePath` before calling `New-MotivationTask`
- FIX-001: `Initialize-AppData` re-resolves all paths from `$env:APPDATA` at call time (enables test redirects)
- FIX-003: `Get-TasksJson` wraps result in `@()` to handle PS 5.1 returning `$null` for `"[]"` JSON

## Requirements Reference

See `DailyMotivationBrainHelper_TechnicalReflection_2026-06-12_v2_1_CORRECTED.md` (kept outside repo) for the full requirements, NFRs, success criteria, and phased roadmap.
